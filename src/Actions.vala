namespace Paper {
    /**
     * The strip commands, by their keybinding names. Keys runs them from
     * shortcuts and Demo runs them directly, so the demo exercises exactly
     * what the keys do.
     */
    public class Actions : Object {
        /** Every command, in the order of the spec's key table and the gschema. */
        public const string[] NAMES = {
            "focus-left", "focus-right", "focus-up", "focus-down",
            "move-left", "move-right", "move-up", "move-down",
            "cycle-width", "toggle-full", "slurp", "barf", "center", "toggle-float",
        };

        private Controller c;
        private unowned Meta.Display display;

        public Actions (Controller c, Meta.Display display) {
            this.c = c;
            this.display = display;
        }

        public void run (string name) {
            if (name == "toggle-float") {
                var w = display.focus_window;
                if (w != null) {
                    c.toggle_float (w);
                }
                return;
            }
            var s = c.current_strip ();
            if (s == null) {
                return;
            }
            var work = c.work_area ();
            switch (name) {
                case "focus-left": focus (s, () => s.focus_column (-1)); return;
                case "focus-right": focus (s, () => s.focus_column (1)); return;
                case "focus-up": focus (s, () => s.focus_row (-1)); return;
                case "focus-down": focus (s, () => s.focus_row (1)); return;
                case "move-left": s.move_column (-1); break;
                case "move-right": s.move_column (1); break;
                case "move-up": s.move_in_column (-1); break;
                case "move-down": s.move_in_column (1); break;
                case "cycle-width": s.cycle_width (work.width); break;
                case "toggle-full": s.toggle_full (); break;
                case "slurp": s.slurp (); break;
                case "barf": s.barf (); break;
                case "center":
                    center_focus (s, work, c.hints ());
                    c.relayout ();
                    return;
                default:
                    warning ("pantheon-paper: unknown action %s", name);
                    return;
            }
            scroll_to_focus (s, work, c.hints ());
            c.relayout ();
        }

        private delegate void Move ();

        /** Change the strip's focus, then hand it to Mutter; the focus signal scrolls and lays out. */
        private void focus (Strip s, Move move) {
            var before = s.focused;
            move ();
            if (s.focused == before) {
                return;
            }
            var w = c.window_for (s.focused);
            if (w != null) {
                w.activate (display.get_current_time ());
            }
        }
    }

    /** Registers each action under its name in io.github.arsfeld.paper.keybindings. */
    public class Keys : Object {
        private const string SCHEMA = "io.github.arsfeld.paper.keybindings";

        private unowned Meta.Display display;
        private Actions actions;
        private Settings? settings = null;

        public Keys (Meta.Display display, Actions actions) {
            this.display = display;
            this.actions = actions;
            // new Settings() on a schema that is not installed aborts the
            // process, and here the process is the whole session: without the
            // schema the strip still tiles, it just has no keys.
            var source = SettingsSchemaSource.get_default ();
            if (source == null || source.lookup (SCHEMA, true) == null) {
                warning ("pantheon-paper: schema %s is not installed; keybindings are off", SCHEMA);
                return;
            }
            settings = new Settings (SCHEMA);
            foreach (var name in Actions.NAMES) {
                display.add_keybinding (name, settings, Meta.KeyBindingFlags.NONE, (d, w, e, binding) => {
                    this.actions.run (binding.get_name ());
                });
            }
        }

        public void destroy () {
            if (settings == null) {
                return;
            }
            foreach (var name in Actions.NAMES) {
                display.remove_keybinding (name);
            }
        }
    }
}
