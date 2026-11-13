# pantheon-paper

PaperWM-style scrolling tiling for Pantheon, as a Gala plugin: each workspace
on the primary monitor is a horizontal strip of columns that scrolls to follow
focus. Columns hold one or more stacked windows. Dialogs and other non-normal
windows float.

Built against Gala 8.6 and Mutter 48. Packaged and configured for NixOS in
[arsfeld/nixos](https://github.com/arsfeld/nixos) (`packages/pantheon-paper`,
`modules/desktop/pantheon-paper.nix`).

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
Pantheon's defaults (Super+←/→ half-tiling, Super+↑/↓ maximize and the
multitasking view, Super+Shift+arrows move-to-monitor); the NixOS module clears
those. Toggle-full and barf avoid Super+F (picture-in-picture) and Super+O
(rotation lock) instead.

## Build and test

```
meson setup build && ninja -C build && meson test -C build
```
