using Paper;

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/focus/ignores_non_normal", () => {
        var t = new FocusTracker ();
        assert (t.last == 0);
        t.focused (5, true);
        t.focused (9, false);
        assert (t.last == 5);
        t.forget (5);
        assert (t.last == 0);
        t.focused (7, true);
        assert (t.last == 7);
    });
    Test.add_func ("/focus/forget_other_keeps_last", () => {
        var t = new FocusTracker ();
        t.focused (7, true);
        t.forget (9);
        assert (t.last == 7);
    });

    Test.run ();
}
