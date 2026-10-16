"""Makes the game's sound effects with ElevenLabs sound generation.

  python tools/make_eleven_sfx.py              # every sound not made yet
  python tools/make_eleven_sfx.py hit_heavy    # just these (remade)

Writes assets/audio/sfx/<name>.ogg, plus <name>_2.ogg, <name>_3.ogg ... for
sounds with variants (sfx.gd picks one at random each time). The API key is
read from ELEVENLABS_API_KEY in the git-ignored .env and never printed.
"""
import json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
CLEAN = (" Realistic cinematic foley, as in a modern martial-arts film: close-miked, punchy, full low end, crisp"
         " transient. One single isolated sound, dry, no music, no voice, no crowd, no background ambience.")
# name: (seconds, variants, prompt)
SOUNDS = {
    "hit_light": (0.6, 3, "A fast bare-knuckle punch landing on a person's face, sharp meaty smack of fist on skin with a tight body thud."),
    "hit_heavy": (0.9, 3, "A brutal full-power kick landing in a man's ribs, deep heavy body thump with a dull crack and the air knocked out, weighty cinematic impact."),
    # Hits by what the blow struck (arena_3d.gd picks from the contact).
    "punch_head": (0.55, 3, "A bare-knuckle punch cracking into a man's jaw, sharp wet slap of knuckles on the face with a snap of the head."),
    "punch_body": (0.6, 3, "A hard punch sinking into a man's stomach, deep muffled thud of a fist into the torso through a cotton shirt."),
    "kick_head": (0.8, 3, "A powerful high kick smashing into a man's head, a loud heavy whack of shin on skull with a deep thud."),
    "kick_body": (0.8, 3, "A roundhouse kick slamming into a man's ribs, a heavy booming body thump with a dull crack."),
    "kick_leg": (0.6, 3, "A low kick chopping into a man's thigh, a sharp heavy slap of shin on leg muscle."),
    "block_heavy": (0.7, 3, "A heavy kick blocked by crossed forearms, a hard bone-on-bone smack with a deep jolting thud."),
    "block": (0.6, 3, "A hard punch stopped by a raised forearm guard, solid bone-on-forearm smack with a short muffled thud."),
    "whoosh": (0.5, 3, "A very fast punch cutting through the air, short sharp swish with the snap of a cotton sleeve."),
    "whoosh_heavy": (0.7, 2, "A powerful spinning kick slicing through the air, deep heavy swoosh with loose trousers whipping."),
    "ko": (2.5, 1, "A knocked-out fighter collapsing onto old stone paving, a heavy limp body slamming to the ground with a deep low boom and slow decaying rumble, slow-motion film moment."),
    "round": (3.0, 1, "One strike of a large bronze bell in a Kathmandu temple at night, deep warm ring with a long natural shimmering decay."),
    "fight": (1.8, 1, "One huge Nepali dhol drum hit together with a bright jhyali cymbal crash, massive and cinematic, the start of a duel."),
    "menu_move": (0.5, 1, "A tiny soft click of a small wooden prayer bead tapped on wood, subtle and clean user-interface tick."),
    "menu_confirm": (1.2, 1, "A single gentle strike of a small brass Tibetan singing bowl, clear ting with a soft shimmering tail."),
    "menu_back": (0.5, 1, "A soft low knock on an old wooden door, muted and short, user-interface back sound."),
    "wipe": (1.0, 1, "A swift cinematic whoosh, a heavy silk cloth swept fast through the air, smooth transition sound."),
    "step_walk": (0.5, 4, "One single footstep of a cloth shoe on old stone paving, calm and grounded, a soft scuff and gentle heel tap."),
    "step_run": (0.5, 4, "One single quick running footstep of a cloth shoe on stone paving, a fast slap with a light grit scuff."),
    "jump": (0.5, 2, "A fighter springing off stone ground into a jump, a short foot push and scuff with a cloth rustle."),
    "land": (0.6, 2, "A fighter landing on stone paving with both feet after a jump, a firm heavy thud with a little grit."),
    "sweep": (0.8, 2, "A leg sweep: a low fast swoosh along the floor ending in a hard slap of a shin against an ankle."),
    "fall": (1.2, 2, "A man swept off his feet crashing flat on his back on stone paving, a heavy body slam thud with a grunt-free exhale of cloth."),
}


def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No ELEVENLABS_API_KEY in .env")


def generate(key, seconds, prompt):
    body = json.dumps({"text": prompt + CLEAN, "duration_seconds": max(0.5, seconds),
                       "prompt_influence": 0.6}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128",
                                 data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            return urllib.request.urlopen(req, timeout=180).read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(20)
                continue
            sys.exit("ElevenLabs refused (%d): %s" % (e.code, e.read()[:400].decode("utf-8", "ignore")))
        except (ConnectionError, urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(10)


def to_ogg(mp3, path, seconds):
    """Starts on the sound (no lead-in silence), peaks evenly, fades out."""
    import imageio_ffmpeg
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp.write(mp3)
    chain = ("silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:%.2f,"
             "afade=t=out:st=%.2f:d=%.2f,dynaudnorm=p=0.9:m=8" % (seconds, seconds * 0.7, seconds * 0.3))
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp.name, "-af", chain,
                    "-ar", "44100", "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.unlink(tmp.name)


def main():
    key = api_key()
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or [n for n in SOUNDS if not os.path.exists(os.path.join(OUT, n + ".ogg"))]
    for name in wanted:
        seconds, variants, prompt = SOUNDS[name]
        for v in range(variants):
            path = os.path.join(OUT, name + ("" if v == 0 else "_%d" % (v + 1)) + ".ogg")
            to_ogg(generate(key, seconds, prompt), path, seconds)
        print("made", name, "x%d" % variants, flush=True)


if __name__ == "__main__":
    main()
