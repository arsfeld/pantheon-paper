/*
 * The few Mutter calls that differ between the two supported Mutters:
 * 46 (libmutter-14, elementary OS 8) and 48 (libmutter-16, NixOS). Call these
 * instead of the Mutter API directly, or the other one stops building.
 * HAS_MUTTER47/48 are defined by meson.build for libmutter-16.
 */
namespace Paper {
    /** The pointer position and modifiers (the cursor tracker moved from Display to Backend in 48). */
    public void pointer (Meta.Display display, out Graphene.Point p, out Clutter.ModifierType mods) {
#if HAS_MUTTER48
        display.get_context ().get_backend ().get_cursor_tracker ().get_pointer (out p, out mods);
#else
        display.get_cursor_tracker ().get_pointer (out p, out mods);
#endif
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
}
