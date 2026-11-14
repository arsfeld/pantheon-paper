namespace Paper {
    /** Why a window is being re-checked; decides where it re-enters a strip. */
    public enum Reason {
        CREATED,
        FULLSCREEN,
        MINIMIZED,
        WORKSPACE,
        MONITOR,
        TRANSIENT,
        FLOAT,
        KIND
    }

    /**
     * Binds Mutter to the pure core: tracks windows, keeps one Strip per
     * workspace (primary monitor), and lays them out on every change.
     *
     * A crash here ends the Pantheon session, so every handler looks windows
     * up by id and tolerates them being gone; `unmanaging` drops a window from
     * every map before anything else can touch it.
     */
    public class Controller : Object, WidthHints, SoloCheck {
        public Gala.WindowManager wm { get; construct; }
        /** The saved settings; `params` and the app rules follow it live. */
        public Config config { get; construct; }
        /** Gap and width presets, shared by every strip, kept in sync with `config`. */
        public Params @params = new Params ();

        private unowned Meta.Display display;
        private Gee.HashMap<Meta.Workspace, Strip> strips = new Gee.HashMap<Meta.Workspace, Strip> ();
        private Gee.HashMap<uint64?, Meta.Window> windows = new Gee.HashMap<uint64?, Meta.Window> (id_hash, id_equal);
        private Gee.HashMap<uint64?, Gee.ArrayList<ulong>> handlers = new Gee.HashMap<uint64?, Gee.ArrayList<ulong>> (id_hash, id_equal);
        /** User float toggles, which override app rules both ways. */
        private FloatState floats = new FloatState ();
        /** The last focused normal window, for the D-Bus interface. */
        private FocusTracker focus = new FocusTracker ();
        private Gee.HashSet<uint64?> adopted = new Gee.HashSet<uint64?> (id_hash, id_equal);
        /**
         * Workspaces whose tiling is switched off for this session. Pantheon's
         * workspaces are dynamic, so there is nothing stable to save it against;
         * a workspace Gala removes is pruned, as its strip is.
         */
        private Gee.HashSet<Meta.Workspace> off = new Gee.HashSet<Meta.Workspace> ();
        /**
         * Where a window sat when it went fullscreen. Gala moves a fullscreen
         * window to a workspace of its own and back again, so the slot keeps its
         * workspace and is used only when the window re-enters that one.
         */
        private class Slot {
            public Meta.Workspace workspace;
            public int column;
            public int preset;
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
        /** The exact size last asked for (hints included), to tell an answer from a pending request. */
        private Gee.HashMap<uint64?, Rect?> asked_size = new Gee.HashMap<uint64?, Rect?> (id_hash, id_equal);
        private const int64 RESIZE_GRACE = 1000000;
        private uint recheck_source = 0;
        private Gee.ArrayList<ulong> display_handlers = new Gee.ArrayList<ulong> ();
        private ulong[] manager_handlers = {};
        private ulong config_handler = 0;
        private Applier applier;
        private Settings interface_settings;
        public bool applying { get; private set; default = false; }
        /**
         * Something the D-Bus interface reports may have changed: either switch,
         * the active workspace (`workspace_tiled` may differ there), the last
         * focused normal window, or whether a window floats.
         */
        public signal void state_changed ();
        /** A window the user is moving or resizing: layouts leave it where the pointer has it. */
        public uint64 grabbed { get; set; default = 0; }

        public Controller (Gala.WindowManager wm, Config config) {
            Object (wm: wm, config: config);
        }

        construct {
            display = wm.get_display ();
            applier = new Applier (this);
            interface_settings = new Settings ("org.gnome.desktop.interface");
            refresh_params ();
            config_handler = config.changed.connect (on_config_changed);

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
            manager_handlers += manager.active_workspace_changed.connect (() => {
                relayout (false);
                state_changed ();
            });

            adopt_existing ();
        }

        public void destroy () {
            if (config_handler != 0) {
                config.disconnect (config_handler);
                config_handler = 0;
            }
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

        /** The active workspace's strip; null while tiling is off there. */
        public Strip? current_strip () {
            var ws = display.get_workspace_manager ().get_active_workspace ();
            return tiles (ws) ? strip_for (ws) : null;
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
            return config.animate && interface_settings.get_boolean ("enable-animations");
        }

        // ---- settings ----

        private void refresh_params () {
            @params.gap = config.gap;
            @params.presets = presets_or_default (config.presets);
            @params.default_preset = nearest_preset (@params.presets, config.default_width);
        }

        private void on_config_changed (string key) {
            refresh_params ();
            if (key == "enabled") {
                set_enabled (config.enabled);
                return;
            }
            if (key == "app-rules") {
                // A rule can float or unfloat windows already open.
                foreach (var w in windows.values.to_array ()) {
                    if (adopted.contains (w.get_id ())) {
                        reevaluate (w, Reason.FLOAT);
                    }
                }
                relayout ();
                state_changed ();
                return;
            }
            relayout ();
        }

        /** The first app rule matching the window's GTK application id, sandboxed app id or WM_CLASS. */
        public AppRule? rule_for (Meta.Window w) {
            if (config.rules.size == 0) {
                return null;
            }
            return match_rule (config.rules, w.get_gtk_application_id (), w.get_sandboxed_app_id (), w.get_wm_class ());
        }

        /** A window whose rule gives it a column of its own (SoloCheck, for slurp and drops). */
        public bool is_solo (uint64 id) {
            var w = window_for (id);
            if (w == null) {
                return false;
            }
            var rule = rule_for (w);
            return rule != null && rule.own_column;
        }

        /** Whether a rule floats the window, before the user's toggle. */
        private bool rule_floats (Meta.Window w) {
            var rule = rule_for (w);
            return rule != null && rule.float_;
        }

        /** The effective state: the user's toggle, or else the window's rule. */
        public bool is_floating (uint64 id) {
            var w = window_for (id);
            return w != null && floats.floats (id, rule_floats (w));
        }

        // ---- the focused window and app ids, for the D-Bus interface ----

        /** A normal toplevel: not a dialog, popup, utility, dock, override-redirect or taskbar-less window. */
        private static bool is_normal (Meta.Window w) {
            return w.get_window_type () == Meta.WindowType.NORMAL
                && !w.is_override_redirect () && !w.is_skip_taskbar ();
        }

        /**
         * The last focused normal window, still tracked and still normal; null
         * if there is none. Re-checked here as well as on change: Wingpanel's
         * window first takes focus as NORMAL and becomes a DOCK later.
         */
        public Meta.Window? focused_window () {
            var w = focus.last == 0 ? null : window_for (focus.last);
            return w != null && is_normal (w) ? w : null;
        }

        /**
         * A window's type or taskbar state changed after it was shown. Steam's
         * main window (steamwebhelper) is first shown as something not normal
         * and turns NORMAL later, so it was never tiled until something else
         * re-checked it; Wingpanel goes the other way, NORMAL to DOCK. Either
         * way the strip is re-checked, and a window that stopped being normal
         * can no longer be the focused one.
         */
        private void on_kind_changed (uint64 id) {
            var w = window_for (id);
            if (w == null) {
                return;
            }
            if (adopted.contains (id)) {
                reevaluate (w, Reason.KIND);
            }
            if (is_normal (w) || focus.last != id) {
                return;
            }
            focus.forget (id);
            state_changed ();
        }

        /**
         * The window's app: id is its GTK application id, else its sandboxed
         * app id, else its WM_CLASS ("" when it has none); name is the matching
         * .desktop file's name, else the id.
         */
        public void app_of (Meta.Window w, out string id, out string name) {
            id = w.get_gtk_application_id () ?? w.get_sandboxed_app_id () ?? w.get_wm_class () ?? "";
            name = id;
            if (id == "") {
                return;
            }
            // WM_CLASS is often capitalised where the .desktop file is not.
            foreach (var candidate in new string[] { id, id.down () }) {
                var info = new GLib.DesktopAppInfo (candidate + ".desktop");
                if (info != null) {
                    name = info.get_name ();
                    return;
                }
            }
        }

        /** Every tracked normal window, in creation order. */
        public Gee.List<Meta.Window> normal_windows () {
            var keys = new Gee.ArrayList<uint64?> (id_equal);
            keys.add_all (windows.keys);
            keys.sort ((a, b) => (uint64) a < (uint64) b ? -1 : ((uint64) a > (uint64) b ? 1 : 0));
            var list = new Gee.ArrayList<Meta.Window> ();
            foreach (var id in keys) {
                if (is_normal (windows[id])) {
                    list.add (windows[id]);
                }
            }
            return list;
        }

        // ---- switching tiling off and on ----

        /** Whether new and re-entering windows of `ws` go into its strip. */
        private bool tiles (Meta.Workspace? ws) {
            return ws != null && config.enabled && !off.contains (ws);
        }

        /**
         * The per-workspace switch: false when `ws` was switched off for this
         * session. It is the switch's own value, independent of `enabled`.
         */
        public bool workspace_tiled (Meta.Workspace ws) {
            return !off.contains (ws);
        }

        public void set_workspace_tiled (Meta.Workspace ws, bool on) {
            if (on == workspace_tiled (ws)) {
                return;
            }
            if (on) {
                off.remove (ws);
                if (config.enabled) {
                    adopt (ws);
                }
            } else {
                off.add (ws);
                release (ws);
            }
            state_changed ();
        }

        /** The global switch (`enabled`): drop every strip, or adopt every workspace. */
        private void set_enabled (bool on) {
            if (on) {
                var manager = display.get_workspace_manager ();
                for (int i = 0; i < manager.get_n_workspaces (); i++) {
                    var ws = manager.get_workspace_by_index (i);
                    if (!off.contains (ws)) {
                        adopt (ws, false);
                    }
                }
                relayout ();
            } else {
                // A copy: release unsets entries (to_array () warns in C).
                var all = new Gee.ArrayList<Meta.Workspace> ();
                all.add_all (strips.keys);
                foreach (var ws in all) {
                    release (ws);
                }
            }
            state_changed ();
        }

        /**
         * Drop the workspace's strip and leave its windows where they are. Only
         * parked windows move, just far enough inside the work area on their
         * side to be fully on screen, or they would be stranded off the edge.
         * The windows stay tracked, so `adopt` can take them back.
         */
        private void release (Meta.Workspace ws) {
            if (!strips.has_key (ws)) {
                return;
            }
            var strip = strips[ws];
            var work = work_area_of (ws);
            bool wall_left, wall_right;
            walls (out wall_left, out wall_right);
            var result = layout (strip, work, this, wall_left, wall_right);
            strips.unset (ws);
            foreach (var p in result.windows) {
                var w = window_for (p.id);
                if (w == null) {
                    continue;
                }
                // Stop any animation, so the window shows where its frame is.
                applier.forget (p.id);
                var actor = w.get_compositor_private () as Clutter.Actor;
                if (actor != null) {
                    actor.set_translation (0, 0, 0);
                }
                if (!p.parked || p.id == grabbed) {
                    continue;
                }
                var f = w.get_frame_rect ();
                int x = f.x;
                if (x + f.width > work.x + work.width) {
                    x = work.x + work.width - f.width;
                }
                if (x < work.x) {
                    x = work.x;
                }
                if (x != f.x) {
                    // A user op, as the Applier moves windows.
                    w.move_resize_frame (true, x, f.y, f.width, f.height);
                }
            }
        }

        /**
         * Tile the workspace's windows again, as columns ordered left to right
         * by where their frames are now. With `lay_out` false the caller lays
         * out, once for several workspaces.
         */
        private void adopt (Meta.Workspace ws, bool lay_out = true) {
            if (!tiles (ws)) {
                return;
            }
            // In id (creation) order, so windows at the same x, such as two
            // released from one edge, keep a stable order rather than the
            // hash map's.
            var keys = new Gee.ArrayList<uint64?> (id_equal);
            keys.add_all (windows.keys);
            keys.sort ((a, b) => (uint64) a < (uint64) b ? -1 : ((uint64) a > (uint64) b ? 1 : 0));
            uint64[] ids = {};
            int[] xs = {};
            foreach (var id in keys) {
                var w = windows[id];
                if (w.get_workspace () != ws || !adopted.contains (id) || strip_of (id) != null) {
                    continue;
                }
                if (!should_tile (facts_for (w))) {
                    continue;
                }
                ids += id;
                xs += w.get_frame_rect ().x;
            }
            if (ids.length == 0) {
                return;
            }
            var strip = strip_for (ws);
            foreach (var id in order_by_x (ids, xs)) {
                strip.append (id);
            }
            var focus = display.focus_window;
            if (focus != null && strip.contains (focus.get_id ())) {
                strip.focus (focus.get_id ());
            }
            scroll_to_focus (strip, work_area_of (ws), this);
            if (lay_out) {
                relayout ();
            }
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
                if (tiles (w.get_workspace ()) && should_tile (facts_for (w))) {
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
            ids.add (w.notify["window-type"].connect (() => on_kind_changed (id)));
            ids.add (w.notify["skip-taskbar"].connect (() => on_kind_changed (id)));
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
            floats.forget (id);
            var had_focus = focus.last == id;
            focus.forget (id);
            adopted.remove (id);
            slots.unset (id);
            requested.unset (id);
            last_width.unset (id);
            asked_at.unset (id);
            asked_width.unset (id);
            asked_size.unset (id);
            relayout ();
            if (had_focus) {
                state_changed ();
            }
        }

        private WindowFacts facts_for (Meta.Window w) {
            var id = w.get_id ();
            return WindowFacts () {
                normal_type = is_normal (w),
                has_transient_parent = w.get_transient_for () != null,
                fullscreen = w.is_fullscreen (),
                minimized = w.minimized,
                on_primary = w.get_monitor () == display.get_primary_monitor (),
                on_all_workspaces = w.is_on_all_workspaces (),
                floating = floats.user_floated (id),
                rule_float = floats.rule_floats (id, rule_floats (w)),
            };
        }

        private Strip strip_for (Meta.Workspace ws) {
            if (!strips.has_key (ws)) {
                strips[ws] = new Strip (@params, this);
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
            if (tiles (ws) && should_tile (facts_for (w))) {
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
                asked_size.unset (id);
                if (slots.has_key (id) && slots[id].workspace == ws) {
                    var slot = slots[id];
                    target.insert_at (id, slot.column, slot.preset);
                    var col = target.columns[target.column_of (id)];
                    col.free_px = slot.free_px;
                    col.full = slot.full;
                    slots.unset (id);
                } else if (reason == Reason.WORKSPACE) {
                    target.append (id);
                } else {
                    // A rule's initial width applies only to a new window (or one
                    // that only now became normal); later re-entries keep the width
                    // their saved slot or the default gives.
                    var rule = reason == Reason.CREATED || reason == Reason.KIND ? rule_for (w) : null;
                    double width = rule != null ? rule.width : 0.0;
                    int preset = width > 0.0 && width < 1.0 ? nearest_preset (@params.presets, width) : -1;
                    target.insert_after_focused (id, preset);
                    if (width >= 1.0) {
                        target.columns[target.column_of (id)].full = true;
                    }
                }
                if (w.get_maximized () != 0) {
                    on_maximized (id);
                    return;
                }
                scroll_to_focus (target, work_area_of (ws), this);
            }
            relayout ();
        }

        /** Flip whether the window floats, its rule's verdict included. */
        public void toggle_float (Meta.Window w) {
            var id = w.get_id ();
            if (!windows.has_key (id)) {
                return;
            }
            floats.toggle (id, rule_floats (w));
            reevaluate (w, Reason.FLOAT);
            state_changed ();
        }

        private void on_focus () {
            var w = display.focus_window;
            if (w == null) {
                return;
            }
            var before = focus.last;
            focus.focused (w.get_id (), is_normal (w));
            if (focus.last != before) {
                state_changed ();
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
            // A size the window took by itself (its answer, or a fullscreen or
            // maximize round trip) voids a settled answer: ask again once. An
            // answer that repeats does not change the frame, so it settles.
            asked_size.unset (id);
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
            off.retain_all (live);
        }

        /** The visible workspace's strip laid out as it is on screen (hints and monitor walls included). */
        public LayoutResult layout_of (Strip s) {
            bool wall_left, wall_right;
            walls (out wall_left, out wall_right);
            return layout (s, work_area (), this, wall_left, wall_right);
        }

        /** Whether another monitor adjoins the primary on its left or right edge. */
        public void walls (out bool left, out bool right) {
            left = false;
            right = false;
            int primary = display.get_primary_monitor ();
            var p = display.get_monitor_geometry (primary);
            for (int i = 0; i < display.get_n_monitors (); i++) {
                if (i == primary) {
                    continue;
                }
                var m = display.get_monitor_geometry (i);
                bool overlaps = m.y < p.y + p.height && p.y < m.y + m.height;
                left = left || (overlaps && m.x + m.width == p.x);
                right = right || (overlaps && m.x == p.x + p.width);
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
                bool wall_left, wall_right;
                walls (out wall_left, out wall_right);
                var plain = layout (strip, work, new NoHints (), wall_left, wall_right);
                foreach (var p in plain.windows) {
                    requested[p.id] = p.rect.width;
                }
                var result = layout (strip, work, this, wall_left, wall_right);
                applier.apply (result, animate && entry.key == active && animations_enabled ());
            }
            applying = false;
        }

        /**
         * Whether the window was already asked for exactly this size, long enough
         * ago that its frame is its answer. A client that keeps a different size
         * (not resizable, size increments, a minimum height) is then left at it:
         * asking again would only repeat every recheck, forever.
         */
        public bool size_settled (uint64 id, int width, int height) {
            if (!asked_size.has_key (id) || !asked_at.has_key (id)) {
                return false;
            }
            var a = asked_size[id];
            return a.width == width && a.height == height
                && GLib.get_monotonic_time () - asked_at[id] >= RESIZE_GRACE;
        }

        /** Mark a window as asked to resize, and look again once the grace period is over. */
        public void resize_requested (uint64 id, int width, int height) {
            debug ("resize request %s", ((uint64) id).to_string ());
            asked_size[id] = Rect (0, 0, width, height);
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

        /**
         * One line per column of the active strip, for the demo log, then
         * `|| free:` and every other normal window of the active workspace
         * (floating, or all of them while tiling is off there).
         */
        public string describe () {
            var s = current_strip ();
            var text = "no strip";
            if (s != null) {
                var parts = new string[0];
                foreach (var col in s.columns) {
                    var ws = new string[0];
                    foreach (var id in col.windows) {
                        var w = window_for (id);
                        if (w != null) {
                            ws += frame_text (w, (uint64) id == s.focused);
                        }
                    }
                    parts += string.joinv (" / ", ws);
                }
                text = "scroll=%d | %s".printf (s.scroll_x, string.joinv (" | ", parts));
            }
            var active = display.get_workspace_manager ().get_active_workspace ();
            var free = new string[0];
            foreach (var w in windows.values) {
                if (w.get_workspace () == active && w.get_window_type () == Meta.WindowType.NORMAL
                    && strip_of (w.get_id ()) == null) {
                    free += frame_text (w, false);
                }
            }
            if (free.length > 0) {
                text += " || free: " + string.joinv (" | ", free);
            }
            return text;
        }

        private static string frame_text (Meta.Window w, bool focused) {
            var f = w.get_frame_rect ();
            return "%s%s@%d,%d %dx%d".printf (focused ? "*" : "", w.get_title () ?? "?", f.x, f.y, f.width, f.height);
        }
    }
}
