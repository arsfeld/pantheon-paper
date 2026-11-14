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
