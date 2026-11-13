namespace Paper {
    /** Why a window is being re-checked; decides where it re-enters a strip. */
    public enum Reason {
        CREATED,
        FULLSCREEN,
        MINIMIZED,
        WORKSPACE,
        MONITOR,
        TRANSIENT,
        FLOAT
    }

    /**
     * Binds Mutter to the pure core: tracks windows, keeps one Strip per
     * workspace (primary monitor), and lays them out on every change.
     *
     * A crash here ends the Pantheon session, so every handler looks windows
     * up by id and tolerates them being gone; `unmanaging` drops a window from
     * every map before anything else can touch it.
     */
    public class Controller : Object, WidthHints {
        public Gala.WindowManager wm { get; construct; }

        private unowned Meta.Display display;
        private Gee.HashMap<Meta.Workspace, Strip> strips = new Gee.HashMap<Meta.Workspace, Strip> ();
        private Gee.HashMap<uint64?, Meta.Window> windows = new Gee.HashMap<uint64?, Meta.Window> (id_hash, id_equal);
        private Gee.HashMap<uint64?, Gee.ArrayList<ulong>> handlers = new Gee.HashMap<uint64?, Gee.ArrayList<ulong>> (id_hash, id_equal);
        private Gee.HashSet<uint64?> floating = new Gee.HashSet<uint64?> (id_hash, id_equal);
        private Gee.HashSet<uint64?> adopted = new Gee.HashSet<uint64?> (id_hash, id_equal);
        /**
         * Where a window sat when it went fullscreen. Gala moves a fullscreen
         * window to a workspace of its own and back again, so the slot keeps its
         * workspace and is used only when the window re-enters that one.
         */
        private class Slot {
            public Meta.Workspace workspace;
            public int column;
            public Preset preset;
            public int free_px;
            public bool full;

            public Slot (Meta.Workspace workspace, Strip strip, uint64 id) {
                this.workspace = workspace;
                column = strip.column_of (id);
                var col = strip.columns[column];
                preset = col.preset;
                free_px = col.free_px;
                full = col.full;
            }
        }
        private Gee.HashMap<uint64?, Slot> slots = new Gee.HashMap<uint64?, Slot> (id_hash, id_equal);
        /** Width the layout wants for a window, before width hints. */
        private Gee.HashMap<uint64?, int> requested = new Gee.HashMap<uint64?, int> (id_hash, id_equal);
        /** Last frame width seen, for the size-changed loop guard. */
        private Gee.HashMap<uint64?, int> last_width = new Gee.HashMap<uint64?, int> (id_hash, id_equal);
        /**
         * When each window was last asked to resize (monotonic µs). A frame wider
         * than requested counts as the client refusing only once RESIZE_GRACE has
         * passed: before that it is just the old size, and any size-changed in
         * between (an unminimize, a redraw) says nothing about the answer.
         */
        private Gee.HashMap<uint64?, int64?> asked_at = new Gee.HashMap<uint64?, int64?> (id_hash, id_equal);
        /** The unhinted width that request was for: a hint needs the client to have refused this very width. */
        private Gee.HashMap<uint64?, int> asked_width = new Gee.HashMap<uint64?, int> (id_hash, id_equal);
        private const int64 RESIZE_GRACE = 1000000;
        private uint recheck_source = 0;
        private Gee.ArrayList<ulong> display_handlers = new Gee.ArrayList<ulong> ();
        private ulong[] manager_handlers = {};
        private Applier applier;
        private Settings interface_settings;
        public bool applying { get; private set; default = false; }
        /** A window the user is moving or resizing: layouts leave it where the pointer has it. */
        public uint64 grabbed { get; set; default = 0; }

        public Controller (Gala.WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            display = wm.get_display ();
            applier = new Applier (this);
            interface_settings = new Settings ("org.gnome.desktop.interface");

            display_handlers.add (display.window_created.connect ((w) => {
                track (w);
            }));
            display_handlers.add (display.notify["focus-window"].connect (on_focus));
            display_handlers.add (display.window_entered_monitor.connect ((monitor, w) => {
                // Parked windows can sit mostly on a neighbouring monitor;
                // only windows outside a strip are re-checked here.
                if (w != null && strip_of (w.get_id ()) == null && adopted.contains (w.get_id ())) {
                    reevaluate (w, Reason.MONITOR);
                }
            }));
            display_handlers.add (display.workareas_changed.connect (() => relayout (false)));

            var manager = display.get_workspace_manager ();
            manager_handlers += manager.workspace_removed.connect (prune_workspaces);
            manager_handlers += manager.active_workspace_changed.connect (() => relayout (false));

            adopt_existing ();
        }

        public void destroy () {
            foreach (var h in display_handlers) {
                display.disconnect (h);
            }
            var manager = display.get_workspace_manager ();
            foreach (var h in manager_handlers) {
                manager.disconnect (h);
            }
            if (recheck_source != 0) {
                Source.remove (recheck_source);
                recheck_source = 0;
            }
            foreach (var id in windows.keys.to_array ()) {
                untrack (id);
            }
        }

        // ---- lookups used by Keys, Mouse, Applier and Demo ----

        public Meta.Window? window_for (uint64 id) {
            return windows.has_key (id) ? windows[id] : null;
        }

        public Strip? strip_of (uint64 id) {
            foreach (var s in strips.values) {
                if (s.contains (id)) {
                    return s;
                }
            }
            return null;
        }

        public Strip? current_strip () {
            var ws = display.get_workspace_manager ().get_active_workspace ();
            return ws == null ? null : strip_for (ws);
        }

        public Rect work_area () {
            var ws = display.get_workspace_manager ().get_active_workspace ();
            return work_area_of (ws);
        }

        private Rect work_area_of (Meta.Workspace ws) {
            var r = ws.get_work_area_for_monitor (display.get_primary_monitor ());
            return Rect (r.x, r.y, r.width, r.height);
        }

        public WidthHints hints () {
            return this;
        }

        /** The frame width a client insists on when wider than what the layout asked. */
        public int min_width (uint64 id) {
            var w = window_for (id);
            if (w == null || !requested.has_key (id)) {
                return 0;
            }
            if (!asked_width.has_key (id) || asked_width[id] != requested[id]) {
                return 0; // never asked for this width: ask first
            }
            if (GLib.get_monotonic_time () - asked_at[id] < RESIZE_GRACE) {
                return 0; // asked, no answer yet
            }
            int frame = w.get_frame_rect ().width;
            return frame > requested[id] ? frame : 0;
        }

        public bool animations_enabled () {
            return interface_settings.get_boolean ("enable-animations");
        }

        public bool is_floating (uint64 id) {
            return floating.contains (id);
        }

        // ---- window tracking ----

        private void adopt_existing () {
            var manager = display.get_workspace_manager ();
            var seen = new Gee.HashSet<uint64?> (id_hash, id_equal);
            var all = new SList<Meta.Window> ();
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                foreach (var w in manager.get_workspace_by_index (i).list_windows ()) {
                    if (seen.add (w.get_id ())) {
                        all.append (w);
                    }
                }
            }
            foreach (var w in display.sort_windows_by_stacking (all)) {
                track (w);
                adopted.add (w.get_id ());
                if (should_tile (facts_for (w))) {
                    strip_for (w.get_workspace ()).append (w.get_id ());
                }
            }
            var focus = display.focus_window;
            if (focus != null) {
                on_focus ();
            }
            relayout (false);
        }

        private void track (Meta.Window w) {
            var id = w.get_id ();
            if (windows.has_key (id)) {
                return;
            }
            windows[id] = w;
            var ids = new Gee.ArrayList<ulong> ();
            ids.add (w.shown.connect (() => {
                if (adopted.add (id)) {
                    reevaluate (w, Reason.CREATED);
                }
            }));
            // `unmanaging`, not `unmanaged`: while a window is unmanaged Mutter
            // focuses another one before `unmanaged` fires, and a relayout from
            // that focus change would move the half-destroyed window (SIGSEGV in
            // meta_window_update_monitor).
            ids.add (w.unmanaging.connect (() => untrack (id)));
            ids.add (w.size_changed.connect (() => on_size_changed (id)));
            ids.add (w.workspace_changed.connect (() => {
                if (adopted.contains (id)) {
                    reevaluate (w, Reason.WORKSPACE);
                }
            }));
            ids.add (w.notify["fullscreen"].connect (() => reevaluate (w, Reason.FULLSCREEN)));
            ids.add (w.notify["minimized"].connect (() => reevaluate (w, Reason.MINIMIZED)));
            ids.add (w.notify["transient-for"].connect (() => reevaluate (w, Reason.TRANSIENT)));
            ids.add (w.notify["maximized-horizontally"].connect (() => on_maximized (id)));
            ids.add (w.notify["maximized-vertically"].connect (() => on_maximized (id)));
            handlers[id] = ids;
        }

        private void untrack (uint64 id) {
            var w = window_for (id);
            applier.forget (id);
            windows.unset (id);
            foreach (var s in strips.values) {
                if (s.contains (id)) {
                    s.remove (id);
                }
            }
            if (w != null && handlers.has_key (id)) {
                foreach (var h in handlers[id]) {
                    w.disconnect (h);
                }
            }
            handlers.unset (id);
            floating.remove (id);
            adopted.remove (id);
            slots.unset (id);
            requested.unset (id);
            last_width.unset (id);
            asked_at.unset (id);
            asked_width.unset (id);
            relayout ();
        }

        private WindowFacts facts_for (Meta.Window w) {
            return WindowFacts () {
                normal_type = w.get_window_type () == Meta.WindowType.NORMAL
                    && !w.is_override_redirect () && !w.is_skip_taskbar (),
                has_transient_parent = w.get_transient_for () != null,
                fullscreen = w.is_fullscreen (),
                minimized = w.minimized,
                on_primary = w.get_monitor () == display.get_primary_monitor (),
                on_all_workspaces = w.is_on_all_workspaces (),
                floating = floating.contains (w.get_id ()),
            };
        }

        private Strip strip_for (Meta.Workspace ws) {
            if (!strips.has_key (ws)) {
                strips[ws] = new Strip ();
            }
            return strips[ws];
        }

        /** Put the window in the strip it belongs to, or take it out of every strip. */
        public void reevaluate (Meta.Window w, Reason reason) {
            var id = w.get_id ();
            if (!windows.has_key (id)) {
                return;
            }
            var current = strip_of (id);
            Strip? target = null;
            var ws = w.get_workspace ();
            if (should_tile (facts_for (w)) && ws != null) {
                target = strip_for (ws);
            }
            if (current == target) {
                return;
            }
            if (current != null) {
                if (reason == Reason.FULLSCREEN) {
                    // The strip's own workspace: Gala may already have moved the window.
                    foreach (var entry in strips.entries) {
                        if (entry.value == current) {
                            slots[id] = new Slot (entry.key, current, id);
                        }
                    }
                }
                current.remove (id);
            }
            if (target != null) {
                if (slots.has_key (id) && slots[id].workspace == ws) {
                    var slot = slots[id];
                    target.insert_at (id, slot.column);
                    var col = target.columns[target.column_of (id)];
                    col.preset = slot.preset;
                    col.free_px = slot.free_px;
                    col.full = slot.full;
                    slots.unset (id);
                } else if (reason == Reason.WORKSPACE) {
                    target.append (id);
                } else {
                    target.insert_after_focused (id);
                }
                if (w.get_maximized () != 0) {
                    on_maximized (id);
                    return;
                }
                scroll_to_focus (target, work_area_of (ws), this);
            }
            relayout ();
        }

        public void toggle_float (Meta.Window w) {
            var id = w.get_id ();
            if (!floating.remove (id)) {
                floating.add (id);
            }
            reevaluate (w, Reason.FLOAT);
        }

        private void on_focus () {
            var w = display.focus_window;
            if (w == null) {
                return;
            }
            var s = strip_of (w.get_id ());
            if (s == null) {
                return;
            }
            s.focus (w.get_id ());
            var ws = w.get_workspace ();
            if (ws != null) {
                scroll_to_focus (s, work_area_of (ws), this);
            }
            relayout ();
        }

        /** A tiled window asking to maximize gets a full-width column instead. */
        private void on_maximized (uint64 id) {
            var w = window_for (id);
            var s = strip_of (id);
            if (w == null || s == null || w.get_maximized () == 0) {
                return;
            }
            w.unmaximize (Meta.MaximizeFlags.BOTH);
            s.columns[s.column_of (id)].full = true;
            s.focus (id);
            var ws = w.get_workspace ();
            if (ws != null) {
                scroll_to_focus (s, work_area_of (ws), this);
            }
            relayout ();
        }

        private void on_size_changed (uint64 id) {
            var w = window_for (id);
            if (w == null) {
                return;
            }
            if (applying) {
                return;
            }
            int width = w.get_frame_rect ().width;
            if (last_width.has_key (id) && last_width[id] == width) {
                return;
            }
            last_width[id] = width;
            if (strip_of (id) != null) {
                relayout (false);
            }
        }

        private void prune_workspaces () {
            var manager = display.get_workspace_manager ();
            var live = new Gee.HashSet<Meta.Workspace> ();
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                live.add (manager.get_workspace_by_index (i));
            }
            foreach (var ws in strips.keys.to_array ()) {
                if (!live.contains (ws)) {
                    strips.unset (ws);
                }
            }
        }

        /** Lay out every strip; only the visible workspace animates. */
        public void relayout (bool animate = true) {
            if (applying) {
                return;
            }
            var active = display.get_workspace_manager ().get_active_workspace ();
            applying = true;
            foreach (var entry in strips.entries) {
                var strip = entry.value;
                if (strip.columns.size == 0) {
                    continue;
                }
                var work = work_area_of (entry.key);
                var plain = layout (strip, work, new NoHints ());
                foreach (var p in plain.windows) {
                    requested[p.id] = p.rect.width;
                }
                var result = layout (strip, work, this);
                applier.apply (result, animate && entry.key == active && animations_enabled ());
            }
            applying = false;
        }

        /** Mark a window as asked to resize, and look again once the grace period is over. */
        public void resize_requested (uint64 id) {
            asked_at[id] = GLib.get_monotonic_time ();
            if (requested.has_key (id)) {
                asked_width[id] = requested[id];
            }
            if (recheck_source != 0) {
                Source.remove (recheck_source);
            }
            recheck_source = Timeout.add ((uint) (RESIZE_GRACE / 1000) + 50, () => {
                recheck_source = 0;
                relayout (false);
                return Source.REMOVE;
            });
        }

        /** One line per column of the active strip, for the demo log. */
        public string describe () {
            var s = current_strip ();
            if (s == null) {
                return "no strip";
            }
            var parts = new string[0];
            foreach (var col in s.columns) {
                var ws = new string[0];
                foreach (var id in col.windows) {
                    var w = window_for (id);
                    if (w == null) {
                        continue;
                    }
                    var f = w.get_frame_rect ();
                    ws += "%s%s@%d,%d %dx%d".printf (
                        (uint64) id == s.focused ? "*" : "", w.get_title () ?? "?", f.x, f.y, f.width, f.height);
                }
                parts += string.joinv (" / ", ws);
            }
            return "scroll=%d | %s".printf (s.scroll_x, string.joinv (" | ", parts));
        }
    }
}
