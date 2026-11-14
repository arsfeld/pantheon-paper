using Paper;

bool same (double[] a, double[] b) {
    if (a.length != b.length) {
        return false;
    }
    for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

AppRule rule (string id, bool float_, double width, bool own_column) {
    var r = new AppRule ();
    r.app_id = id;
    r.float_ = float_;
    r.width = width;
    r.own_column = own_column;
    return r;
}

AccelOwner owner (string schema, string key) {
    var o = new AccelOwner ();
    o.schema = schema;
    o.key = key;
    return o;
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/presets/valid", () => {
        assert (presets_valid ({ 0.25, 0.5 }));
        assert (!presets_valid ({ 0.5 }));
        assert (!presets_valid ({ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7 }));
        assert (!presets_valid ({ 0.5, 0.5 }));
        assert (!presets_valid ({ 0.6, 0.4 }));
        assert (!presets_valid ({ 0.05, 0.5 }));
        assert (presets_valid ({ 0.5, 1.0 }));
        // Every comparison with NaN is false: it must fail, not slip through.
        assert (!presets_valid ({ 0.3, double.NAN }));
        assert (!presets_valid ({ double.NAN, 0.5 }));
        assert (!presets_valid ({ 0.3, double.NAN, 0.9 }));
    });

    Test.add_func ("/presets/invalid_falls_back", () => {
        assert (same (presets_or_default ({}), DEFAULT_PRESETS));
        assert (same (presets_or_default ({ 0.25, 0.75 }), { 0.25, 0.75 }));
        assert (same (presets_or_default ({ 0.3, double.NAN }), DEFAULT_PRESETS));
    });

    Test.add_func ("/presets/nearest", () => {
        assert (nearest_preset (DEFAULT_PRESETS, 0.5) == 1);
        assert (nearest_preset (DEFAULT_PRESETS, 0.9) == 2);
        assert (nearest_preset (DEFAULT_PRESETS, 0.0) == 0);
        assert (nearest_preset (DEFAULT_PRESETS, 0.41666) == 0);
        // A NaN default-width reads as the schema default, 0.5.
        assert (nearest_preset (DEFAULT_PRESETS, double.NAN) == 1);
        assert (nearest_preset ({ 0.25, 0.75, 1.0 }, double.NAN) == 0);
    });

    Test.add_func ("/rules/roundtrip", () => {
        var rules = new Gee.ArrayList<AppRule> ();
        rules.add (rule ("a.b", true, 0.0, false));
        rules.add (rule ("c", false, 0.75, true));
        rules.add (rule ("dropped", false, 0.0, false));
        var back = rules_from_variant (rules_to_variant (rules));
        assert (back.size == 2);
        assert (back[0].app_id == "a.b" && back[0].float_ && back[0].width == 0.0 && !back[0].own_column);
        assert (back[1].app_id == "c" && !back[1].float_ && back[1].width == 0.75 && back[1].own_column);
    });

    Test.add_func ("/rules/match", () => {
        var rules = new Gee.ArrayList<AppRule> ();
        rules.add (rule ("Firefox", true, 0.0, false));
        rules.add (rule ("org.gnome.Calculator", true, 0.0, false));
        rules.add (rule ("firefox", false, 0.5, false));
        assert (match_rule (rules, null, null, "firefox") == rules[0]);
        assert (match_rule (rules, "org.gnome.Calculator", null, null) == rules[1]);
        assert (match_rule (rules, null, "", "") == null);
        assert (match_rule (rules, null, null, null) == null);
    });

    Test.add_func ("/accels/normalize", () => {
        assert (accel_normalize ("<Super><Shift>Left") == "shift+super+left");
        assert (accel_normalize ("<Shift><Mod4>left") == "shift+super+left");
        assert (accel_normalize ("<Primary>q") == "control+q");
        assert (accel_normalize ("<Super>") == null);
    });

    Test.add_func ("/accels/clashes", () => {
        var owners = new Gee.HashMap<string, Gee.List<AccelOwner>> ();
        var list = new Gee.ArrayList<AccelOwner> ();
        list.add (owner ("wm", "switch-left"));
        list.add (owner ("paper", "focus-left"));
        owners["super+left"] = list;
        var c = accel_clashes ("<Super>Left", owners, "paper", "focus-left");
        assert (c.size == 1 && c[0].schema == "wm" && c[0].key == "switch-left");
        assert (accel_clashes ("<Super>j", owners, "paper", "focus-left").size == 0);
    });

    Test.run ();
}
