namespace Paper {
    /**
     * Pointer handling: Super+scroll pans the strip, dragging a tiled window
     * drops it into a column or a new column, and resizing one sets its
     * column's width or its share of the column height.
     */
    public class Mouse : Object {
        /** Pixels panned per discrete scroll step and per unit of smooth scroll. */
        private const int STEP_PX = 200;
        private const int SMOOTH_PX = 40;

        /**
         * Gala's own Super+scroll handling is a stage action in the capture
         * phase too: it sees events before Mutter hands them to clients.
         */
        private class ScrollAction : Clutter.Action {
            public weak Mouse mouse;
            public unowned Meta.Display display;

            public override bool handle_event (Clutter.Event event) {
                if (event.get_type () != Clutter.EventType.SCROLL
                    || (event.get_state () & display.compositor_modifiers) == 0) {
                    return Clutter.EVENT_PROPAGATE;
                }
                // Clutter delivers each wheel click twice, as a discrete step and
                // as an emulated smooth one (or the reverse): act on the real one
                // and swallow its echo, so one click pans once.
                if ((event.get_flags () & Clutter.EventFlags.FLAG_POINTER_EMULATED) != 0) {
                    return mouse.has_strip () ? Clutter.EVENT_STOP : Clutter.EVENT_PROPAGATE;
                }
                switch (event.get_scroll_direction ()) {
                    case Clutter.ScrollDirection.SMOOTH:
                        double dx, dy;
                        event.get_scroll_delta (out dx, out dy);
                        // A wheel's smooth unit is one detent; a touchpad's is a fraction of its motion.
                        int scale = event.get_scroll_source () == Clutter.ScrollSource.WHEEL ? STEP_PX : SMOOTH_PX;
                        return mouse.pan_by ((int) Math.round ((dx != 0 ? dx : dy) * scale), false);
                    case Clutter.ScrollDirection.LEFT:
                    case Clutter.ScrollDirection.UP:
                        return mouse.pan_by (-STEP_PX, true);
                    default:
                        return mouse.pan_by (STEP_PX, true);
                }
            }
        }

        private const string ACTION_NAME = "paper-super-scroll";

        private Gala.WindowManager wm;
        private Controller c;
        private unowned Meta.Display display;
        private ulong begin_id;
        private ulong end_id;
        private uint track_source = 0;
        private Clutter.Actor? indicator = null;

        public Mouse (Gala.WindowManager wm, Controller c) {
            this.wm = wm;
            this.c = c;
            display = wm.get_display ();
            var action = new ScrollAction ();
            action.mouse = this;
            action.display = display;
            wm.stage.add_action_full (ACTION_NAME, Clutter.EventPhase.CAPTURE, action);
            begin_id = display.grab_op_begin.connect (on_grab_begin);
            end_id = display.grab_op_end.connect (on_grab_end);
        }

        public void destroy () {
            wm.stage.remove_action_by_name (ACTION_NAME);
            display.disconnect (begin_id);
            display.disconnect (end_id);
            stop_tracking ();
        }

        public bool has_strip () {
            var s = c.current_strip ();
            return s != null && s.columns.size > 0;
        }

        /** Pan the visible strip; STOP only when there was a strip to pan. */
        public bool pan_by (int dx, bool animate) {
            if (!has_strip ()) {
                return Clutter.EVENT_PROPAGATE;
            }
            var s = c.current_strip ();
            pan (s, dx, c.work_area (), c.hints ());
            c.relayout (animate);
            return Clutter.EVENT_STOP;
        }

        private static bool is_move (Meta.GrabOp op) {
            return op == Meta.GrabOp.MOVING || op == Meta.GrabOp.MOVING_UNCONSTRAINED
                || op == Meta.GrabOp.KEYBOARD_MOVING;
        }

        private void on_grab_begin (Meta.Window? w, Meta.GrabOp op) {
            if (w == null || c.strip_of (w.get_id ()) == null) {
                return;
            }
            c.grabbed = w.get_id ();
            if (is_move (op)) {
                start_tracking (w.get_id ());
            }
        }

        private void on_grab_end (Meta.Window? w, Meta.GrabOp op) {
            stop_tracking ();
            if (w == null || c.grabbed != w.get_id ()) {
                return;
            }
            c.grabbed = 0;
            if (is_move (op)) {
                Graphene.Point p;
                Clutter.ModifierType mods;
                display.get_context ().get_backend ().get_cursor_tracker ().get_pointer (out p, out mods);
                drop (w.get_id (), (int) p.x, (int) p.y);
            } else {
                resized (w.get_id ());
            }
        }

        /** End of a move: leave the strip on another monitor, else land where hit_test says. */
        public void drop (uint64 id, int x, int y) {
            var s = c.strip_of (id);
            if (s == null) {
                return;
            }
            if (display.get_current_monitor () != display.get_primary_monitor ()) {
                s.remove (id);
                c.relayout ();
                return;
            }
            var target = hit_test (c.layout_of (s), s, id, x, y);
            s.move_to (id, target);
            s.focus (id);
            scroll_to_focus (s, c.work_area (), c.hints ());
            c.relayout ();
        }

        /** End of a resize: keep a new width as the column's, a new height as the window's share. */
        public void resized (uint64 id) {
            var s = c.strip_of (id);
            var w = c.window_for (id);
            if (s == null || w == null) {
                return;
            }
            var frame = w.get_frame_rect ();
            var work = c.work_area ();
            var col = s.columns[s.column_of (id)];
            var current = c.layout_of (s);
            foreach (var p in current.windows) {
                if (p.id == id && p.rect.width != frame.width) {
                    s.set_free_width (id, frame.width);
                }
            }
            int n = col.windows.size;
            if (n > 1) {
                int row = col.windows.index_of (id);
                int available = work.height - GAP * (n - 1);
                int h = frame.height.clamp (1, available - (n - 1));
                double others = 1.0 - col.shares[row];
                var heights = new int[n];
                for (int i = 0; i < n; i++) {
                    heights[i] = i == row ? h
                        : (int) Math.round ((available - h) * (others > 0 ? col.shares[i] / others : 1.0 / (n - 1)));
                }
                s.set_shares (s.column_of (id), shares_from_heights (heights));
            }
            c.relayout ();
        }

        private void start_tracking (uint64 id) {
            stop_tracking ();
            indicator = new Clutter.Actor ();
            indicator.background_color = Cogl.Color.from_4f (0.21f, 0.54f, 0.90f, 0.3f);
            indicator.reactive = false;
            indicator.visible = false;
            wm.top_window_group.add_child (indicator);
            track_source = Timeout.add (16, () => {
                track (id);
                return Source.CONTINUE;
            });
        }

        private void stop_tracking () {
            if (track_source != 0) {
                Source.remove (track_source);
                track_source = 0;
            }
            if (indicator != null) {
                indicator.destroy ();
                indicator = null;
            }
        }

        /** Show where a dragged window would land. */
        private void track (uint64 id) {
            var s = c.strip_of (id);
            if (s == null || indicator == null) {
                return;
            }
            Graphene.Point p;
            Clutter.ModifierType mods;
            display.get_context ().get_backend ().get_cursor_tracker ().get_pointer (out p, out mods);
            var r = c.layout_of (s);
            var t = hit_test (r, s, id, (int) p.x, (int) p.y);
            if (t.kind == DropKind.NONE || display.get_current_monitor () != display.get_primary_monitor ()) {
                indicator.visible = false;
                return;
            }
            Rect area;
            if (t.kind == DropKind.INTO_COLUMN) {
                area = r.columns[t.column];
            } else {
                // A bar on the boundary the new column would open at.
                int edge = t.column < r.columns.size ? r.columns[t.column].x - GAP / 2
                    : r.columns[t.column - 1].x + r.columns[t.column - 1].width + GAP / 2;
                var work = c.work_area ();
                area = Rect (edge - 8, work.y, 16, work.height);
            }
            indicator.set_position (area.x, area.y);
            indicator.set_size (area.width, area.height);
            indicator.visible = true;
        }
    }
}
