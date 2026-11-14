namespace Paper {
    /**
     * The saved settings, io.github.arsfeld.paper, as typed values that follow
     * the schema live. `changed` fires after a key's value here is updated.
     *
     * new Settings() on a schema that is not installed aborts the process, and
     * here the process is the session: the schema is looked up first, and
     * without it `available` is false, the values are the built-in defaults and
     * the setters do nothing.
     */
    public class Config : Object {
        public const string SCHEMA = "io.github.arsfeld.paper";

        public bool available { get; private set; default = false; }
        /** Get-only: a private setter would clash with set_enabled () in C. */
        public bool enabled { get { return _enabled; } }
        private bool _enabled = true;
        public int gap { get; private set; default = 8; }
        public int margin { get; private set; default = 20; }
        /** Always valid (presets_or_default): 2-6 increasing fractions. */
        public double[] presets = DEFAULT_PRESETS;
        public double default_width { get; private set; default = 0.5; }
        public bool animate { get; private set; default = true; }
        public bool focus_ring { get; private set; default = true; }
        public bool edge_preview { get; private set; default = true; }
        public Gee.List<AppRule> rules = new Gee.ArrayList<AppRule> ();
        public Settings? settings { get; private set; default = null; }

        public signal void changed (string key);

        /** The last invalid width-presets value warned about, so each is logged once. */
        private string? warned_presets = null;

        construct {
            var source = SettingsSchemaSource.get_default ();
            if (source == null || source.lookup (SCHEMA, true) == null) {
                warning ("pantheon-paper: schema %s is not installed; using the default settings", SCHEMA);
                return;
            }
            settings = new Settings (SCHEMA);
            available = true;
            foreach (var key in new string[] { "enabled", "gap", "margin", "width-presets", "default-width", "animate", "focus-ring", "edge-preview", "app-rules" }) {
                load (key);
            }
            settings.changed.connect ((key) => {
                load (key);
                changed (key);
            });
        }

        public void set_enabled (bool v) {
            if (settings != null) {
                settings.set_boolean ("enabled", v);
            }
        }

        private void load (string key) {
            switch (key) {
                case "enabled": _enabled = settings.get_boolean (key); break;
                case "gap": gap = settings.get_int (key); break;
                case "margin": margin = settings.get_int (key); break;
                case "default-width": default_width = settings.get_double (key); break;
                case "animate": animate = settings.get_boolean (key); break;
                case "focus-ring": focus_ring = settings.get_boolean (key); break;
                case "edge-preview": edge_preview = settings.get_boolean (key); break;
                case "app-rules": rules = rules_from_variant (settings.get_value (key)); break;
                case "width-presets": load_presets (); break;
            }
        }

        private void load_presets () {
            var v = settings.get_value ("width-presets");
            double[] read = {};
            foreach (var child in v) {
                read += child.get_double ();
            }
            if (!presets_valid (read)) {
                var text = v.print (false);
                if (text != warned_presets) {
                    warning ("pantheon-paper: width-presets %s is invalid (need 2-6 increasing values in [0.1, 1.0]); using the defaults", text);
                    warned_presets = text;
                }
            } else {
                warned_presets = null;
            }
            presets = presets_or_default (read);
        }
    }
}
