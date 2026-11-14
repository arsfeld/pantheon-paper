namespace Paper {
    /**
     * Test hook, on only when PAPER_DEMO=<n> is in Gala's environment: opens
     * n windows of PAPER_DEMO_CMD (run with the window number appended),
     * then runs a scripted list of strip actions. Before each step it logs
     * `paper-demo: step <i> <name>`, and once the step has settled
     * `paper-demo: at <i> <name> <layout>`. With PAPER_DEMO_WAIT=1 a step waits
     * for /tmp/paper-demo.next to appear (and deletes it), so a screenshot can
     * be taken at each one; otherwise steps are 2 s apart. With
     * PAPER_DEMO_KEYS=1 the steps are the keybinding actions instead, run by
     * name through Actions; with PAPER_DEMO_MOUSE=1 they are drops, a pan and
     * a resize, run through Mouse's end-of-grab handlers with computed
     * coordinates; with PAPER_DEMO_IDLE=1 there are only settle steps, for
     * input injected from outside by tests/inject.py; with PAPER_DEMO_SETTINGS=1
     * they write io.github.arsfeld.paper (and one keybinding) from inside Gala,
     * whose memory GSettings backend `gsettings set` cannot reach; with
     * PAPER_DEMO_TOGGLE=1 they switch tiling off and on, globally and for the
     * active workspace. Never injects input.
     */
    public class Demo : Object {
        public delegate void Step ();

        private class Entry {
            public string name;
            public Step run;

            public Entry (string name, owned Step run) {
                this.name = name;
                this.run = (owned) run;
            }
        }

        private const string NEXT = "/tmp/paper-demo.next";
        /** The app id of tests/demo-window.py's windows. */
        private const string DEMO_APP = "io.github.arsfeld.PaperDemo";
        private const string KEYS = "io.github.arsfeld.paper.keybindings";

        private Controller c;
        private Actions actions;
        private Mouse mouse;
        private Meta.Display display;
        private Gee.ArrayList<Entry> steps = new Gee.ArrayList<Entry> ();
        private int index = 0;
        private int count;
        private int opened = 0;
        private bool wait_for_file;

        public Demo (Controller c, Actions actions, Mouse mouse, Meta.Display display, int count) {
            this.c = c;
            this.actions = actions;
            this.mouse = mouse;
            this.display = display;
            this.count = count;
            wait_for_file = Environment.get_variable ("PAPER_DEMO_WAIT") == "1";
            FileUtils.remove (NEXT);

            add ("open", () => {});
            if (Environment.get_variable ("PAPER_DEMO_IDLE") == "1") {
                // Only settle steps: for input injected from outside (tests/inject.py).
                for (int i = 0; i < 8; i++) {
                    add ("settle", () => {});
                }
                return;
            }
            if (Environment.get_variable ("PAPER_DEMO_TOGGLE") == "1") {
                add_toggle_steps ();
                return;
            }
            if (Environment.get_variable ("PAPER_DEMO_SETTINGS") == "1") {
                add_settings_steps ();
                return;
            }
            if (Environment.get_variable ("PAPER_DEMO_MOUSE") == "1") {
                // Windows are found by title: "demo <n>".
                add ("drop-into", () => {
                    var r = column_rect (2);
                    this.mouse.drop (by_title ("demo 1"), r.x + r.width / 2, r.y + r.height - 50);
                });
                add ("drop-gap", () => {
                    var r = column_rect (0);
                    this.mouse.drop (by_title ("demo 1"), r.x + r.width + c.params.gap / 2, r.y + 100);
                });
                add ("pan", () => this.mouse.pan_by (600, true));
                add ("resize-width", () => {
                    var id = by_title ("demo 2");
                    var w = c.window_for (id);
                    if (w == null) {
                        return;
                    }
                    var f = w.get_frame_rect ();
                    c.grabbed = id;
                    w.move_resize_frame (true, f.x, f.y, 700, f.height);
                    Timeout.add (500, () => {
                        c.grabbed = 0;
                        this.mouse.resized (id);
                        return Source.REMOVE;
                    });
                });
                add ("settle", () => {});
                return;
            }
            if (Environment.get_variable ("PAPER_DEMO_KEYS") == "1") {
                foreach (var name in new string[] {
                    "focus-left", "cycle-width", "cycle-width", "cycle-width", "toggle-full", "toggle-full",
                    "slurp", "focus-down", "focus-up", "move-down", "barf", "move-left", "move-right",
                    "focus-left", "center", "toggle-float", "toggle-float",
                }) {
                    var action = name;
                    add (action, () => this.actions.run (action));
                }
                add ("settle", () => {});
                return;
            }
            add ("focus-left", () => focus_column (-1));
            add ("focus-left", () => focus_column (-1));
            add ("maximize", () => focused ()?.maximize (Meta.MaximizeFlags.BOTH));
            add ("close-mid-animation", () => {
                focus_column (1);
                Timeout.add (50, () => {
                    focused ()?.@delete (display.get_current_time ());
                    return Source.REMOVE;
                });
            });
            add ("fullscreen", () => focused ()?.make_fullscreen ());
            add ("unfullscreen", () => focused_any ()?.unmake_fullscreen ());
            add ("minimize", () => focused ()?.minimize ());
            add ("unminimize", () => {
                foreach (var w in display.get_workspace_manager ().get_active_workspace ().list_windows ()) {
                    if (w.minimized) {
                        w.unminimize ();
                    }
                }
            });
            add ("settle", () => {});
        }

        public void add (string name, owned Step run) {
            steps.add (new Entry (name, (owned) run));
        }

        /**
         * The live settings, in order: each step writes one value and its `at`
         * line shows the result; a window a step opens shows up by the `settle`
         * after it. Demo windows carry the app id DEMO_APP (tests/demo-window.py).
         */
        private void add_settings_steps () {
            add ("gap-24", () => settings ()?.set_int ("gap", 24));
            add ("presets-quarters", () => settings ()?.set_value ("width-presets", new Variant.array (VariantType.DOUBLE, {
                new Variant.double (0.25), new Variant.double (0.5), new Variant.double (0.75),
            })));
            add ("cycle-width", () => this.actions.run ("cycle-width"));
            add ("cycle-width", () => this.actions.run ("cycle-width"));
            add ("bad-presets", () => settings ()?.set_value ("width-presets", new Variant.array (VariantType.DOUBLE, {
                new Variant.double (0.9), new Variant.double (0.1),
            })));
            add ("default-width-third", () => {
                settings ()?.set_double ("default-width", 1.0 / 3.0);
                open_window ();
            });
            add ("settle", () => {});
            add ("rule-float", () => {
                var w = focused ();
                if (w != null) {
                    message ("paper-demo: app ids gtk=%s sandboxed=%s wm_class=%s",
                        w.get_gtk_application_id () ?? "-", w.get_sandboxed_app_id () ?? "-", w.get_wm_class () ?? "-");
                }
                set_rule (DEMO_APP, true, 0.0, false);
            });
            add ("rule-width-full", () => {
                set_rule (DEMO_APP, false, 1.0, false);
                open_window ();
            });
            add ("settle", () => {});
            add ("rule-solo", () => set_rule (DEMO_APP, false, 0.0, true));
            add ("focus-left", () => this.actions.run ("focus-left"));
            add ("slurp", () => this.actions.run ("slurp"));
            add ("settle", () => {});
            add ("rebind", () => {
                // Lookup first, as Keys does: a missing schema aborts Gala.
                var source = SettingsSchemaSource.get_default ();
                if (source == null || source.lookup (KEYS, true) == null) {
                    warning ("paper-demo: %s is not installed", KEYS);
                    return;
                }
                // Not <Super>h: that is org.gnome.desktop.wm.keybindings minimize,
                // which then wins. Nothing else binds <Super>j.
                // An "as" built element by element: set_strv and Variant.strv
                // both pass a string[] where C wants const pointers, and warn.
                new Settings (KEYS).set_value ("focus-left",
                    new Variant.array (VariantType.STRING, { new Variant.string ("<Super>j") }));
            });
            for (int i = 0; i < 4; i++) {
                add ("settle", () => {});
            }
        }

        /**
         * Tiling off and on: for the session through `enabled`, then for the
         * active workspace through the controller (the switch the D-Bus
         * property drives). A window opened while the workspace is off stays
         * out of the strip (`|| free:` in the log) until it is switched on.
         */
        private void add_toggle_steps () {
            add ("off", () => settings ()?.set_boolean ("enabled", false));
            add ("on", () => settings ()?.set_boolean ("enabled", true));
            add ("ws-off", () => set_ws_tiled (false));
            add ("open-on-ws-off", () => open_window ());
            add ("ws-on", () => set_ws_tiled (true));
            add ("settle", () => {});
        }

        private void set_ws_tiled (bool on) {
            var ws = display.get_workspace_manager ().get_active_workspace ();
            if (ws != null) {
                c.set_workspace_tiled (ws, on);
                message ("paper-demo: workspace_tiled=%s", c.workspace_tiled (ws).to_string ());
            }
        }

        private Settings? settings () {
            if (c.config.settings == null) {
                warning ("paper-demo: %s is not installed", Config.SCHEMA);
            }
            return c.config.settings;
        }

        private void set_rule (string app_id, bool float_, double width, bool own_column) {
            var rule = new AppRule ();
            rule.app_id = app_id;
            rule.float_ = float_;
            rule.width = width;
            rule.own_column = own_column;
            var rules = new Gee.ArrayList<AppRule> ();
            rules.add (rule);
            settings ()?.set_value ("app-rules", rules_to_variant (rules));
        }

        /** Run PAPER_DEMO_CMD with the next window number. */
        private void open_window () {
            var cmd = Environment.get_variable ("PAPER_DEMO_CMD") ?? "io.elementary.terminal";
            opened++;
            try {
                Process.spawn_command_line_async ("%s %d".printf (cmd, opened));
            } catch (Error e) {
                warning ("paper-demo: cannot run %s: %s", cmd, e.message);
            }
        }

        public void start () {
            Timeout.add (400, () => {
                open_window ();
                return opened < count ? Source.CONTINUE : Source.REMOVE;
            });
            int waited = 0;
            Timeout.add (250, () => {
                var s = c.current_strip ();
                int tiled = 0;
                if (s != null) {
                    foreach (var col in s.columns) {
                        tiled += col.windows.size;
                    }
                }
                if (tiled >= count || ++waited > 120) {
                    next_step ();
                    return Source.REMOVE;
                }
                return Source.CONTINUE;
            });
        }

        private void next_step () {
            if (index >= steps.size) {
                message ("paper-demo: done");
                return;
            }
            var entry = steps[index];
            message ("paper-demo: step %d %s", index, entry.name);
            entry.run ();
            int i = index;
            Timeout.add (800, () => {
                message ("paper-demo: at %d %s %s", i, entry.name, c.describe ());
                index++;
                if (wait_for_file) {
                    Timeout.add (100, () => {
                        if (!FileUtils.test (NEXT, FileTest.EXISTS)) {
                            return Source.CONTINUE;
                        }
                        FileUtils.remove (NEXT);
                        next_step ();
                        return Source.REMOVE;
                    });
                } else {
                    Timeout.add (1200, () => {
                        next_step ();
                        return Source.REMOVE;
                    });
                }
                return Source.REMOVE;
            });
        }

        private Rect column_rect (int i) {
            var s = c.current_strip ();
            var r = c.layout_of (s);
            return i < r.columns.size ? r.columns[i] : Rect (0, 0, 0, 0);
        }

        private uint64 by_title (string title) {
            var s = c.current_strip ();
            foreach (var col in s.columns) {
                foreach (var id in col.windows) {
                    var w = c.window_for (id);
                    if (w != null && w.get_title () == title) {
                        return id;
                    }
                }
            }
            return 0;
        }

        public Meta.Window? focused () {
            var s = c.current_strip ();
            return s == null ? null : c.window_for (s.focused);
        }

        private Meta.Window? focused_any () {
            return display.focus_window;
        }

        public void focus_column (int delta) {
            var s = c.current_strip ();
            if (s == null) {
                return;
            }
            s.focus_column (delta);
            focused ()?.activate (display.get_current_time ());
        }
    }
}
