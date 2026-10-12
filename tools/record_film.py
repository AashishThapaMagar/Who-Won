"""Record the cinematic film (scenes/WhoWonFilm.tscn) as a 1920x1080 MP4.

The film draws itself into a 1920x1080 canvas and saves every frame
(FILM_FRAMES), so it records on any monitor; Godot's movie maker runs
alongside at a small window size only to capture the sound. ffmpeg then
joins the frames and the sound.

    python tools/record_film.py out_folder                # -> out_folder/WhoWon_Cinematic.mp4
    python tools/record_film.py out_folder --stills 6,14  # frames at those seconds only

Needs ffmpeg on PATH or `pip install imageio-ffmpeg`.
"""
import glob
import os
import shutil
import subprocess
import sys

GODOT = r"C:\Users\aashi\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENE = "res://scenes/WhoWonFilm.tscn"


def ffmpeg() -> str:
    found = shutil.which("ffmpeg")
    if found:
        return found
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def main() -> None:
    out = os.path.abspath(sys.argv[1])
    os.makedirs(out, exist_ok=True)
    env = dict(os.environ)
    if len(sys.argv) > 3 and sys.argv[2] == "--stills":
        env["FILM_STILLS"] = sys.argv[3]
        env["FILM_OUT"] = out
        subprocess.run([GODOT, "--path", ROOT, "--resolution", "960x540", SCENE], cwd=ROOT, env=env, timeout=900)
        return
    frames = os.path.join(out, "frames")
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    env["FILM_FRAMES"] = frames
    sound = os.path.join(out, "sound.avi")
    subprocess.run([GODOT, "--path", ROOT, "--resolution", "960x540", "--fixed-fps", "30",
                    "--write-movie", sound, SCENE], cwd=ROOT, env=env, timeout=4000)
    count = len(glob.glob(os.path.join(frames, "f*.jpg")))
    print("frames", count)
    target = os.path.join(out, "WhoWon_Cinematic.mp4")
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-framerate", "30", "-i", os.path.join(frames, "f%05d.jpg"),
                    "-i", sound, "-map", "0:v", "-map", "1:a", "-shortest",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", target], check=True)
    print("wrote", target, os.path.getsize(target) // 1024, "KB")


if __name__ == "__main__":
    main()
