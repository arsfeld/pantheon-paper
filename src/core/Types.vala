namespace Paper {
    /** Gap between columns and between stacked windows, in logical pixels. */
    public const int GAP = 8;
    /**
     * How much of a parked column stays on screen. Mutter keeps 75 px of a
     * window moved as a user op on screen, so a smaller sliver would only
     * disagree with where Mutter actually puts the window.
     */
    public const int SLIVER = 75;
    /** Duration of layout animations. */
    public const uint ANIM_MS = 200;

    public struct Rect {
        public int x;
        public int y;
        public int width;
        public int height;

        public Rect (int x, int y, int width, int height) {
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }
}

namespace Paper {
    /** Hash and equality for boxed window ids, for Gee collections. */
    public uint id_hash (uint64? id) {
        return (uint) ((uint64) id ^ ((uint64) id >> 32));
    }

    public bool id_equal (uint64? a, uint64? b) {
        return (uint64) a == (uint64) b;
    }
}
