package main

// Fixed-size ring of grid snapshots. All memory is allocated once up front.
Undo :: struct {
    buf:   []u8,
    gens:  []int,
    depth, cell_n, head, count: int,
}

undo_make :: proc(cell_n, depth: int) -> Undo {
    return Undo{buf = make([]u8, cell_n*depth), gens = make([]int, depth), depth = depth, cell_n = cell_n}
}

undo_destroy :: proc(u: ^Undo) {
    delete(u.buf); delete(u.gens)
}

undo_push :: proc(u: ^Undo, g: ^Grid, generation: int) {
    copy(u.buf[u.head*u.cell_n:(u.head+1)*u.cell_n], g.cells)
    u.gens[u.head] = generation
    u.head = (u.head+1) % u.depth
    u.count = min(u.count+1, u.depth)
}

// Restores the most recent snapshot into g. Returns its generation and the population.
undo_pop :: proc(u: ^Undo, g: ^Grid) -> (generation, population: int, ok: bool) {
    if u.count == 0 { return 0, 0, false }
    u.head = (u.head-1+u.depth) % u.depth
    u.count -= 1
    copy(g.cells, u.buf[u.head*u.cell_n:(u.head+1)*u.cell_n])
    for v in g.cells { population += int(v) }
    return u.gens[u.head], population, true
}
