"""Records every fighter's built-in fight voice with ElevenLabs, in the same
voice that speaks their story lines (narrate_story.py CAST).

  python tools/voice_fighters.py            # every line not recorded yet
  python tools/voice_fighters.py anant      # just these fighters (remade)

Writes audio/voices/<fighter>/<event>_<n>.ogg. voice_bank.gd plays them for
any moment a player hasn't recorded their own take for. The API key is read
from ELEVENLABS_API_KEY in the git-ignored .env and never printed.
"""
import json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from narrate_story import CAST  # noqa: E402

MODEL = "eleven_multilingual_v2"
# Fight lines are shouted and acted: loose and expressive.
SETTINGS = {"stability": 0.3, "similarity_boost": 0.8, "style": 0.6, "use_speaker_boost": True}
# event -> lines. general: battle cries on big moves; hit: taking a blow;
# landed_hit: after landing a big one; super; call_enemy: the taunt;
# victory; defeat.
LINES = {
    "anant": {
        "general": ["Hah!", "Hyah!", "Focus."], "hit": ["Ngh!", "Hmph!", "Ugh."],
        "landed_hit": ["Too slow.", "Again."], "super": ["Crown Barrage!"],
        "call_enemy": ["Come, student.", "Show me what you have learned."],
        "victory": ["The final word is mine.", "Rise, and train harder."],
        "defeat": ["So... the student surpasses the master."],
    },
    "ish": {
        "general": ["Hyaah!", "Hah!", "Take this!"], "hit": ["Agh!", "Ugh!", "Argh!"],
        "landed_hit": ["Yes!", "Got you!"], "super": ["Flash Hammer!"],
        "call_enemy": ["Come on, I'm ready!", "For the tea stall!"],
        "victory": ["One step closer to the dream!", "That's for everyone at the stall!"],
        "defeat": ["Not yet... not like this."],
    },
    "sab": {
        "general": ["Hup!", "Hoh!", "Here it comes!"], "hit": ["Oof!", "Hey, ow!", "Ugh!"],
        "landed_hit": ["Ha! Felt that?", "Too easy."],
        "call_enemy": ["Wake me when you're ready.", "Come on, I haven't got all day."],
        "victory": ["Ha! Time for a nap.", "Was that it? I barely woke up."],
        "defeat": ["Fine, fine... you win this one."],
    },
    "bib": {
        "general": ["Haa!", "Yaah!", "Keep moving!"], "hit": ["Agh!", "Nngh!", "Ah!"],
        "landed_hit": ["Didn't see that coming!", "Faster!"],
        "call_enemy": ["I'm not afraid anymore!", "Catch me if you can!"],
        "victory": ["I didn't run. Not this time.", "Fear is behind me now."],
        "defeat": ["I... I still have to get stronger."],
    },
    "abhi": {
        "general": ["Hraah!", "Boom!", "Lock in!"], "hit": ["Gah!", "Argh!", "Oof!"],
        "landed_hit": ["Thunder!", "Feel that?"],
        "call_enemy": ["Is that all you got?", "Time to lock in!"],
        "victory": ["Thunder never forgets!", "Remember the name. Kri!"],
        "defeat": ["Lock in... next time, lock in."],
    },
    "anug": {
        "general": ["Hah!", "Save!", "Not past me!"], "hit": ["Ugh!", "Oof!", "Agh!"],
        "landed_hit": ["Clearance!", "Blocked, and back!"],
        "call_enemy": ["Nothing gets past the last line.", "Take your best shot."],
        "victory": ["Clean sheet.", "Nothing gets past me."],
        "defeat": ["You found the gap... well played."],
    },
    "sup": {
        "general": ["Hah!", "Hyah!", "Flow."], "hit": ["Ngh!", "Ah!", "Hmph!"],
        "landed_hit": ["Spiral!", "Keep up."],
        "call_enemy": ["Move with me.", "Feel the rhythm."],
        "victory": ["The spiral always returns.", "Balance is everything."],
        "defeat": ["The circle turns... I will rise again."],
    },
}


def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No ELEVENLABS_API_KEY in .env")


def tts(key, voice_id, text):
    body = json.dumps({"text": text, "model_id": MODEL, "voice_settings": SETTINGS}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice_id,
                                 data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            return urllib.request.urlopen(req, timeout=120).read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(15)
                continue
            sys.exit("ElevenLabs refused (%d): %s" % (e.code, e.read()[:300].decode("utf-8", "ignore")))
        except (ConnectionError, urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(10)


def to_ogg(mp3, path):
    """Starts on the voice, levelled to sit with the fight's sounds."""
    import imageio_ffmpeg
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp.write(mp3)
    chain = ("silenceremove=start_periods=1:start_threshold=-42dB,areverse,"
             "silenceremove=start_periods=1:start_threshold=-42dB,areverse,loudnorm=I=-16:TP=-1.5")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp.name, "-af", chain,
                    "-ar", "44100", "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.unlink(tmp.name)


def main():
    key = api_key()
    chosen = sys.argv[1:] or list(LINES)
    for fighter in chosen:
        folder = os.path.join(ROOT, "audio", "voices", fighter)
        os.makedirs(folder, exist_ok=True)
        made = 0
        for event, lines in LINES[fighter].items():
            for n, text in enumerate(lines):
                path = os.path.join(folder, "%s_%d.ogg" % (event, n + 1))
                if os.path.exists(path) and not sys.argv[1:]:
                    continue
                to_ogg(tts(key, CAST[fighter], text), path)
                made += 1
        print("voiced", fighter, made, "lines", flush=True)


if __name__ == "__main__":
    main()
