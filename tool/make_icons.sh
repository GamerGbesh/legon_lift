#!/usr/bin/env bash
# Rasterises the app icon (SPEC 11.5) from the SVG sources in assets/icon/.
#
#   icon.svg            -> icon_1024.png             legacy / Play-style icon (rounded square, rx 224)
#                       -> icon_512.png              preview
#   icon_background.svg -> icon_background_1024.png  adaptive-icon background (full bleed gradient)
#   icon_foreground.svg -> icon_foreground_1024.png  adaptive-icon foreground (transparent)
#   icon_monochrome.svg -> icon_monochrome_1024.png  Android 13+ themed icon (white on transparent)
#
# After rendering it checks that every visible pixel of the foreground and monochrome layers lies
# inside the adaptive-icon safe zone (circle of radius 313 px = 66/108 of 1024, centred), so no
# launcher mask can clip the art.
#
# Usage:
#   tool/make_icons.sh             render the PNGs only (assets/icon/)
#   tool/make_icons.sh --launcher  also run flutter_launcher_icons, which writes android/** (WS1 /
#                                  integration step: needs the flutter_launcher_icons section of pubspec.yaml)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
icon_dir="$repo_root/assets/icon"
flutter_bin="${FLUTTER_BIN:-$HOME/development/flutter/bin}"

run_launcher=false
for arg in "$@"; do
  case "$arg" in
    --launcher) run_launcher=true ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (librsvg)" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 not found" >&2; exit 1; }

render() { # $1 = svg, $2 = png, $3 = size
  rsvg-convert -w "$3" -h "$3" "$icon_dir/$1" -o "$icon_dir/$2"
  echo "wrote assets/icon/$2"
}

render icon.svg            icon_1024.png            1024
render icon.svg            icon_512.png             512
render icon_background.svg icon_background_1024.png 1024
render icon_foreground.svg icon_foreground_1024.png 1024
render icon_monochrome.svg icon_monochrome_1024.png 1024

# Safe-zone check (needs Pillow). -I keeps the interpreter isolated from the working directory.
python3 -I - "$icon_dir" <<'PY'
import math
import sys
from pathlib import Path

from PIL import Image

SAFE_RADIUS = 1024 * 66 / 108 / 2  # 312.9 px
icon_dir = Path(sys.argv[1])
failed = False
for name in ("icon_foreground_1024.png", "icon_monochrome_1024.png"):
    img = Image.open(icon_dir / name).convert("RGBA")
    if img.size != (1024, 1024):
        print(f"error: {name} is {img.size}, expected 1024x1024", file=sys.stderr)
        failed = True
        continue
    alpha = img.getchannel("A")
    width, height = img.size
    pixels = alpha.load()
    worst = 0.0
    for y in range(height):
        for x in range(width):
            if pixels[x, y] > 8:  # ignore the faintest anti-aliasing fringe
                worst = max(worst, math.hypot(x + 0.5 - 512, y + 0.5 - 512))
    status = "ok" if worst <= SAFE_RADIUS else "OUTSIDE SAFE ZONE"
    print(f"{name}: art reaches radius {worst:.0f} px (safe zone {SAFE_RADIUS:.0f}) {status}")
    failed |= worst > SAFE_RADIUS
sys.exit(1 if failed else 0)
PY

if $run_launcher; then
  (cd "$repo_root" && "$flutter_bin/dart" run flutter_launcher_icons)
fi
