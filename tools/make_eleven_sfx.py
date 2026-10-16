"""Makes the game's sound effects with ElevenLabs sound generation.

  python tools/make_eleven_sfx.py              # every sound not made yet
  python tools/make_eleven_sfx.py hit_heavy    # just these (remade)

Writes assets/audio/sfx/<name>.ogg, plus <name>_2.ogg, <name>_3.ogg ... for
sounds with variants (sfx.gd picks one at random each time). The API key is
read from ELEVENLABS_API_KEY in the git-ignored .env and never printed.
"""
import json, os, subprocess, sys, tempfile, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
CLEAN = " Single isolated sound effect, dry, close-up, no music, no voice, no background ambience."
# name: (seconds, variants, prompt)
SOUNDS = {
    "hit_light": (0.6, 3, "Fast punch landing on a body in a kung fu movie, tight snappy slap-thump impact."),
    "hit_heavy": (0.8, 3, "Powerful martial-arts kick landing on a body, deep heavy thump with a crack, kung fu film impact."),
    "block": (0.6, 2, "Martial-arts forearm block, a punch stopped by a raised arm, dull leathery smack."),
    "whoosh": (0.5, 3, "Very fast punch swinging through the air, short sharp kung fu whoosh with cloth snap."),
    "whoosh_heavy": (0.7, 2, "Heavy roundhouse kick swinging through the air, deep swoosh with loose cloth trousers flapping."),
    "ko": (2.2, 1, "Knockout in a kung fu film: a fighter falls hard onto a stone courtyard, heavy body thud with a deep cinematic boom and long tail."),
    "round": (2.5, 1, "Single strike of a large bronze Nepali temple bell, warm deep ring with a long natural decay."),
    "fight": (1.6, 1, "One huge dhol drum hit together with a bright cymbal crash, the start of a fight, cinematic and punchy."),
    "menu_move": (0.5, 1, "Tiny soft wooden tick, a small wood block tapped once, gentle user-interface hover click."),
    "menu_confirm": (1.0, 1, "Short bright tap on a small brass singing bowl, clear ting with a quick shimmer, user-interface confirm."),
    "menu_back": (0.5, 1, "Soft low muted knock on wood, user-interface back or cancel sound."),
    "wipe": (1.0, 1, "Quick cinematic transition whoosh, a swift swipe of heavy cloth through the air."),
    "step_walk": (0.5, 4, "One single footstep of a soft leather shoe on old stone paving, calm walking pace."),
    "step_run": (0.5, 4, "One single quick running footstep on stone paving, a light scuff and slap."),
    "jump": (0.5, 1, "A fighter pushing off the ground to jump, short foot scuff and cloth rustle."),
    "land": (0.6, 1, "A fighter landing on stone ground on both feet after a jump, firm thud with a little grit."),
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
    try:
        return urllib.request.urlopen(req, timeout=180).read()
    except urllib.error.HTTPError as e:
        sys.exit("ElevenLabs refused (%d): %s" % (e.code, e.read()[:400].decode("utf-8", "ignore")))


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
