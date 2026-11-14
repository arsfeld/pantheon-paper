namespace Paper {
    /**
     * The indicator's popover: a stack of the main page and the Shortcuts
     * page. Main page, top to bottom: Tiling, Tile this workspace, Float
     * "<window>", the no-plugin notice, Gap, Margin, Animate, Shortcuts, Add rule for
     * "<app>"…, Tiling Settings….
     *
     * Tiling, Gap, Margin and Animate are GSettings and always work. The two live
     * switches go through the model to the plugin's bus object and are
     * insensitive while it has no owner.
     */
    public class IndicatorPopover : Gtk.Stack {
        public const string NOT_RUNNING = "Tiling plugin not running — log out and back in";

        /** Emitted after a settings page was opened, so the indicator closes. */
        public signal void launched ();

        private IndicatorModel model;
        private Granite.SwitchModelButton workspace_switch;
        private Granite.SwitchModelButton float_switch;
        private Gtk.ModelButton add_rule;

        public IndicatorPopover (IndicatorModel model, Settings? keys) {
            Object (homogeneous: false, vhomogeneous: false,
                transition_type: Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            this.model = model;
            var settings = model.settings;

            var tiling = new Granite.SwitchModelButton ("Tiling");
            tiling.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            model.bind_property ("enabled", tiling, "active",
                BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            workspace_switch = new Granite.SwitchModelButton ("Tile this workspace");
            model.bind_property ("workspace_tiled", workspace_switch, "active",
                BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            float_switch = new Granite.SwitchModelButton ("");
            model.bind_property ("focused_floating", float_switch, "active",
                BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            var not_running = new Gtk.Label (NOT_RUNNING) {
                halign = Gtk.Align.START,
                margin_start = 12,
                margin_end = 12,
                margin_top = 3,
                margin_bottom = 3,
                wrap = true,
                max_width_chars = 32,
                xalign = 0,
                no_show_all = true
            };
            not_running.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            model.bind_property ("connected", not_running, "visible",
                BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);

            var gap_row = scale_row ("Gap", "gap", 48);
            var margin_row = scale_row ("Margin", "margin", 100);

            var animate = new Granite.SwitchModelButton ("Animate");
            settings.bind ("animate", animate, "active", SettingsBindFlags.DEFAULT);

            var focus_ring = new Granite.SwitchModelButton ("Focus ring");
            settings.bind ("focus-ring", focus_ring, "active", SettingsBindFlags.DEFAULT);

            // menu_name switches this stack to the named page.
            var shortcuts_button = new Gtk.ModelButton () {
                text = "Shortcuts",
                menu_name = "shortcuts"
            };

            add_rule = new Gtk.ModelButton ();
            add_rule.clicked.connect (() => launch ("settings://paper/rules?add="
                + Uri.escape_string (model.focused_id, null, false)));

            var open_settings = new Gtk.ModelButton () {
                text = "Tiling Settings…"
            };
            open_settings.clicked.connect (() => launch ("settings://paper"));

            var main = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                width_request = 260
            };
            main.add (tiling);
            main.add (workspace_switch);
            main.add (float_switch);
            main.add (not_running);
            main.add (separator ());
            main.add (gap_row);
            main.add (margin_row);
            main.add (animate);
            main.add (focus_ring);
            main.add (separator ());
            main.add (shortcuts_button);
            main.add (add_rule);
            main.add (open_settings);

            add_named (main, "main");
            add_named (new ShortcutsView (keys), "shortcuts");

            model.notify.connect (sync);
            sync ();
            show_all ();
        }

        /** A labelled slider bound to an int key, 0 to `max`. */

        private Gtk.Box scale_row (string label, string key, int max) {

            var name = new Gtk.Label (label) {

                halign = Gtk.Align.START,

                margin_start = 12

            };

            var scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, max, 1) {

                hexpand = true,

                digits = 0,

                draw_value = true,

                value_pos = Gtk.PositionType.RIGHT,

                margin_end = 12

            };

            model.settings.bind (key, scale.adjustment, "value", SettingsBindFlags.DEFAULT);

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {

                margin_top = 3,

                margin_bottom = 3

            };

            row.add (name);

            row.add (scale);

            return row;

        }


        private static Gtk.Separator separator () {
            return new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
                margin_top = 3,
                margin_bottom = 3
            };
        }

        /* Labels and sensitivity from the model; the bindings carry the values. */
        private void sync () {
            var has_app = model.connected && model.focused_id != "";
            var app = model.focused_name != "" ? model.focused_name : model.focused_id;
            workspace_switch.sensitive = model.connected && model.enabled;
            float_switch.sensitive = model.can_float;
            float_switch.text = has_app ? "Float \"%s\"".printf (app) : "Float window";
            add_rule.sensitive = has_app;
            add_rule.text = has_app ? "Add rule for \"%s\"…".printf (app) : "Add rule…";
        }

        private void launch (string uri) {
            try {
                AppInfo.launch_default_for_uri (uri, null);
            } catch (Error e) {
                warning ("pantheon-paper: could not open %s: %s", uri, e.message);
            }
            launched ();
        }
    }
}
