package main

Grid :: struct {
    w, h: int,
    cells: []u8,
}

grid_make :: proc(w, h: int) -> Grid {
    return Grid{w, h, make([]u8, w*h)}
}

grid_set :: proc(g: ^Grid, x, y: int, value: u8) -> int {
    if x < 0 || y < 0 || x >= g.w || y >= g.h { return 0 }
    i := y*g.w+x
    delta := int(value)-int(g.cells[i])
    g.cells[i] = value
    return delta
}

// Every visited point is clipped by grid_set, including out-of-bounds drags.
paint_line :: proc(g: ^Grid, x0, y0, x1, y1: int, value: u8) -> int {
    x, y := x0, y0
    dx, dy := abs(x1-x0), -abs(y1-y0)
    sx, sy := 1, 1
    if x0 > x1 { sx = -1 }; if y0 > y1 { sy = -1 }
    err := dx+dy
    delta := 0
    for {
        delta += grid_set(g, x, y, value)
        if x == x1 && y == y1 { break }
        e2 := 2*err
        if e2 >= dy { err += dy; x += sx }
        if e2 <= dx { err += dx; y += sy }
    }
    return delta
}
