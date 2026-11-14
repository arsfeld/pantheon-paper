namespace Paper {
    /**
     * What the indicator shows, from GSettings (`enabled`) and, while the
     * plugin owns io.github.arsfeld.Paper, its proxy (`set_proxy`). No GTK, so
     * it is tested with a fake proxy and GSettings' memory backend.
     *
     * Writing `enabled` writes the setting; writing `workspace_tiled` or
     * `focused_floating` writes the proxy, and only while connected. Values
     * read from the proxy are stored without writing them back.
     */
    public class IndicatorModel : Object {
        public const string ICON_TILING = "paper-tiling-symbolic";
        public const string ICON_WORKSPACE_OFF = "paper-tiling-workspace-off-symbolic";
        public const string ICON_OFF = "paper-tiling-off-symbolic";

        public Settings settings { get; construct; }

        /** Whether the plugin's bus name has an owner and the proxy is set. */
        public bool connected { get; private set; default = false; }
        /** The `enabled` setting, bound both ways. */
        public bool enabled { get; set; default = true; }
        public string focused_id { get; private set; default = ""; }
        public string focused_name { get; private set; default = ""; }
        public string icon_name { get; private set; default = ICON_TILING; }

        private PaperProxy? proxy = null;
        private ulong[] handlers = {};
        // Set while copying the proxy's values in, so the setters do not write them back.
        private bool reading = false;

        private bool _workspace_tiled = true;
        public bool workspace_tiled {
            get { return _workspace_tiled; }
            set {
                _workspace_tiled = value;
                if (!reading && proxy != null && proxy.workspace_tiled != value) {
                    proxy.workspace_tiled = value;
                }
                update_icon ();
            }
        }

        private bool _focused_floating = false;
        public bool focused_floating {
            get { return _focused_floating; }
            set {
                _focused_floating = value;
                if (!reading && proxy != null && proxy.focused_floating != value) {
                    proxy.focused_floating = value;
                }
            }
        }

        public IndicatorModel (Settings settings) {
            Object (settings: settings);
        }

        construct {
            settings.bind ("enabled", this, "enabled", SettingsBindFlags.DEFAULT);
            notify["enabled"].connect (update_icon);
            update_icon ();
        }

        /** Follow `p`, or with null forget the plugin (its name lost its owner). */
        public void set_proxy (PaperProxy? p) {
            if (proxy != null) {
                foreach (var id in handlers) {
                    SignalHandler.disconnect (proxy, id);
                }
            }
            handlers = {};
            proxy = p;
            if (p != null) {
                // The real proxy announces changes with PropertiesChanged; the
                // fake in the tests (and any plain object) with notify.
                if (p is DBusProxy) {
                    handlers += ((DBusProxy) p).g_properties_changed.connect (() => refresh ());
                }
                handlers += p.notify.connect (() => refresh ());
            }
            refresh ();
        }

        /** Copy the proxy's values in, or the disconnected defaults without one. */
        public void refresh () {
            reading = true;
            connected = proxy != null;
            if (proxy != null) {
                var app = proxy.focused_app;
                workspace_tiled = proxy.workspace_tiled;
                focused_floating = proxy.focused_floating;
                focused_id = app.id ?? "";
                focused_name = app.name ?? "";
            } else {
                workspace_tiled = true;
                focused_floating = false;
                focused_id = "";
                focused_name = "";
            }
            reading = false;
            update_icon ();
        }

        private void update_icon () {
            string name;
            if (!enabled) {
                name = ICON_OFF;
            } else if (connected && !workspace_tiled) {
                name = ICON_WORKSPACE_OFF;
            } else {
                name = ICON_TILING;
            }
            if (name != icon_name) {
                icon_name = name;
            }
        }
    }
}
