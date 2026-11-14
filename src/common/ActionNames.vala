namespace Paper {
    /**
     * Every strip command by its keybinding name, in the order of the spec's
     * key table and the gschema. The plugin binds them; the indicator and the
     * plug list them in this order.
     */
    public const string[] ACTION_NAMES = {
        "focus-left", "focus-right", "focus-up", "focus-down",
        "move-left", "move-right", "move-up", "move-down",
        "cycle-width", "toggle-full", "slurp", "barf", "center", "toggle-float",
    };
}
