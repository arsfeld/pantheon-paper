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

    Test.add_func ("/game/steam_and_gamescope", () => {
        assert (is_game_class ("steam_app_2483190"));
        assert (is_game_class ("Steam_App_10"));
        assert (is_game_class ("gamescope"));
        assert (is_game_class ("forzahorizon6.exe"));
        assert (!is_game_class ("steam"));
        assert (!is_game_class ("steamwebhelper"));
        assert (!is_game_class (null));
    });
    Test.add_func ("/fight/aspect_keeper_floats_on_third_revert", () => {
        var g = new FightGuard ();
        int64 t = 0;
        for (int i = 1; i <= FightGuard.FIGHTS; i++) {
            g.asked (1);
            assert (!g.resized (1, true, t));      // takes the column's size
            t += 400000;
            bool fighter = g.resized (1, false, t); // and goes back to its own
            assert (fighter == (i == FightGuard.FIGHTS));
            t += 400000;
        }
    });
    Test.add_func ("/fight/own_size_answer_never_counts", () => {
        var g = new FightGuard ();
        for (int i = 0; i < 10; i++) {
            g.asked (1);
            assert (!g.resized (1, false, i * 100000)); // a terminal's size increments
        }
    });
    Test.add_func ("/fight/old_reverts_expire", () => {
        var g = new FightGuard ();
        int64 t = 0;
        for (int i = 0; i < 10; i++) {
            g.asked (1);
            g.resized (1, true, t);
            assert (!g.resized (1, false, t + 1));
            t += FightGuard.WINDOW_US / 2 + 1; // one revert per half window: never three in one
        }
    });
    Test.add_func ("/fight/forget", () => {
        var g = new FightGuard ();
        g.resized (1, true, 0);
        g.resized (1, false, 1);
        g.resized (1, true, 2);
        g.resized (1, false, 3);
        g.forget (1);
        g.resized (1, true, 4);
        assert (!g.resized (1, false, 5));
    });

    Test.run ();
}
