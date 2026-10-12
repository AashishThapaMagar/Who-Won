"""Encode a movie-maker recording (Godot --write-movie .avi) into an MP4 for
Shorts / Reels / TikTok: H.264 (yuv420p, CRF 18), AAC audio, fast start.

    python tools/encode_teaser.py teaser_dashain.avi WhoWon_Dashain_Teaser.mp4
    python tools/encode_teaser.py teaser_dashain.avi --stills out_folder   # one frame every 2 s

Needs ffmpeg: either on PATH or from `pip install imageio-ffmpeg`.
"""
import os
import shutil
import subprocess
import sys


def ffmpeg() -> str:
    found = shutil.which("ffmpeg")
    if found:
        return found
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def main() -> None:
    source = sys.argv[1]
    if len(sys.argv) > 3 and sys.argv[2] == "--stills":
        out = sys.argv[3]
        os.makedirs(out, exist_ok=True)
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", source, "-vf", "fps=0.5,scale=540:-1",
                        os.path.join(out, "still_%02d.jpg")], check=True)
        return
    target = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(source)[0] + ".mp4"
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", source,
                    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", target], check=True)
    print("wrote", target, os.path.getsize(target) // 1024, "KB")


if __name__ == "__main__":
    main()
