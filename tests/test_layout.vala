using Paper;

class MapHints : Object, WidthHints {
    public Gee.HashMap<uint64?, int> widths = new Gee.HashMap<uint64?, int> (
        (k) => (uint) (uint64) k, (a, b) => (uint64) a == (uint64) b);
    public int min_width (uint64 id) {
        return widths.has_key (id) ? widths[id] : 0;
    }
}

const Rect WORK = { 0, 32, 1920, 1048 };

Strip strip_of (int n) {
    var s = new Strip ();
    for (int i = 1; i <= n; i++) {
        s.insert_after_focused (i);
    }
    return s;
}

Placement at (LayoutResult r, uint64 id) {
    foreach (var p in r.windows) {
        if (p.id == id) {
            return p;
        }
    }
    assert_not_reached ();
}

Strip margined (int n) {
    var s = strip_of (n);
    s.params.margin = 20;
    return s;
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/layout/two_halves_side_by_side", () => {
        var r = layout (strip_of (2), WORK, new NoHints ());
        var a = at (r, 1);
        var b = at (r, 2);
        assert (a.rect.x == 0 && a.rect.y == 32 && a.rect.width == 952 && a.rect.height == 1048);
        assert (b.rect.x == 960 && b.rect.width == 952);
        assert (!a.parked && !b.parked);
        assert (r.columns.size == 2 && r.columns[1].x == 960);
    });

    Test.add_func ("/layout/stacked_heights_share_column", () => {
        var s = strip_of (2);
        s.focus (1);
        s.slurp ();
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).rect.y == 32 && at (r, 1).rect.height == 520);
        assert (at (r, 2).rect.y == 560 && at (r, 2).rect.height == 520);
        s.set_shares (0, { 1.0, 3.0 });
        r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).rect.height == 260 && at (r, 2).rect.y == 300 && at (r, 2).rect.height == 780);
    });

    Test.add_func ("/layout/parks_far_right", () => {
        var r = layout (strip_of (4), WORK, new NoHints ());
        assert (at (r, 3).parked && at (r, 3).rect.x == 1845 && at (r, 3).rect.width == 952);
        assert (at (r, 4).parked && at (r, 4).rect.x == 1845);
    });

    Test.add_func ("/layout/parks_far_left", () => {
        var s = strip_of (4);
        s.scroll_x = 2880;
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).parked && at (r, 1).rect.x == 75 - 952);
        assert (at (r, 3).parked && at (r, 3).rect.x == 75 - 952); // only 8 px would show
        assert (!at (r, 4).parked && at (r, 4).rect.x == 0);
    });

    Test.add_func ("/layout/straddling_column_not_parked", () => {
        var s = strip_of (3);
        s.scroll_x = 400;
        var r = layout (s, WORK, new NoHints ());
        assert (!at (r, 1).parked && at (r, 1).rect.x == -400);
        assert (!at (r, 3).parked && at (r, 3).rect.x == 1520);
    });

    // Another monitor beyond an edge: nothing may cross it, or its majority
    // lands on that monitor and Mutter takes it off the primary's workspace.
    Test.add_func ("/layout/walled_right_parks_inside", () => {
        var r = layout (strip_of (4), WORK, new NoHints (), false, true);
        assert (!at (r, 2).parked && at (r, 2).rect.x == 960);
        assert (at (r, 3).parked && at (r, 3).rect.x == 1920 - 952);
        assert (at (r, 4).parked && at (r, 4).rect.x == 1920 - 952);
    });

    Test.add_func ("/layout/walled_right_straddling_parks_inside", () => {
        var s = strip_of (3);
        s.scroll_x = 400;
        var r = layout (s, WORK, new NoHints (), false, true);
        assert (at (r, 3).parked && at (r, 3).rect.x == 968);
        assert (!at (r, 1).parked && at (r, 1).rect.x == -400); // the open left edge still straddles
    });

    Test.add_func ("/layout/walled_left_parks_inside", () => {
        var s = strip_of (3);
        s.scroll_x = 400;
        var r = layout (s, WORK, new NoHints (), true, false);
        assert (at (r, 1).parked && at (r, 1).rect.x == 0);
        assert (!at (r, 3).parked && at (r, 3).rect.x == 1520);
    });

    Test.add_func ("/layout/work_area_offset", () => {
        Rect work = { 100, 0, 1000, 800 };
        var r = layout (strip_of (1), work, new NoHints ());
        assert (at (r, 1).rect.x == 100 && at (r, 1).rect.width == 492);
    });

    Test.add_func ("/layout/full_column_takes_work_width", () => {
        var s = strip_of (2);
        s.focus (1);
        s.toggle_full ();
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).rect.width == 1920 && r.columns[0].x == 0);
        assert (at (r, 2).parked && at (r, 2).rect.x == 1845); // natural x 1928 is off screen
    });

    Test.add_func ("/layout/free_width_used", () => {
        var s = strip_of (2);
        s.set_free_width (1, 700);
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).rect.width == 700 && at (r, 2).rect.x == 708);
    });

    Test.add_func ("/layout/width_hint_widens_column", () => {
        var s = strip_of (2);
        s.focus (1);
        s.cycle_width (1920); s.cycle_width (1920); // HALF -> TWO_THIRDS -> THIRD
        var h = new MapHints ();
        h.widths[1] = 800;
        var r = layout (s, WORK, h);
        assert (at (r, 1).rect.width == 800 && at (r, 2).rect.x == 808);
        h.widths[1] = 300; // smaller than the preset: ignored
        r = layout (s, WORK, h);
        assert (at (r, 1).rect.width == 632);
    });

    Test.add_func ("/layout/scroll_to_focus_minimal_move", () => {
        var s = strip_of (4);
        s.focus (3);
        scroll_to_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 2872 - 1920);
        s.focus (2);
        scroll_to_focus (s, WORK, new NoHints ()); // already fully visible
        assert (s.scroll_x == 952);
        s.focus (1);
        scroll_to_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 0);
    });

    Test.add_func ("/layout/scroll_to_focus_wide_column_centres", () => {
        var s = strip_of (2);
        var h = new MapHints ();
        h.widths[2] = 2500;
        scroll_to_focus (s, WORK, h);
        assert (s.scroll_x == 1250); // left 960, width 2500, centred at x -290
    });

    Test.add_func ("/layout/scroll_to_focus_empty_strip", () => {
        var s = new Strip ();
        s.scroll_x = 300;
        scroll_to_focus (s, WORK, new NoHints ());
        center_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 300);
        assert (layout (s, WORK, new NoHints ()).windows.size == 0);
    });

    Test.add_func ("/layout/center_focus", () => {
        var s = strip_of (3);
        s.focus (2);
        center_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 476);
    });

    Test.add_func ("/layout/pan_clamps", () => {
        var s = strip_of (2);
        pan (s, 5000, WORK, new NoHints ());
        assert (s.scroll_x == 1912 - 960);
        pan (s, -9999, WORK, new NoHints ());
        assert (s.scroll_x == -960);
        pan (s, 100, WORK, new NoHints ());
        assert (s.scroll_x == -860);
    });

    Test.add_func ("/layout/gap_param", () => {
        var s = strip_of (2);
        s.params.gap = 20;
        var r = layout (s, WORK, new NoHints ());
        assert (r.columns[1].x - (r.columns[0].x + r.columns[0].width) == 20);
    });

    // The margin: the focused column stops short of the edge, so the
    // neighbour beyond it peeks in. WORK is 1920 wide, gap 8: U = 1880.
    Test.add_func ("/layout/margin_halves", () => {
        var r = layout (margined (2), WORK, new NoHints ());
        assert (at (r, 1).rect.x == 20 && at (r, 1).rect.width == 932);
        assert (at (r, 2).rect.x == 960 && at (r, 2).rect.width == 932);
    });

    Test.add_func ("/layout/margin_full_width", () => {
        var s = margined (2);
        s.focus (1);
        s.toggle_full ();
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 1).rect.x == 20 && at (r, 1).rect.width == 1880);
    });

    Test.add_func ("/layout/margin_scroll_to_focus_peeks", () => {
        var s = margined (4);
        s.focus (3);
        scroll_to_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 932);
        var r = layout (s, WORK, new NoHints ());
        assert (at (r, 3).rect.x + at (r, 3).rect.width == 1900); // 20 px short of the edge
        assert (at (r, 4).parked && at (r, 4).rect.x == 1845); // its last 20 px show
        s.focus (1);
        scroll_to_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 0 && at (layout (s, WORK, new NoHints ()), 1).rect.x == 20);
    });

    Test.add_func ("/layout/margin_center_focus", () => {
        var s = margined (3);
        s.focus (2);
        center_focus (s, WORK, new NoHints ());
        assert (s.scroll_x == 466 && at (layout (s, WORK, new NoHints ()), 2).rect.x == 494);
    });

    Test.add_func ("/layout/margin_walled_right_peeks", () => {
        var r = layout (margined (3), WORK, new NoHints (), false, true);
        // Flush with the wall and lowered under column 2, which ends at 1892.
        assert (at (r, 3).parked && at (r, 3).rect.x == 988);
    });

    Test.add_func ("/layout/margin_never_eats_half_the_screen", () => {
        var s = strip_of (1);
        s.params.margin = 100;
        Rect narrow = { 0, 0, 300, 800 };
        assert (s.params.usable (300) == 150);
        assert (layout (s, narrow, new NoHints ()).windows[0].rect.width == 67); // round (150 * 0.5) - 8
    });

    // The column a screen edge hides: what an edge preview shows.
    Test.add_func ("/layout/hidden_beyond_ends", () => {
        var s = margined (4);
        s.focus (3);
        scroll_to_focus (s, WORK, new NoHints ());
        var r = layout (s, WORK, new NoHints ());
        assert (hidden_beyond (r, WORK, Side.RIGHT) == 3);
        assert (hidden_beyond (r, WORK, Side.LEFT) == 0);
    });

    Test.add_func ("/layout/hidden_beyond_none_when_it_fits", () => {
        var r = layout (margined (2), WORK, new NoHints ());
        assert (hidden_beyond (r, WORK, Side.LEFT) == -1 && hidden_beyond (r, WORK, Side.RIGHT) == -1);
    });

    Test.add_func ("/layout/hidden_beyond_walled_parked_counts", () => {
        var r = layout (margined (3), WORK, new NoHints (), false, true);
        assert (hidden_beyond (r, WORK, Side.RIGHT) == 2); // parked at 988, its centre on screen
    });

    Test.add_func ("/layout/hidden_beyond_straddler", () => {
        var s = strip_of (3);
        s.scroll_x = 400; // column 3 at 1520, width 952: its centre 1996 is past 1920
        var r = layout (s, WORK, new NoHints ());
        assert (hidden_beyond (r, WORK, Side.RIGHT) == 2 && hidden_beyond (r, WORK, Side.LEFT) == -1);
    });

    Test.add_func ("/layout/hidden_beyond_walled_left_full_width", () => {
        var s = margined (2);
        s.focus (1);
        s.toggle_full ();
        s.focus (2);
        scroll_to_focus (s, WORK, new NoHints ());
        // Column 1 is parked flush at 0, 1880 wide: its centre (940) is left of the middle.
        var r = layout (s, WORK, new NoHints (), true, false);
        assert (r.parked[0] && r.columns[0].x == 0);
        assert (hidden_beyond (r, WORK, Side.LEFT) == 0 && hidden_beyond (r, WORK, Side.RIGHT) == -1);
    });

    Test.run ();
}
