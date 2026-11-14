using Paper;

const string PAPER = "io.github.arsfeld.paper";
const string KEYS = "io.github.arsfeld.paper.keybindings";
const string TEST = "io.github.arsfeld.paper.test";

Settings fresh_settings () {
    var s = new Settings (PAPER);
    foreach (var k in s.settings_schema.list_keys ()) {
        s.reset (k);
    }
    return s;
}

// The test schema layered over the plugin's (GSETTINGS_SCHEMA_DIR).
SettingsSchemaSource test_source () {
    try {
        return new SettingsSchemaSource.from_directory (
            Environment.get_variable ("PAPER_TEST_SCHEMA_DIR"), SettingsSchemaSource.get_default (), false);
    } catch (Error e) {
        error ("test schemas: %s", e.message);
    }
}

bool has_owner (Gee.List<AccelOwner> owners, string schema, string key) {
    foreach (var o in owners) {
        if (o.schema == schema && o.key == key) {
            return true;
        }
    }
    return false;
}

void assert_presets (Settings s, double[] want) {
    var got = (double[]) s.get_value ("width-presets");
    assert (got.length == want.length);
    for (int i = 0; i < want.length; i++) {
        assert ((got[i] - want[i]).abs () < 1e-9);
    }
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/plug/rules_add_remove_writes", () => {
        var settings = fresh_settings ();
        var model = new RulesModel (settings);
        assert (model.rules.size == 0);

        int i = model.add ("org.gnome.Calculator");
        assert (i == 0);
        assert (model.rules.size == 1);
        // A rule at its defaults is shown but not stored.
        assert (settings.get_value ("app-rules").n_children () == 0);
        // Adding the same id (any case) finds the existing row.
        assert (model.add ("ORG.gnome.calculator") == 0);
        assert (model.rules.size == 1);

        var r = new AppRule () { app_id = "org.gnome.Calculator", float_ = true };
        model.update (0, r);
        var v = settings.get_value ("app-rules");
        assert (v.n_children () == 1);
        string id;
        bool f;
        double w;
        bool own;
        v.get_child (0, "(sbdb)", out id, out f, out w, out own);
        assert (id == "org.gnome.Calculator");
        assert (f);
        assert (w == 0.0);
        assert (!own);

        model.update (0, new AppRule () { app_id = "org.gnome.Calculator" });
        assert (settings.get_value ("app-rules").n_children () == 0);
        // Still listed for the rest of the session.
        assert (model.rules.size == 1);

        model.update (0, new AppRule () { app_id = "org.gnome.Calculator", own_column = true });
        assert (settings.get_value ("app-rules").n_children () == 1);
        model.remove (0);
        assert (model.rules.size == 0);
        assert (settings.get_value ("app-rules").n_children () == 0);
    });

    Test.add_func ("/plug/rules_follow_outside_changes", () => {
        var settings = fresh_settings ();
        var model = new RulesModel (settings);
        model.add ("org.gnome.TextEditor");
        var b = new VariantBuilder (new VariantType ("a(sbdb)"));
        b.add ("(sbdb)", "org.gnome.Calculator", true, 0.0, false);
        settings.set_value ("app-rules", b.end ());
        // The stored rule arrives and the unsaved default row stays.
        assert (model.rules.size == 2);
        assert (model.index_of ("org.gnome.Calculator") >= 0);
        assert (model.index_of ("org.gnome.TextEditor") >= 0);
        assert (model.rules[model.index_of ("org.gnome.Calculator")].float_);
    });

    Test.add_func ("/plug/rule_width_choices", () => {
        double[] p = { 1.0 / 3.0, 0.5, 2.0 / 3.0 };
        // 0 = Default, 1..n = presets, n + 1 = Full width.
        assert (rule_width_index (p, 0.0) == 0);
        assert (rule_width_index (p, 0.5) == 2);
        assert (rule_width_index (p, 0.45) == 2);
        assert (rule_width_index (p, 1.0) == 4);
        assert (rule_width_value (p, 0) == 0.0);
        assert (rule_width_value (p, 1) == p[0]);
        assert (rule_width_value (p, 4) == 1.0);
    });

    Test.add_func ("/plug/key_owners", () => {
        var owners = collect_key_owners (test_source ());
        assert (owners.has_key ("super+left"));
        assert (has_owner (owners["super+left"], TEST, "x"));
        assert (has_owner (owners["super+left"], KEYS, "focus-left"));
        // Same filter as tools/keys-check.py: a one-character value is not an accelerator.
        assert (owners.has_key ("alt+control+t"));
        assert (!owners.has_key ("a"));

        var clashes = accel_clashes ("<Super>Left", owners, KEYS, "focus-left");
        assert (has_owner (clashes, TEST, "x"));
        assert (!has_owner (clashes, KEYS, "focus-left"));
    });

    Test.add_func ("/plug/remove_accel", () => {
        var src = test_source ();
        var s = new Settings.full (src.lookup (TEST, true), null, null);
        s.reset ("x");
        s.set_strv ("x", { "<Super>Left", "<Mod4>Right" });
        remove_accel (s, "x", "<super>left");
        var left = s.get_strv ("x");
        assert (left.length == 1 && left[0] == "<Mod4>Right");
        // A different spelling of the same accelerator is removed too.
        remove_accel (s, "x", "<Super>Right");
        assert (s.get_strv ("x").length == 0);
    });

    Test.add_func ("/plug/presets_edit_refuses_invalid", () => {
        var settings = fresh_settings ();
        var model = new PresetsModel (settings);
        double third = 0.3333333333, two_thirds = 0.6666666667;
        assert (model.presets ().length == 3);

        assert (!model.add (0.05));
        assert (!model.add (1.2));
        assert (!model.add (double.NAN));
        assert (!model.add (0.5));
        // Within half a percent is the same entry as far as the editor shows.
        assert (!model.add (0.334));
        assert_presets (settings, { third, 0.5, two_thirds });

        assert (model.add (0.25));
        assert_presets (settings, { 0.25, third, 0.5, two_thirds });
        assert (model.add (1.0));
        assert_presets (settings, { 0.25, third, 0.5, two_thirds, 1.0 });
        assert (model.add (0.9));
        assert (!model.can_add);
        assert (!model.add (0.8));
        assert (model.presets ().length == 6);

        assert (model.remove (0));
        assert (model.remove (0));
        assert (model.remove (0));
        assert (model.remove (0));
        assert (!model.can_remove);
        assert (!model.remove (0));
        assert_presets (settings, { 0.9, 1.0 });
    });

    Test.add_func ("/plug/presets_remove_moves_default_width", () => {
        var settings = fresh_settings ();
        var model = new PresetsModel (settings);
        settings.set_double ("default-width", 0.6666666667);
        assert (model.default_index () == 2);
        assert (model.remove (2));
        // The default width follows to the nearest remaining preset.
        assert (settings.get_double ("default-width") == 0.5);
        assert (model.default_index () == 1);
        // Two left: refused, nothing written.
        assert (!model.remove (0));
        assert (settings.get_double ("default-width") == 0.5);
        assert (model.presets ().length == 2);
    });

    Test.add_func ("/plug/presets_nan_default_width", () => {
        var settings = fresh_settings ();
        var model = new PresetsModel (settings);
        // `nan` is valid GVariant text for a double: the editor still shows a
        // listed preset, and its next write replaces the NaN with one.
        settings.set_double ("default-width", double.NAN);
        assert (model.default_index () == 1);
        assert (model.add (0.25));
        assert (settings.get_double ("default-width") == 0.5);
    });

    Test.run ();
}
