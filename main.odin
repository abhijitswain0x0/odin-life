package main

import rl "vendor:raylib"
import "core:math"

CELL_SIZE :: 8
GRID_W :: 200
GRID_H :: 120

State :: struct {
    cur, next: Grid,
    running, wrap, show_grid: bool,
    ticks_per_s, accum: f32,
    generation, population: int,
    camera: rl.Camera2D,
}

main :: proc() {
    state := State{cur=grid_make(GRID_W, GRID_H), next=grid_make(GRID_W, GRID_H),
        wrap=true, ticks_per_s=10, camera=rl.Camera2D{zoom=1}}
    defer delete(state.cur.cells)
    defer delete(state.next.cells)
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(1280, 720, "Odin Life")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    prev_x, prev_y, prev_button := 0, 0, 0
    for !rl.WindowShouldClose() {
        mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)
        x, y := int(math.floor(mouse.x/CELL_SIZE)), int(math.floor(mouse.y/CELL_SIZE))
        button := 0
        if rl.IsMouseButtonDown(.LEFT) { button = 1 }
        if rl.IsMouseButtonDown(.RIGHT) { button = 2 }
        if button != 0 {
            value: u8 = 1
            if button == 2 { value = 0 }
            if prev_button != button { prev_x, prev_y = x, y }
            state.population += paint_line(&state.cur, prev_x, prev_y, x, y, value)
        }
        prev_x, prev_y, prev_button = x, y, button
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{15, 20, 29, 255})
        rl.BeginMode2D(state.camera)
        draw_cells(&state)
        rl.EndMode2D()
        rl.EndDrawing()
    }
}
