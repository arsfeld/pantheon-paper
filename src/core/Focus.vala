namespace Paper {
    /**
     * The last focused *normal* window, which is what "focused" means to the
     * D-Bus interface: a panel popover, a menu or a dock can take Mutter's
     * focus while the user still means the window they were working in.
     */
    public class FocusTracker : Object {
        /** The window id, or 0 when there is none. */
        public uint64 last { get; private set; default = 0; }

        public void focused (uint64 id, bool normal) {
            if (normal) {
                last = id;
            }
        }

        /** The window is gone: if it was the last one, there is none now. */
        public void forget (uint64 id) {
            if (last == id) {
                last = 0;
            }
        }
    }
}
