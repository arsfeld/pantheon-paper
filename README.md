# pantheon-paper

PaperWM-style scrolling tiling for Pantheon, as a Gala plugin: each workspace
on the primary monitor is a horizontal strip of columns that scrolls to follow
focus. Columns hold one or more stacked windows. Dialogs and other non-normal
windows float.

Built against Gala 8.6 with Mutter 46 (elementary OS 8) or Mutter 48 (NixOS).
The few calls that differ between them are in `src/Compat.vala`.

## Install

On elementary OS 8, from the [pantheon-apt](https://arsfeld.github.io/pantheon-apt)
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

## Build and test

```
meson setup build && ninja -C build && meson test -C build
```

CI (`.github/workflows/ci.yml`) builds the `.deb` in elementary OS 8
(`ci/build-deb.sh`), installs it there and checks it, including that
elementary's own gala loads the plugin and keeps running
(`ci/check-install.sh`). Each push to master publishes the `.deb` as a GitHub
Release, which pantheon-apt picks up within the hour. To run the same locally:

```
docker run --rm -v "$PWD:/src" -w /src ghcr.io/elementary/docker:circe-stable \
  sh -c 'git config --global --add safe.directory /src && ci/build-deb.sh && ci/check-install.sh'
```
