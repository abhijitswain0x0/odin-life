package main
import rl "vendor:raylib"

draw_cells :: proc(s: ^State) {
    for y in 0..<s.cur.h {
        for x in 0..<s.cur.w {
            if s.cur.cells[y*s.cur.w+x] != 0 {
                rl.DrawRectangle(i32(x*CELL_SIZE), i32(y*CELL_SIZE), CELL_SIZE, CELL_SIZE,
                    rl.Color{99, 235, 169, 255})
            }
        }
    }
}
