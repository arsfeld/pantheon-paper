#!/usr/bin/env python3
"""A plain GTK 3 window for the PAPER_DEMO hook: titled `demo <n>`, with a big
number and a colour per window, so screenshots show which window is where.
With PAPER_DEMO_WIDE=<n>, window n refuses to be narrower than 1100 px; with
PAPER_DEMO_FIXED=<n>, window n is not resizable; with PAPER_DEMO_UNDECORATED=<n>,
window n asks for no decorations (Motif hints, as Steam's main window does,
which matters under X11: see `adopt` in Controller.vala). With
PAPER_DEMO_ASPECT=<n>, window n behaves as a game keeping its aspect does: given
any size, it resizes itself back to its width at 21:9 a moment later (see
FightGuard in src/core/Tiling.vala). With PAPER_DEMO_GAME=<n>, window n's app id
is steam_app_1, a Proton game's class (is_game_class). Otherwise its app id is
io.github.arsfeld.PaperDemo.

With --popup it opens instead one small window with the POPUP_MENU type hint
and the app id io.github.arsfeld.PaperPopup, another client's popup, to see
where Mutter's focus goes. GTK 3 sends no type hint over Wayland, so Mutter
manages it as a NORMAL window and it takes focus as any app window does: it
does not stand in for a Wingpanel popover, which Mutter sees as a DOCK window
(see the README's D-Bus section)."""
import os
import sys

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

# A fixed app id (the Wayland app_id GTK takes from the program name, which
# Mutter reports as WM_CLASS), for app rules in PAPER_DEMO_SETTINGS.
popup = "--popup" in sys.argv[1:]
args = [a for a in sys.argv[1:] if a != "--popup"]
GLib.set_prgname("io.github.arsfeld.PaperPopup" if popup else "io.github.arsfeld.PaperDemo")

if popup:
    win = Gtk.Window(title="popup")
    win.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
    win.set_default_size(300, 200)
    win.add(Gtk.Label(label="popup"))
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
    sys.exit(0)

game_class = None
n = args[0] if args else "0"
if os.environ.get("PAPER_DEMO_GAME") == n:
    GLib.set_prgname("steam_app_1")
    game_class = "steam_app_1"
colours = ["#c6262e", "#f37329", "#f9c440", "#68b723", "#3689e6", "#a56de2"]
css = Gtk.CssProvider()
css.load_from_data(
    f"window {{ background: {colours[int(n) % len(colours)]}; }} label {{ font-size: 96px; color: white; }}".encode()
)
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
win = Gtk.Window(title=f"demo {n}")
if game_class:
    win.set_wmclass(game_class, game_class)  # X11: WM_CLASS is fixed at Gtk init, before set_prgname
win.set_default_size(500, 400)
label = Gtk.Label(label=n)
if os.environ.get("PAPER_DEMO_WIDE") == n:
    label.set_size_request(1100, -1)
win.add(label)
if os.environ.get("PAPER_DEMO_FIXED") == n:
    win.set_resizable(False)
if os.environ.get("PAPER_DEMO_UNDECORATED") == n:
    win.set_decorated(False)
if os.environ.get("PAPER_DEMO_ASPECT") == n:
    pending = []

    def keep_aspect(w, event):
        want = round(event.width * 9 / 21)
        if event.height != want and not pending:
            def back():
                pending.clear()
                # The GdkWindow, not Gtk.Window.resize, which GTK reconciles
                # with its default size and drops: a game resizes its X window.
                w.get_window().resize(event.width, want)
                return False

            pending.append(GLib.timeout_add(300, back))
        return False

    win.connect("configure-event", keep_aspect)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
