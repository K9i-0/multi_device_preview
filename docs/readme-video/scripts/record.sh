#!/bin/zsh
# Records the demo take: the example must be running (mise run example) and
# its window must be 1600x1000 points. Build the helpers first:
#   swiftc -O scripts/post.swift -o scripts/post
#   swiftc -O scripts/wininfo.swift -o scripts/wininfo
# Then convert: ffmpeg -i out/take.mov -vf "crop=3200:1936:0:64,fps=30" \
#   -c:v libx264 -crf 16 -pix_fmt yuv420p -an public/take.mp4
# Event times land in out/events.log; edit-manifest.json frames come from
# them (round(seconds * 30)) and were checked against the footage.
set -e
P="$(cd "$(dirname "$0")" && pwd)/post"
cd "$(dirname "$0")/.."
mkdir -p out
RECT=$(scripts/wininfo | awk '{print $2","$3","$4","$5}')
$P click 274 516; sleep 0.8; $P click 1516 28; sleep 3
osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "multi_device_preview") to true'
$P click 0 0 >/dev/null 2>&1 || true
rm -f out/take.mov out/events.log
T0=$(python3 -c 'import time;print(time.time())')
screencapture -v -C -k -V 30 -R "$RECT" out/take.mov &
ev(){ python3 -c "import time;print(f'{time.time()-$T0:.3f} $1')" >> out/events.log; }
at(){ while (( $(python3 -c "import time;print(int((time.time()-$T0)*1000))") < $1 )); do sleep 0.02; done; }
at 1500; ev drag_up;   $P drag 200 620 -260
at 3700; ev drag_down; $P drag 200 360 260
at 6000; ev tap_item;  $P click 150 494
at 9300; ev tap_back;  $P click 200 524
at 11500; ev tap_search; $P click 200 235
at 12300; ev type_start; for c in l a t t e; do $P type $c; sleep 0.14; done; ev type_end
at 14000; ev enter; $P enter
at 17000; ev add1; $P click 333 302
at 17600; ev add2; $P click 333 302
at 19200; ev cart; $P click 353 174
at 22000; ev close; $P click 274 516
at 23500; ev orders; $P click 204 774
at 25500; ev menu; $P click 91 774
wait
