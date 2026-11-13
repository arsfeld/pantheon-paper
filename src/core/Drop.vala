namespace Paper {
    /**
     * Where a window dragged to (x, y) would land. Over the middle third of a
     * visible column it joins that column, at the row the pointer is at
     * (counting only the column's other windows); over a column's left or
     * right third, or the gap between two columns, it becomes a new column
     * there. Parked columns are never targets; anywhere else is NONE.
     * Indices are pre-move, as Strip.move_to expects.
     */
    public DropTarget hit_test (LayoutResult r, Strip s, uint64 dragged, int x, int y) {
        var none = DropTarget () { kind = DropKind.NONE };
        for (int i = 0; i < s.columns.size; i++) {
            var col = s.columns[i];
            var rect = r.columns[i];
            if (is_parked (r, col)) {
                continue;
            }
            if (x >= rect.x && x < rect.x + rect.width) {
                int third = rect.width / 3;
                if (x < rect.x + third) {
                    return DropTarget () { kind = DropKind.NEW_COLUMN, column = i };
                }
                if (x >= rect.x + rect.width - third) {
                    return DropTarget () { kind = DropKind.NEW_COLUMN, column = i + 1 };
                }
                if (col.windows.size == 1 && col.windows[0] == dragged) {
                    return none;
                }
                int row = 0;
                foreach (var p in r.windows) {
                    if (p.id != dragged && col.windows.contains (p.id) && p.rect.y + p.rect.height / 2 < y) {
                        row++;
                    }
                }
                return DropTarget () { kind = DropKind.INTO_COLUMN, column = i, row = row };
            }
            if (i + 1 < s.columns.size && x >= rect.x + rect.width && x < r.columns[i + 1].x) {
                return DropTarget () { kind = DropKind.NEW_COLUMN, column = i + 1 };
            }
        }
        return none;
    }

    private bool is_parked (LayoutResult r, Column col) {
        foreach (var p in r.windows) {
            if (p.id == col.windows[0]) {
                return p.parked;
            }
        }
        return false;
    }

    /** Height shares from window heights; all zero gives equal shares. */
    public double[] shares_from_heights (int[] heights) {
        var shares = new double[heights.length];
        int sum = 0;
        foreach (var h in heights) {
            sum += int.max (h, 0);
        }
        for (int i = 0; i < heights.length; i++) {
            shares[i] = sum > 0 ? int.max (heights[i], 0) / (double) sum : 1.0 / heights.length;
        }
        return shares;
    }
}
