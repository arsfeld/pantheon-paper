namespace Paper {
    public class Plugin : Gala.Plugin {
        private Controller? controller = null;
        private Demo? demo = null;

        public override void initialize (Gala.WindowManager wm) {
            var display = wm.get_display ();
            message ("pantheon-paper: loaded on %d monitor(s)", display.get_n_monitors ());
            controller = new Controller (wm);

            var n = int.parse (Environment.get_variable ("PAPER_DEMO") ?? "0");
            if (n > 0) {
                demo = new Demo (controller, display, n);
                demo.start ();
            }
        }

        public override void destroy () {
            if (controller != null) {
                controller.destroy ();
                controller = null;
            }
            demo = null;
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
