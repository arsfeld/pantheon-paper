#!/usr/bin/env python3
"""A plain GTK 3 window for the PAPER_DEMO hook: titled `demo <n>`, with a big
number and a colour per window, so screenshots show which window is where.
With PAPER_DEMO_WIDE=<n>, window n refuses to be narrower than 1100 px; with
PAPER_DEMO_FIXED=<n>, window n is not resizable; with PAPER_DEMO_UNDECORATED=<n>,
window n asks for no decorations (Motif hints, as Steam's main window does,
which matters under X11: see `adopt` in Controller.vala). Its app id is
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

n = args[0] if args else "0"
colours = ["#c6262e", "#f37329", "#f9c440", "#68b723", "#3689e6", "#a56de2"]
css = Gtk.CssProvider()
css.load_from_data(
    f"window {{ background: {colours[int(n) % len(colours)]}; }} label {{ font-size: 96px; color: white; }}".encode()
)
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
win = Gtk.Window(title=f"demo {n}")
win.set_default_size(500, 400)
label = Gtk.Label(label=n)
if os.environ.get("PAPER_DEMO_WIDE") == n:
    label.set_size_request(1100, -1)
win.add(label)
if os.environ.get("PAPER_DEMO_FIXED") == n:
    win.set_resizable(False)
if os.environ.get("PAPER_DEMO_UNDECORATED") == n:
    win.set_decorated(False)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
