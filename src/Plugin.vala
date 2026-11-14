namespace Paper {
    public class Plugin : Gala.Plugin {
        private Controller? controller = null;
        private Keys? keys = null;
        private Mouse? mouse = null;
        private Demo? demo = null;

        public override void initialize (Gala.WindowManager wm) {
            var display = wm.get_display ();
            message ("pantheon-paper: loaded on %d monitor(s)", display.get_n_monitors ());
            controller = new Controller (wm, new Config ());
            var actions = new Actions (controller, display);
            keys = new Keys (display, actions);
            mouse = new Mouse (wm, controller);

            var n = int.parse (Environment.get_variable ("PAPER_DEMO") ?? "0");
            if (n > 0) {
                demo = new Demo (controller, actions, mouse, display, n);
                demo.start ();
            }
        }

        public override void destroy () {
            if (keys != null) {
                keys.destroy ();
                keys = null;
            }
            if (mouse != null) {
                mouse.destroy ();
                mouse = null;
            }
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
