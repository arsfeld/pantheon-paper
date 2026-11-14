namespace Paper {
    /**
     * The strip commands' keyboard shortcuts. Click a shortcut, then press the
     * new one: Escape cancels, Backspace disables. A shortcut another binding
     * already uses asks before taking it from there. Mutter follows the
     * keybindings schema live, so a change applies at once.
     */
    public class ShortcutsPage : Switchboard.SettingsPage {
        /** Null when the keybindings schema is not installed. */
        public Settings? keys { get; construct; }

        private Gee.HashMap<string, Gtk.Button> buttons = new Gee.HashMap<string, Gtk.Button> ();
        private string? capturing = null;

        public ShortcutsPage (Settings? keys) {
            Object (
                keys: keys,
                title: "Shortcuts",
                description: "Click a shortcut and press new keys. Escape cancels; Backspace disables it.",
                icon: new ThemedIcon ("preferences-desktop-keyboard")
            );
        }

        construct {
            show_end_title_buttons = true;
            if (keys == null) {
                child = new Granite.Placeholder ("Shortcuts are not installed") {
                    description = "The settings schema %s is missing.".printf (KEYS_SCHEMA),
                    icon = new ThemedIcon ("dialog-warning")
                };
                return;
            }

            var list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list.add_css_class ("rich-list");
            var schema = keys.settings_schema;
            foreach (unowned string name in ACTION_NAMES) {
                if (!schema.has_key (name)) {
                    continue;
                }
                list.append (action_row (name, schema.get_key (name).get_summary () ?? name));
            }
            child = new Gtk.Frame (null) {
                child = list
            };
            unmap.connect (() => {
                if (capturing != null) {
                    stop_capture ();
                }
            });
            keys.changed.connect ((name) => {
                if (name != capturing) {
                    show_accels (name);
                }
            });
        }

        private Gtk.Widget action_row (string name, string summary) {
            var label = new Gtk.Label (summary) {
                xalign = 0,
                hexpand = true,
                wrap = true
            };
            var button = new Gtk.Button () {
                valign = Gtk.Align.CENTER,
                child = new Gtk.Label ("")
            };
            button.add_css_class ("flat");
            buttons[name] = button;
            show_accels (name);

            // Capture phase: ahead of the button's own Return and Space handling.
            var key = new Gtk.EventControllerKey () {
                propagation_phase = Gtk.PropagationPhase.CAPTURE
            };
            key.key_pressed.connect ((keyval, keycode, state) => on_key (key, name, keyval, keycode, state));
            button.add_controller (key);
            var focus = new Gtk.EventControllerFocus ();
            // Focus moving elsewhere in the window ends the capture; the
            // window losing focus (to a compositor prompt about the
            // shortcut inhibitor, say) does not.
            focus.leave.connect (() => {
                var window = get_root () as Gtk.Window;
                if (capturing == name && window != null && window.is_active) {
                    stop_capture ();
                }
            });
            button.add_controller (focus);
            button.clicked.connect (() => start_capture (name));

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.append (label);
            box.append (button);
            return box;
        }

        private void show_accels (string name) {
            var button = buttons[name];
            if (button == null) {
                return;
            }
            var parts = new string[0];
            foreach (unowned string a in keys.get_strv (name)) {
                var text = Granite.accel_to_string (a);
                if (text != null && text != "") {
                    parts += text;
                }
            }
            ((Gtk.Label) button.child).label = parts.length == 0 ? "Disabled" : string.joinv (", ", parts);
        }

        private Gdk.Toplevel? toplevel () {
            var native = get_native ();
            return native != null ? native.get_surface () as Gdk.Toplevel : null;
        }

        private void start_capture (string name) {
            if (capturing != null) {
                stop_capture ();
            }
            capturing = name;
            ((Gtk.Label) buttons[name].child).label = "Press a shortcut…";
            // Otherwise Gala acts on the shortcut (Super+arrows, say) before
            // this window sees it.
            var top = toplevel ();
            if (top != null) {
                top.inhibit_system_shortcuts (null);
            }
        }

        private void stop_capture () {
            var name = capturing;
            capturing = null;
            var top = toplevel ();
            if (top != null) {
                top.restore_system_shortcuts ();
            }
            if (name != null) {
                show_accels (name);
            }
        }

        private bool on_key (Gtk.EventControllerKey controller, string name, uint keyval, uint keycode, Gdk.ModifierType state) {
            if (capturing != name) {
                return false;
            }
            var mods = state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK
                | Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.SUPER_MASK);
            if (mods == 0 && keyval == Gdk.Key.Escape) {
                stop_capture ();
                return true;
            }
            if (mods == 0 && keyval == Gdk.Key.BackSpace) {
                stop_capture ();
                keys.set_strv (name, {});
                return true;
            }
            if (is_modifier (keyval)) {
                return true;
            }
            // The key as unshifted: <Super><Shift>f, not <Super><Shift>F.
            uint base_keyval;
            int group, level;
            Gdk.ModifierType consumed;
            var display = get_display ();
            if (!display.translate_key (keycode, 0, (int) controller.get_group (), out base_keyval, out group, out level, out consumed)) {
                base_keyval = keyval;
            }
            base_keyval = Gdk.keyval_to_lower (base_keyval);
            // A global shortcut needs a modifier, or every typed letter would trigger it.
            if (mods == 0 || !Gtk.accelerator_valid (base_keyval, mods)) {
                return true;
            }
            var accel = Gtk.accelerator_name (base_keyval, mods);
            stop_capture ();
            propose (name, accel);
            return true;
        }

        private static bool is_modifier (uint keyval) {
            switch (keyval) {
            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
            case Gdk.Key.Alt_L:
            case Gdk.Key.Alt_R:
            case Gdk.Key.Meta_L:
            case Gdk.Key.Meta_R:
            case Gdk.Key.Super_L:
            case Gdk.Key.Super_R:
            case Gdk.Key.Hyper_L:
            case Gdk.Key.Hyper_R:
            case Gdk.Key.ISO_Level3_Shift:
            case Gdk.Key.ISO_Level5_Shift:
            case Gdk.Key.Caps_Lock:
            case Gdk.Key.Num_Lock:
                return true;
            default:
                return false;
            }
        }

        // Set `accel` on `name`, after asking if some other binding has it.
        private void propose (string name, string accel) {
            var src = SettingsSchemaSource.get_default ();
            var clashes = accel_clashes (accel, collect_key_owners (src), KEYS_SCHEMA, name);
            if (clashes.size == 0) {
                keys.set_strv (name, { accel });
                return;
            }

            var others = new string[0];
            foreach (var o in clashes) {
                string? summary = null;
                var schema = src.lookup (o.schema, true);
                if (schema != null && schema.has_key (o.key)) {
                    summary = schema.get_key (o.key).get_summary ();
                }
                var where = "%s %s".printf (o.schema, o.key);
                others += summary != null ? "“%s” (%s)".printf (summary, where) : where;
            }
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                "%s is already in use".printf (Granite.accel_to_string (accel) ?? accel),
                "It is the shortcut for %s. Replace it there, or cancel and keep it as it is.".printf (string.joinv (", ", others)),
                "dialog-warning",
                Gtk.ButtonsType.CANCEL
            ) {
                modal = true,
                transient_for = get_root () as Gtk.Window
            };
            var replace = dialog.add_button ("Replace", Gtk.ResponseType.ACCEPT);
            replace.add_css_class ("destructive-action");
            dialog.response.connect ((response) => {
                if (response == Gtk.ResponseType.ACCEPT) {
                    foreach (var o in clashes) {
                        var schema = src.lookup (o.schema, true);
                        if (schema != null) {
                            remove_accel (new Settings.full (schema, null, null), o.key, accel);
                        }
                    }
                    keys.set_strv (name, { accel });
                }
                show_accels (name);
                dialog.destroy ();
            });
            dialog.present ();
        }
    }
}
