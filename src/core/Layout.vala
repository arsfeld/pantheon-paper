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
        /** Its column's index in the strip. */
        public int column;
    }

    public class LayoutResult : Object {
        public Gee.ArrayList<Placement?> windows = new Gee.ArrayList<Placement?> ();
        /** Each column's on-screen rectangle, in strip order. */
        public Gee.ArrayList<Rect?> columns = new Gee.ArrayList<Rect?> ();
        /** Whether each column is parked, in strip order. */
        public Gee.ArrayList<bool> parked = new Gee.ArrayList<bool> ();
    }

    public enum Side {
        LEFT,
        RIGHT
    }

    private int column_width (Params p, Column col, Rect work, WidthHints hints) {
        int w;
        if (col.full) {
            w = p.usable (work.width);
        } else if (col.free_px > 0) {
            w = col.free_px;
        } else {
            w = p.pixels (col.preset, work.width);
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
            left += column_width (s.params, s.columns[i], work, hints) + s.params.gap;
        }
        width = column_width (s.params, s.columns[index], work, hints);
    }

    private int total_width (Strip s, Rect work, WidthHints hints) {
        if (s.columns.size == 0) {
            return 0;
        }
        int left, width;
        column_span (s, s.columns.size - 1, work, hints, out left, out width);
        return left + width;
    }

    /**
     * wall_left / wall_right: another monitor adjoins the work area on that
     * side. A column crossing such an edge would sit mostly on that monitor,
     * and Mutter would take it off the primary's workspace (with
     * workspaces-only-on-primary it becomes sticky), so it is parked inside
     * the edge instead, flush with it, for the applier to lower beneath the
     * visible columns.
     */
    public LayoutResult layout (Strip s, Rect work, WidthHints hints, bool wall_left = false, bool wall_right = false) {
        var result = new LayoutResult ();
        int gap = s.params.gap;
        int left = 0;
        foreach (var col in s.columns) {
            int w = column_width (s.params, col, work, hints);
            int x = work.x + s.params.margin + left - s.scroll_x;
            int right = work.x + work.width;
            int visible = int.min (x + w, right) - int.max (x, work.x);
            bool parked = false;
            if (wall_right && x + w > right && x > work.x) {
                x = right - w;
                parked = true;
            } else if (wall_left && x < work.x && x + w < right) {
                x = work.x;
                parked = true;
            } else if (visible < SLIVER) {
                x = x >= work.x ? right - SLIVER : work.x + SLIVER - w;
                parked = true;
            }
            result.columns.add (Rect (x, work.y, w, work.height));
            result.parked.add (parked);

            int n = col.windows.size;
            int available = work.height - gap * (n - 1);
            int y = work.y;
            for (int r = 0; r < n; r++) {
                int h = r == n - 1
                    ? work.y + work.height - y
                    : (int) Math.round (available * col.shares[r]);
                result.windows.add (Placement () {
                    id = col.windows[r],
                    rect = Rect (x, y, w, h),
                    parked = parked,
                    column = result.columns.size - 1,
                });
                y += h + gap;
            }
            left += w + gap;
        }
        return result;
    }

    /**
     * The column a screen edge hides: the one nearest the visible area on
     * `side` that has its centre beyond that edge, or is parked on that half
     * of the work area. Its index into `r.columns`, or -1 when nothing is
     * hidden there.
     */
    public int hidden_beyond (LayoutResult r, Rect work, Side side) {
        int n = r.columns.size;
        for (int k = 0; k < n; k++) {
            int i = side == Side.RIGHT ? k : n - 1 - k;
            int centre = r.columns[i].x + r.columns[i].width / 2;
            bool hidden = side == Side.RIGHT
                ? centre > work.x + work.width || (r.parked[i] && !on_left (r.columns[i], work))
                : centre < work.x || (r.parked[i] && on_left (r.columns[i], work));
            if (hidden) {
                return i;
            }
        }
        return -1;
    }

    /** Which half of the work area a column sits on: where it is parked, if it is. */
    private bool on_left (Rect c, Rect work) {
        return c.x + c.width / 2 < work.x + work.width / 2;
    }

    /**
     * The parked windows in the order to lower them, nearest the visible
     * columns first. Lowering sends a window to the bottom, so the nearest
     * parked column ends on top on each side, and its strip is what peeks in
     * at the edge.
     */
    public Gee.List<uint64?> lowering_order (LayoutResult r, Rect work) {
        var order = new Gee.ArrayList<uint64?> ();
        int n = r.columns.size;
        // Left side: from the visible columns outward (high index to low); then the right, low to high.
        for (int k = 0; k < 2 * n; k++) {
            int c = k < n ? n - 1 - k : k - n;
            if (!r.parked[c] || on_left (r.columns[c], work) != (k < n)) {
                continue;
            }
            foreach (var p in r.windows) {
                if (p.column == c) {
                    order.add (p.id);
                }
            }
        }
        return order;
    }

    /**
     * Scroll the least needed to show the focused column whole between the
     * margins (centred if it is too wide for them), so the column beyond an
     * edge keeps a margin's width of itself on screen.
     */
    public void scroll_to_focus (Strip s, Rect work, WidthHints hints) {
        int c = s.focused_column ();
        if (c < 0) {
            return;
        }
        int left, width;
        column_span (s, c, work, hints, out left, out width);
        int usable = s.params.usable (work.width);
        if (width >= usable) {
            s.scroll_x = s.params.margin + left - (work.width - width) / 2;
        } else if (left < s.scroll_x) {
            s.scroll_x = left;
        } else if (left + width > s.scroll_x + usable) {
            s.scroll_x = left + width - usable;
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
        s.scroll_x = s.params.margin + left + width / 2 - work.width / 2;
    }

    /** Pan by dx, keeping the strip within half a screen of either end. */
    public void pan (Strip s, int dx, Rect work, WidthHints hints) {
        int half = work.width / 2;
        s.scroll_x = (s.scroll_x + dx).clamp (-half, int.max (-half, total_width (s, work, hints) - half));
    }
}
