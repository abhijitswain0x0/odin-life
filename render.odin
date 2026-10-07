package main

import "core:math"
import rl "vendor:raylib"

COLOR_BG        :: rl.Color{15, 20, 29, 255}
COLOR_CELL      :: rl.Color{99, 235, 169, 255}
COLOR_GRID      :: rl.Color{255, 255, 255, 28}
COLOR_BORDER    :: rl.Color{90, 100, 120, 255}
MIN_GRID_CELL_PX :: 6 // grid lines are hidden when a cell is smaller than this on screen

// Range of cells visible through the camera, clamped to the grid. Half-open: [x0, x1) x [y0, y1).
visible_cells :: proc(s: ^State) -> (x0, y0, x1, y1: int) {
    tl := rl.GetScreenToWorld2D({0, 0}, s.camera)
    br := rl.GetScreenToWorld2D({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, s.camera)
    x0 = max(0, int(math.floor(tl.x/CELL_SIZE)))
    y0 = max(0, int(math.floor(tl.y/CELL_SIZE)))
    x1 = min(s.cur.w, int(math.ceil(br.x/CELL_SIZE)))
    y1 = min(s.cur.h, int(math.ceil(br.y/CELL_SIZE)))
    return
}

COLOR_DEAD :: rl.Color{20, 27, 40, 255}

// Writes one color per cell into the pixel buffer and uploads it, only when something changed.
upload_cells :: proc(s: ^State) {
    if !s.dirty { return }
    for v, i in s.cur.cells { s.pixels[i] = v != 0 ? COLOR_CELL : COLOR_DEAD }
    rl.UpdateTexture(s.tex, raw_data(s.pixels))
    s.dirty = false
}

// One textured quad for the whole grid. The GPU clips whatever is off screen.
draw_cells :: proc(s: ^State) {
    upload_cells(s)
    src := rl.Rectangle{0, 0, f32(s.cur.w), f32(s.cur.h)}
    dst := rl.Rectangle{0, 0, f32(s.cur.w*CELL_SIZE), f32(s.cur.h*CELL_SIZE)}
    rl.DrawTexturePro(s.tex, src, dst, {0, 0}, 0, rl.WHITE)
    rl.DrawRectangleLines(0, 0, i32(s.cur.w*CELL_SIZE), i32(s.cur.h*CELL_SIZE), COLOR_BORDER)
}

draw_grid_lines :: proc(s: ^State) {
    if !s.show_grid || s.camera.zoom*CELL_SIZE < MIN_GRID_CELL_PX { return }
    x0, y0, x1, y1 := visible_cells(s)
    thick := 1/s.camera.zoom
    for x in x0..=x1 {
        rl.DrawLineEx({f32(x*CELL_SIZE), f32(y0*CELL_SIZE)}, {f32(x*CELL_SIZE), f32(y1*CELL_SIZE)}, thick, COLOR_GRID)
    }
    for y in y0..=y1 {
        rl.DrawLineEx({f32(x0*CELL_SIZE), f32(y*CELL_SIZE)}, {f32(x1*CELL_SIZE), f32(y*CELL_SIZE)}, thick, COLOR_GRID)
    }
}

// Screen-space overlay. Call outside BeginMode2D.
draw_hud :: proc(s: ^State) {
    rl.DrawRectangle(0, 0, 640, 30, rl.Color{0, 0, 0, 150})
    rl.DrawText(rl.TextFormat("gen %d   pop %d   %.0f gen/s   wrap %s   %s   zoom %.2f",
        i32(s.generation), i32(s.population), s.ticks_per_s,
        s.wrap ? cstring("on") : cstring("off"),
        s.running ? cstring("running") : cstring("paused"), s.camera.zoom),
        10, 6, 20, rl.RAYWHITE)
    rl.DrawFPS(rl.GetScreenWidth()-90, 6)
}
