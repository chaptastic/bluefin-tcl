# Niri Waybar + Mako Setup

## Context

The bluefin-tcl custom image currently runs niri with DankMaterialShell (DMS) as the desktop shell. DMS appears to crash on resume from sleep, and since Noctalia (another Quickshell config) was already tried and rejected, the goal is to step outside the Quickshell ecosystem entirely.

The user only needs a status bar/panel and notifications — launcher is already handled by Vicinae. That reduces scope from "full desktop shell" to "panel + notification daemon," which is well-served by battle-tested tools.

## Goals

- Replace DMS with a stable panel + notifications stack for niri.
- Ship a Catppuccin Mocha theme that doesn't look ugly out of the box.
- Fix the sizing issues that make default waybar feel chunky.
- Bake the final config into the image so rebuilds preserve it.

## Non-goals

- Launcher replacement (Vicinae stays).
- Full desktop shell features (app drawers, control center, etc.).
- Multi-theme support — Mocha only, but structured so palette swap is trivial.

## Stack

- **waybar** — the panel. Already installed via `recipe-bazzite-mini.yml`.
- **mako** — notification daemon. Already installed.
- **PragmataPro** — font, already has Nerd Font glyphs baked in. Verify availability; fall back to JetBrainsMono Nerd Font if not packaged.

DMS, Quickshell, and associated packages stay installed for now — removal happens in a separate follow-up once the new setup is proven stable.

## Waybar design

### Bar properties

- Position: **top**
- Height: **30px** (default ~40 is too chunky)
- Background: Mocha `base` (#1e1e2e) at **92% opacity**, 1px `surface0` border-bottom
- Font: **PragmataPro 11pt**
- Horizontal padding per module: 8px; inter-module gap: 4px

### Module layout

| Region | Modules |
|--------|---------|
| Left   | `niri/workspaces`, `niri/window` |
| Center | `clock` (date + time) |
| Right  | `idle_inhibitor`, `cpu`, `memory`, `pulseaudio`, `bluetooth`, `network`, `battery`, `tray` |

### Module behavior notes

- `niri/workspaces`: numeric labels, mauve underline on active workspace, no pill backgrounds.
- `niri/window`: truncate long titles to ~60 chars.
- `clock`: format `%a %b %-d · %H:%M`; tooltip shows calendar.
- `idle_inhibitor`: click to toggle; icon changes with state.
- `cpu` / `memory`: percent only in bar; tooltip with details.
- `pulseaudio`: scroll to change volume; click to toggle mute; right-click opens `pavucontrol`.
- `bluetooth`: icon reflects on/off/connected; click opens `blueman-manager` (or equivalent).
- `network`: icon by connection type; tooltip with SSID/IP.
- `battery`: percent + icon; warning at 20%, critical at 10%.
- `tray`: standard system tray, spacing 10px.

### Niri integration

Use native `niri/workspaces` and `niri/window` modules (waybar 0.10.4+). Verification step in the plan will confirm the shipped version supports them; if not, fall back to a small IPC shim script.

## Styling approach

CSS is structured for maintainability:

- `mocha.css` — color palette lifted from [catppuccin/waybar](https://github.com/catppuccin/waybar). Defines `@define-color` variables for the full Mocha palette.
- `style.css` — imports `mocha.css` and references only the color variables, never hex literals. Swapping palette is one `@import` line change.

### Accent usage

- **mauve** (#cba6f7) — active workspace underline, notification left border, idle inhibitor active state.
- **text** (#cdd6f4) — default foreground.
- **subtext1** (#bac2de) — muted/inactive module text.
- **red** (#f38ba8) — battery critical, urgent tray flags.
- **yellow** (#f9e2af) — battery warning.

## Mako design

- Background: Mocha `mantle` (#181825)
- Border: 2px `mauve` left-side accent
- Foreground: `text`
- Font: PragmataPro 11pt
- Anchor: top-right
- Default timeout: 5s
- Critical timeout: 0 (sticky)
- Margin: 10px from edges (with 10px gap below the bar)
- Per-urgency overrides: critical notifications get `red` border instead of `mauve`.

## File layout

### Iteration phase (user-local)

```
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
~/.config/waybar/mocha.css
~/.config/mako/config
```

### Bake-in phase (system defaults)

```
files/system/etc/xdg/waybar/config.jsonc
files/system/etc/xdg/waybar/style.css
files/system/etc/xdg/waybar/mocha.css
files/system/etc/xdg/mako/config
```

XDG system defaults are picked up when no user-local config exists, so users can still override per-user by dropping files in `~/.config/`.

## Workflow

1. **Verify prerequisites** — confirm waybar version supports native niri modules; confirm PragmataPro package availability on Bazzite.
2. **Write user-local config** into `~/.config/waybar/` and `~/.config/mako/`.
3. **Launch and iterate** — run waybar and mako directly against a live niri session; tweak until it looks right.
4. **Wire into niri** — add `spawn-at-startup` entries in niri config for waybar and mako so they come up with the session.
5. **Bake into image** — copy finalized configs into `files/system/etc/xdg/`.
6. **Package updates** — add PragmataPro package (or bundle the font file in `files/system/usr/share/fonts/`) to `recipe-bazzite-mini.yml`.
7. **Disable DMS autostart** — stop DMS from launching with the niri session, but leave the package installed until the new setup is proven across a few sleep/resume cycles.

DMS removal from the recipe happens in a separate pass once the user is satisfied.

## Risks and open questions

- **PragmataPro packaging** — if it's not in Fedora/Bazzite repos, need to bundle the font file directly. Font file licensing/source is the user's responsibility; the plan will ask before adding anything.
- **Waybar niri module support** — if the shipped version is too old, fall back to a `niri msg --json workspaces` polling script in a `custom/` module. Minor code, not a blocker.
- **Sleep/resume stability** — this design assumes the crash is DMS/Quickshell-specific. If waybar also crashes on resume, the issue is lower in the stack (compositor or kernel) and this swap won't fix it. Resume-cycle testing is an explicit step in the plan.
- **Tray support** — waybar's tray relies on `libappindicator`/StatusNotifierItem; most apps work, but some GTK tray apps still use the legacy XEmbed protocol and won't show. Acceptable tradeoff.

## Success criteria

- Bar and notifications come up with niri on login.
- Active workspace, focused window, clock, and all right-side modules visibly work.
- PragmataPro icons render correctly (no tofu).
- Theme matches the Iron Giant wallpaper aesthetic — violet/mauve accents on dark base.
- No crashes across at least 3 sleep/resume cycles.
- Configs persist across image rebuilds via `files/system/etc/xdg/`.
