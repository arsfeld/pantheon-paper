namespace Paper {
    /**
     * The Layout page's width-preset editor over `width-presets` and
     * `default-width`. It only ever writes a valid list (presets_valid): an
     * entry outside 10-100 %, one that shows as the same percentage as an
     * existing entry, a seventh entry, or removing below two are refused.
     * The list is kept sorted.
     */
    public class PresetsModel : Object {
        public const int MIN = 2;
        public const int MAX = 6;

        public Settings settings { get; construct; }
        // A method, not a property: GObject properties cannot hold a double[].
        private double[] values = {};
        public bool can_add { get; private set; }
        public bool can_remove { get; private set; }

        /** The list changed, from here or from outside. */
        public signal void changed ();

        public PresetsModel (Settings settings) {
            Object (settings: settings);
        }

        construct {
            settings.changed["width-presets"].connect (load);
            load ();
        }

        /** The presets, sorted. */
        public double[] presets () {
            return values;
        }

        /** "33%" for 0.3333333333. */
        public static string percent (double fraction) {
            return "%d%%".printf ((int) Math.round (fraction * 100));
        }

        /** Add `fraction` in its sorted place; false if refused. */
        public bool add (double fraction) {
            if (values.length >= MAX || !(fraction >= 0.1 && fraction <= 1.0)) {
                return false;
            }
            foreach (var v in values) {
                if (percent (v) == percent (fraction)) {
                    return false;
                }
            }
            double[] next = {};
            bool placed = false;
            foreach (var v in values) {
                if (!placed && fraction < v) {
                    next += fraction;
                    placed = true;
                }
                next += v;
            }
            if (!placed) {
                next += fraction;
            }
            return store (next);
        }

        /** Remove entry `i`; false if refused. */
        public bool remove (int i) {
            if (values.length <= MIN || i < 0 || i >= values.length) {
                return false;
            }
            double[] next = {};
            for (int j = 0; j < values.length; j++) {
                if (j != i) {
                    next += values[j];
                }
            }
            return store (next);
        }

        /** The preset `default-width` snaps to. */
        public int default_index () {
            return nearest_preset (values, settings.get_double ("default-width"));
        }

        public void set_default_index (int i) {
            if (i >= 0 && i < values.length && settings.get_double ("default-width") != values[i]) {
                settings.set_double ("default-width", values[i]);
            }
        }

        private bool store (double[] next) {
            if (!presets_valid (next)) {
                return false;
            }
            // Keep default-width on a listed preset, so the page's dropdown
            // shows what the plugin uses.
            var dw = settings.get_double ("default-width");
            var snapped = next[nearest_preset (next, dw)];
            var b = new VariantBuilder (new VariantType ("ad"));
            foreach (var v in next) {
                b.add ("d", v);
            }
            settings.set_value ("width-presets", b.end ());
            if (snapped != dw) {
                settings.set_double ("default-width", snapped);
            }
            return true;
        }

        private void load () {
            values = presets_or_default ((double[]) settings.get_value ("width-presets"));
            can_add = values.length < MAX;
            can_remove = values.length > MIN;
            changed ();
        }
    }
}
