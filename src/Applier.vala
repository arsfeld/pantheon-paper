namespace Paper {
    /**
     * Moves windows to their layout rectangles. Pure moves (scrolling,
     * reordering) animate through the window actor's translation; a resize
     * lands only when a Wayland client answers, so resizes apply directly.
     */
    public class Applier : Object {
        private weak Controller controller;

        public Applier (Controller controller) {
            this.controller = controller;
        }

        public void apply (LayoutResult result, bool animate) {
            foreach (var p in result.windows) {
                var w = controller.window_for (p.id);
                if (w == null || p.id == controller.grabbed) {
                    continue;
                }
                var f = w.get_frame_rect ();
                var r = p.rect;
                if (f.x == r.x && f.y == r.y && f.width == r.width && f.height == r.height) {
                    continue;
                }
                bool move_only = f.width == r.width && f.height == r.height;
                if (!move_only) {
                    controller.resize_requested (p.id);
                }
                // user_op: Mutter clamps non-user moves fully on screen, which
                // would pull parked windows back in; a user op only has to stay
                // partly visible (PaperWM moves windows the same way).
                w.move_resize_frame (true, r.x, r.y, r.width, r.height);
                var actor = w.get_compositor_private () as Clutter.Actor;
                if (actor == null) {
                    continue;
                }
                if (!animate || !move_only) {
                    actor.set_translation (0, 0, 0);
                    continue;
                }
                // Continue from wherever an earlier animation had got to.
                actor.set_translation (actor.translation_x + (f.x - r.x), actor.translation_y + (f.y - r.y), 0);
                actor.save_easing_state ();
                actor.set_easing_duration (ANIM_MS);
                actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                actor.set_translation (0, 0, 0);
                actor.restore_easing_state ();
            }
        }

        /** Drop anything held for a window that is going away. */
        public void forget (uint64 id) {
            var w = controller.window_for (id);
            if (w == null) {
                return;
            }
            var actor = w.get_compositor_private () as Clutter.Actor;
            if (actor != null) {
                actor.remove_transition ("translation-x");
                actor.remove_transition ("translation-y");
            }
        }
    }
}
