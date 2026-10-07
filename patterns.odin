package main

// Built-in patterns are stored as RLE so the importer is exercised by the same data.
Pattern :: struct {
    name: string,
    rle:  string,
}

PATTERNS := [?]Pattern{
    {"glider",      "bob$2bo$3o!"},
    {"lwss",        "bo2bo$o4b$o3bo$4o!"},
    {"gosper gun",  "24bo$22bobo$12b2o6b2o12b2o$11bo3bo4b2o12b2o$2o8bo5bo3b2o$2o8bo3bob2o4bobo$10bo5bo7bo$11bo3bo$12b2o!"},
    {"pulsar",      "2b3o3b3o2$o4bobo4bo$o4bobo4bo$o4bobo4bo$2b3o3b3o2$2b3o3b3o$o4bobo4bo$o4bobo4bo$o4bobo4bo2$2b3o3b3o!"},
    {"r-pentomino", "b2o$2ob$bo!"},
}

// Parses RLE text into live cell offsets (x, y). Returns the pattern bounding size.
// Comment lines start with '#'. The "x = .., y = .." header is optional.
parse_rle :: proc(text: string, out: ^[dynamic][2]int) -> (w, h: int, ok: bool) {
    x, y, count := 0, 0, 0
    in_header := false
    line_start := true
    i := 0
    for i < len(text) {
        c := text[i]
        if line_start && (c == '#' || c == 'x' || c == 'X') {
            for i < len(text) && text[i] != '\n' { i += 1 }  // skip comment or header line
            continue
        }
        line_start = c == '\n'
        _ = in_header
        switch {
        case c >= '0' && c <= '9':
            count = count*10 + int(c-'0')
        case c == 'b' || c == 'B' || c == '.':
            x += max(count, 1); count = 0
        case c == 'o' || c == 'O' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'):
            n := max(count, 1); count = 0
            for _ in 0..<n { append(out, [2]int{x, y}); x += 1 }
            w = max(w, x)
        case c == '$':
            y += max(count, 1); count = 0; x = 0
        case c == '!':
            return w, y+1, len(out) > 0
        }
        i += 1
    }
    return w, y+1, len(out) > 0
}

// Writes cells into g with the pattern's top-left at (ox, oy). Clipped to the grid.
// Returns the change in population.
stamp_cells :: proc(g: ^Grid, cells: [][2]int, ox, oy: int) -> int {
    delta := 0
    for c in cells { delta += grid_set(g, ox+c.x, oy+c.y, 1) }
    return delta
}
