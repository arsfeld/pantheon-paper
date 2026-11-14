namespace Paper {
    public enum DropKind {
        NONE,
        /** Into column `column`, at row `row`. */
        INTO_COLUMN,
        /** A new column inserted at index `column`. */
        NEW_COLUMN
    }

    /** A drop position. Indices refer to the strip as it was before the move. */
    public struct DropTarget {
        public DropKind kind;
        public int column;
        public int row;
    }

    public class Column : Object {
        /** An index into Params.presets, clamped when used. */
        public int preset = 1;
        /** A width set by a mouse resize; 0 means use the preset. */
        public int free_px = 0;
        public bool full = false;
        public Gee.ArrayList<uint64?> windows = new Gee.ArrayList<uint64?> ((a, b) => (uint64) a == (uint64) b);
        /** Each window's share of the column height; sums to 1. */
        public Gee.ArrayList<double?> shares = new Gee.ArrayList<double?> ();
        /** The row focus returns to when the column is focused again. */
        public int active_row = 0;

        public Column.with (uint64 id, int preset) {
            this.preset = preset;
            windows.add (id);
            reset_shares ();
        }

        public void reset_shares () {
            shares.clear ();
            for (int i = 0; i < windows.size; i++) {
                shares.add (1.0 / windows.size);
            }
            active_row = active_row.clamp (0, int.max (0, windows.size - 1));
        }
    }

    /**
     * A workspace's windows as a row of columns, scrolled by `scroll_x`.
     * Pure: window ids only, no Mutter types.
     */
    public class Strip : Object {
        public Params @params;
        public SoloCheck solo;
        public Gee.ArrayList<Column> columns = new Gee.ArrayList<Column> ();
        public int scroll_x = 0;
        /** The focused window, or 0. */
        public uint64 focused = 0;

        public Strip (Params @params = new Params (), SoloCheck solo = new NoSolo ()) {
            this.@params = @params;
            this.solo = solo;
        }

        /** A new column holding `id`; preset -1 means params.default_preset. */
        private Column new_column (uint64 id, int preset = -1) {
            return new Column.with (id, preset < 0 ? @params.default_preset : preset);
        }

        public bool contains (uint64 id) {
            return column_of (id) >= 0;
        }

        public int column_of (uint64 id) {
            for (int i = 0; i < columns.size; i++) {
                if (columns[i].windows.contains (id)) {
                    return i;
                }
            }
            return -1;
        }

        private int row_of (int column, uint64 id) {
            return columns[column].windows.index_of (id);
        }

        /** The focused column's index, or -1. */
        public int focused_column () {
            return focused == 0 ? -1 : column_of (focused);
        }

        public void insert_after_focused (uint64 id, int preset = -1) {
            if (id == 0 || contains (id)) {
                return;
            }
            columns.insert (focused_column () + 1, new_column (id, preset));
            focused = id;
        }

        /** Insert as a new column at index `column` (clamped), and focus it. */
        public void insert_at (uint64 id, int column, int preset = -1) {
            if (id == 0 || contains (id)) {
                return;
            }
            columns.insert (column.clamp (0, columns.size), new_column (id, preset));
            focused = id;
        }

        public void append (uint64 id, int preset = -1) {
            if (id == 0 || contains (id)) {
                return;
            }
            columns.add (new_column (id, preset));
            if (focused == 0) {
                focused = id;
            }
        }

        public void remove (uint64 id) {
            int c = column_of (id);
            if (c < 0) {
                return;
            }
            var col = columns[c];
            int r = row_of (c, id);
            col.windows.remove_at (r);
            if (col.windows.size > 0) {
                col.reset_shares ();
                if (focused == id) {
                    var row = int.min (r, col.windows.size - 1);
                    col.active_row = row;
                    focused = col.windows[row];
                }
                return;
            }
            columns.remove_at (c);
            if (focused != id) {
                return;
            }
            if (c > 0) {
                focused = active_window (columns[c - 1]);
            } else if (columns.size > 0) {
                focused = active_window (columns[0]);
            } else {
                focused = 0;
            }
        }

        public uint64 active_window (Column col) {
            return col.windows[col.active_row.clamp (0, col.windows.size - 1)];
        }

        public void focus (uint64 id) {
            int c = column_of (id);
            if (c < 0) {
                return;
            }
            columns[c].active_row = row_of (c, id);
            focused = id;
        }

        public void focus_column (int delta) {
            int c = focused_column ();
            if (c < 0) {
                return;
            }
            focused = active_window (columns[(c + delta).clamp (0, columns.size - 1)]);
        }

        public void focus_row (int delta) {
            int c = focused_column ();
            if (c < 0) {
                return;
            }
            var col = columns[c];
            col.active_row = (row_of (c, focused) + delta).clamp (0, col.windows.size - 1);
            focused = col.windows[col.active_row];
        }

        public void move_column (int delta) {
            int c = focused_column ();
            int to = c + delta;
            if (c < 0 || to < 0 || to >= columns.size) {
                return;
            }
            var col = columns.remove_at (c);
            columns.insert (to, col);
        }

        public void move_in_column (int delta) {
            int c = focused_column ();
            if (c < 0) {
                return;
            }
            var col = columns[c];
            int r = row_of (c, focused);
            int to = r + delta;
            if (to < 0 || to >= col.windows.size) {
                return;
            }
            col.windows[r] = col.windows[to];
            col.windows[to] = focused;
            col.active_row = to;
        }

        public void cycle_width (int work_width) {
            int c = focused_column ();
            if (c < 0) {
                return;
            }
            var col = columns[c];
            if (col.free_px > 0) {
                int best = 0;
                int best_diff = int.MAX;
                for (int p = 0; p < @params.presets.length; p++) {
                    int diff = (@params.pixels (p, work_width) - col.free_px).abs ();
                    if (diff < best_diff) {
                        best = p;
                        best_diff = diff;
                    }
                }
                col.preset = best;
                col.free_px = 0;
            } else {
                col.preset = (@params.clamp_preset (col.preset) + 1) % @params.presets.length;
            }
            col.full = false;
        }

        public void toggle_full () {
            int c = focused_column ();
            if (c >= 0) {
                columns[c].full = !columns[c].full;
            }
        }

        public void slurp () {
            int c = focused_column ();
            if (c < 0 || c + 1 >= columns.size) {
                return;
            }
            var next = columns[c + 1];
            if (solo.is_solo (next.windows[0]) || any_solo (columns[c])) {
                return;
            }
            var id = next.windows.remove_at (0);
            if (next.windows.size == 0) {
                columns.remove_at (c + 1);
            } else {
                next.reset_shares ();
            }
            columns[c].windows.add (id);
            columns[c].reset_shares ();
        }

        public void barf () {
            int c = focused_column ();
            if (c < 0 || columns[c].windows.size < 2) {
                return;
            }
            var col = columns[c];
            col.windows.remove (focused);
            col.reset_shares ();
            columns.insert (c + 1, new_column (focused, col.preset));
        }

        private bool any_solo (Column col) {
            foreach (var w in col.windows) {
                if (solo.is_solo (w)) {
                    return true;
                }
            }
            return false;
        }

        public void set_free_width (uint64 id, int px) {
            int c = column_of (id);
            if (c >= 0 && px > 0) {
                columns[c].free_px = px;
                columns[c].full = false;
            }
        }

        public void set_shares (int column, double[] shares) {
            if (column < 0 || column >= columns.size || shares.length != columns[column].windows.size) {
                return;
            }
            double sum = 0;
            foreach (var v in shares) {
                sum += v;
            }
            if (sum <= 0) {
                return;
            }
            var col = columns[column];
            col.shares.clear ();
            foreach (var v in shares) {
                col.shares.add (v / sum);
            }
        }

        public void move_to (uint64 id, DropTarget drop) {
            var t = drop;
            int c = column_of (id);
            if (c < 0 || t.kind == DropKind.NONE) {
                return;
            }
            bool alone = columns[c].windows.size == 1;
            if (t.kind == DropKind.INTO_COLUMN && t.column >= 0 && t.column < columns.size
                && t.column != c && (solo.is_solo (id) || any_solo (columns[t.column]))) {
                // A solo window never shares a column: it lands beside the target instead.
                t = DropTarget () { kind = DropKind.NEW_COLUMN, column = t.column + 1 };
            }
            if (t.kind == DropKind.NEW_COLUMN && alone && (t.column == c || t.column == c + 1)) {
                return; // its own slot
            }
            if (t.kind == DropKind.INTO_COLUMN) {
                if (t.column < 0 || t.column >= columns.size) {
                    return;
                }
                if (t.column == c && t.row == row_of (c, id)) {
                    return;
                }
            }
            var was_focused = focused == id;
            remove (id);
            // Indices were taken before the removal; an emptied column to the left shifts them.
            int target = t.column;
            if (alone && target > c) {
                target--;
            }
            if (t.kind == DropKind.INTO_COLUMN) {
                var col = columns[target];
                col.windows.insert (t.row.clamp (0, col.windows.size), id);
                col.reset_shares ();
            } else {
                columns.insert (target.clamp (0, columns.size), new_column (id));
            }
            if (was_focused || focused == 0) {
                focus (id);
            }
        }
    }

    /** The ids ordered by their x, left to right; equal xs keep their order. */
    public uint64[] order_by_x (uint64[] ids, int[] xs) {
        var idx = new Gee.ArrayList<int> ();
        for (int i = 0; i < ids.length; i++) {
            idx.add (i);
        }
        // Gee's sort is a merge sort (TimSort), so it is stable.
        idx.sort ((a, b) => xs[a] < xs[b] ? -1 : (xs[a] > xs[b] ? 1 : 0));
        var result = new uint64[ids.length];
        for (int i = 0; i < ids.length; i++) {
            result[i] = ids[idx[i]];
        }
        return result;
    }
}
