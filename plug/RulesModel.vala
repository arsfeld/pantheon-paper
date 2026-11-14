namespace Paper {
    /**
     * The App Rules page's list, kept in step with `app-rules`. Every change
     * writes the whole list through rules_to_variant, which leaves out rules
     * at their defaults: such a rule stays listed for the rest of the session
     * (it was just added, or just set back) but is not stored.
     */
    public class RulesModel : Object {
        public Settings settings { get; construct; }
        public Gee.List<AppRule> rules { get; private set; }

        /** The list changed, from here or from outside. */
        public signal void changed ();

        private bool writing = false;

        public RulesModel (Settings settings) {
            Object (settings: settings);
        }

        construct {
            rules = rules_from_variant (settings.get_value ("app-rules"));
            settings.changed["app-rules"].connect (() => {
                if (!writing) {
                    reload ();
                }
            });
        }

        /** Index of the rule for `app_id` (ignoring case), or -1. */
        public int index_of (string app_id) {
            for (int i = 0; i < rules.size; i++) {
                if (rules[i].app_id.casefold () == app_id.casefold ()) {
                    return i;
                }
            }
            return -1;
        }

        /** Add a rule at its defaults, or find the existing one; its index. */
        public int add (string app_id) {
            int i = index_of (app_id);
            if (i >= 0) {
                return i;
            }
            rules.add (new AppRule () { app_id = app_id });
            write ();
            return rules.size - 1;
        }

        public void remove (int i) {
            rules.remove_at (i);
            write ();
        }

        public void update (int i, AppRule r) {
            rules[i] = new AppRule () {
                app_id = r.app_id,
                float_ = r.float_,
                width = r.width,
                own_column = r.own_column
            };
            write ();
        }

        private void write () {
            writing = true;
            settings.set_value ("app-rules", rules_to_variant (rules));
            writing = false;
            changed ();
        }

        // The stored rules, followed by the default ones only listed here.
        private void reload () {
            var stored = rules_from_variant (settings.get_value ("app-rules"));
            var kept = new Gee.ArrayList<AppRule> ();
            foreach (var r in rules) {
                if (r.is_default ()) {
                    kept.add (r);
                }
            }
            rules = stored;
            foreach (var r in kept) {
                if (index_of (r.app_id) < 0) {
                    rules.add (r);
                }
            }
            changed ();
        }
    }

    /*
     * A rule's width as the page's dropdown lists it: 0 Default, 1..n the
     * presets, n + 1 Full width. A stored fraction shows as the preset it
     * snaps to, as the plugin applies it.
     */
    public int rule_width_index (double[] presets, double width) {
        if (width <= 0.0) {
            return 0;
        }
        if (width >= 1.0) {
            return presets.length + 1;
        }
        return nearest_preset (presets, width) + 1;
    }

    public double rule_width_value (double[] presets, int index) {
        if (index <= 0) {
            return 0.0;
        }
        if (index > presets.length) {
            return 1.0;
        }
        return presets[index - 1];
    }

    /** `RunningApps`' reply, `(a(ss))`, as entries; empty for anything else. */
    public AppEntry[] apps_from_reply (Variant reply) {
        AppEntry[] apps = {};
        if (!reply.is_of_type (new VariantType ("(a(ss))"))) {
            return apps;
        }
        foreach (var child in reply.get_child_value (0)) {
            string id;
            string name;
            child.get ("(ss)", out id, out name);
            if (id != "") {
                apps += AppEntry () { id = id, name = name };
            }
        }
        return apps;
    }
}
