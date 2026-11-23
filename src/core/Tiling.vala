namespace Paper {
    /** What decides whether a window belongs in a strip, gathered from Mutter by the controller. */
    public struct WindowFacts {
        /** A normal toplevel: not a dialog, popup, utility, dock or override-redirect window. */
        public bool normal_type;
        public bool has_transient_parent;
        public bool fullscreen;
        public bool minimized;
        public bool on_primary;
        public bool on_all_workspaces;
        /** Toggled to float by the user. */
        public bool floating;
        /** Floated by an app rule. */
        public bool rule_float;
    }

    public bool should_tile (WindowFacts f) {
        return f.normal_type && !f.has_transient_parent && !f.fullscreen && !f.minimized
            && f.on_primary && !f.on_all_workspaces && !f.floating && !f.rule_float;
    }
}

namespace Paper {
    /**
     * Whether windows float. The user's toggle overrides an app rule both
     * ways: `floating` holds windows the user floated, `unfloated` windows the
     * user tiled although a rule floats them.
     */
    public class FloatState : Object {
        private Gee.HashSet<uint64?> floating = new Gee.HashSet<uint64?> (id_hash, id_equal);
        private Gee.HashSet<uint64?> unfloated = new Gee.HashSet<uint64?> (id_hash, id_equal);

        /** Floated by the user (WindowFacts.floating). */
        public bool user_floated (uint64 id) {
            return floating.contains (id);
        }

        /** Floated by its rule, unless the user tiled it (WindowFacts.rule_float). */
        public bool rule_floats (uint64 id, bool rule_float) {
            return rule_float && !unfloated.contains (id);
        }

        /** The effective state. */
        public bool floats (uint64 id, bool rule_float) {
            return user_floated (id) || rule_floats (id, rule_float);
        }

        /** Flip the effective state. */
        public void toggle (uint64 id, bool rule_float) {
            if (floats (id, rule_float)) {
                floating.remove (id);
                if (rule_float) {
                    unfloated.add (id);
                }
            } else {
                floating.add (id);
                unfloated.remove (id);
            }
        }

        public void forget (uint64 id) {
            floating.remove (id);
            unfloated.remove (id);
        }
    }
}

namespace Paper {
    /**
     * Whether a WM_CLASS is a game's, which floats unless an app rule says
     * otherwise. Every Proton title on X11, and every game Steam starts under
     * its runtime, is `steam_app_<appid>`; under Wine's Wayland driver
     * (PROTON_ENABLE_WAYLAND) the app id is the executable, `<name>.exe`;
     * gamescope nests a whole game in one window. A game draws at a size and aspect it picks itself and answers a
     * column's size by resizing back, so tiling one makes it jump between the
     * two sizes, and a fullscreen game that loses focus over it minimizes.
     */
    public bool is_game_class (string? wm_class) {
        if (wm_class == null) {
            return false;
        }
        var c = wm_class.ascii_down ();
        return c.has_prefix ("steam_app_") || c.has_suffix (".exe") || c == "gamescope";
    }

    /**
     * Notices a tiled window fighting the layout: one that took the size it was
     * asked for and then, unasked, changed it again (a game keeping its aspect,
     * a player restoring its video size). A window that only ever answers with
     * its own size (size increments, a minimum) never took the asked size, so
     * it settles through Controller.size_settled and is never counted here.
     * `FIGHTS` reverts within `WINDOW_US` float the window, for any app, game
     * or not, that the class check misses.
     */
    public class FightGuard : Object {
        public const int FIGHTS = 3;
        public const int64 WINDOW_US = 10000000;

        private Gee.HashMap<uint64?, Gee.ArrayList<int64?>> reverts =
            new Gee.HashMap<uint64?, Gee.ArrayList<int64?>> (id_hash, id_equal);
        private Gee.HashSet<uint64?> took = new Gee.HashSet<uint64?> (id_hash, id_equal);

        /** A new size was asked of the window: whether it takes it is a fresh question. */
        public void asked (uint64 id) {
            took.remove (id);
        }

        /**
         * The window's frame changed by itself to `matches` (whether it is the
         * size last asked) at `now`. True when that makes it a fighter.
         */
        public bool resized (uint64 id, bool matches, int64 now) {
            if (matches) {
                took.add (id);
                return false;
            }
            if (!took.remove (id)) {
                return false;
            }
            if (!reverts.has_key (id)) {
                reverts[id] = new Gee.ArrayList<int64?> ();
            }
            var times = reverts[id];
            times.add (now);
            while (times.size > 0 && now - times[0] > WINDOW_US) {
                times.remove_at (0);
            }
            return times.size >= FIGHTS;
        }

        public void forget (uint64 id) {
            reverts.unset (id);
            took.remove (id);
        }
    }
}
