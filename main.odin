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
MIN_ZOOM :: 0.1
MAX_ZOOM :: 40.0
ZOOM_STEP :: 1.1

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

// Wheel zooms around the cursor, middle-drag pans.
update_camera :: proc(s: ^State) {
    mouse := rl.GetMousePosition()
    wheel := rl.GetMouseWheelMove()
    if wheel != 0 {
        world := rl.GetScreenToWorld2D(mouse, s.camera)
        s.camera.zoom = clamp(s.camera.zoom*math.pow(ZOOM_STEP, wheel), MIN_ZOOM, MAX_ZOOM)
        s.camera.offset = mouse
        s.camera.target = world
    }
    if rl.IsMouseButtonDown(.MIDDLE) {
        s.camera.target -= rl.GetMouseDelta()/s.camera.zoom
    }
}

main :: proc() {
    state := State{cur=grid_make(GRID_W, GRID_H), next=grid_make(GRID_W, GRID_H),
        wrap=true, ticks_per_s=10, camera=rl.Camera2D{zoom=0.75}}
    defer delete(state.cur.cells)
    defer delete(state.next.cells)
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(1280, 720, "Odin Life")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    state.camera.offset = {640, 360}
    state.camera.target = {GRID_W*CELL_SIZE/2, GRID_H*CELL_SIZE/2}
    prev_x, prev_y, prev_button := 0, 0, 0
    for !rl.WindowShouldClose() {
        update_camera(&state)
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
        if rl.IsKeyPressed(.G) { state.show_grid = !state.show_grid }
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
        draw_grid_lines(&state)
        rl.EndMode2D()
        draw_hud(&state)
        rl.EndDrawing()
    }
}
