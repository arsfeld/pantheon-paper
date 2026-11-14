namespace Paper {
    public const double[] DEFAULT_PRESETS = { 1.0 / 3.0, 0.5, 2.0 / 3.0 };

    // 2-6 entries, each in [0.1, 1.0], strictly increasing.
    public bool presets_valid (double[] p) {
        if (p.length < 2 || p.length > 6) {
            return false;
        }
        for (int i = 0; i < p.length; i++) {
            if (p[i] < 0.1 || p[i] > 1.0) {
                return false;
            }
            if (i > 0 && p[i] <= p[i - 1]) {
                return false;
            }
        }
        return true;
    }

    public double[] presets_or_default (double[] p) {
        if (presets_valid (p)) {
            return p;
        }
        double[] d = {};
        foreach (var v in DEFAULT_PRESETS) {
            d += v;
        }
        return d;
    }

    // Index of the closest entry; ties go to the lower index.
    public int nearest_preset (double[] p, double fraction) {
        int best = 0;
        double best_d = double.MAX;
        for (int i = 0; i < p.length; i++) {
            double d = (p[i] - fraction).abs ();
            if (d < best_d) {
                best_d = d;
                best = i;
            }
        }
        return best;
    }
}
