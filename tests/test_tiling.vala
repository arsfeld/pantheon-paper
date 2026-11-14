using Paper;

WindowFacts normal () {
    return WindowFacts () {
        normal_type = true,
        has_transient_parent = false,
        fullscreen = false,
        minimized = false,
        on_primary = true,
        on_all_workspaces = false,
        floating = false,
        rule_float = false,
    };
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/tiling/normal_window_tiles", () => {
        assert (should_tile (normal ()));
    });
    Test.add_func ("/tiling/non_normal_type_floats", () => {
        var f = normal (); f.normal_type = false;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/transient_floats", () => {
        var f = normal (); f.has_transient_parent = true;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/fullscreen_leaves", () => {
        var f = normal (); f.fullscreen = true;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/minimized_leaves", () => {
        var f = normal (); f.minimized = true;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/secondary_monitor_floats", () => {
        var f = normal (); f.on_primary = false;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/all_workspaces_floats", () => {
        var f = normal (); f.on_all_workspaces = true;
        assert (!should_tile (f));
    });
    Test.add_func ("/tiling/floating_toggle_floats", () => {
        var f = normal (); f.floating = true;
        assert (!should_tile (f));
    });

    Test.add_func ("/tiling/rule_float", () => {
        var f = normal (); f.rule_float = true;
        assert (!should_tile (f));
    });

    // R5: the user's toggle overrides an app rule both ways.
    Test.add_func ("/float/toggle_without_rule", () => {
        var f = new FloatState ();
        assert (!f.floats (1, false));
        f.toggle (1, false);
        assert (f.floats (1, false));
        assert (f.user_floated (1) && !f.rule_floats (1, false));
        f.toggle (1, false);
        assert (!f.floats (1, false));
    });
    Test.add_func ("/float/toggle_overrides_rule", () => {
        var f = new FloatState ();
        assert (f.floats (1, true));
        assert (f.rule_floats (1, true));
        f.toggle (1, true);
        assert (!f.floats (1, true));
        assert (!f.user_floated (1) && !f.rule_floats (1, true));
        f.toggle (1, true);
        assert (f.floats (1, true));
    });
    Test.add_func ("/float/rule_dropped_after_unfloat", () => {
        var f = new FloatState ();
        f.toggle (1, true); // tiled despite the rule
        assert (!f.floats (1, false));
        f.toggle (1, false); // the rule is gone: a plain user float
        assert (f.floats (1, false) && f.floats (1, true));
    });
    Test.add_func ("/float/forget", () => {
        var f = new FloatState ();
        f.toggle (1, false);
        f.toggle (2, true);
        f.forget (1);
        f.forget (2);
        assert (!f.floats (1, false));
        assert (f.floats (2, true));
    });

    Test.run ();
}
