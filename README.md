# pantheon-paper

PaperWM-style scrolling tiling for Pantheon, as a Gala plugin: each workspace
on the primary monitor is a horizontal strip of columns that scrolls to follow
focus. Columns hold one or more stacked windows. Dialogs and other non-normal
windows float. The focused tiled window has a ring in the accent colour, in
the gap around it, or just inside its edge where it meets the panel or the
screen edge.

Built against Gala 8.6 with Mutter 46 (elementary OS 8) or Mutter 48 (NixOS).
The few calls that differ between them are in `src/Compat.vala`.

## Install

On elementary OS 8, from the [pantheon-extras](https://arsfeld.github.io/pantheon-extras)
repository (set it up as its page says), then log out and back in:

```
sudo apt install pantheon-paper
```

On NixOS it is packaged and configured in
[arsfeld/nixos](https://github.com/arsfeld/nixos) (`packages/pantheon-paper`,
`modules/desktop/pantheon-paper.nix`).

Gala loads plugins only at startup, and a crash in one ends the session.

## Keys

| Key | Action |
|---|---|
| Super+←/→ | Focus the previous/next column |
| Super+↑/↓ | Focus the window above/below |
| Super+Shift+←/→ | Move the column |
| Super+Shift+↑/↓ | Move the window within its column |
| Super+R | Cycle width 1/3 → 1/2 → 2/3 |
| Super+M | Toggle full width |
| Super+I / Super+U | Slurp / barf |
| Super+C | Centre the focused column |
| Super+Shift+F | Toggle floating |

Bindings live in `io.github.arsfeld.paper.keybindings`. Several collide with
Pantheon's defaults: Super+←/→ switched workspaces, which move to
Ctrl+Super+←/→ (half-screen tiling's keys; tiling and edge tiling are turned
off), Super+↓ also opened the multitasking view, which keeps Super+S, and
Super+Shift+arrows moved windows between monitors, which is unbound. The
Debian package changes these defaults with
`debian/pantheon-paper.gschema.override`, the NixOS module through dconf; a
value in your own settings still wins. `tools/keys-check.py` fails on any
clash left. Toggle-full and barf avoid Super+F (picture-in-picture) and Super+O
(rotation lock) instead.

## D-Bus

While Gala runs with the plugin, it owns `io.github.arsfeld.Paper` on the
session bus (object `/io/github/arsfeld/Paper`, same interface name), live
session state for the panel indicator and the settings page:

| Member | Kind | Meaning |
|---|---|---|
| `WorkspaceTiled` | property `b`, read/write | Tiling on the active workspace (its own switch, independent of `enabled`) |
| `FocusedFloating` | property `b`, read/write | Whether the focused window floats; writing a different value toggles it |
| `FocusedApp` | property `(ss)`, read | App id and name of the focused window, `("", "")` if none |
| `RunningApps` | method `→ a(ss)` | App id and name of every open normal window, once per app |

Changes are announced with `PropertiesChanged`. "Focused" is the last focused
*normal* window. Measured in the headless Gala: opening a Wingpanel popover
moves Mutter's focus to Wingpanel, a DOCK window, and clicking empty desktop
leaves focus where it was; in both cases `FocusedApp` keeps naming the app
window. A GTK 3 window with the POPUP_MENU type hint
(`tests/demo-window.py --popup`) is no stand-in for a popover: over Wayland
the hint is never sent, Mutter manages it as a normal window, and it counts
as focused like any other app.

A float toggle, from the key or the bus, overrides an app rule both ways: a
window a rule floats can be tiled, and floated again.

## Build and test

```
meson setup build && ninja -C build && meson test -C build
```

CI (`.github/workflows/ci.yml`) builds the `.deb` in elementary OS 8
(`ci/build-deb.sh`), installs it there and checks it, including that
elementary's own gala loads the plugin and keeps running
(`ci/check-install.sh`). Each push to master publishes the `.deb` as a GitHub
Release, which pantheon-extras picks up within the hour. To run the same locally:

```
docker run --rm -v "$PWD:/src" -w /src ghcr.io/elementary/docker:circe-stable \
  sh -c 'git config --global --add safe.directory /src && ci/build-deb.sh && ci/check-install.sh'
```
