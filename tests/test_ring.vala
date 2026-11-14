using Paper;

void assert_rect (Rect r, int x, int y, int width, int height) {
    if (r.x != x || r.y != y || r.width != width || r.height != height) {
        error ("got %d,%d %dx%d, want %d,%d %dx%d", r.x, r.y, r.width, r.height, x, y, width, height);
    }
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/ring/width_fits_half_the_gap", () => {
        assert (ring_width (8) == RING_WIDTH);
        assert (ring_width (5) == 2);
        assert (ring_width (1) == 0);
        assert (ring_width (0) == 0);
    });
    Test.add_func ("/ring/box_surrounds_frame_relative_to_buffer", () => {
        // A frame inset 20 px into its buffer by client-side shadows.
        var box = ring_box (Rect (120, 70, 400, 300), 100, 50, 3, Rect (0, 0, 1920, 1080));
        assert_rect (box, 17, 17, 406, 306);
    });
    Test.add_func ("/ring/box_stays_inside_the_work_area", () => {
        // Flush with the panel (work area from y=30), the right and the bottom
        // edge: those bars move inward over the window's edge.
        var box = ring_box (Rect (968, 30, 952, 1050), 968, 30, 3, Rect (0, 30, 1920, 1050));
        assert_rect (box, -3, 0, 955, 1050);
    });
    Test.add_func ("/ring/bars_tile_the_box_edge", () => {
        var bars = ring_bars (406, 306, 3);
        assert (bars.length == 4);
        assert_rect (bars[0], 0, 0, 406, 3);
        assert_rect (bars[1], 0, 303, 406, 3);
        assert_rect (bars[2], 0, 3, 3, 300);
        assert_rect (bars[3], 403, 3, 3, 300);
    });

    Test.run ();
}
