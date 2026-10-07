#!/bin/bash
# Scripted demo: runs ./life under Xvfb, drives it with xdotool, records with ffmpeg x11grab
# and burns a caption for each step into the video. Usage: scripts/record_demo.sh [out.mp4]
# Needs: xvfb, ffmpeg (with libx264 and drawtext), xdotool, Mesa software GL.
set -u
cd "$(dirname "$0")/.."
if [ -z "${DISPLAY:-}" ] || [ -z "${DEMO_IN_XVFB:-}" ]; then
    export DEMO_IN_XVFB=1
    exec xvfb-run -a -s '-screen 0 1280x720x24' "$0" "$@"
fi
OUT=${1:-demo.mp4}
GAME=${GAME:-./life}
SHOTS=${SHOTS:-/tmp/demo-shots}
FONT=${FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}
CAP=/tmp/demo-caption.txt
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$SHOTS"; rm -f "$SHOTS"/*.png
[ -x "$GAME" ] || odin build . -out:"$GAME"

n=0
caption() { printf '%s' "$1" | fmt -w 88 > "$CAP"; }
wait_s() { sleep "$1"; }
shot() { n=$((n+1)); ffmpeg -loglevel error -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 -y "$SHOTS/$(printf %02d $n)-$1.png"; }
key() { xdotool keydown "$1"; sleep .12; xdotool keyup "$1"; sleep "${2:-.35}"; }
# Default camera: zoom 0.75, grid centered. Cell (cx,cy) center -> screen.
cell() { awk -v x="$1" -v y="$2" 'BEGIN{printf "%d %d", 640+(x*8+4-800)*0.75, 360+(y*8+4-480)*0.75}'; }
paint() { local p; p=$(cell "$1" "$2"); set -- $p; xdotool mousemove "$1" "$2"; sleep .05; xdotool mousedown 1; sleep .1; xdotool mouseup 1; sleep .05; }
erase() { local p; p=$(cell "$1" "$2"); set -- $p; xdotool mousemove "$1" "$2"; sleep .05; xdotool mousedown 3; sleep .1; xdotool mouseup 3; sleep .05; }
# stamp X Y row...  ('#' alive)
stamp() { local ox=$1 oy=$2 y=0 row x; shift 2; for row in "$@"; do for ((x=0; x<${#row}; x++)); do [ "${row:$x:1}" = '#' ] && paint $((ox+x)) $((oy+y)); done; y=$((y+1)); done; }
faster() { for ((i=0; i<${1:-20}; i++)); do key Up .06; done; }
slower() { for ((i=0; i<${1:-30}; i++)); do key Down .06; done; }
wheel() { for ((i=0; i<$2; i++)); do xdotool click "$1"; sleep .07; done; sleep .3; }  # 4 = zoom in, 5 = zoom out

launch() {
    $GAME "$@" >> /tmp/demo-game.log 2>&1 &
    GPID=$!
    for i in $(seq 1 60); do WID=$(xdotool search --name 'Odin Life' 2>/dev/null | head -1); [ -n "$WID" ] && break; sleep .1; done
    sleep 1
}
restart() { kill $GPID 2>/dev/null; wait $GPID 2>/dev/null; launch --rle scripts/demo.rle; xdotool mousemove 20 700; sleep .5; }
at() { local p; p=$(cell "$1" "$2"); set -- $p; xdotool mousemove "$1" "$2"; sleep .15; }
: > /tmp/demo-game.log
launch --rle scripts/demo.rle
xdotool mousemove 20 700; sleep 1

caption "starting"
ffmpeg -loglevel error -y -f x11grab -framerate 15 -video_size 1280x720 -i "$DISPLAY" \
    -vf "drawtext=fontfile=$FONT:textfile=$CAP:reload=1:expansion=none:fontcolor=white:fontsize=22:box=1:boxcolor=black@0.65:boxborderw=8:x=24:y=h-95" \
    -c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p "$OUT" &
FPID=$!
sleep 1

caption "1. Launch: HUD visible, default 200x120 grid, paused"; sleep 3; shot launch

caption "2. LMB paint, RMB erase, fast drag leaves no gaps"
stamp 20 8 '#####' '#...#' '#####'; sleep .5
xdotool mousemove 120 150 mousedown 1; sleep .1; xdotool mousemove 520 560; sleep .1; xdotool mousemove 140 560; sleep .1; xdotool mousemove 520 160; sleep .1; xdotool mouseup 1; sleep 1; shot fast-drag
xdotool mousemove 330 100 mousedown 3; sleep .1; xdotool mousemove 330 640; sleep .1; xdotool mouseup 3; sleep 1.5; shot erase
key c 1

caption "3. Painting and erasing while the simulation runs"
key space .5; faster 8
xdotool mousemove 700 200 mousedown 1; sleep .1; xdotool mousemove 1100 450; sleep .1; xdotool mousemove 700 500; sleep .1; xdotool mouseup 1; sleep 1.5; shot paint-running
xdotool mousemove 650 150 mousedown 3; sleep .1; xdotool mousemove 1150 550; sleep .1; xdotool mouseup 3; sleep 1.5; shot erase-running
key space .5; key c 1; slower 30; faster 40   # paused, cleared, speed 120

zin() { at "$1" "$2"; wheel 4 10; }   # zoom in on the pattern so it is legible
zout() { wheel 5 10; xdotool mousemove 20 700; sleep .3; }
caption "4a. Blinker: period 2 (pop stays 3)"
stamp 30 20 '###'; zin 31 20; shot blinker-gen0
key n 1; shot blinker-gen1; key n 1; shot blinker-gen2; key c .3; zout
caption "4b. Block: still life (pop stays 4)"
stamp 30 20 '##' '##'; zin 30 20; shot block-gen0
key n 1; key n 1; shot block-gen2; key c .3; zout
caption "4c. Glider: shifts (+1,+1) every 4 generations"
stamp 30 20 '.#.' '..#' '###'; zin 31 21; shot glider-gen0
key n .5; key n .5; key n .5; key n 1; shot glider-gen4; key c .3; zout

caption "5. Wrap ON: a glider crosses every edge and corner and reappears opposite"
slower 6   # about 31 gen/s
run_glider() {  # label x y rows...
    local label=$1 x=$2 y=$3; shift 3
    stamp "$x" "$y" "$@"; shot "$label-0"; key space .1
    sleep .8; shot "$label-1"; sleep .9; shot "$label-2"; sleep 1.2; shot "$label-3"
    key space .3; key c .4
}
SE=('.#.' '..#' '###'); SW=('.#.' '#..' '###'); NE=('###' '..#' '.#.'); NW=('###' '#..' '.#.')
run_glider wrap-se-right 192 60 "${SE[@]}"
run_glider wrap-se-bottom 100 111 "${SE[@]}"
run_glider wrap-se-corner 192 111 "${SE[@]}"
run_glider wrap-sw-left 4 60 "${SW[@]}"
run_glider wrap-sw-corner 4 111 "${SW[@]}"
run_glider wrap-ne-top 100 6 "${NE[@]}"
run_glider wrap-ne-corner 192 6 "${NE[@]}"
run_glider wrap-nw-corner 4 6 "${NW[@]}"

caption "6. Wrap OFF: glider hits the border and dies or stops as a block"
key w 1
stamp 188 108 '.#.' '..#' '###'
key space .3; shot nowrap-start; sleep 3; shot nowrap-mid; sleep 5; shot nowrap-end
key space .5; key c .5; key w .5

caption "7. Play/pause and stepping: N and Right while paused, N and Right while running"
stamp 100 60 '.#.' '..#' '###'; sleep .3; slower 30; shot step-paused-0
key n .6; key Right .6; shot step-paused-2
key space .3; sleep 1.5; shot play; key n .5; key Right .5; shot step-running; key space .5; shot paused-again
key c .5

caption "8. Speed Up/Down, clamped at 1 and 120 gen/s"
faster 40; sleep .5; shot speed-max
slower 60; sleep .5; shot speed-min
faster 6; sleep .5; shot speed-mid

caption "9. Randomize (~25% alive, generation resets) and clear (all reset to 0)"
key n .5; key n .5; shot before-random
key r 1; shot random
key space .3; sleep 2; key space .3; shot random-stepped
key r 1; shot random-again
key c 1; shot cleared

restart
caption "10. Grid lines (G) at default zoom, then at low and high zoom"
key r .6; key g 1; shot grid-on-default
xdotool mousemove 640 360; wheel 4 12; shot grid-high-zoom
key g 1; shot grid-off-high-zoom; key g .5
wheel 5 30; shot grid-on-low-zoom; key g .5; shot grid-off-low-zoom; key g .3

restart
caption "11. Wheel zoom stays centered on the cursor, clamps at both ends"
stamp 159 33 '##' '##'; xdotool mousemove 1000 200; wheel 4 70; shot zoom-max
xdotool mousemove 300 500; wheel 5 120; shot zoom-min
xdotool mousemove 640 360; wheel 4 12; sleep .3; shot zoom-mid-a
xdotool mousemove 900 250; wheel 4 6; shot zoom-mid-b

restart
caption "12. MMB drag pans: far off the grid and back"
key r .5; xdotool mousemove 640 360; wheel 5 10; shot pan-start
panx() { xdotool mousemove "$1" 360 mousedown 2; sleep .1; for i in $(seq 1 10); do xdotool mousemove_relative -- "$2" 0; sleep .04; done; xdotool mouseup 2; sleep .2; }
for i in $(seq 1 10); do panx 1000 -40; done; sleep .4; shot pan-far
for i in $(seq 1 10); do panx 300 40; done; sleep .4; shot pan-back

caption "13. Clicks and drags outside the grid: no crash, no writes, counters unchanged"
restart; key r .5; xdotool mousemove 640 360; wheel 5 12; xdotool mousemove 20 700; sleep .4; shot outside-before
xdotool mousemove 80 80 mousedown 1; sleep .1; xdotool mousemove 80 700; sleep .1; xdotool mouseup 1; sleep .3
xdotool mousemove 1250 40 mousedown 3; sleep .1; xdotool mousemove 1250 600; sleep .1; xdotool mouseup 3; sleep .8; shot outside-after
xdotool mousemove 100 360 mousedown 1; sleep .1; xdotool mousemove 640 360; sleep .1; xdotool mousemove 1200 360; sleep .1; xdotool mouseup 1; sleep .8; shot outside-through
kill -0 $GPID 2>/dev/null && echo "game still alive after outside clicks" >> /tmp/demo-game.log

caption "14. Window resize while running"
key c .5; key r .8; key space .3
xdotool windowsize "$WID" 900 520; sleep 2; shot resize-small
xdotool windowsize "$WID" 1100 650; sleep 2; shot resize-mid
xdotool windowsize "$WID" 1280 720; sleep 2; shot resize-full
key space .5

restart
caption "15. Counters: blinker pop 3, block pop 4, glider pop 5, clear back to 0"
key c .5; stamp 20 20 '###'; stamp 40 20 '##' '##'; stamp 60 20 '.#.' '..#' '###'
key n .8; shot counters-gen1; key n .8; shot counters-gen2; key n 1; shot counters-gen3; key c 1; shot counters-cleared

caption "16. Stretch: patterns on keys 1-5 (glider, LWSS, Gosper gun, pulsar, R-pentomino), then run"
kill $GPID 2>/dev/null; wait $GPID 2>/dev/null; launch --rle scripts/demo.rle   # fresh default view
xdotool mousemove 20 700; sleep .5
at 30 30; key 1; at 60 30; key 2; at 100 25; key 3; at 150 30; key 4; at 170 90; key 5; at 100 100; xdotool mousemove 20 700; sleep .5; shot patterns
faster 20; key space .3; sleep 4; shot patterns-running; key space .5

caption "17. Stretch: RLE import (L stamps scripts/demo.rle, the 7-cell acorn, at the cursor)"
key c .5; at 100 60; key l 1; xdotool mousemove 20 700; sleep .5; shot rle-acorn

caption "18. Stretch: undo (Ctrl+Z) reverts the last stamp, paint stroke or clear"
at 40 90; key 2; xdotool mousemove 20 700; sleep .5; shot undo-before
xdotool keydown ctrl; sleep .1; key z .6; xdotool keyup ctrl; shot undo-after-1
key c .5; shot undo-cleared
xdotool keydown ctrl; sleep .1; key z .6; xdotool keyup ctrl; shot undo-after-clear

caption "19. Stretch: 1000x1000 grid (--big), texture rendering, running (software GL, so FPS is low)"
kill $GPID 2>/dev/null; wait $GPID 2>/dev/null; launch --big
key r 1; shot big-random; key space .5; sleep 6; shot big-running-a; sleep 6; shot big-running-b; key space .5

caption "End of demo"; sleep 2
kill -INT $FPID 2>/dev/null; wait $FPID 2>/dev/null
if kill -0 $GPID 2>/dev/null; then echo "GAME_ALIVE=yes" > /tmp/demo-status; else echo "GAME_ALIVE=no" > /tmp/demo-status; fi
kill $GPID 2>/dev/null
cat /tmp/demo-status
