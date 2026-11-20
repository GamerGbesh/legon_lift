#!/usr/bin/env bash
# Regenerates the app's original UI sounds (SPEC 11.6) with ffmpeg synthesis.
# No samples are downloaded; every sound is computed from a formula below.
#
#   assets/sounds/beep_short.ogg  880 Hz, 150 ms, peak -6 dBFS, soft attack, smooth fade out.
#                                 Played for countdown ticks (last 3 s of rest) and small confirmations.
#   assets/sounds/rest_done.ogg   three 988 Hz (B5) beeps of 120 ms with 90 ms gaps, peak -3 dBFS.
#                                 Played when rest ends; WS1 copies it to android/app/src/main/res/raw/
#                                 for the notification channel.
#
# Each tone is a sine with a quiet octave partial (warmer than a bare sine, still a clean "beep"),
# a 5 ms attack and a quadratic release so there are no clicks at either end.
# Output: mono, 44.1 kHz, Ogg Vorbis, metadata stripped and bit-exact so reruns are reproducible.
#
# Usage: tool/make_sounds.sh            (from anywhere; writes into the repo's assets/sounds/)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$repo_root/assets/sounds"
mkdir -p "$out_dir"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found" >&2; exit 1; }

render() { # $1 = output file, $2 = duration (s), $3 = aevalsrc expression
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "aevalsrc=exprs='$3':s=44100:d=$2:c=mono" \
    -c:a libvorbis -q:a 4 -ac 1 -map_metadata -1 -fflags +bitexact -flags:a +bitexact \
    "$1"
}

# Gains are set so the decoded peak lands on the target level. The tone (0.85*fundamental +
# 0.15*octave) peaks near 0.92 and the release has already started at the 5 ms attack point,
# so the gain sits above the plain dBFS value (-6 dBFS = 0.501, -3 dBFS = 0.708).

# beep_short: 150 ms.
beep_len=0.150
beep_expr="0.61*min(1,t/0.005)*pow(1-t/${beep_len},2)*(0.85*sin(2*PI*880*t)+0.15*sin(2*PI*1760*t))"
render "$out_dir/beep_short.ogg" "$beep_len" "$beep_expr"

# rest_done: beeps start every 210 ms (120 ms tone + 90 ms gap); 3 beeps -> 0.54 s total.
# st(0, ...) stores the time since the current beep started; the beep is gated to its first 120 ms.
tone=0.120
period=0.210
rest_expr="st(0,mod(t,${period}));"
rest_expr+="0.86*lt(ld(0),${tone})*min(1,ld(0)/0.005)*pow(max(0,1-ld(0)/${tone}),1.5)"
rest_expr+="*(0.85*sin(2*PI*988*t)+0.15*sin(2*PI*1976*t))"
render "$out_dir/rest_done.ogg" 0.540 "$rest_expr"

for f in "$out_dir"/beep_short.ogg "$out_dir"/rest_done.ogg; do
  size=$(stat -c %s "$f")
  if (( size >= 60 * 1024 )); then
    echo "error: $f is $size bytes (limit 60 KB)" >&2
    exit 1
  fi
  echo "wrote ${f#"$repo_root"/} ($size bytes)"
done
