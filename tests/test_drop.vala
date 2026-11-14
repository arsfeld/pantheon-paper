using Paper;

const Rect WORK = { 0, 32, 1920, 1048 };

Strip strip_of (int n) {
    var s = new Strip ();
    for (int i = 1; i <= n; i++) {
        s.insert_after_focused (i);
    }
    return s;
}

// [1] [2,3] [4]: column 1 stacks 2 over 3 (centres y 292 and 812).
Strip with_stack () {
    var s = strip_of (4);
    s.focus (2);
    s.slurp ();
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

DropTarget hit (Strip s, uint64 dragged, int x, int y) {
    return hit_test (layout (s, WORK, new NoHints ()), s, dragged, x, y);
}

void main (string[] args) {
    Test.init (ref args);

    // Three halves: columns at x 0-952, 960-1912, 1920-2872 (parked at 1845).
    Test.add_func ("/drop/middle_third_into_column", () => {
        var t = hit (strip_of (3), 1, 1436, 600);
        assert (t.kind == DropKind.INTO_COLUMN && t.column == 1 && t.row == 1);
    });

    Test.add_func ("/drop/row_from_pointer_y", () => {
        var s = with_stack ();
        assert (hit (s, 1, 1436, 100).row == 0);
        assert (hit (s, 1, 1436, 500).row == 1);
        assert (hit (s, 1, 1436, 1000).row == 2);
    });

    Test.add_func ("/drop/left_third_new_column_before", () => {
        var t = hit (strip_of (3), 1, 1000, 500);
        assert (t.kind == DropKind.NEW_COLUMN && t.column == 1);
    });

    Test.add_func ("/drop/right_third_new_column_after", () => {
        var t = hit (strip_of (3), 1, 1900, 500);
        assert (t.kind == DropKind.NEW_COLUMN && t.column == 2);
    });

    Test.add_func ("/drop/gap_is_new_column", () => {
        var t = hit (strip_of (3), 3, 955, 500);
        assert (t.kind == DropKind.NEW_COLUMN && t.column == 1);
    });

    Test.add_func ("/drop/own_single_column_is_none", () => {
        assert (hit (strip_of (3), 2, 1436, 500).kind == DropKind.NONE);
    });

    Test.add_func ("/drop/own_stacked_column_rows_skip_dragged", () => {
        var t = hit (with_stack (), 2, 1436, 1000);
        assert (t.kind == DropKind.INTO_COLUMN && t.column == 1 && t.row == 1);
    });

    Test.add_func ("/drop/parked_column_not_targeted", () => {
        // Column 2 is parked at 1845 over column 1's right third: the visible column wins.
        var t = hit (strip_of (3), 1, 1880, 500);
        assert (t.kind == DropKind.NEW_COLUMN && t.column == 2);
    });

    Test.add_func ("/drop/outside_is_none", () => {
        assert (hit (strip_of (2), 1, 1915, 500).kind == DropKind.NONE);
        assert (hit (new Strip (), 1, 100, 100).kind == DropKind.NONE);
    });

    // A solo window never shares a column, so the preview shows what Strip.move_to does.
    Test.add_func ("/drop/solo_into_column_is_new_column_after", () => {
        var t = hit (solo_strip (3, { 2 }), 1, 1436, 600);
        assert (t.kind == DropKind.NEW_COLUMN && t.column == 2);
        var u = hit (solo_strip (3, { 1 }), 1, 1436, 600);
        assert (u.kind == DropKind.NEW_COLUMN && u.column == 2);
        // Within its own stacked column the reorder stays a reorder.
        var v = with_stack ();
        v.solo = new SetSolo ();
        ((SetSolo) v.solo).ids.add (3);
        var w = hit (v, 2, 1436, 1000);
        assert (w.kind == DropKind.INTO_COLUMN && w.column == 1);
    });

    Test.add_func ("/drop/shares_from_heights_normalised", () => {
        var s = shares_from_heights ({ 300, 700 });
        assert (s.length == 2 && (s[0] - 0.3).abs () < 1e-9 && (s[1] - 0.7).abs () < 1e-9);
        var z = shares_from_heights ({ 0, 0 });
        assert (z[0] == 0.5 && z[1] == 0.5);
        assert (shares_from_heights ({}).length == 0);
    });

    Test.run ();
}
