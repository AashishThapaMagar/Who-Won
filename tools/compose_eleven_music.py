"""Makes the game's music with ElevenLabs Music: the menu theme, one track
per arena and the storybook theme, all Kung Fu Hustle-style swagger played
on Nepali instruments. (Supreme Khatiwada's theme, game_intro_1.mp3, is kept
for the end credits.)

  python tools/compose_eleven_music.py            # every track not made yet
  python tools/compose_eleven_music.py menu terai # just these (remade)

Writes assets/audio/music/<name>.ogg. The API key is read from
ELEVENLABS_API_KEY in the git-ignored .env and never printed.
"""
import json, os, subprocess, sys, tempfile, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")
ALWAYS = (" Instrumental only, no vocals, no singing. Clean studio mix, cinematic film-score quality."
          " Seamless loop: the ending flows back into the opening without a fade-out or a final hit.")
TRACKS = {
    "menu_theme": (120, "Main title theme for a Nepali martial-arts fighting game, in the spirit of a 2000s Hong Kong "
        "kung fu action-comedy score. Opens with a lone sarangi phrase over a deep dhyangro drum, then the full "
        "band kicks in: driving madal and dholak groove, bansuri flute hook, jhyali cymbal accents, narsingha horn "
        "fanfare stabs, pentatonic heroic melody with swagger and a wink of comedy. 140 BPM."),
    "story_theme": (120, "Gentle storybook theme for a Nepali folk tale, sits under a narrator. Slow and warm: soft "
        "sarangi melody, breathy bansuri flute, quiet madal heartbeat, distant singing bowl, sparse tanpura drone. "
        "Nostalgic, wistful, a hint of a kung fu film's quiet before a duel. 70 BPM, low and spacious."),
    "heritage_square": (150, "Night fight in an old Kathmandu temple square under the moon, kung fu standoff. "
        "Tense and stylish: sarangi lead with slides, low bansuri, madal and tabla-like hand drums, temple bells, "
        "jhyali cymbals building into a fast chase section, Hong Kong action-film swagger. 128 BPM."),
    "terai_plains": (150, "Morning fight in a Tharu village on the green plains of southern Nepal. Bright and bouncy: "
        "Tharu folk madal and dholak rhythms, jhyali, bansuri flute runs, bamboo percussion, playful plucked "
        "strings, cheeky Kung Fu Hustle comedy energy with heroic brass-like stabs. 145 BPM."),
    "hill_village": (150, "Morning fight on a ridge village above terraced valleys and the Himalaya. Gurung and "
        "Magar hill folk feel: damphu frame drum and madal groove, sarangi and bansuri trading phrases, "
        "murchunga jaw-harp twang, airy and adventurous, kung fu action pacing with big hits. 136 BPM."),
    "gompa_courtyard": (150, "Sunset duel in a Himalayan Buddhist monastery courtyard, Shaolin-style kung fu. "
        "Dungchen long horn drones, gyaling oboe melody, rolmo cymbals, damaru and big temple drum, singing bowls, "
        "deep wordless drone, building from meditative to a fierce rhythmic battle. 120 BPM."),
    "himalayan_pass": (150, "Epic high-noon duel on a snowy Himalayan pass with prayer flags. Wide and heroic: icy "
        "wind texture, dungchen horns, thundering dhol and taiko-like drums, fast sarangi runs, soaring bansuri, "
        "a grand final-boss kung fu showdown feel. 132 BPM."),
    "dashain_ground": (150, "Festive fight on a Dashain festival ridge with kites and a bamboo swing, in the spirit "
        "of Kung Fu Hustle's comic chase music. Nepali Panche Baja wedding band: shehnai-like sanai lead, "
        "narsingha horn blasts, damaha and dholaki drums, jhyali cymbals, plus madal and bansuri; swaggering, "
        "joyful, mischievous and fast. 150 BPM."),
}


def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No ELEVENLABS_API_KEY in .env")


def compose(key, seconds, prompt):
    body = json.dumps({"prompt": prompt + ALWAYS, "music_length_ms": seconds * 1000, "model_id": "music_v1"}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/music?output_format=mp3_44100_192", data=body,
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        return urllib.request.urlopen(req, timeout=600).read()
    except urllib.error.HTTPError as e:
        sys.exit("ElevenLabs refused (%d): %s" % (e.code, e.read()[:400].decode("utf-8", "ignore")))


def to_ogg(mp3, path):
    import imageio_ffmpeg
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp.write(mp3)
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp.name,
                    "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", path],
                   check=True)
    os.unlink(tmp.name)


def main():
    key = api_key()
    wanted = sys.argv[1:] or [n for n in TRACKS if not os.path.exists(os.path.join(OUT, n + ".ogg"))]
    for name in wanted:
        seconds, prompt = TRACKS[name]
        path = os.path.join(OUT, name + ".ogg")
        to_ogg(compose(key, seconds, prompt), path)
        print("made", name, flush=True)


if __name__ == "__main__":
    main()
