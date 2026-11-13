namespace Paper {
    public class Plugin : Gala.Plugin {
        private Gala.WindowManager? wm = null;

        public override void initialize (Gala.WindowManager wm) {
            this.wm = wm;
            var display = wm.get_display ();
            message ("pantheon-paper: loaded on %d monitor(s)", display.get_n_monitors ());
        }

        public override void destroy () {
        }
    }
}

public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "PaperWM tiling",
        author = "arsfeld",
        plugin_type = typeof (Paper.Plugin),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.IMMEDIATE,
    };
}
