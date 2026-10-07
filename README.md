# odin-life

Conway's Game of Life in [Odin](https://odin-lang.org) with the bundled `vendor:raylib`. No other dependencies.

Demo video: see the [v0.1.0 release](https://github.com/abhijitswain0x0/odin-life/releases/tag/v0.1.0). Test checklist: [docs/test-report.md](docs/test-report.md).

## Build and run

    odin run .                    # dev
    odin build . -o:speed         # release build
    odin build . -out:life        # named binary
    odin test .                   # unit tests, no window needed

Options:

    ./life --big                  # 1000x1000 grid
    ./life --rle file.rle         # RLE file to stamp with L

Needs a display and OpenGL. On a headless box use Xvfb and Mesa software GL (`LIBGL_ALWAYS_SOFTWARE=1`).

## Controls

| Input | Action |
| --- | --- |
| Space | Play / pause |
| N or Right | Step one generation |
| Up / Down | Faster / slower (1-120 gen/s) |
| R | Randomize (about 25% alive), resets generation |
| C | Clear, resets generation |
| G | Toggle grid lines |
| W | Toggle wrap (torus or dead borders) |
| LMB / RMB | Draw / erase (works while running) |
| MMB drag | Pan |
| Wheel | Zoom around the cursor |
| 1-5 | Stamp glider, LWSS, Gosper gun, pulsar, R-pentomino at the cursor |
| L | Stamp the RLE file given with `--rle` at the cursor |
| Drop an `.rle` file | Stamp it at the grid center |
| Ctrl+Z | Undo the last edit (stroke, stamp, randomize, clear) |

## Layout

- `main.odin`: window, main loop, input
- `grid.odin`: grid, neighbor counting, step (B3/S23, double buffered)
- `render.odin`: texture drawing, grid lines, HUD
- `patterns.odin`: built-in patterns and RLE parser
- `undo.odin`: fixed-size snapshot ring
- `grid_test.odin`: tests
- `scripts/record_demo.sh`: scripted Xvfb + ffmpeg + xdotool demo

## Recording the demo

    scripts/record_demo.sh demo.mp4

The video is not committed. It is attached to the release.

## License

MIT
