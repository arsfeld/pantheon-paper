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
