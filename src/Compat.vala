/*
 * The few Mutter calls that differ between the two supported Mutters:
 * 46 (libmutter-14, elementary OS 8) and 48 (libmutter-16, NixOS). Call these
 * instead of the Mutter API directly, or the other one stops building.
 * HAS_MUTTER47/48 are defined by meson.build for libmutter-16.
 */
namespace Paper {
    /** The cursor tracker (it moved from Display to Backend in 48). */
    public unowned Meta.CursorTracker cursor_tracker (Meta.Display display) {
#if HAS_MUTTER48
        return display.get_context ().get_backend ().get_cursor_tracker ();
#else
        return display.get_cursor_tracker ();
#endif
    }

    /** The pointer position and modifiers. */
    public void pointer (Meta.Display display, out Graphene.Point p, out Clutter.ModifierType mods) {
        cursor_tracker (display).get_pointer (out p, out mods);
    }

    /** Sets an actor's background colour (Clutter.Color gave way to Cogl.Color in 47). */
    public void set_background (Clutter.Actor actor, float r, float g, float b, float a) {
#if HAS_MUTTER47
        actor.background_color = Cogl.Color.from_4f (r, g, b, a);
#else
        actor.background_color = Clutter.Color.from_rgba (
            (uint8) Math.round (r * 255), (uint8) Math.round (g * 255),
            (uint8) Math.round (b * 255), (uint8) Math.round (a * 255));
#endif
    }

    /**
     * Pantheon's accent colour, 0-1 per channel. Gala's StyleManager holds a
     * Cogl.Color from Mutter 47 and a Clutter.Color before it; both have uint8
     * channels, so `var` covers the two. It reads black until AccountsService
     * answers (and in the headless Gala, always): elementary's blue then.
     */
    public void accent_color (out float r, out float g, out float b) {
        var c = Gala.Drawing.StyleManager.get_instance ().theme_accent_color;
        if (c.red == 0 && c.green == 0 && c.blue == 0) {
            r = 0.21f;
            g = 0.54f;
            b = 0.90f;
            return;
        }
        r = c.red / 255.0f;
        g = c.green / 255.0f;
        b = c.blue / 255.0f;
    }
}
