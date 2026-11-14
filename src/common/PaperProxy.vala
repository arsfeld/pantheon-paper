namespace Paper {
    public const string BUS_NAME = "io.github.arsfeld.Paper";
    public const string BUS_PATH = "/io/github/arsfeld/Paper";

    /**
     * The client side of io.github.arsfeld.Paper (src/Bus.vala), for the
     * indicator and the plug. Needs gio, so it is in `proxy_sources`, not
     * `common_sources`: the plugin implements the server and never links it.
     *
     * Properties are read from the proxy's cache; changes arrive as
     * PropertiesChanged, i.e. DBusProxy's `g-properties-changed`, not `notify`.
     */
    [DBus (name = "io.github.arsfeld.Paper")]
    public interface PaperProxy : Object {
        /** Tiling on the active workspace. */
        public abstract bool workspace_tiled { get; set; }
        /** Whether the focused window floats; writing it toggles floating. */
        public abstract bool focused_floating { get; set; }
        /** App id and name of the last focused normal window, ("", "") if none. */
        public abstract AppEntry focused_app { owned get; }
        /** App id and name of every tracked normal window. */
        public abstract AppEntry[] running_apps () throws GLib.DBusError, GLib.IOError;
    }
}
