namespace Paper {
    /**
     * Per-app rules: float, initial width and own column, one row per app.
     * "Add Rule…" offers the apps with windows open, from the plugin's
     * RunningApps, and a field for any id.
     */
    public class RulesPage : Switchboard.SettingsPage {
        public Settings settings { get; construct; }

        private RulesModel model;
        private PresetsModel presets;
        private Gtk.ListBox list;
        private Gtk.MenuButton add_menu;
        private Gtk.ListBox running_list;
        private Gtk.Label running_status;
        private Gtk.Entry id_entry;
        // Names RunningApps reported, for ids with no desktop file.
        private Gee.HashMap<string, string> known_names = new Gee.HashMap<string, string> ();
        private Cancellable? fetching = null;
        // A rule to scroll to once the list is on screen.
        private string? pending_reveal = null;
        // Set while a row writes its own change, so the list is not rebuilt under it.
        private bool editing = false;

        public RulesPage (Settings settings) {
            Object (
                settings: settings,
                title: "App Rules",
                description: "How windows of particular apps are placed when they open. A rule with every option at its default is removed.",
                icon: new ThemedIcon ("application-x-executable")
            );
        }

        construct {
            show_end_title_buttons = true;
            model = new RulesModel (settings);
            presets = new PresetsModel (settings);

            list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list.add_css_class ("rich-list");
            var empty = new Gtk.Label ("No rules: every app tiles with the defaults") {
                margin_top = 12,
                margin_bottom = 12
            };
            empty.add_css_class ("dim-label");
            list.set_placeholder (empty);
            var frame = new Gtk.Frame (null) {
                child = list
            };

            add_menu = new Gtk.MenuButton () {
                label = "Add Rule…",
                halign = Gtk.Align.END,
                popover = build_add_popover ()
            };

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.append (frame);
            box.append (add_menu);
            child = box;

            model.changed.connect (() => {
                if (!editing) {
                    fill ();
                }
            });
            presets.changed.connect (fill);
            list.map.connect (apply_reveal);
            fill ();
        }

        /** Add a rule for `app_id` (or find its row) and bring it into view. */
        public void reveal (string app_id) {
            model.add (app_id);
            pending_reveal = app_id;
            fill ();
            apply_reveal ();
        }

        private void apply_reveal () {
            if (pending_reveal == null || !list.get_mapped ()) {
                return;
            }
            var id = pending_reveal;
            pending_reveal = null;
            // After layout, so the scrolled window knows where the row is.
            Idle.add (() => {
                for (var c = list.get_first_child (); c != null; c = c.get_next_sibling ()) {
                    if (c is Gtk.ListBoxRow && c.get_data<string> ("app-id") == id) {
                        c.grab_focus ();
                        break;
                    }
                }
                return Source.REMOVE;
            });
        }

        private string app_name (string id) {
            var info = new DesktopAppInfo (id + ".desktop");
            if (info != null) {
                return info.get_display_name ();
            }
            return known_names[id.casefold ()] ?? id;
        }

        private Icon app_icon (string id) {
            var info = new DesktopAppInfo (id + ".desktop");
            if (info != null && info.get_icon () != null) {
                return info.get_icon ();
            }
            return new ThemedIcon ("application-default-icon");
        }

        private void fill () {
            for (var c = list.get_first_child (); c != null; c = list.get_first_child ()) {
                list.remove (c);
            }
            foreach (var rule in model.rules) {
                list.append (rule_row (rule));
            }
        }

        private Gtk.ListBoxRow rule_row (AppRule rule) {
            var id = rule.app_id;
            var values = presets.presets ();

            var icon = new Gtk.Image.from_gicon (app_icon (id)) {
                icon_size = Gtk.IconSize.LARGE
            };
            var name = new Gtk.Label (app_name (id)) {
                xalign = 0,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
            var id_label = new Gtk.Label (id) {
                xalign = 0,
                selectable = true,
                ellipsize = Pango.EllipsizeMode.MIDDLE
            };
            id_label.add_css_class ("dim-label");
            id_label.add_css_class ("small-label");
            var remove_rule = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
                tooltip_text = "Remove rule",
                valign = Gtk.Align.CENTER
            };
            remove_rule.add_css_class ("flat");

            var float_switch = new Gtk.Switch () {
                active = rule.float_,
                valign = Gtk.Align.CENTER
            };
            string[] widths = { "Default" };
            foreach (var v in values) {
                widths += PresetsModel.percent (v);
            }
            widths += "Full width";
            var width = new Gtk.DropDown.from_strings (widths) {
                selected = rule_width_index (values, rule.width),
                valign = Gtk.Align.CENTER
            };
            var own = new Gtk.Switch () {
                active = rule.own_column,
                valign = Gtk.Align.CENTER
            };

            var options = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            options.append (new Gtk.Label ("Float"));
            options.append (float_switch);
            options.append (new Gtk.Label ("Width") {
                margin_start = 12
            });
            options.append (width);
            options.append (new Gtk.Label ("Own column") {
                margin_start = 12
            });
            options.append (own);

            var grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 6
            };
            grid.attach (icon, 0, 0, 1, 2);
            grid.attach (name, 1, 0);
            grid.attach (id_label, 1, 1);
            grid.attach (remove_rule, 2, 0, 1, 2);
            grid.attach (options, 1, 2, 2);

            var row = new Gtk.ListBoxRow () {
                child = grid,
                activatable = false
            };
            row.set_data<string> ("app-id", id);

            float_switch.notify["active"].connect (() => write_row (id, float_switch, width, own));
            own.notify["active"].connect (() => write_row (id, float_switch, width, own));
            width.notify["selected"].connect (() => write_row (id, float_switch, width, own));
            remove_rule.clicked.connect (() => {
                int i = model.index_of (id);
                if (i >= 0) {
                    model.remove (i);
                }
            });
            return row;
        }

        // Every write reads all of a row's controls, so the stored rule is the row.
        private void write_row (string id, Gtk.Switch float_switch, Gtk.DropDown width, Gtk.Switch own) {
            int i = model.index_of (id);
            if (i < 0) {
                return;
            }
            editing = true;
            model.update (i, new AppRule () {
                app_id = id,
                float_ = float_switch.active,
                width = rule_width_value (presets.presets (), (int) width.selected),
                own_column = own.active
            });
            editing = false;
        }

        private Gtk.Popover build_add_popover () {
            running_list = new Gtk.ListBox () {
                activate_on_single_click = true
            };
            running_list.add_css_class ("rich-list");
            running_list.row_activated.connect ((row) => {
                var id = row.get_data<string> ("app-id");
                if (id != null) {
                    add_and_close (id);
                }
            });
            running_status = new Gtk.Label ("") {
                xalign = 0,
                wrap = true,
                max_width_chars = 36
            };
            running_status.add_css_class ("dim-label");
            var scrolled = new Gtk.ScrolledWindow () {
                child = running_list,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                propagate_natural_height = true,
                max_content_height = 240
            };

            id_entry = new Gtk.Entry () {
                placeholder_text = "App id, e.g. org.gnome.Calculator",
                hexpand = true
            };
            var add = new Gtk.Button.with_label ("Add") {
                sensitive = false
            };
            add.add_css_class ("suggested-action");
            id_entry.changed.connect (() => add.sensitive = id_entry.text.strip () != "");
            id_entry.activate.connect (() => {
                if (id_entry.text.strip () != "") {
                    add_and_close (id_entry.text.strip ());
                }
            });
            add.clicked.connect (() => add_and_close (id_entry.text.strip ()));
            var typed = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            typed.append (id_entry);
            typed.append (add);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6,
                width_request = 320
            };
            box.append (new Granite.HeaderLabel ("Open apps"));
            box.append (running_status);
            box.append (scrolled);
            box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            box.append (new Granite.HeaderLabel ("Any app"));
            box.append (typed);

            var popover = new Gtk.Popover () {
                child = box
            };
            popover.show.connect (() => {
                id_entry.text = "";
                fetch_running.begin ();
            });
            popover.closed.connect (() => {
                if (fetching != null) {
                    fetching.cancel ();
                }
            });
            return popover;
        }

        private void add_and_close (string id) {
            add_menu.popdown ();
            reveal (id);
        }

        /*
         * RunningApps, asynchronously and with a short timeout, so a hung Gala
         * cannot freeze System Settings. Without the plugin on the bus only
         * the typed id is offered.
         */
        private async void fetch_running () {
            if (fetching != null) {
                fetching.cancel ();
            }
            var cancellable = new Cancellable ();
            fetching = cancellable;
            for (var c = running_list.get_first_child (); c != null; c = running_list.get_first_child ()) {
                running_list.remove (c);
            }
            running_list.visible = false;
            running_status.visible = true;
            running_status.label = "Looking for open apps…";

            AppEntry[] apps = {};
            string? failure = null;
            try {
                var proxy = yield Bus.get_proxy<PaperProxy> (
                    BusType.SESSION, BUS_NAME, BUS_PATH,
                    DBusProxyFlags.DO_NOT_AUTO_START | DBusProxyFlags.DO_NOT_LOAD_PROPERTIES | DBusProxyFlags.DO_NOT_CONNECT_SIGNALS,
                    cancellable
                );
                var dbus = (DBusProxy) proxy;
                if (dbus.g_name_owner == null) {
                    failure = "The tiling plugin is not running, so open apps cannot be listed. Type an app id below.";
                } else {
                    var reply = yield dbus.call ("RunningApps", null, DBusCallFlags.NO_AUTO_START, 2000, cancellable);
                    apps = apps_from_reply (reply);
                }
            } catch (IOError.CANCELLED e) {
                return;
            } catch (Error e) {
                failure = "Open apps could not be listed (%s). Type an app id below.".printf (e.message);
            }
            if (cancellable.is_cancelled ()) {
                return;
            }
            fetching = null;
            if (failure != null) {
                running_status.label = failure;
                return;
            }

            // One row per app, by name.
            var seen = new Gee.HashSet<string> ();
            var unique = new Gee.ArrayList<AppEntry?> ();
            foreach (var a in apps) {
                if (seen.add (a.id.casefold ())) {
                    unique.add (a);
                    known_names[a.id.casefold ()] = a.name;
                }
            }
            unique.sort ((x, y) => strcmp (x.name.collate_key (), y.name.collate_key ()));
            if (unique.size == 0) {
                running_status.label = "No apps have windows open.";
                return;
            }
            running_status.visible = false;
            running_list.visible = true;
            foreach (var a in unique) {
                var name = new Gtk.Label (a.name != "" ? a.name : a.id) {
                    xalign = 0
                };
                var id = new Gtk.Label (a.id) {
                    xalign = 0,
                    ellipsize = Pango.EllipsizeMode.MIDDLE
                };
                id.add_css_class ("dim-label");
                id.add_css_class ("small-label");
                var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                text.append (name);
                text.append (id);
                var row = new Gtk.ListBoxRow () {
                    child = text
                };
                row.set_data<string> ("app-id", a.id);
                running_list.append (row);
            }
        }
    }
}
