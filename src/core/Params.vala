namespace Paper {
    /**
     * The tunable parts of the layout: the gap, the width presets (fractions
     * of the work area width) and the preset new columns start at. A column's
     * preset is an index into `presets`; it is clamped, never rewritten, when
     * the list shrinks, so a longer list brings the old width back.
     */
    public class Params : Object {
        /** Gap between columns and between stacked windows, in logical pixels. */
        public int gap = 8;
        /**
         * Space kept between the strip and the screen edges, where the column
         * beyond a focused one peeks in. 0 here; the Controller sets it from
         * the settings.
         */
        public int margin = 0;
        public double[] presets = DEFAULT_PRESETS;
        public int default_preset = 1;

        public int clamp_preset (int preset) {
            return preset.clamp (0, presets.length - 1);
        }

        /** The width columns are sized against: the work area less both margins, never under half of it. */
        public int usable (int work_width) {
            return int.max (work_width - 2 * margin, work_width / 2);
        }

        /** Column width in pixels for a work area this wide. */
        public int pixels (int preset, int work_width) {
            return (int) Math.round (usable (work_width) * presets[clamp_preset (preset)]) - gap;
        }
    }

    /** Windows that always keep a column to themselves. */
    public interface SoloCheck : Object {
        public abstract bool is_solo (uint64 id);
    }

    public class NoSolo : Object, SoloCheck {
        public bool is_solo (uint64 id) {
            return false;
        }
    }
}
