package main

import rl "vendor:raylib"
import "core:math"

CELL_SIZE :: 8
GRID_W :: 200
GRID_H :: 120
MAX_STEPS_PER_FRAME :: 10
MIN_SPEED :: 1.0
MAX_SPEED :: 120.0
SPEED_FACTOR :: 1.25
RANDOM_DENSITY :: 25

State :: struct {
    cur, next: Grid,
    running, wrap, show_grid: bool,
    ticks_per_s, accum: f32,
    generation, population: int,
    camera: rl.Camera2D,
}

do_step :: proc(s: ^State) {
    s.population = step(&s.cur, &s.next, s.wrap)
    s.cur, s.next = s.next, s.cur
    s.generation += 1
}

randomize :: proc(s: ^State) {
    s.population = 0
    for i in 0..<len(s.cur.cells) {
        alive := rl.GetRandomValue(0, 99) < RANDOM_DENSITY
        s.cur.cells[i] = alive ? 1 : 0
        if alive { s.population += 1 }
    }
    s.generation = 0
    s.accum = 0
}

clear_grid :: proc(s: ^State) {
    for i in 0..<len(s.cur.cells) { s.cur.cells[i] = 0 }
    s.population, s.generation, s.accum = 0, 0, 0
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

        if rl.IsKeyPressed(.SPACE) { state.running = !state.running }
        if (rl.IsKeyPressed(.N) || rl.IsKeyPressed(.RIGHT)) { do_step(&state) }
        if rl.IsKeyPressed(.UP) { state.ticks_per_s = min(state.ticks_per_s*SPEED_FACTOR, MAX_SPEED) }
        if rl.IsKeyPressed(.DOWN) { state.ticks_per_s = max(state.ticks_per_s/SPEED_FACTOR, MIN_SPEED) }
        if rl.IsKeyPressed(.R) { randomize(&state) }
        if rl.IsKeyPressed(.C) { clear_grid(&state) }
        if rl.IsKeyPressed(.W) { state.wrap = !state.wrap }
        if state.running {
            state.accum += rl.GetFrameTime()
            period := 1/state.ticks_per_s
            steps := 0
            for state.accum >= period && steps < MAX_STEPS_PER_FRAME {
                do_step(&state)
                state.accum -= period
                steps += 1
            }
            if steps == MAX_STEPS_PER_FRAME { state.accum = 0 }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{15, 20, 29, 255})
        rl.BeginMode2D(state.camera)
        draw_cells(&state)
        rl.EndMode2D()
        rl.DrawText(rl.TextFormat("gen %d  pop %d  %.0f gen/s  wrap %s  %s", i32(state.generation), i32(state.population), state.ticks_per_s, state.wrap ? cstring("on") : cstring("off"), state.running ? cstring("running") : cstring("paused")), 10, 10, 20, rl.RAYWHITE)
        rl.EndDrawing()
    }
}
