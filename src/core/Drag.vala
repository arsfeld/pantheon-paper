namespace Paper {
    /** How far a window must be pulled up or down out of the strip before a drag stops panning. */
    public const int DETACH_PX = 100;

    /**
     * A move grab of a tiled window, as PaperWM does it: dragging sideways
     * pans the whole strip with the window, so the window stays in its column.
     * Pulling it DETACH_PX up or down takes it out of the tiling for the rest
     * of the grab, and it lands where it is dropped (Drop.vala). Detaching is
     * one-way: moving back into the band does not resume panning.
     */
    public class DragPan {
        private int x0;
        private int y0;
        private int scroll0;
        public bool detached { get; private set; default = false; }

        public DragPan (int x, int y, int scroll_x) {
            x0 = x;
            y0 = y;
            scroll0 = scroll_x;
        }

        /** Track the pointer; while still panning, set the strip's scroll so it follows. */
        public void update (Strip s, int x, int y, Rect work, WidthHints hints) {
            if (detached) {
                return;
            }
            if ((y - y0).abs () > DETACH_PX) {
                detached = true;
                return;
            }
            s.scroll_x = scroll0;
            pan (s, -(x - x0), work, hints);
        }

        /** Taken out of the strip by some other means (another monitor). */
        public void detach () {
            detached = true;
        }
    }
}
