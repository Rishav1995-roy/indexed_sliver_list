#!/usr/bin/env bash
# Regenerates doc/demo.gif and the screenshots in doc/.
# Usage: tool/make_demo.sh   (from the package root; needs flutter and ffmpeg)
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"
$FLUTTER test --run-skipped -t demo tool/demo/demo_test.dart
mkdir -p doc
ffmpeg -y -loglevel error -framerate 15 -i build/demo_frames/frame_%03d.png \
  -vf "fps=12,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
  -loop 0 doc/demo.gif
ls -l doc/demo.gif
