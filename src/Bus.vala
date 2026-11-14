namespace Paper {
    /** An app id and its display name, `(ss)` on the bus. */
    public struct AppEntry {
        public string id;
        public string name;
    }

    /**
     * `io.github.arsfeld.Paper` on the session bus, object
     * `/io/github/arsfeld/Paper`: live session state for the Wingpanel
     * indicator and the Switchboard plug. Saved settings are GSettings, not
     * here.
     *
     * Getters return cached values, refreshed on the controller's
     * `state_changed`, so a D-Bus read never touches a Mutter window, and each
     * change is announced once with PropertiesChanged, emitted here: Vala's
     * generated server code does not turn `notify` into it. Failing to get the
     * bus or the name is logged and nothing else: Gala keeps running without
     * the interface.
     */
    [DBus (name = "io.github.arsfeld.Paper")]
    public class Bus : Object {
        public const string NAME = "io.github.arsfeld.Paper";
        public const string PATH = "/io/github/arsfeld/Paper";

        private Controller c;
        private ulong state_handler = 0;
        private uint owner_id = 0;
        private uint object_id = 0;
        private DBusConnection? connection = null;

        private bool tiled = true;
        private bool floating = false;
        private AppEntry app = AppEntry () { id = "", name = "" };

        /** Tiling on the active workspace: its own switch, independent of `enabled`. */
        [CCode (notify = false)]
        public bool workspace_tiled {
            get { return tiled; }
            set {
                var ws = active_workspace ();
                if (ws != null) {
                    c.set_workspace_tiled (ws, value);
                }
            }
        }

        /** Whether the focused window floats; writing a different value toggles it. */
        [CCode (notify = false)]
        public bool focused_floating {
            get { return floating; }
            set {
                var w = c.focused_window ();
                if (w != null && value != c.is_floating (w.get_id ())) {
                    c.toggle_float (w);
                }
            }
        }

        /** App id and display name of the last focused normal window, ("", "") if none. */
        public AppEntry focused_app {
            owned get { return app; }
        }

        /** App id and name of every tracked normal window, de-duplicated by id. */
        public AppEntry[] running_apps () throws GLib.DBusError, GLib.IOError {
            var seen = new Gee.HashSet<string> ();
            AppEntry[] apps = {};
            foreach (var w in c.normal_windows ()) {
                string id, name;
                c.app_of (w, out id, out name);
                if (id != "" && seen.add (id)) {
                    apps += AppEntry () { id = id, name = name };
                }
            }
            return apps;
        }

        private Bus (Controller c) {
            this.c = c;
        }

        /** Export the interface for `c` and own the name; undo with `unown`. */
        [DBus (visible = false)]
        public static Bus own (Controller c) {
            var bus = new Bus (c);
            bus.start ();
            return bus;
        }

        private void start () {
            refresh ();
            state_handler = c.state_changed.connect (refresh);
            owner_id = GLib.Bus.own_name (BusType.SESSION, NAME, BusNameOwnerFlags.NONE,
                on_bus_acquired, null,
                () => warning ("pantheon-paper: could not own %s on the session bus", NAME));
        }

        private void on_bus_acquired (DBusConnection conn) {
            try {
                object_id = conn.register_object (PATH, this);
                connection = conn;
            } catch (IOError e) {
                warning ("pantheon-paper: could not export %s: %s", PATH, e.message);
            }
        }

        /** Release the name and the object, and stop following the controller. */
        [DBus (visible = false)]
        public void unown () {
            if (state_handler != 0) {
                c.disconnect (state_handler);
                state_handler = 0;
            }
            if (connection != null && object_id != 0) {
                connection.unregister_object (object_id);
            }
            object_id = 0;
            connection = null;
            if (owner_id != 0) {
                GLib.Bus.unown_name (owner_id);
                owner_id = 0;
            }
        }

        private Meta.Workspace? active_workspace () {
            return c.wm.get_display ().get_workspace_manager ().get_active_workspace ();
        }

        /** Recompute every property and announce the ones that changed. */
        private void refresh () {
            var changed = new VariantBuilder (new VariantType ("a{sv}"));
            bool any = false;

            var ws = active_workspace ();
            var now_tiled = ws == null || c.workspace_tiled (ws);
            if (now_tiled != tiled) {
                tiled = now_tiled;
                changed.add ("{sv}", "WorkspaceTiled", new Variant.boolean (tiled));
                any = true;
            }

            var w = c.focused_window ();
            var now_floating = w != null && c.is_floating (w.get_id ());
            if (now_floating != floating) {
                floating = now_floating;
                changed.add ("{sv}", "FocusedFloating", new Variant.boolean (floating));
                any = true;
            }

            string id = "", name = "";
            if (w != null) {
                c.app_of (w, out id, out name);
            }
            if (id != app.id || name != app.name) {
                app = AppEntry () { id = id, name = name };
                changed.add ("{sv}", "FocusedApp", new Variant ("(ss)", id, name));
                any = true;
            }

            if (!any || connection == null || object_id == 0) {
                return;
            }
            try {
                connection.emit_signal (null, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                    new Variant ("(sa{sv}as)", NAME, changed, null));
            } catch (Error e) {
                warning ("pantheon-paper: PropertiesChanged: %s", e.message);
            }
        }
    }
}
