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

// Cell value at (x, y). Out of range is wrapped when wrap is true, else dead.
grid_get :: proc(g: ^Grid, x, y: int, wrap: bool) -> u8 {
    xx, yy := x, y
    if wrap {
        xx = (x%g.w + g.w) % g.w
        yy = (y%g.h + g.h) % g.h
    } else if x < 0 || y < 0 || x >= g.w || y >= g.h {
        return 0
    }
    return g.cells[yy*g.w+xx]
}

count_neighbors :: proc(g: ^Grid, x, y: int, wrap: bool) -> int {
    n := 0
    for dy in -1..=1 {
        for dx in -1..=1 {
            if dx == 0 && dy == 0 { continue }
            n += int(grid_get(g, x+dx, y+dy, wrap))
        }
    }
    return n
}

// B3/S23. Writes the next generation into next and returns its population.
// Pure with respect to (cur, next, wrap): no window and no allocation.
step :: proc(cur, next: ^Grid, wrap: bool) -> int {
    pop := 0
    for y in 0..<cur.h {
        for x in 0..<cur.w {
            n := count_neighbors(cur, x, y, wrap)
            alive := cur.cells[y*cur.w+x] != 0
            v: u8 = 0
            if n == 3 || (alive && n == 2) { v = 1; pop += 1 }
            next.cells[y*cur.w+x] = v
        }
    }
    return pop
}
