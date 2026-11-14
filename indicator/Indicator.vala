/*
 * pantheon-paper in Wingpanel: an icon for tiling's state (on, this workspace
 * off, off) and a popover with its switches. Settings come from GSettings;
 * live state from io.github.arsfeld.Paper, which the Gala plugin owns. The
 * name is watched, so the indicator follows Gala restarting.
 */
public class Paper.Indicator : Wingpanel.Indicator {
    private const string ICONS = "/io/github/arsfeld/paper/indicator/icons";

    private IndicatorModel model;
    private Settings? keys;
    private uint watch_id = 0;
    // Bumped on every appearance or loss of the name, so a proxy that
    // arrives after its name vanished again is dropped.
    private uint generation = 0;

    private Gtk.Image? icon = null;
    private IndicatorPopover? popover = null;

    public Indicator (Settings settings, Settings? keys) {
        Object (code_name: "paper");
        this.keys = keys;
        model = new IndicatorModel (settings);
        model.notify["icon-name"].connect (() => {
            if (icon != null) {
                icon.icon_name = model.icon_name;
            }
        });
        watch_id = GLib.Bus.watch_name (BusType.SESSION, BUS_NAME, BusNameWatcherFlags.NONE,
            on_appeared, on_vanished);
    }

    construct {
        Gtk.IconTheme.get_default ().add_resource_path (ICONS);
        visible = true;
    }

    ~Indicator () {
        if (watch_id != 0) {
            GLib.Bus.unwatch_name (watch_id);
        }
    }

    private void on_appeared (DBusConnection conn, string name, string owner) {
        var gen = ++generation;
        conn.get_proxy.begin<PaperProxy> (BUS_NAME, BUS_PATH, DBusProxyFlags.DO_NOT_AUTO_START, null, (obj, res) => {
            try {
                var proxy = conn.get_proxy.end<PaperProxy> (res);
                if (gen == generation) {
                    model.set_proxy (proxy);
                }
            } catch (Error e) {
                warning ("pantheon-paper: no proxy for %s: %s", BUS_NAME, e.message);
            }
        });
    }

    private void on_vanished (DBusConnection? conn, string name) {
        generation++;
        model.set_proxy (null);
    }

    public override Gtk.Widget get_display_widget () {
        if (icon == null) {
            icon = new Gtk.Image.from_icon_name (model.icon_name, Gtk.IconSize.LARGE_TOOLBAR) {
                tooltip_text = "Tiling"
            };
        }
        return icon;
    }

    public override Gtk.Widget? get_widget () {
        if (popover == null) {
            popover = new IndicatorPopover (model, keys);
            popover.launched.connect (() => close ());
        }
        return popover;
    }

    public override void opened () {
        if (popover != null) {
            popover.visible_child_name = "main";
        }
    }

    public override void closed () {
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    // Nothing to tile on the login screen.
    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }
    // A missing schema would abort Wingpanel in new Settings (); look it up first.
    var source = SettingsSchemaSource.get_default ();
    if (source == null || source.lookup ("io.github.arsfeld.paper", true) == null) {
        warning ("pantheon-paper: schema io.github.arsfeld.paper is not installed; no indicator");
        return null;
    }
    Settings? keys = null;
    if (source.lookup ("io.github.arsfeld.paper.keybindings", true) != null) {
        keys = new Settings ("io.github.arsfeld.paper.keybindings");
    }
    return new Paper.Indicator (new Settings ("io.github.arsfeld.paper"), keys);
}
