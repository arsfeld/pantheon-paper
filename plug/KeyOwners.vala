namespace Paper {
    /**
     * Who binds what: every accelerator in every `as` key of every
     * non-relocatable schema in `src`, by its accel_normalize form. The
     * values that count are those tools/keys-check.py counts: containing a
     * `<`, or longer than one character.
     */
    public Gee.Map<string, Gee.List<AccelOwner>> collect_key_owners (SettingsSchemaSource src) {
        var owners = new Gee.HashMap<string, Gee.List<AccelOwner>> ();
        string[] fixed;
        string[] relocatable;
        src.list_schemas (true, out fixed, out relocatable);
        var as_type = new VariantType ("as");
        foreach (unowned string id in fixed) {
            var schema = src.lookup (id, true);
            if (schema == null) {
                continue;
            }
            Settings? settings = null;
            foreach (var key in schema.list_keys ()) {
                if (!schema.get_key (key).get_value_type ().equal (as_type)) {
                    continue;
                }
                if (settings == null) {
                    settings = new Settings.full (schema, null, null);
                }
                foreach (unowned string accel in settings.get_strv (key)) {
                    if (!accel.contains ("<") && accel.char_count () <= 1) {
                        continue;
                    }
                    var n = accel_normalize (accel);
                    if (n == null) {
                        continue;
                    }
                    if (!owners.has_key (n)) {
                        owners[n] = new Gee.ArrayList<AccelOwner> ();
                    }
                    owners[n].add (new AccelOwner () { schema = id, key = key });
                }
            }
        }
        return owners;
    }

    /** Drop every spelling of `accel` from the `as` key `key`. */
    public void remove_accel (Settings settings, string key, string accel) {
        var n = accel_normalize (accel);
        string[] kept = {};
        foreach (unowned string a in settings.get_strv (key)) {
            if (accel_normalize (a) != n) {
                kept += a;
            }
        }
        settings.set_strv (key, kept);
    }
}
