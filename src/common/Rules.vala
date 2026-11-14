namespace Paper {
    public class AppRule : Object {
        public string app_id { get; set; default = ""; }
        public bool float_ { get; set; default = false; }
        public double width { get; set; default = 0.0; }
        public bool own_column { get; set; default = false; }

        public bool is_default () {
            return !float_ && width == 0.0 && !own_column;
        }
    }

    // Type a(sbdb): app id, float, width fraction (0 = none), own column.
    public Gee.ArrayList<AppRule> rules_from_variant (Variant v) {
        var rules = new Gee.ArrayList<AppRule> ();
        if (!v.is_of_type (new VariantType ("a(sbdb)"))) {
            return rules;
        }
        foreach (var child in v) {
            string id;
            bool f;
            double w;
            bool own;
            child.get ("(sbdb)", out id, out f, out w, out own);
            var r = new AppRule ();
            r.app_id = id;
            r.float_ = f;
            r.width = w;
            r.own_column = own;
            rules.add (r);
        }
        return rules;
    }

    public Variant rules_to_variant (Gee.List<AppRule> rules) {
        var b = new VariantBuilder (new VariantType ("a(sbdb)"));
        foreach (var r in rules) {
            if (!r.is_default ()) {
                b.add ("(sbdb)", r.app_id, r.float_, r.width, r.own_column);
            }
        }
        return b.end ();
    }

    // Case-insensitive, first rule wins; null and empty ids never match.
    public AppRule? match_rule (Gee.List<AppRule> rules, string? gtk_id, string? sandboxed_id, string? wm_class) {
        foreach (var r in rules) {
            foreach (var id in new string?[] { gtk_id, sandboxed_id, wm_class }) {
                if (id != null && id != "" && id.casefold () == r.app_id.casefold ()) {
                    return r;
                }
            }
        }
        return null;
    }
}
