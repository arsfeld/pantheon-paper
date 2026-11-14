#!/bin/sh
# Installs dist/*.deb in elementary OS 8 beside Pantheon's own settings, then
# checks that the plugin, the Wingpanel indicator and the Switchboard plug sit where gala loads plugins and links, that its
# schema is compiled in, that none of its keys clash with Pantheon's as
# installed (tools/keys-check.py), and that elementary's own gala loads it and
# keeps running: a plugin that crashes on load ends the user's session.
set -eux

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends elementary-default-settings python3 dbus ./dist/*.deb >/dev/null

plugin=/usr/lib/x86_64-linux-gnu/gala/plugins/libgala-paper.so
test -f "$plugin"
if ldd "$plugin" | grep 'not found'; then exit 1; fi
for lib in /usr/lib/x86_64-linux-gnu/wingpanel/libpaper-indicator.so \
  /usr/lib/x86_64-linux-gnu/switchboard-3/personal/libpaper-plug.so; do
  test -f "$lib"
  if ldd "$lib" | grep 'not found'; then exit 1; fi
done
gsettings list-keys io.github.arsfeld.paper | grep -qx width-presets
gsettings list-keys io.github.arsfeld.paper.keybindings | grep -qx focus-left
test "$(XDG_CURRENT_DESKTOP=Pantheon gsettings get org.gnome.mutter edge-tiling)" = false
XDG_CURRENT_DESKTOP=Pantheon gsettings list-recursively | python3 tools/keys-check.py

# A headless gala on its own session bus, for 15 s. timeout's 124 means it was
# still running; anything else is a crash or an early exit.
mkdir -p -m 1777 /tmp/.X11-unix
mkdir -p -m 700 /tmp/xdg
rc=0
XDG_RUNTIME_DIR=/tmp/xdg XDG_CURRENT_DESKTOP=Pantheon G_MESSAGES_DEBUG=pantheon-paper \
  dbus-run-session -- timeout 15 gala --headless --virtual-monitor 1920x1080 >/tmp/gala.log 2>&1 || rc=$?
grep -q 'pantheon-paper: loaded on 1 monitor' /tmp/gala.log || { cat /tmp/gala.log; exit 1; }
[ "$rc" = 124 ] || { cat /tmp/gala.log; echo "gala exited with $rc" >&2; exit 1; }
