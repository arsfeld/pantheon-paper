namespace Paper {
    public class AccelOwner : Object {
        public string schema { get; set; default = ""; }
        public string key { get; set; default = ""; }
    }

    // Same as norm() in tools/keys-check.py: aliased, sorted modifiers and the
    // lowercased key joined by "+"; null when there is no key.
    public string? accel_normalize (string accel) {
        var mods = new Gee.ArrayList<string> ();
        var key = new StringBuilder ();
        int i = 0;
        while (i < accel.length) {
            if (accel[i] == '<') {
                int end = accel.index_of_char ('>', i + 1);
                if (end > i + 1) {
                    mods.add (alias_modifier (accel.substring (i + 1, end - i - 1).down ()));
                    i = end + 1;
                    continue;
                }
            }
            key.append_c (accel[i]);
            i++;
        }
        var k = key.str.down ();
        if (k == "") {
            return null;
        }
        mods.sort ((a, b) => strcmp (a, b));
        var parts = new string[0];
        foreach (var m in mods) {
            parts += m;
        }
        parts += k;
        return string.joinv ("+", parts);
    }

    string alias_modifier (string m) {
        switch (m) {
        case "ctrl":
        case "primary":
            return "control";
        case "mod1":
            return "alt";
        case "mod4":
            return "super";
        default:
            return m;
        }
    }

    // Owners of the same normalised accelerator other than (own_schema, own_key).
    public Gee.ArrayList<AccelOwner> accel_clashes (string accel, Gee.Map<string, Gee.List<AccelOwner>> owners, string own_schema, string own_key) {
        var found = new Gee.ArrayList<AccelOwner> ();
        var n = accel_normalize (accel);
        if (n == null || !owners.has_key (n)) {
            return found;
        }
        foreach (var o in owners[n]) {
            if (!(o.schema == own_schema && o.key == own_key)) {
                found.add (o);
            }
        }
        return found;
    }
}
