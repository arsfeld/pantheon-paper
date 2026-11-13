namespace Paper {
    /** The width a window actually needs, when larger than asked (0 = unknown). */
    public interface WidthHints : Object {
        public abstract int min_width (uint64 id);
    }

    public class NoHints : Object, WidthHints {
        public int min_width (uint64 id) {
            return 0;
        }
    }

    public struct Placement {
        public uint64 id;
        public Rect rect;
        /** Pushed against a screen edge with only a sliver showing. */
        public bool parked;
    }

    public class LayoutResult : Object {
        public Gee.ArrayList<Placement?> windows = new Gee.ArrayList<Placement?> ();
        /** Each column's on-screen rectangle, in strip order. */
        public Gee.ArrayList<Rect?> columns = new Gee.ArrayList<Rect?> ();
    }

    private int column_width (Column col, Rect work, WidthHints hints) {
        int w;
        if (col.full) {
            w = work.width;
        } else if (col.free_px > 0) {
            w = col.free_px;
        } else {
            w = col.preset.pixels (work.width);
        }
        foreach (var id in col.windows) {
            w = int.max (w, hints.min_width (id));
        }
        return w;
    }

    /** Column i's left edge in strip coordinates (before scrolling), and its width. */
    private void column_span (Strip s, int index, Rect work, WidthHints hints, out int left, out int width) {
        left = 0;
        for (int i = 0; i < index; i++) {
            left += column_width (s.columns[i], work, hints) + GAP;
        }
        width = column_width (s.columns[index], work, hints);
    }

    private int total_width (Strip s, Rect work, WidthHints hints) {
        if (s.columns.size == 0) {
            return 0;
        }
        int left, width;
        column_span (s, s.columns.size - 1, work, hints, out left, out width);
        return left + width;
    }

    public LayoutResult layout (Strip s, Rect work, WidthHints hints) {
        var result = new LayoutResult ();
        int left = 0;
        foreach (var col in s.columns) {
            int w = column_width (col, work, hints);
            int x = work.x + left - s.scroll_x;
            int visible = int.min (x + w, work.x + work.width) - int.max (x, work.x);
            bool parked = visible < SLIVER;
            if (parked) {
                x = x >= work.x ? work.x + work.width - SLIVER : work.x + SLIVER - w;
            }
            result.columns.add (Rect (x, work.y, w, work.height));

            int n = col.windows.size;
            int available = work.height - GAP * (n - 1);
            int y = work.y;
            for (int r = 0; r < n; r++) {
                int h = r == n - 1
                    ? work.y + work.height - y
                    : (int) Math.round (available * col.shares[r]);
                result.windows.add (Placement () {
                    id = col.windows[r],
                    rect = Rect (x, y, w, h),
                    parked = parked,
                });
                y += h + GAP;
            }
            left += w + GAP;
        }
        return result;
    }

    /** Scroll the least needed to show the focused column whole (left-aligned if too wide). */
    public void scroll_to_focus (Strip s, Rect work, WidthHints hints) {
        int c = s.focused_column ();
        if (c < 0) {
            return;
        }
        int left, width;
        column_span (s, c, work, hints, out left, out width);
        if (width >= work.width || left < s.scroll_x) {
            s.scroll_x = left;
        } else if (left + width > s.scroll_x + work.width) {
            s.scroll_x = left + width - work.width;
        }
    }

    /** Scroll so the focused column's centre sits at the work area's centre. */
    public void center_focus (Strip s, Rect work, WidthHints hints) {
        int c = s.focused_column ();
        if (c < 0) {
            return;
        }
        int left, width;
        column_span (s, c, work, hints, out left, out width);
        s.scroll_x = left + width / 2 - work.width / 2;
    }

    /** Pan by dx, keeping the strip within half a screen of either end. */
    public void pan (Strip s, int dx, Rect work, WidthHints hints) {
        int half = work.width / 2;
        s.scroll_x = (s.scroll_x + dx).clamp (-half, int.max (-half, total_width (s, work, hints) - half));
    }
}
