namespace Paper {
    /**
     * A thumbnail of the window a screen edge hides, shown while the pointer
     * rests against that edge (PaperWM's edge preview). The margin already
     * leaves a strip of that window at the edge, so the pointer is over it and
     * a click there focuses it; the thumbnail is non-reactive and never takes
     * the click.
     *
     * It follows the pointer through the cursor tracker's
     * `position-invalidated`, which fires on every pointer motion whatever
     * the pointer is over, and consumes nothing. Only edges that end the
     * screen count: where another monitor adjoins, the pointer crosses over.
     */
    public class EdgePreview : Object {
        /** How close to the edge the pointer must be, and how far it may stray before the preview goes. */
        private const int REACH = 2;
        private const uint DELAY_MS = 100;
        private const float SCALE = 0.15f;

        private Gala.WindowManager wm;
        private weak Controller c;
        private unowned Meta.Display display;
        private ulong motion_handler = 0;
        private ulong grab_begin_handler = 0;
        private ulong grab_end_handler = 0;
        private bool grabbing = false;
        private uint delay_source = 0;

        /** What the delay is waiting to show, or what is shown. */
        private Side side = Side.RIGHT;
        private Meta.Window? target = null;
        private Clutter.Actor? source = null;
        private ulong destroy_handler = 0;
        private Clutter.Clone? clone = null;

        public EdgePreview (Gala.WindowManager wm, Controller c) {
            this.wm = wm;
            this.c = c;
            display = wm.get_display ();
            motion_handler = cursor_tracker (display).position_invalidated.connect (refresh);
            grab_begin_handler = display.grab_op_begin.connect (() => {
                grabbing = true;
                hide ();
            });
            grab_end_handler = display.grab_op_end.connect (() => {
                grabbing = false;
                refresh ();
            });
        }

        public void destroy () {
            hide ();
            if (motion_handler != 0) {
                cursor_tracker (display).disconnect (motion_handler);
                motion_handler = 0;
            }
            if (grab_begin_handler != 0) {
                display.disconnect (grab_begin_handler);
                display.disconnect (grab_end_handler);
                grab_begin_handler = 0;
                grab_end_handler = 0;
            }
        }

        /** Show, keep, move or drop the preview for where the pointer is now. */
        public void refresh () {
            Graphene.Point p;
            Clutter.ModifierType mods;
            pointer (display, out p, out mods);
            Side at;
            var w = wanted ((int) p.x, (int) p.y, out at);
            if (w == null) {
                hide ();
                return;
            }
            if (w == target && at == side) {
                if (clone != null) {
                    place ((int) p.y);
                }
                return;
            }
            hide ();
            target = w;
            side = at;
            delay_source = Timeout.add (DELAY_MS, () => {
                delay_source = 0;
                show ();
                return Source.REMOVE;
            });
        }

        /** Where the preview is on the stage, for the demo log. */
        public string describe () {
            if (clone == null) {
                return "none";
            }
            var e = clone.get_transformed_extents ();
            return "%s %s @%d,%d %dx%d".printf (side == Side.LEFT ? "left" : "right", target.get_title () ?? "?",
                (int) Math.round (e.get_x ()), (int) Math.round (e.get_y ()),
                (int) Math.round (e.get_width ()), (int) Math.round (e.get_height ()));
        }

        /** The window to preview for a pointer at (x, y), and on which side; null for none. */
        private Meta.Window? wanted (int x, int y, out Side at) {
            at = Side.RIGHT;
            if (!c.config.edge_preview || grabbing || wm.is_modal ()) {
                return null;
            }
            var focus = display.focus_window;
            if (focus != null && focus.fullscreen) {
                return null;
            }
            var ws = display.get_workspace_manager ().get_active_workspace ();
            var s = c.current_strip ();
            if (s == null || !c.workspace_tiled (ws) || s.columns.size == 0) {
                return null;
            }
            var work = c.work_area ();
            if (y < work.y || y >= work.y + work.height) {
                return null;
            }
            bool wall_left, wall_right;
            c.walls (out wall_left, out wall_right);
            if (!wall_left && x < work.x + REACH) {
                at = Side.LEFT;
            } else if (!wall_right && x >= work.x + work.width - REACH) {
                at = Side.RIGHT;
            } else {
                return null;
            }
            int i = hidden_beyond (c.layout_of (s), work, at);
            return i < 0 ? null : c.window_for (s.active_window (s.columns[i]));
        }

        private void show () {
            source = target == null ? null : target.get_compositor_private () as Clutter.Actor;
            if (source == null) {
                target = null;
                return;
            }
            clone = new Clutter.Clone (source) {
                reactive = false
            };
            clone.set_scale (SCALE, SCALE);
            wm.top_window_group.add_child (clone);
            // The window may close while previewed: Mutter destroys its actor after `unmanaging`.
            destroy_handler = source.destroy.connect (hide);
            Graphene.Point p;
            Clutter.ModifierType mods;
            pointer (display, out p, out mods);
            place ((int) p.y);
            if (c.animations_enabled ()) {
                clone.opacity = 0;
                clone.save_easing_state ();
                clone.set_easing_duration (ANIM_MS);
                clone.opacity = 255;
                clone.restore_easing_state ();
            }
        }

        /** Flush against the edge, centred on the pointer's height, inside the work area. */
        private void place (int pointer_y) {
            var work = c.work_area ();
            int w = (int) Math.round (source.width * SCALE);
            int h = (int) Math.round (source.height * SCALE);
            int x = side == Side.LEFT ? work.x : work.x + work.width - w;
            int y = (pointer_y - h / 2).clamp (work.y, int.max (work.y, work.y + work.height - h));
            clone.set_position (x, y);
        }

        private void hide () {
            if (delay_source != 0) {
                Source.remove (delay_source);
                delay_source = 0;
            }
            if (source != null) {
                source.disconnect (destroy_handler);
                destroy_handler = 0;
                source = null;
            }
            if (clone != null) {
                clone.destroy ();
                clone = null;
            }
            target = null;
        }
    }
}
