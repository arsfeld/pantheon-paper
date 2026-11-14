namespace Paper {
    /**
     * An outline in the accent colour around the focused tiled window, in the
     * gap outside its frame. It is a child of that window's actor, so it rides
     * the Applier's scroll animation (the actor's translation) and stacks,
     * minimizes and changes workspace with the window, with nothing to track.
     *
     * The ring dies with its window actor: it is dropped on the actor's
     * `destroy` as well as whenever the Controller moves it.
     */
    public class FocusRing : Object {
        private Meta.Window? window = null;
        private Clutter.Actor? parent = null;
        private Clutter.Actor? ring = null;
        private int width = 0;
        private Rect bounds;
        private ulong size_handler = 0;
        private ulong destroy_handler = 0;
        private ulong accent_handler = 0;

        construct {
            accent_handler = Gala.Drawing.StyleManager.get_instance ()
                .notify["theme-accent-color"].connect (recolor);
        }

        /** Put the ring around `w`, `width` px wide and inside `bounds`; null or 0 takes it away. */
        public void show (Meta.Window? w, int width, Rect bounds) {
            var actor = w == null ? null : w.get_compositor_private () as Clutter.Actor;
            if (actor == null || width <= 0) {
                hide ();
                return;
            }
            if (w != window || actor != parent) {
                hide ();
                attach (w, actor);
            }
            this.width = width;
            this.bounds = bounds;
            place ();
        }

        public void hide () {
            if (window != null) {
                window.disconnect (size_handler);
                window = null;
            }
            if (parent != null) {
                parent.disconnect (destroy_handler);
                parent = null;
            }
            if (ring != null) {
                ring.destroy ();
                ring = null;
            }
        }

        public void destroy () {
            hide ();
            if (accent_handler != 0) {
                Gala.Drawing.StyleManager.get_instance ().disconnect (accent_handler);
                accent_handler = 0;
            }
        }

        /** Where the ring is on the stage, for the demo log. */
        public string describe () {
            if (ring == null) {
                return "none";
            }
            var e = ring.get_transformed_extents ();
            return "@%d,%d %dx%d".printf ((int) Math.round (e.get_x ()), (int) Math.round (e.get_y ()),
                (int) Math.round (e.get_width ()), (int) Math.round (e.get_height ()));
        }

        private void attach (Meta.Window w, Clutter.Actor actor) {
            window = w;
            parent = actor;
            ring = new Clutter.Actor ();
            ring.reactive = false;
            for (int i = 0; i < 4; i++) {
                var bar = new Clutter.Actor ();
                bar.reactive = false;
                ring.add_child (bar);
            }
            recolor ();
            actor.add_child (ring);
            // A Wayland client's new size lands after the Applier asked for it.
            size_handler = w.size_changed.connect (place);
            // Mutter destroys the actor after `unmanaging`; drop the ring with it.
            destroy_handler = actor.destroy.connect (hide);
        }

        private void place () {
            if (ring == null || window == null) {
                return;
            }
            var f = window.get_frame_rect ();
            var b = window.get_buffer_rect ();
            var box = ring_box (Rect (f.x, f.y, f.width, f.height), b.x, b.y, width, bounds);
            ring.set_position (box.x, box.y);
            ring.set_size (box.width, box.height);
            var bars = ring_bars (box.width, box.height, width);
            int i = 0;
            for (var bar = ring.get_first_child (); bar != null && i < bars.length; bar = bar.get_next_sibling ()) {
                bar.set_position (bars[i].x, bars[i].y);
                bar.set_size (bars[i].width, bars[i].height);
                i++;
            }
        }

        private void recolor () {
            if (ring == null) {
                return;
            }
            float r, g, b;
            accent_color (out r, out g, out b);
            for (var bar = ring.get_first_child (); bar != null; bar = bar.get_next_sibling ()) {
                set_background (bar, r, g, b, 1.0f);
            }
        }
    }
}
