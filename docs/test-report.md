# Test report

Recorded on 2026-10-07 with Odin dev-2026-10, Linux, Xvfb and Mesa software OpenGL. The release video is a scripted 1280x720 H.264 recording at 15 FPS, with captions. The application targets 60 FPS independently of capture rate.

## Build and unit tests

- PASS: `odin build . -out:life -vet` (no diagnostics).
- PASS: `odin test .` (11 tests, all successful).
- Tests cover blinker period 2, block stability, glider translation, wrap crossings, dead borders, bounded painting/interpolation, RLE parsing/stamping, population and undo.

## Video checklist

The numbers match the on-screen captions. Cases 16-19 cover the requested stretch milestone.

- [x] 1. PASS: launch, visible HUD, default 200x120 grid, paused at generation 0/population 0, 10 gen/s, wrap on.
- [x] 2. PASS: LMB paint, RMB erase, fast multi-segment drags have no gaps.
- [x] 3. PASS: paint and erase while running; generation continues advancing.
- [x] 4. PASS: blinker alternates and returns at generation 2 (population 3); block unchanged (4); glider shifts (+1,+1) at generation 4 (5).
- [x] 5. PASS: separate gliders cross right, bottom, left and top edges and SE, SW, NE and NW corners with wrap on; population remains 5.
- [x] 6. PASS: with wrap off, the same glider reaches a dead border and stops as a four-cell block rather than reappearing.
- [x] 7. PASS: play/pause and N/Right step keys work while paused and while running.
- [x] 8. PASS: speed changes and clamps at 1 and 120 gen/s.
- [x] 9. PASS: randomize produces about 25% live cells and resets generation; clear resets generation/population to 0.
- [x] 10. PASS: G toggles grid lines at default/high zoom; lines are suppressed at low zoom.
- [x] 11. PASS: wheel zoom around the cursor, with lower/upper clamps 0.05 and 40. The block under the cursor makes zoom anchoring visible.
- [x] 12. PASS: MMB pan moves the grid fully offscreen and returns to the starting view.
- [x] 13. PASS: wholly outside clicks/drags leave counters unchanged, with no crash. A separate stroke through the grid changes only in-bounds cells.
- [x] 14. PASS: resize to 900x520, 1100x650 and back to 1280x720 while running; HUD and simulation remain active.
- [x] 15. PASS: combined blinker/block/glider population is 12 at generations 1, 2 and 3; clear returns both counters to 0.
- [x] 16. PASS: all five built-in patterns stamp and evolve (glider, LWSS, Gosper gun, pulsar, R-pentomino).
- [x] 17. PASS: L imports the acorn RLE fixture, population 7.
- [x] 18. PASS: Ctrl+Z removes the last LWSS stamp (16 to 7 cells); undoing clear restores the seven-cell acorn.
- [x] 19. PASS: `--big` opens a 1000x1000 grid, randomizes and runs using point-filtered texture rendering; no crash.

## Performance and limits

The ordinary grid generally showed about 59-60 application FPS during capture. The 1000x1000 grid ran under software GL, not a physical GPU. These observations are not a guarantee of real-hardware performance; the real-hardware 60 FPS target remains unbenchmarked. Frame rate and random populations can vary on repeat runs.

The video is driven by Xvfb, ffmpeg x11grab and xdotool, not a manual demonstration. Captions are burned in with drawtext. The script restarts the game between camera cases so each has a known camera state. It is intentionally slower than a benchmark so the viewer can follow the checks.

The extra file-drop RLE shortcut is implemented but not exercised by this recording; keyboard RLE import and parser unit tests are exercised. The undo demo covers stamp and clear; the unit tests cover snapshot restoration.

## Workflow notes

All code milestones and documentation are merged through separate squash PRs. The requested milestone 5 adds patterns, RLE, a preallocated undo ring and texture rendering. One texture quad replaces per-cell drawing; the GPU clips offscreen cells, while grid lines use a visible-cell range. Build/test execution is local; GitHub changes and release upload use the signed-in website as requested. The video is a release asset, not a repository file.
