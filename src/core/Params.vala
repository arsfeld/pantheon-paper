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
        public double[] presets = DEFAULT_PRESETS;
        public int default_preset = 1;

        public int clamp_preset (int preset) {
            return preset.clamp (0, presets.length - 1);
        }

        /** Column width in pixels for a work area this wide. */
        public int pixels (int preset, int work_width) {
            return (int) Math.round (work_width * presets[clamp_preset (preset)]) - gap;
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
