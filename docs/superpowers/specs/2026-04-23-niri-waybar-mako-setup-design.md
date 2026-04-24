# Niri Waybar + Mako Setup

## Context

The bluefin-tcl custom image currently runs niri with DankMaterialShell (DMS) as the desktop shell. DMS appears to crash on resume from sleep, and since Noctalia (another Quickshell config) was already tried and rejected, the goal is to step outside the Quickshell ecosystem entirely.

The user only needs a status bar/panel and notifications — launcher is already handled by Vicinae. That reduces scope from "full desktop shell" to "panel + notification daemon," which is well-served by battle-tested tools.

The current niri configuration is split between a main `config.kdl` (the user's earlier "lightweight waybar + mako + vicinae" attempt) and a `dms/` subdirectory of DMS-flavored subconfigs. The split made sense when DMS was the organizing principle; without DMS it's just sprawl. Scope includes cleaning it up.

PragmataPro (with bundled Nerd Font glyphs) is already installed via the user's chezmoi dotfiles.

## Goals

- Replace DMS with a stable panel + notifications stack for niri.
- Ship a Catppuccin Mocha theme that harmonizes with the user's Iron Giant wallpaper (violet/mauve palette).
- Fix the sizing issues that make default waybar feel chunky.
- Consolidate the fragmented niri config into one readable file.
- Preserve the "finger feel" of the DMS keybind scheme while swapping DMS IPC for standard CLI tools.
- Deploy via chezmoi (configs) and bluebuild recipe updates (packages).

## Non-goals

- Launcher replacement — Vicinae stays, to be run in daemon mode.
- Full desktop shell features (app drawers, control center, settings panel, notepad, dankdash wallpaper picker).
- Multi-theme support — Mocha only, but structured so palette swap is trivial.
- Font packaging — PragmataPro is already handled.
- Removing DMS from the image in this pass. The package stays installed for easy rollback during the trial period; removal is a separate follow-up once stability is proven.

## Deploy targets

Two places get touched:

**Chezmoi source** at `/home/chap/.local/share/chezmoi/` (dotfiles):
- `dot_config/waybar/` — replace existing `config.jsonc` and `style.css`; add new `mocha.css`.
- `dot_config/mako/config` — new file.
- `dot_config/niri/config.kdl` — rewrite as consolidated single file.
- `dot_config/niri/dms/` — delete after consolidation.
- `dot_local/bin/executable_niri-powermenu` — new script.

**bluebuild recipe** at `recipes/recipe-bazzite-mini.yml`:
- Add packages: `fuzzel`, `swaybg`.
- `swaylock`, `waybar`, `mako`, `vicinae` already present.
- `brightnessctl`, `playerctl`, `wireplumber` (provides `wpctl`), `gnome-system-monitor` assumed present on Bazzite — plan will verify.

## Waybar design

### Bar properties

- Position: **top**
- Height: **30px** (default ~40 is too chunky; existing unused config had 32 — 30 is slightly tighter)
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
- `bluetooth`: icon reflects on/off/connected; click opens `blueman-manager` (or equivalent — picked at impl time based on what's installed on Bazzite).
- `network`: icon by connection type; tooltip with SSID/IP.
- `battery`: percent + icon; warning at 20%, critical at 10%.
- `tray`: standard system tray, spacing 10px.

### Niri integration

Use native `niri/workspaces` and `niri/window` modules (waybar 0.10.4+). Implementation plan verifies shipped waybar version supports them; fallback is a `custom/` module polling `niri msg --json workspaces`.

## Styling approach

- `mocha.css` — palette lifted from [catppuccin/waybar](https://github.com/catppuccin/waybar). Defines `@define-color` variables for the full Mocha palette.
- `style.css` — imports `mocha.css`, references only the color variables. Palette swap is a one-line change.

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
- Critical timeout: 0 (sticky), `red` border
- Margin: 10px from edges (with 10px gap below the bar)

## Niri config cleanup

### Consolidation

Flatten to a single `dot_config/niri/config.kdl`. Port kept material from `dms/` (binds, layout, outputs, windowrules, colors) into the main file. Delete the `dms/` subdirectory once the new config is validated. Git history preserves rollback.

### Keybind replacements

Keep the user's muscle memory; replace DMS IPC with standard CLI tools.

| Bind | Function | Implementation |
|------|----------|----------------|
| `Super+space` | Launcher | `spawn "vicinae" "toggle"` (daemon via `spawn-at-startup "vicinae" "server"`) |
| `Super+X` | Power menu | `spawn "niri-powermenu"` (fuzzel-based script, see below) |
| `Mod+Alt+L` | Lock | `spawn "swaylock" "-f"` |
| `Mod+N` | Dismiss notifications | `spawn "makoctl" "dismiss" "--all"` |
| `Ctrl+Alt+Del` | Task manager | `spawn "gnome-system-monitor"` |
| `XF86AudioRaiseVolume` | Volume up | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 3%+` |
| `XF86AudioLowerVolume` | Volume down | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 3%-` |
| `XF86AudioMute` | Mute | `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` |
| `XF86AudioMicMute` | Mic mute | `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` |
| `XF86AudioPlay/Pause` | Play/pause | `playerctl play-pause` |
| `XF86AudioNext/Prev` | Media skip | `playerctl next` / `playerctl previous` |
| `XF86MonBrightnessUp/Down` | Brightness | `brightnessctl set 5%+` / `brightnessctl set 5%-` |
| `Mod+1..9` | Workspace focus | Pure niri — keep as-is |
| `Mod+Ctrl+{Up,Down,Left,Right}` | Column/workspace moves | Pure niri — keep as-is |

All `allow-when-locked=true` flags from the original media/volume/brightness binds carry over.

### Dropped binds

No reasonable replacement and no indicated use — dropped entirely. User can reintroduce if missed.

- `Mod+Comma` (DMS settings panel)
- `Mod+M` (task manager — duplicate of Ctrl+Alt+Del)
- `Mod+Shift+N` (DMS notepad)
- `Mod+Y` (DMS wallpaper picker — wallpaper now set via `swaybg` at startup)

### Power menu script

`dot_local/bin/executable_niri-powermenu`:

```bash
#!/usr/bin/env bash
set -euo pipefail

choice=$(printf '%s\n' Lock Suspend Reboot Shutdown "Log Out" \
  | fuzzel --dmenu --prompt "Power » " --lines 5)

case "$choice" in
  Lock)       swaylock -f ;;
  Suspend)    systemctl suspend ;;
  Reboot)     systemctl reboot ;;
  Shutdown)   systemctl poweroff ;;
  "Log Out")  niri msg action quit --skip-confirmation ;;
esac
```

Plain text labels — no Nerd Font glyphs — to keep the script portable and avoid font-render edge cases.

### Wallpaper

`spawn-at-startup "swaybg" "-i" "/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png" "-m" "fill"`.

### Startup spawns

`config.kdl` retains / gains:
- `spawn-at-startup "waybar"`
- `spawn-at-startup "mako"`
- `spawn-at-startup "vicinae" "server"`
- `spawn-at-startup "swaybg" "-i" "<wallpaper>" "-m" "fill"`

## File layout summary

Paths relative to chezmoi source root `/home/chap/.local/share/chezmoi/`:

```
dot_config/waybar/config.jsonc     # replaced
dot_config/waybar/style.css        # replaced
dot_config/waybar/mocha.css        # new — palette
dot_config/mako/config             # new
dot_config/niri/config.kdl         # rewritten, consolidated
dot_config/niri/dms/               # deleted
dot_local/bin/executable_niri-powermenu  # new
```

Recipe change in `recipes/recipe-bazzite-mini.yml`:
```yaml
- fuzzel
- swaybg
```
added alongside existing `waybar`, `mako`, `swaylock`, `vicinae`.

## Workflow

1. **Verify prerequisites:**
   - Waybar version supports native `niri/workspaces` / `niri/window` modules.
   - `brightnessctl`, `playerctl`, `wpctl`, `gnome-system-monitor` are available on current Bazzite build.
   - Vicinae supports `server` + `toggle` subcommands (or equivalent daemon interface).
2. **Add packages to recipe** — `fuzzel`, `swaybg`. Commit to bluefin-tcl repo.
3. **Write the waybar + mako files** into chezmoi source.
4. **Write consolidated `config.kdl`** preserving kept binds and porting from `dms/`.
5. **Write `niri-powermenu` script**, ensure executable bit via chezmoi `executable_` prefix.
6. **`chezmoi apply`** to deploy.
7. **Iterate live** — launch waybar and mako against the running niri session; tweak CSS / JSON as needed, editing chezmoi source directly.
8. **Delete `dms/` subdir** from chezmoi source once the consolidated config is validated.
9. **Sleep/resume test** — verify across at least 3 suspend cycles that nothing crashes.
10. **Commit chezmoi changes** to git.
11. **Rebuild the image** to pick up new packages; validate on next reboot.

## Risks and open questions

- **Waybar niri module support** — fall back to `custom/` module polling if version is too old.
- **Vicinae daemon interface** — plan verifies the exact `server`/`toggle` subcommands before wiring keybind. If Vicinae uses different flags, the spec's specific commands get adjusted.
- **Sleep/resume stability** — design assumes DMS/Quickshell is the crash source. If waybar also crashes on resume, the issue is lower in the stack and this swap won't fix it. Resume testing is step 9.
- **Tray support** — waybar's tray uses `libappindicator`/StatusNotifierItem; some legacy XEmbed tray apps won't show. Acceptable.
- **swaylock config** — no existing `~/.config/swaylock/config` in chezmoi. Plain `swaylock -f` is fine to start; a matching Mocha-themed config is a nice-to-have for later, not in scope here.
- **Wallpaper path portability** — hardcoding `/var/home/chap/wallpapers/...` ties the niri config to this user on this system. If chezmoi templating is ever desired for multi-host, the path becomes a template variable. Plain string for now.

## Success criteria

- Bar and notifications come up with niri on login (once the user switches the active niri config path off the `dms/` subdir).
- All modules in the waybar layout visibly work and reflect system state.
- PragmataPro icons render correctly (no tofu).
- Theme harmonizes with the Iron Giant wallpaper — mauve accents on dark Mocha base.
- All retained keybinds trigger the expected action via the replacement CLI tool.
- `Super+X` opens the fuzzel power menu and each option works end-to-end (including logout).
- Vicinae launches instantly on `Super+space` (daemon mode — no cold-start lag).
- No crashes across at least 3 sleep/resume cycles.
- `dms/` subdirectory deleted; niri config is a single file.
- All changes committed in both repos (chezmoi, bluefin-tcl).
