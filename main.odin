package main

import rl "vendor:raylib"
import "core:math"
import "core:os"
import "core:strings"

CELL_SIZE :: 8
GRID_W :: 200
GRID_H :: 120
MAX_STEPS_PER_FRAME :: 10
MIN_SPEED :: 1.0
MAX_SPEED :: 120.0
SPEED_FACTOR :: 1.25
RANDOM_DENSITY :: 25
MIN_ZOOM :: 0.05
BIG_W :: 1000
BIG_H :: 1000
UNDO_DEPTH :: 32
MAX_ZOOM :: 40.0
ZOOM_STEP :: 1.1

State :: struct {
    cur, next: Grid,
    running, wrap, show_grid: bool,
    ticks_per_s, accum: f32,
    generation, population: int,
    camera: rl.Camera2D,
    // Stretch features
    tex: rl.Texture2D,
    pixels: []rl.Color,
    dirty: bool,
    undo: Undo,
    rle_path: string,
}

do_step :: proc(s: ^State) {
    s.population = step(&s.cur, &s.next, s.wrap)
    s.cur, s.next = s.next, s.cur
    s.generation += 1
    s.dirty = true
}

randomize :: proc(s: ^State) {
    undo_push(&s.undo, &s.cur, s.generation)
    s.dirty = true
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
    undo_push(&s.undo, &s.cur, s.generation)
    s.dirty = true
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

// Stamps RLE text with its center at cell (cx, cy). Returns false if it does not parse.
stamp_rle :: proc(s: ^State, rle: string, cx, cy: int) -> bool {
    cells: [dynamic][2]int
    defer delete(cells)
    w, h, ok := parse_rle(rle, &cells)
    if !ok { return false }
    undo_push(&s.undo, &s.cur, s.generation)
    s.population += stamp_cells(&s.cur, cells[:], cx-w/2, cy-h/2)
    s.dirty = true
    return true
}

load_rle_file :: proc(path: string) -> (text: string, ok: bool) {
    data, err := os.read_entire_file(path, context.allocator)
    if err != nil { return "", false }
    return string(data), true
}

main :: proc() {
    gw, gh := GRID_W, GRID_H
    rle_path := ""
    args := os.args[1:]
    for i := 0; i < len(args); i += 1 {
        switch args[i] {
        case "--big": gw, gh = BIG_W, BIG_H
        case "--rle": if i+1 < len(args) { rle_path = args[i+1]; i += 1 }
        }
    }
    state := State{cur=grid_make(gw, gh), next=grid_make(gw, gh), rle_path=rle_path,
        wrap=true, ticks_per_s=10, camera=rl.Camera2D{zoom=0.75}}
    defer delete(state.cur.cells)
    defer delete(state.next.cells)
    state.undo = undo_make(gw*gh, UNDO_DEPTH)
    defer undo_destroy(&state.undo)
    state.pixels = make([]rl.Color, gw*gh)
    defer delete(state.pixels)
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(1280, 720, "Odin Life")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    // One texture holds every cell: one pixel per cell, point filtered, drawn as a single quad.
    img := rl.Image{data = raw_data(state.pixels), width = i32(gw), height = i32(gh), mipmaps = 1, format = .UNCOMPRESSED_R8G8B8A8}
    state.tex = rl.LoadTextureFromImage(img)
    defer rl.UnloadTexture(state.tex)
    rl.SetTextureFilter(state.tex, .POINT)
    state.dirty = true
    state.camera.offset = {640, 360}
    state.camera.target = {f32(gw*CELL_SIZE)/2, f32(gh*CELL_SIZE)/2}
    state.camera.zoom = clamp(min(1280/f32(gw*CELL_SIZE), 720/f32(gh*CELL_SIZE)), MIN_ZOOM, 1)
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
            if prev_button != button {
                prev_x, prev_y = x, y
                undo_push(&state.undo, &state.cur, state.generation)  // one undo step per stroke
            }
            state.population += paint_line(&state.cur, prev_x, prev_y, x, y, value)
            state.dirty = true
        }
        prev_x, prev_y, prev_button = x, y, button

        if rl.IsKeyPressed(.SPACE) { state.running = !state.running }
        if (rl.IsKeyPressed(.N) || rl.IsKeyPressed(.RIGHT)) { do_step(&state) }
        if rl.IsKeyPressed(.UP) { state.ticks_per_s = min(state.ticks_per_s*SPEED_FACTOR, MAX_SPEED) }
        if rl.IsKeyPressed(.DOWN) { state.ticks_per_s = max(state.ticks_per_s/SPEED_FACTOR, MIN_SPEED) }
        if rl.IsKeyPressed(.R) { randomize(&state) }
        if rl.IsKeyPressed(.C) { clear_grid(&state) }
        ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
        if ctrl && rl.IsKeyPressed(.Z) {
            if g, p, ok := undo_pop(&state.undo, &state.cur); ok {
                state.generation, state.population, state.dirty = g, p, true
            }
        }
        for k in 0..<len(PATTERNS) {
            if rl.IsKeyPressed(rl.KeyboardKey(int(rl.KeyboardKey.ONE)+k)) { stamp_rle(&state, PATTERNS[k].rle, x, y) }
        }
        if rl.IsKeyPressed(.L) && state.rle_path != "" {
            if text, ok := load_rle_file(state.rle_path); ok { stamp_rle(&state, text, x, y); delete(text) }
        }
        if rl.IsFileDropped() {
            files := rl.LoadDroppedFiles()
            if files.count > 0 {
                path := string(files.paths[0])
                if text, ok := load_rle_file(path); ok {
                    stamp_rle(&state, text, state.cur.w/2, state.cur.h/2); delete(text)
                    state.rle_path = strings.clone(path)
                }
            }
            rl.UnloadDroppedFiles(files)
        }
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
