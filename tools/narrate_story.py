"""Records Story Mode with ElevenLabs: the narration and every character's
own lines, each in their own voice (CAST).

Each line of each book becomes audio/story/<fighter>/<key>.ogg, which
story_dialogue.gd plays when the line comes up (and turns the page after).
A manifest remembers what text and voice each file was made from, so a
re-run only records new or changed lines.

  python tools/narrate_story.py --voice bill --cast  # narration and dialogue

  python tools/narrate_story.py --sample            # one line, every candidate voice
  python tools/narrate_story.py --voice george      # every book
  python tools/narrate_story.py --voice george --only ish sab
  python tools/narrate_story.py --voice george --dry-run

The API key is read from ELEVENLABS_API_KEY in the git-ignored .env; it is
never printed or written anywhere else.
"""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"C:\Users\aashi\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
# ElevenLabs' stock narrators (premade voices any account can use).
VOICES = {
    "george": "JBFqnCBsd6RMkjVDRZzb",   # warm British storyteller
    "brian": "nPczCjzI2devNBz1zQrb",    # deep, resonant American narrator
    "daniel": "onwK4e9ZLuTAKqWW03F9",   # authoritative British broadcaster
    "bill": "pqHfZKP75CvOlQylNhV4",     # weathered, trustworthy documentary voice
}
MODEL = "eleven_multilingual_v2"
# Cinematic: unhurried and expressive, still steady from line to line.
SETTINGS = {"stability": 0.42, "similarity_boost": 0.8, "style": 0.38, "use_speaker_boost": True}
SAMPLE_LINE = "Then the letter came. The same one, sealed, to all six of the master's old students."
# Who speaks each fighter's lines (ElevenLabs premade voices).
CAST = {
    "anant": "pNInz6obpgDQGcFmaJgB",   # Adam: dominant, firm - the master
    "ish": "TX3LPaxmHKxFdv7VOQHJ",     # Liam: energetic, young - the tea-stall dreamer
    "sab": "N2lVS1w4EtoT3dr4eOWO",     # Callum: husky trickster - the lazy joker
    "bib": "SOYHLrjzK2X1ezoPC6cr",     # Harry: fierce young warrior - facing his fear
    "abhi": "IKne3meq5aSn9XLyUdCD",    # Charlie: deep, confident, energetic - the showman
    "anug": "iP95p4xoKVk53GoZ742B",    # Chris: charming, down to earth - the last line
    "sup": "cjVigY5qzO86Huf0OWal",     # Eric: smooth - the spiral
}
# Characters act more than the narrator: a little looser, more style.
CAST_SETTINGS = {"stability": 0.38, "similarity_boost": 0.8, "style": 0.45, "use_speaker_boost": True}


def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No ELEVENLABS_API_KEY in .env")


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def speakable(text):
    """What the narrator reads: shouted capitals read as words."""
    text = text.replace("\u2026", "...")
    return re.sub(r"\b([A-Z]{2,}(?:\s+[A-Z]{2,})*)\b", lambda m: m.group(1).capitalize(), text)


def tts(key, voice_id, text, settings=None):
    body = json.dumps({"text": speakable(text), "model_id": MODEL, "voice_settings": settings or SETTINGS}).encode()
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice_id,
        data=body, headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        return urllib.request.urlopen(req, timeout=120).read()
    except urllib.error.HTTPError as e:
        detail = e.read()[:300].decode("utf-8", "ignore")
        sys.exit("ElevenLabs refused (%d): %s" % (e.code, detail))


def to_ogg(mp3_bytes, out_path):
    """A touch of warmth and a small room, levelled for the story screen."""
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp.write(mp3_bytes)
    chain = "highpass=f=70,aecho=0.85:0.6:42|71:0.10|0.06,loudnorm=I=-18:TP=-2:LRA=9"
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", tmp.name, "-af", chain,
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", out_path], check=True)
    os.unlink(tmp.name)


def story_lines():
    out = os.path.join(tempfile.gettempdir(), "whowon_story_lines.json")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools/export_story_lines.gd", "--", out],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with open(out, encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default="george", help="one of %s, or a voice id" % ", ".join(VOICES))
    ap.add_argument("--only", nargs="*", help="fighter ids (ish sab bib abhi anug anant sup)")
    ap.add_argument("--sample", action="store_true", help="record one line with every candidate voice")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--cast", action="store_true", help="also record each character's own lines")
    args = ap.parse_args()
    key = api_key()
    if args.sample:
        out_dir = os.path.join(ROOT, "build", "narrator_samples")
        os.makedirs(out_dir, exist_ok=True)
        for name, vid in VOICES.items():
            path = os.path.join(out_dir, "narrator_%s.ogg" % name)
            to_ogg(tts(key, vid, SAMPLE_LINE), path)
            print("sample", path)
        return
    voice_id = VOICES.get(args.voice, args.voice)
    books = story_lines()
    manifest_path = os.path.join(ROOT, "audio", "story", "narration_manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf-8")) if os.path.exists(manifest_path) else {}
    made = skipped = chars = 0
    for fighter, lines in books.items():
        if args.only and fighter not in args.only:
            continue
        folder = os.path.join(ROOT, "audio", "story", fighter)
        os.makedirs(folder, exist_ok=True)
        for line in lines:
            speaker = line["speaker"]
            if not line["text"].strip() or (speaker != "" and not (args.cast and speaker in CAST)):
                continue
            voice = voice_id if speaker == "" else CAST[speaker]
            path = os.path.join(folder, line["key"] + ".ogg")
            stamp = hashlib.sha1((voice + "|" + line["text"]).encode()).hexdigest()
            rel = "%s/%s" % (fighter, line["key"])
            if os.path.exists(path) and manifest.get(rel) == stamp:
                skipped += 1
                continue
            chars += len(line["text"])
            if args.dry_run:
                print("would record", rel, "|", line["text"][:60])
                continue
            to_ogg(tts(key, voice, line["text"], None if speaker == "" else CAST_SETTINGS), path)
            manifest[rel] = stamp
            made += 1
            print("recorded", rel)
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=1, sort_keys=True)
    print("made %d, already done %d, %d characters" % (made, skipped, chars))


if __name__ == "__main__":
    main()
