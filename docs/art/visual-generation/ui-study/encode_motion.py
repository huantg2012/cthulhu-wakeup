"""Encode the study's complete 24-second cycle at 60 fps.

Usage: python3 encode_motion.py /absolute/frame-directory --ffmpeg /path/to/ffmpeg
Requires Pillow for the pixel-exact loop-boundary check.
"""

import argparse
from pathlib import Path
import subprocess

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "evidence")
    args = parser.parse_args()
    fps, count = 60, 1440
    for frame in range(count + 1):
        path = args.frames / f"frame-{frame:04d}.png"
        if not path.is_file():
            raise SystemExit(f"Missing capture frame: {path}")
    with Image.open(args.frames / "frame-0000.png") as first:
        with Image.open(args.frames / f"frame-{count:04d}.png") as endpoint:
            if first.size != endpoint.size or first.convert("RGB").tobytes() != endpoint.convert("RGB").tobytes():
                raise SystemExit("The cycle endpoint differs from its start. Capture cannot loop seamlessly.")

    args.output.mkdir(parents=True, exist_ok=True)
    source = [args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
              "-framerate", str(fps), "-i", str(args.frames / "frame-%04d.png")]
    # Exclude the repeated endpoint, so playback never holds a duplicated seam frame.
    formats = {
        "mp4": ["-c:v", "libx264", "-crf", "16", "-preset", "fast",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart"],
        # Lossy WebP can quantize neighbouring frames identically and merge them,
        # producing 33 ms holds in the subtle perimeter movement.
        "webp": ["-c:v", "libwebp_anim", "-lossless", "1", "-quality", "100",
                 "-compression_level", "2", "-loop", "0"],
    }
    for extension, options in formats.items():
        destination = args.output / f"peripheral-motion.{extension}"
        temporary = args.output / f"peripheral-motion.pending.{extension}"
        try:
            subprocess.run(source + ["-frames:v", str(count)] + options + [str(temporary)], check=True)
            if extension == "webp":
                with Image.open(temporary) as animation:
                    if animation.n_frames != count:
                        raise SystemExit("WebP merged capture frames, interrupting the 60 fps cadence.")
                    for frame in range(count):
                        animation.seek(frame)
                        animation.load()
                        if animation.info["duration"] not in (16, 17):
                            raise SystemExit("Unexpected WebP frame hold.")
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
        print(f"{destination.name}: {count} frames, {fps} fps, 24 seconds, {destination.stat().st_size} bytes")


if __name__ == "__main__":
    main()
