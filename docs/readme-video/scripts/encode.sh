#!/bin/sh
# Compresses the Remotion master for the GitHub README (keep it well under 10 MB).
set -e
cd "$(dirname "$0")/.."
ffmpeg -v error -y -i out/readme-master.mp4 -an \
  -c:v libx264 -preset veryslow -crf "${CRF:-24}" -profile:v high -level 4.1 \
  -pix_fmt yuv420p -movflags +faststart out/multi_device_preview.mp4
ls -l out/multi_device_preview.mp4
