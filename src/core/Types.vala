namespace Paper {
    /** Gap between columns and between stacked windows, in logical pixels. */
    public const int GAP = 8;
    /** How much of a parked column stays on screen. */
    public const int SLIVER = 10;
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
