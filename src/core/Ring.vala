namespace Paper {
    /** Width of the focus ring around the focused tiled window. */
    public const int RING_WIDTH = 3;

    /**
     * How wide the ring may be with this gap. It sits in the gap outside the
     * frame, and the other half of the gap belongs to the neighbour, so at
     * most half of it; 0 means no ring.
     */
    public int ring_width (int gap) {
        return int.min (RING_WIDTH, gap / 2);
    }

    /**
     * The ring's outer box, `width` px outside `frame` on every side but kept
     * inside `bounds` (the work area), relative to the window actor's origin:
     * its buffer rect, which also holds the client-side shadows. Columns have
     * gaps between them but sit flush with the panel and the screen edges, so
     * there a bar covers the window's own edge instead of going unseen.
     */
    public Rect ring_box (Rect frame, int origin_x, int origin_y, int width, Rect bounds) {
        int left = int.max (frame.x - width, bounds.x);
        int top = int.max (frame.y - width, bounds.y);
        int right = int.min (frame.x + frame.width + width, bounds.x + bounds.width);
        int bottom = int.min (frame.y + frame.height + width, bounds.y + bounds.height);
        return Rect (left - origin_x, top - origin_y, right - left, bottom - top);
    }

    /** The four bars (top, bottom, left, right) of a ring box this size, relative to the box. */
    public Rect[] ring_bars (int box_width, int box_height, int width) {
        return {
            Rect (0, 0, box_width, width),
            Rect (0, box_height - width, box_width, width),
            Rect (0, width, width, box_height - 2 * width),
            Rect (box_width - width, width, width, box_height - 2 * width),
        };
    }
}
