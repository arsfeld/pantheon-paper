using Paper;

const Rect WORK = { 0, 32, 1920, 1048 };

// Three half-width columns: the strip is 2872 px wide.
Strip strip_of (int n) {
    var s = new Strip ();
    for (int i = 1; i <= n; i++) {
        s.insert_after_focused (i);
    }
    s.scroll_x = 0;
    return s;
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/drag/sideways_pans_with_pointer", () => {
        var s = strip_of (3);
        var d = new DragPan (1000, 50, s.scroll_x);
        d.update (s, 700, 60, WORK, new NoHints ());
        assert (!d.detached);
        assert (s.scroll_x == 300);
        // Back the other way: relative to the grab start, not accumulated.
        d.update (s, 900, 40, WORK, new NoHints ());
        assert (s.scroll_x == 100);
    });

    Test.add_func ("/drag/pan_is_clamped_like_super_scroll", () => {
        var s = strip_of (3);
        var d = new DragPan (1000, 50, s.scroll_x);
        d.update (s, 3000, 50, WORK, new NoHints ());
        assert (s.scroll_x == -960);
    });

    Test.add_func ("/drag/pulling_out_detaches_for_good", () => {
        var s = strip_of (3);
        var d = new DragPan (1000, 50, s.scroll_x);
        d.update (s, 900, 50 + DETACH_PX, WORK, new NoHints ());
        assert (!d.detached);
        assert (s.scroll_x == 100);
        d.update (s, 800, 50 + DETACH_PX + 1, WORK, new NoHints ());
        assert (d.detached);
        // Once detached the strip stays where the pan left it.
        assert (s.scroll_x == 100);
        d.update (s, 500, 50, WORK, new NoHints ());
        assert (d.detached);
        assert (s.scroll_x == 100);
    });

    Test.add_func ("/drag/upwards_detaches_too", () => {
        var s = strip_of (2);
        var d = new DragPan (500, 600, 0);
        d.update (s, 500, 600 - DETACH_PX - 1, WORK, new NoHints ());
        assert (d.detached);
    });

    Test.run ();
}
