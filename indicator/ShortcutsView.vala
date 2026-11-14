namespace Paper {
    /**
     * The popover's Shortcuts page: every action with its current
     * accelerators, read from io.github.arsfeld.paper.keybindings and
     * formatted by granite. Read only; the plug edits them.
     */
    public class ShortcutsView : Gtk.Box {
        /** Actions.NAMES in src/Actions.vala; copied, the indicator does not link the plugin. */
        public const string[] NAMES = {
            "focus-left", "focus-right", "focus-up", "focus-down",
            "move-left", "move-right", "move-up", "move-down",
            "cycle-width", "toggle-full", "slurp", "barf", "center", "toggle-float",
        };

        private Settings? keys;
        private Gtk.Grid grid;

        /** `keys` is null when the keybindings schema is not installed. */
        public ShortcutsView (Settings? keys) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.keys = keys;

            // menu_name switches the enclosing Gtk.Stack to the main page.
            add (new Gtk.ModelButton () {
                text = "Tiling",
                inverted = true,
                menu_name = "main"
            });
            add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
                margin_top = 3,
                margin_bottom = 3
            });

            grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 6,
                margin_start = 12,
                margin_end = 12,
                margin_bottom = 6
            };
            add (grid);

            if (keys != null) {
                keys.changed.connect (() => fill ());
            }
            fill ();
        }

        private void fill () {
            grid.foreach ((child) => child.destroy ());
            if (keys == null) {
                var none = new Gtk.Label ("Shortcuts are not installed") {
                    halign = Gtk.Align.START
                };
                none.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                grid.attach (none, 0, 0);
                grid.show_all ();
                return;
            }
            var schema = keys.settings_schema;
            int row = 0;
            foreach (unowned string name in NAMES) {
                if (!schema.has_key (name)) {
                    continue;
                }
                var label = new Gtk.Label (schema.get_key (name).get_summary () ?? name) {
                    halign = Gtk.Align.START,
                    hexpand = true,
                    wrap = true,
                    max_width_chars = 28,
                    xalign = 0
                };
                var accel = new Gtk.Label (accels_text (keys.get_strv (name))) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.START
                };
                accel.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                grid.attach (label, 0, row);
                grid.attach (accel, 1, row);
                row++;
            }
            grid.show_all ();
        }

        private static string accels_text (string[] accels) {
            var parts = new string[0];
            foreach (unowned string a in accels) {
                var text = Granite.accel_to_string (a);
                if (text != null && text != "") {
                    parts += text;
                }
            }
            return parts.length == 0 ? "Disabled" : string.joinv (", ", parts);
        }
    }
}
