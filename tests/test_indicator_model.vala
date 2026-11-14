using Paper;

/*
 * Stands in for the D-Bus proxy. Vala installs no GObject properties for a
 * [DBus] interface's members, so each change bumps `changes`, a real property,
 * to announce itself with notify the way PropertiesChanged does on the bus.
 */
class FakeProxy : Object, PaperProxy {
    public int changes { get; set; default = 0; }

    private bool tiled = true;
    public bool workspace_tiled {
        get { return tiled; }
        set { tiled = value; changes++; }
    }

    private bool floating = false;
    public bool focused_floating {
        get { return floating; }
        set { floating = value; changes++; }
    }

    private AppEntry _app = AppEntry () { id = "", name = "" };
    public AppEntry app {
        get { return _app; }
        set { _app = value; changes++; }
    }
    public AppEntry focused_app {
        owned get { return _app; }
    }

    public AppEntry[] running_apps () throws GLib.DBusError, GLib.IOError {
        return { _app };
    }
}

Settings fresh_settings () {
    var s = new Settings ("io.github.arsfeld.paper");
    s.reset ("enabled");
    return s;
}

const string ON = "paper-tiling-symbolic";
const string WS_OFF = "paper-tiling-workspace-off-symbolic";
const string OFF = "paper-tiling-off-symbolic";

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/indicator/icon_states", () => {
        var settings = fresh_settings ();
        var model = new IndicatorModel (settings);
        var fake = new FakeProxy ();
        model.set_proxy (fake);
        assert (model.connected);
        assert (model.enabled);
        assert (model.icon_name == ON);

        fake.workspace_tiled = false;
        assert (!model.workspace_tiled);
        assert (model.icon_name == WS_OFF);

        settings.set_boolean ("enabled", false);
        assert (!model.enabled);
        assert (model.icon_name == OFF);
        fake.workspace_tiled = true;
        assert (model.icon_name == OFF);

        settings.set_boolean ("enabled", true);
        assert (model.icon_name == ON);
    });

    Test.add_func ("/indicator/name_vanishes_and_returns", () => {
        var settings = fresh_settings ();
        var model = new IndicatorModel (settings);
        assert (!model.connected);
        assert (model.icon_name == ON);

        var fake = new FakeProxy ();
        fake.workspace_tiled = false;
        fake.focused_floating = true;
        fake.app = AppEntry () { id = "org.gnome.Calculator", name = "Calculator" };
        model.set_proxy (fake);
        assert (model.connected);
        assert (!model.workspace_tiled);
        assert (model.focused_floating);
        assert (model.focused_id == "org.gnome.Calculator");
        assert (model.focused_name == "Calculator");
        assert (model.icon_name == WS_OFF);

        model.set_proxy (null);
        assert (!model.connected);
        assert (model.focused_id == "");
        assert (model.focused_name == "");
        assert (!model.focused_floating);
        assert (model.icon_name == ON);
        settings.set_boolean ("enabled", false);
        assert (model.icon_name == OFF);
        settings.set_boolean ("enabled", true);

        // A stale proxy no longer drives the model.
        fake.workspace_tiled = true;
        fake.workspace_tiled = false;
        assert (model.icon_name == ON);

        var again = new FakeProxy ();
        again.workspace_tiled = false;
        again.app = AppEntry () { id = "org.gnome.TextEditor", name = "Text Editor" };
        model.set_proxy (again);
        assert (model.connected);
        assert (!model.workspace_tiled);
        assert (model.focused_name == "Text Editor");
        assert (model.icon_name == WS_OFF);
    });

    Test.add_func ("/indicator/switch_writes_settings", () => {
        var settings = fresh_settings ();
        var model = new IndicatorModel (settings);
        model.enabled = false;
        assert (!settings.get_boolean ("enabled"));
        assert (model.icon_name == OFF);
        model.enabled = true;
        assert (settings.get_boolean ("enabled"));
    });

    Test.add_func ("/indicator/live_switches_write_the_proxy", () => {
        var model = new IndicatorModel (fresh_settings ());
        var fake = new FakeProxy ();
        model.set_proxy (fake);
        model.workspace_tiled = false;
        assert (!fake.workspace_tiled);
        model.focused_floating = true;
        assert (fake.focused_floating);
        // With no proxy a write goes nowhere and does not throw.
        fake.workspace_tiled = true;
        model.set_proxy (null);
        model.workspace_tiled = false;
        assert (fake.workspace_tiled);
    });

    Test.run ();
}
