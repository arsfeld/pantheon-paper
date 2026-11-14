namespace Paper {
    /** Tiling on or off, the gap, the column widths and animation. */
    public class LayoutPage : Switchboard.SettingsPage {
        public Settings settings { get; construct; }

        private PresetsModel presets;
        private Gtk.ListBox preset_list;
        private Gtk.SpinButton new_preset;
        private Gtk.Button add_preset;
        private Gtk.Label preset_error;
        private Gtk.DropDown default_width;
        // Set while the dropdown is refilled, so that is not taken as a choice.
        private bool filling = false;

        public LayoutPage (Settings settings) {
            Object (
                settings: settings,
                title: "Layout",
                description: "Windows on the primary monitor tile into a strip of columns that scrolls to follow focus.",
                icon: new ThemedIcon ("preferences-desktop-workspaces"),
                activatable: true
            );
        }

        construct {
            show_end_title_buttons = true;
            settings.bind ("enabled", status_switch, "active", SettingsBindFlags.DEFAULT);
            presets = new PresetsModel (settings);

            var gap = int_spin ("gap", 48);
            var margin = int_spin ("margin", 100);

            var animate = new Gtk.Switch () {
                valign = Gtk.Align.CENTER
            };
            settings.bind ("animate", animate, "active", SettingsBindFlags.DEFAULT);

            var focus_ring = new Gtk.Switch () {
                valign = Gtk.Align.CENTER
            };
            settings.bind ("focus-ring", focus_ring, "active", SettingsBindFlags.DEFAULT);

            var edge_preview = new Gtk.Switch () {
                valign = Gtk.Align.CENTER
            };
            settings.bind ("edge-preview", edge_preview, "active", SettingsBindFlags.DEFAULT);

            default_width = new Gtk.DropDown.from_strings ({}) {
                valign = Gtk.Align.CENTER
            };
            default_width.notify["selected"].connect (() => {
                if (!filling && default_width.selected != Gtk.INVALID_LIST_POSITION) {
                    presets.set_default_index ((int) default_width.selected);
                }
            });
            settings.changed["default-width"].connect (select_default);

            var general = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 12
            };
            attach_row (general, 0, "Gap between windows", "In pixels, between columns and between stacked windows", gap);
            attach_row (general, 1, "Margin at screen edges", "Where the next window peeks in; 0 for none", margin);
            attach_row (general, 2, "New column width", "Snaps to one of the widths below", default_width);
            attach_row (general, 3, "Animate", "Also needs the desktop's animations on", animate);
            attach_row (general, 4, "Focus ring", "An outline in the accent colour around the focused tiled window", focus_ring);
            attach_row (general, 5, "Edge previews", "A thumbnail of the hidden window when the pointer rests at a screen edge", edge_preview);

            preset_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            preset_list.add_css_class ("rich-list");
            var frame = new Gtk.Frame (null) {
                child = preset_list
            };

            new_preset = new Gtk.SpinButton.with_range (10, 100, 1) {
                value = 75,
                valign = Gtk.Align.CENTER
            };
            add_preset = new Gtk.Button.with_label ("Add Width") {
                valign = Gtk.Align.CENTER
            };
            preset_error = new Gtk.Label ("") {
                hexpand = true,
                xalign = 0,
                wrap = true
            };
            preset_error.add_css_class ("dim-label");
            var adder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            adder.append (preset_error);
            adder.append (new_preset);
            adder.append (new Gtk.Label ("%"));
            adder.append (add_preset);
            add_preset.clicked.connect (add_clicked);
            new_preset.activate.connect (add_clicked);

            var widths_header = new Granite.HeaderLabel ("Column widths") {
                secondary_text = "Cycle Width steps through these, as a share of the screen: 2 to 6, each from 10% to 100%"
            };

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.append (general);
            box.append (widths_header);
            box.append (frame);
            box.append (adder);
            child = box;

            presets.changed.connect (fill);
            fill ();
        }

        /**
         * A spin button for an int key. A spin button's value is a double: copied
         * by hand rather than trusting GSettings' numeric mapping.
         */
        private Gtk.SpinButton int_spin (string key, int max) {
            var spin = new Gtk.SpinButton.with_range (0, max, 1) {
                valign = Gtk.Align.CENTER,
                value = settings.get_int (key)
            };
            spin.value_changed.connect (() => {
                var v = (int) spin.value;
                if (settings.get_int (key) != v) {
                    settings.set_int (key, v);
                }
            });
            settings.changed[key].connect (() => spin.value = settings.get_int (key));
            return spin;
        }

        private static void attach_row (Gtk.Grid grid, int row, string title, string subtitle, Gtk.Widget control) {
            var label = new Gtk.Label (title) {
                xalign = 0,
                hexpand = true
            };
            var sub = new Gtk.Label (subtitle) {
                xalign = 0,
                wrap = true
            };
            sub.add_css_class ("dim-label");
            sub.add_css_class ("small-label");
            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            text.append (label);
            text.append (sub);
            grid.attach (text, 0, row);
            grid.attach (control, 1, row);
        }

        private void add_clicked () {
            var pct = (int) new_preset.value;
            if (presets.add (pct / 100.0)) {
                preset_error.label = "";
                return;
            }
            if (!presets.can_add) {
                preset_error.label = "At most %d widths".printf (PresetsModel.MAX);
            } else {
                preset_error.label = "%d%% is already listed".printf (pct);
            }
        }

        private void fill () {
            for (var c = preset_list.get_first_child (); c != null; c = preset_list.get_first_child ()) {
                preset_list.remove (c);
            }
            var values = presets.presets ();
            var labels = new string[0];
            for (int i = 0; i < values.length; i++) {
                var text = PresetsModel.percent (values[i]);
                labels += text;
                var remove = new Gtk.Button.from_icon_name ("list-remove-symbolic") {
                    tooltip_text = "Remove %s".printf (text),
                    sensitive = presets.can_remove,
                    valign = Gtk.Align.CENTER
                };
                remove.add_css_class ("flat");
                int index = i;
                remove.clicked.connect (() => {
                    preset_error.label = "";
                    presets.remove (index);
                });
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                row.append (new Gtk.Label (text) {
                    hexpand = true,
                    xalign = 0
                });
                row.append (remove);
                preset_list.append (row);
            }
            add_preset.sensitive = presets.can_add;
            new_preset.sensitive = presets.can_add;

            filling = true;
            default_width.model = new Gtk.StringList (labels);
            filling = false;
            select_default ();
        }

        private void select_default () {
            filling = true;
            default_width.selected = presets.default_index ();
            filling = false;
        }
    }
}
