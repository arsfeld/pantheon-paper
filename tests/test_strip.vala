using Paper;

// "1,2|3": columns separated by |, windows top to bottom by ,
string order (Strip s) {
    var cols = new string[0];
    foreach (var c in s.columns) {
        var ws = new string[0];
        foreach (var w in c.windows) {
            ws += ((uint64) w).to_string ();
        }
        cols += string.joinv (",", ws);
    }
    return string.joinv ("|", cols);
}

// Columns [1] [2] ... [n], focus on the last.
Strip strip_of (int n) {
    var s = new Strip ();
    for (int i = 1; i <= n; i++) {
        s.insert_after_focused (i);
    }
    return s;
}

// Column 0 holds 1 and 2 stacked; column 1 holds 3. Focus on 1.
Strip stacked () {
    var s = strip_of (3);
    s.focus (1);
    s.slurp ();
    s.focus (1);
    return s;
}

class SetSolo : Object, SoloCheck {
    public Gee.HashSet<uint64?> ids = new Gee.HashSet<uint64?> (id_hash, id_equal);
    public bool is_solo (uint64 id) {
        return ids.contains (id);
    }
}

// strip_of (n) whose solo set is `ids`.
Strip solo_strip (int n, uint64[] ids) {
    var solo = new SetSolo ();
    foreach (var id in ids) {
        solo.ids.add (id);
    }
    var s = new Strip (new Params (), solo);
    for (int i = 1; i <= n; i++) {
        s.insert_after_focused (i);
    }
    return s;
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/strip/ops_on_empty_strip", () => {
        var s = new Strip ();
        s.focus_column (1); s.focus_row (-1); s.slurp (); s.barf ();
        s.cycle_width (1920); s.toggle_full (); s.move_column (1); s.move_in_column (1);
        s.remove (42); s.focus (42);
        s.move_to (42, DropTarget () { kind = DropKind.NEW_COLUMN, column = 0, row = 0 });
        assert (s.columns.size == 0 && s.focused == 0);
    });

    Test.add_func ("/strip/insert_after_focused_order", () => {
        var s = strip_of (2);
        s.focus (1);
        s.insert_after_focused (3);
        assert (order (s) == "1|3|2");
        assert (s.focused == 3);
        assert (s.columns[1].preset == 1);
        assert (s.columns[1].shares[0] == 1.0);
    });

    Test.add_func ("/strip/append_goes_last", () => {
        var s = strip_of (2);
        s.focus (1);
        s.append (3);
        assert (order (s) == "1|2|3");
        assert (s.focused == 1);
    });

    Test.add_func ("/strip/remove_focused_prefers_same_column", () => {
        var s = stacked ();
        s.remove (1);
        assert (order (s) == "2|3" && s.focused == 2);
        var t = stacked ();
        t.focus (2);
        t.remove (2);
        assert (order (t) == "1|3" && t.focused == 1);
    });

    Test.add_func ("/strip/remove_focused_falls_back_left", () => {
        var s = strip_of (3);
        s.focus (2);
        s.remove (2);
        assert (order (s) == "1|3" && s.focused == 1);
    });

    Test.add_func ("/strip/remove_focused_first_column_falls_back_right", () => {
        var s = strip_of (2);
        s.focus (1);
        s.remove (1);
        assert (order (s) == "2" && s.focused == 2);
        s.remove (2);
        assert (s.columns.size == 0 && s.focused == 0);
    });

    Test.add_func ("/strip/remove_unfocused_keeps_focus", () => {
        var s = strip_of (3);
        s.remove (1);
        assert (order (s) == "2|3" && s.focused == 3);
    });

    Test.add_func ("/strip/remove_last_window_drops_column", () => {
        var s = stacked ();
        s.remove (2);
        assert (order (s) == "1|3");
        assert (s.columns[0].shares.size == 1 && s.columns[0].shares[0] == 1.0);
    });

    Test.add_func ("/strip/focus_column_clamps", () => {
        var s = strip_of (3);
        s.focus (1);
        s.focus_column (-1);
        assert (s.focused == 1);
        s.focus_column (5);
        assert (s.focused == 3);
    });

    Test.add_func ("/strip/focus_column_returns_to_active_row", () => {
        var s = stacked ();
        s.focus (2);
        s.focus_column (1);
        assert (s.focused == 3);
        s.focus_column (-1);
        assert (s.focused == 2);
    });

    Test.add_func ("/strip/focus_row_clamps", () => {
        var s = stacked ();
        s.focus_row (-1);
        assert (s.focused == 1);
        s.focus_row (1);
        assert (s.focused == 2);
        s.focus_row (1);
        assert (s.focused == 2);
    });

    Test.add_func ("/strip/move_column_at_end_noop", () => {
        var s = strip_of (2);
        s.move_column (1);
        assert (order (s) == "1|2");
        s.move_column (-1);
        assert (order (s) == "2|1" && s.focused == 2);
    });

    Test.add_func ("/strip/move_in_column", () => {
        var s = stacked ();
        s.move_in_column (-1);
        assert (order (s) == "1,2|3");
        s.move_in_column (1);
        assert (order (s) == "2,1|3" && s.focused == 1);
    });

    Test.add_func ("/strip/slurp_without_next", () => {
        var s = strip_of (2);
        s.slurp ();
        assert (order (s) == "1|2");
    });

    Test.add_func ("/strip/barf_single", () => {
        var s = strip_of (2);
        s.focus (1);
        s.barf ();
        assert (order (s) == "1|2" && s.focused == 1);
    });

    Test.add_func ("/strip/slurp_then_barf_roundtrip", () => {
        var s = strip_of (2);
        s.focus (1);
        s.slurp ();
        assert (order (s) == "1,2");
        assert (s.columns[0].shares[0] == 0.5 && s.columns[0].shares[1] == 0.5);
        assert (s.focused == 1);
        s.focus (2);
        s.barf ();
        assert (order (s) == "1|2" && s.focused == 2);
    });

    Test.add_func ("/strip/barf_keeps_preset", () => {
        var s = stacked ();
        s.cycle_width (1920);
        s.barf ();
        assert (order (s) == "2|1|3");
        assert (s.columns[1].preset == 2);
    });

    Test.add_func ("/strip/cycle_width_steps_presets", () => {
        var s = strip_of (1);
        s.toggle_full ();
        assert (s.columns[0].full);
        s.cycle_width (1920);
        assert (s.columns[0].preset == 2 && !s.columns[0].full);
        s.cycle_width (1920);
        assert (s.columns[0].preset == 0);
        s.cycle_width (1920);
        assert (s.columns[0].preset == 1);
    });

    Test.add_func ("/strip/cycle_width_from_free_snaps_nearest", () => {
        var s = strip_of (1);
        s.set_free_width (1, 700); // 1920: THIRD=632 HALF=952 TWO_THIRDS=1272
        assert (s.columns[0].free_px == 700);
        s.cycle_width (1920);
        assert (s.columns[0].preset == 0 && s.columns[0].free_px == 0);
    });

    Test.add_func ("/strip/set_shares_normalises", () => {
        var s = stacked ();
        s.set_shares (0, { 1.0, 3.0 });
        assert (s.columns[0].shares[0] == 0.25 && s.columns[0].shares[1] == 0.75);
        s.set_shares (0, { 1.0 });
        assert (s.columns[0].shares[0] == 0.25);
        s.set_shares (7, { 1.0 });
    });

    Test.add_func ("/strip/move_to_new_column", () => {
        var s = strip_of (3);
        s.move_to (3, DropTarget () { kind = DropKind.NEW_COLUMN, column = 0 });
        assert (order (s) == "3|1|2" && s.focused == 3);
        var t = strip_of (3);
        t.move_to (1, DropTarget () { kind = DropKind.NEW_COLUMN, column = 3 });
        assert (order (t) == "2|3|1");
    });

    Test.add_func ("/strip/move_to_into_column_clamps_row", () => {
        var s = strip_of (2);
        s.move_to (1, DropTarget () { kind = DropKind.INTO_COLUMN, column = 1, row = 9 });
        assert (order (s) == "2,1");
        assert (s.columns[0].shares[1] == 0.5);
    });

    Test.add_func ("/strip/move_to_own_slot_noop", () => {
        var s = strip_of (3);
        s.move_to (1, DropTarget () { kind = DropKind.NEW_COLUMN, column = 1 });
        assert (order (s) == "1|2|3");
        var t = stacked ();
        t.move_to (1, DropTarget () { kind = DropKind.INTO_COLUMN, column = 0, row = 0 });
        assert (order (t) == "1,2|3");
        t.move_to (1, DropTarget () { kind = DropKind.NONE });
        assert (order (t) == "1,2|3");
    });

    Test.add_func ("/strip/insert_at_restores_slot", () => {
        var s = strip_of (3);
        s.focus (1);
        s.insert_at (4, 1);
        assert (order (s) == "1|4|2|3" && s.focused == 4);
        s.insert_at (5, 99);
        assert (order (s) == "1|4|2|3|5");
        s.insert_at (4, 0);
        assert (order (s) == "1|4|2|3|5");
    });

    Test.add_func ("/strip/presets_shrink_clamps", () => {
        var s = strip_of (1);
        s.cycle_width (1920);
        var col = s.columns[0];
        assert (col.preset == 2);
        s.params.presets = { 0.3, 0.6 };
        assert (s.params.pixels (col.preset, 1000) == 600 - 8);
        s.cycle_width (1000);
        assert (col.preset == 0);
    });

    Test.add_func ("/strip/custom_presets_cycle", () => {
        var s = strip_of (1);
        s.params.presets = { 0.25, 0.5, 0.75, 1.0 };
        s.columns[0].preset = 0;
        int[] seen = {};
        for (int i = 0; i < 4; i++) {
            s.cycle_width (1920);
            seen += s.columns[0].preset;
        }
        assert (seen[0] == 1 && seen[1] == 2 && seen[2] == 3 && seen[3] == 0);
    });

    Test.add_func ("/strip/slurp_skips_solo", () => {
        var s = solo_strip (3, { 2 });
        s.focus (1);
        s.slurp ();
        assert (order (s) == "1|2|3");
        var t = solo_strip (3, { 1 });
        t.focus (1);
        t.slurp ();
        assert (order (t) == "1|2|3");
    });

    Test.add_func ("/strip/drop_into_solo_becomes_column", () => {
        var s = solo_strip (3, { 3 });
        s.move_to (1, DropTarget () { kind = DropKind.INTO_COLUMN, column = 2, row = 0 });
        assert (s.contains (1) && s.column_of (1) != s.column_of (3));
        assert (s.columns.size == 3);
        var t = solo_strip (3, { 1 });
        t.move_to (1, DropTarget () { kind = DropKind.INTO_COLUMN, column = 2, row = 0 });
        assert (t.contains (1) && t.column_of (1) != t.column_of (3));
        assert (t.columns.size == 3);
    });

    Test.add_func ("/strip/order_by_x", () => {
        var ids = order_by_x ({ 1, 2, 3 }, { 500, -200, 100 });
        assert (ids.length == 3 && ids[0] == 2 && ids[1] == 3 && ids[2] == 1);
        var tie = order_by_x ({ 4, 5, 6 }, { 10, 0, 10 });
        assert (tie[0] == 5 && tie[1] == 4 && tie[2] == 6);
    });

    Test.run ();
}
