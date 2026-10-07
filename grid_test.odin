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

// Sets cells at the given offset from rows of '#' (alive) and '.' (dead).
stamp :: proc(g: ^Grid, ox, oy: int, rows: []string) {
    for row, y in rows {
        for c, x in row {
            if c == '#' { grid_set(g, ox+x, oy+y, 1) }
        }
    }
}

same :: proc(a, b: ^Grid) -> bool {
    for i in 0..<len(a.cells) {
        if a.cells[i] != b.cells[i] { return false }
    }
    return true
}

// Steps cur forward n generations using the two buffers, swapping each time.
advance :: proc(cur, next: ^Grid, n: int, wrap: bool) {
    for _ in 0..<n {
        step(cur, next, wrap)
        cur^, next^ = next^, cur^
    }
}

@(test)
blinker_period_two :: proc(t: ^testing.T) {
    a, b, start := grid_make(10, 10), grid_make(10, 10), grid_make(10, 10)
    defer delete(a.cells); defer delete(b.cells); defer delete(start.cells)
    stamp(&a, 4, 4, {"###"}); stamp(&start, 4, 4, {"###"})
    advance(&a, &b, 1, true)
    testing.expect(t, !same(&a, &start))
    advance(&a, &b, 1, true)
    testing.expect(t, same(&a, &start))
}

@(test)
block_is_still :: proc(t: ^testing.T) {
    a, b, start := grid_make(10, 10), grid_make(10, 10), grid_make(10, 10)
    defer delete(a.cells); defer delete(b.cells); defer delete(start.cells)
    stamp(&a, 4, 4, {"##", "##"}); stamp(&start, 4, 4, {"##", "##"})
    pop := step(&a, &b, true)
    testing.expect(t, pop == 4)
    testing.expect(t, same(&b, &start))
}

@(test)
glider_shifts_by_one :: proc(t: ^testing.T) {
    glider := []string{".#.", "..#", "###"}
    a, b, expected := grid_make(12, 12), grid_make(12, 12), grid_make(12, 12)
    defer delete(a.cells); defer delete(b.cells); defer delete(expected.cells)
    stamp(&a, 3, 3, glider); stamp(&expected, 4, 4, glider)
    advance(&a, &b, 4, true)
    testing.expect(t, same(&a, &expected))
}

@(test)
glider_wraps_around_edge :: proc(t: ^testing.T) {
    // Moving right and down, a glider on a 8x8 torus returns to its start after 32 generations.
    glider := []string{".#.", "..#", "###"}
    a, b, start := grid_make(8, 8), grid_make(8, 8), grid_make(8, 8)
    defer delete(a.cells); defer delete(b.cells); defer delete(start.cells)
    stamp(&a, 2, 2, glider); stamp(&start, 2, 2, glider)
    advance(&a, &b, 32, true)
    testing.expect(t, same(&a, &start))
    // Partway through, live cells must exist at the opposite side (x or y near 0).
    c, d := grid_make(8, 8), grid_make(8, 8)
    defer delete(c.cells); defer delete(d.cells)
    stamp(&c, 5, 5, glider)
    advance(&c, &d, 12, true)
    found := false
    for y in 0..<2 { for x in 0..<8 { if c.cells[y*8+x] != 0 { found = true } } }
    testing.expect(t, found)
}

@(test)
no_wrap_edge_sees_dead :: proc(t: ^testing.T) {
    // A vertical blinker on the left edge: with wrap it gains a cell across the seam, without wrap it does not.
    w, nw := grid_make(8, 8), grid_make(8, 8)
    wn, nn := grid_make(8, 8), grid_make(8, 8)
    defer delete(w.cells); defer delete(nw.cells); defer delete(wn.cells); defer delete(nn.cells)
    stamp(&w, 0, 3, {"#", "#", "#"}); stamp(&wn, 0, 3, {"#", "#", "#"})
    step(&w, &nw, true)
    step(&wn, &nn, false)
    testing.expect(t, nw.cells[4*8+7] == 1)   // wrapped neighbor at x=7
    testing.expect(t, nn.cells[4*8+7] == 0)   // dead border
    testing.expect(t, nn.cells[4*8+0] == 1)
    testing.expect(t, count_neighbors(&wn, 0, 4, false) == 2)
}

@(test)
rle_glider_parses :: proc(t: ^testing.T) {
    cells: [dynamic][2]int
    defer delete(cells)
    w, h, ok := parse_rle("#C comment\nx = 3, y = 3, rule = B3/S23\nbob$2bo$3o!\n", &cells)
    testing.expect(t, ok)
    testing.expect(t, w == 3 && h == 3)
    testing.expect(t, len(cells) == 5)
    testing.expect(t, cells[0] == [2]int{1, 0})
    testing.expect(t, cells[4] == [2]int{2, 2})
}

@(test)
builtin_patterns_have_expected_population :: proc(t: ^testing.T) {
    expected := [?]int{5, 9, 36, 48, 5}
    for p, i in PATTERNS {
        cells: [dynamic][2]int
        defer delete(cells)
        _, _, ok := parse_rle(p.rle, &cells)
        testing.expectf(t, ok && len(cells) == expected[i], "%s: got %d cells", p.name, len(cells))
    }
}

@(test)
pulsar_has_period_three :: proc(t: ^testing.T) {
    cells: [dynamic][2]int
    defer delete(cells)
    parse_rle(PATTERNS[3].rle, &cells)
    a, b, start := grid_make(30, 30), grid_make(30, 30), grid_make(30, 30)
    defer delete(a.cells); defer delete(b.cells); defer delete(start.cells)
    stamp_cells(&a, cells[:], 8, 8); stamp_cells(&start, cells[:], 8, 8)
    advance(&a, &b, 1, true)
    testing.expect(t, !same(&a, &start))
    advance(&a, &b, 2, true)
    testing.expect(t, same(&a, &start))
}

@(test)
undo_restores_snapshots_in_order :: proc(t: ^testing.T) {
    g := grid_make(10, 10)
    defer delete(g.cells)
    u := undo_make(100, 3)
    defer undo_destroy(&u)
    undo_push(&u, &g, 0)            // empty
    grid_set(&g, 1, 1, 1)
    undo_push(&u, &g, 7)            // one cell
    grid_set(&g, 2, 2, 1)
    gen, pop, ok := undo_pop(&u, &g)
    testing.expect(t, ok && gen == 7 && pop == 1)
    gen, pop, ok = undo_pop(&u, &g)
    testing.expect(t, ok && gen == 0 && pop == 0)
    _, _, ok = undo_pop(&u, &g)
    testing.expect(t, !ok)
    // Ring drops the oldest entry when full.
    for i in 0..<5 { grid_set(&g, i, 0, 1); undo_push(&u, &g, i) }
    testing.expect(t, u.count == 3)
    gen, _, _ = undo_pop(&u, &g)
    testing.expect(t, gen == 4)
}

@(test)
big_grid_step_matches_edge_rules :: proc(t: ^testing.T) {
    // Fast interior path and edge path agree on a glider crossing the seam.
    a, b := grid_make(64, 64), grid_make(64, 64)
    defer delete(a.cells); defer delete(b.cells)
    stamp(&a, 60, 60, {".#.", "..#", "###"})
    advance(&a, &b, 40, true)
    pop := 0
    for v in a.cells { pop += int(v) }
    testing.expect(t, pop == 5)
}
