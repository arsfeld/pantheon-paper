namespace Paper {
    public const string PAPER_SCHEMA = "io.github.arsfeld.paper";
    public const string KEYS_SCHEMA = "io.github.arsfeld.paper.keybindings";

    /**
     * supported_settings that also claims `paper/rules?add=<id>`, which the
     * indicator's "Add rule" opens. Switchboard looks a settings:// path up
     * with has_key and get, and falls back to the parent path on a miss, so
     * a plain map would open `paper` and drop the query. Claimed here, the
     * whole `rules?add=<id>` reaches search_callback.
     */
    class Locations : Gee.TreeMap<string, string?> {
        const string ADD = "paper/rules?add=";

        public Locations () {
            base (null, null);
        }

        public override bool has_key (string key) {
            return key.has_prefix (ADD) || base.has_key (key);
        }

        public override string? @get (string key) {
            if (key.has_prefix (ADD)) {
                return key.substring ("paper/".length);
            }
            return base.@get (key);
        }
    }

    /** System Settings → Tiling: Layout, App Rules and Shortcuts. */
    public class Plug : Switchboard.Plug {
        private Gtk.Widget? main = null;
        private Gtk.Stack? stack = null;
        private RulesPage? rules_page = null;

        public Plug () {
            var locations = new Locations ();
            locations["paper"] = "layout";
            locations["paper/rules"] = "rules";
            locations["paper/shortcuts"] = "shortcuts";
            Object (
                category: Category.PERSONAL,
                code_name: "io.github.arsfeld.paper",
                display_name: "Tiling",
                description: "Scrolling tiling: layout, app rules and shortcuts",
                icon: "preferences-desktop-workspaces",
                supported_settings: locations
            );
        }

        public override Gtk.Widget get_widget () {
            if (main == null) {
                main = build ();
            }
            return main;
        }

        // Every schema is looked up before `new Settings`, which aborts on a
        // missing one: here that would take System Settings down with it.
        private Gtk.Widget build () {
            var src = SettingsSchemaSource.get_default ();
            if (src == null || src.lookup (PAPER_SCHEMA, true) == null) {
                var header = new Adw.HeaderBar () {
                    show_title = false
                };
                header.add_css_class ("flat");
                var missing = new Granite.Placeholder ("Tiling is not installed") {
                    description = "The settings schema %s is missing.".printf (PAPER_SCHEMA),
                    icon = new ThemedIcon ("dialog-warning"),
                    vexpand = true
                };
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                box.append (header);
                box.append (missing);
                return box;
            }
            var settings = new Settings (PAPER_SCHEMA);
            Settings? keys = src.lookup (KEYS_SCHEMA, true) != null ? new Settings (KEYS_SCHEMA) : null;

            rules_page = new RulesPage (settings);
            stack = new Gtk.Stack ();
            stack.add_named (new LayoutPage (settings), "layout");
            stack.add_named (rules_page, "rules");
            stack.add_named (new ShortcutsPage (keys), "shortcuts");

            var sidebar = new Switchboard.SettingsSidebar (stack) {
                show_title_buttons = true
            };
            return new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                start_child = sidebar,
                end_child = stack,
                resize_start_child = false,
                shrink_start_child = false,
                shrink_end_child = false,
                position = 200
            };
        }

        public override void shown () {
        }

        public override void hidden () {
        }

        /** `layout`, `rules`, `rules?add=<uri-escaped id>` or `shortcuts`. */
        public override void search_callback (string location) {
            get_widget ();
            if (stack == null) {
                return;
            }
            var parts = location.split ("?", 2);
            switch (parts[0]) {
            case "rules":
            case "shortcuts":
                stack.visible_child_name = parts[0];
                break;
            default:
                stack.visible_child_name = "layout";
                break;
            }
            if (parts[0] == "rules" && parts.length == 2 && parts[1].has_prefix ("add=")) {
                var id = Uri.unescape_string (parts[1].substring ("add=".length));
                if (id != null && id.strip () != "") {
                    rules_page.reveal (id.strip ());
                }
            }
        }

        public override async Gee.TreeMap<string, string> search (string search) {
            var results = new Gee.TreeMap<string, string> (null, null);
            results["%s → %s".printf (display_name, "Layout")] = "layout";
            results["%s → %s".printf (display_name, "App Rules")] = "rules";
            results["%s → %s".printf (display_name, "Shortcuts")] = "shortcuts";
            return results;
        }
    }
}

public Switchboard.Plug get_plug (Module module) {
    return new Paper.Plug ();
}
