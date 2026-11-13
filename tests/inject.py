#!/usr/bin/env python3
"""Drive real input into a *private* headless Gala through Mutter's
RemoteDesktop D-Bus API (the bus in DBUS_SESSION_BUS_ADDRESS). Never point it
at a live session: it moves that session's pointer and presses its keys.

usage: inject.py ACTION...
  key:super+shift+m   press the keys in order, release them in reverse
  scroll:N            N discrete vertical scroll steps (negative scrolls up)
  scrollsuper:N       the same with Super held
  move:DX,DY          relative pointer motion
  home                pointer to the top-left corner
  down / up           left button press / release
  sleep:S             wait S seconds
  mark:TEXT           print TEXT (flushed), to sync a capture with the input
"""
import sys
import time

from gi.repository import Gio, GLib

KEYSYMS = {
    "super": 0xFFEB, "shift": 0xFFE1, "ctrl": 0xFFE3, "alt": 0xFFE9,
    "left": 0xFF51, "up": 0xFF52, "right": 0xFF53, "down": 0xFF54,
}
BTN_LEFT = 0x110

bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def call(path, iface, method, args=None, reply=None):
    return bus.call_sync("org.gnome.Mutter.RemoteDesktop", path, iface, method, args,
                         GLib.VariantType(reply) if reply else None, Gio.DBusCallFlags.NONE, -1, None)


session = call("/org/gnome/Mutter/RemoteDesktop", "org.gnome.Mutter.RemoteDesktop",
               "CreateSession", None, "(o)").unpack()[0]
S = "org.gnome.Mutter.RemoteDesktop.Session"
call(session, S, "Start")


def keysym(name):
    return KEYSYMS.get(name, ord(name) if len(name) == 1 else 0)


def key(sym, pressed):
    call(session, S, "NotifyKeyboardKeysym", GLib.Variant("(ub)", (sym, pressed)))


for action in sys.argv[1:]:
    verb, _, arg = action.partition(":")
    if verb == "key":
        syms = [keysym(k) for k in arg.split("+")]
        for s in syms:
            key(s, True)
        time.sleep(0.05)
        for s in reversed(syms):
            key(s, False)
    elif verb in ("scroll", "scrollsuper"):
        if verb == "scrollsuper":
            key(KEYSYMS["super"], True)
            time.sleep(0.05)
        steps = int(arg)
        for _ in range(abs(steps)):
            call(session, S, "NotifyPointerAxisDiscrete", GLib.Variant("(ui)", (0, 1 if steps > 0 else -1)))
            time.sleep(0.05)
        if verb == "scrollsuper":
            key(KEYSYMS["super"], False)
    elif verb == "move":
        dx, dy = (float(v) for v in arg.split(","))
        # Several small steps, so a drag registers as motion.
        for _ in range(10):
            call(session, S, "NotifyPointerMotionRelative", GLib.Variant("(dd)", (dx / 10, dy / 10)))
            time.sleep(0.02)
    elif verb == "home":
        call(session, S, "NotifyPointerMotionRelative", GLib.Variant("(dd)", (-10000.0, -10000.0)))
    elif verb in ("down", "up"):
        call(session, S, "NotifyPointerButton", GLib.Variant("(ib)", (BTN_LEFT, verb == "down")))
    elif verb == "mark":
        print(arg, flush=True)
    elif verb == "sleep":
        time.sleep(float(arg))
    else:
        sys.exit(f"unknown action {action}")
    time.sleep(0.1)

call(session, S, "Stop")
