package main
import "core:testing"

@(test)
painting_bounds_and_line :: proc(t: ^testing.T) {
    g := grid_make(20, 20)
    defer delete(g.cells)
    testing.expect(t, grid_set(&g, -1, 0, 1) == 0)
    testing.expect(t, paint_line(&g, 0, 0, 19, 19, 1) == 20)
    for i in 0..<20 { testing.expect(t, g.cells[i*20+i] == 1) }
    testing.expect(t, paint_line(&g, 0, 0, 19, 19, 0) == -20)
}
