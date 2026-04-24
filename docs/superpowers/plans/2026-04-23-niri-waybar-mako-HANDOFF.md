# Handoff — Niri Waybar + Mako Setup (Resume Document)

**Context date:** 2026-04-23
**Status at handoff:** All config work committed. Paused before image rebuild + niri-session tests.

## What this is

We're replacing DankMaterialShell (DMS) with a waybar + mako + fuzzel stack on niri. DMS was crashing on resume from sleep. The new stack is themed Catppuccin Mocha to harmonize with the user's Iron Giant wallpaper.

**Spec:** `docs/superpowers/specs/2026-04-23-niri-waybar-mako-setup-design.md`
**Plan:** `docs/superpowers/plans/2026-04-23-niri-waybar-mako-setup.md`

Both repos are on `main`. User consented to direct-to-main commits for this work.

## What's done

### bluefin-tcl repo (`/var/home/chap/Projects/bluefin-tcl`)
- `f405192` — Added `fuzzel`, `swaybg`, `blueman`, `network-manager-applet` to `recipes/recipe-bazzite-mini.yml`.
- Spec/plan commits precede this (`353ae0a` and earlier).
- **Not pushed yet.**

### chezmoi repo (`/home/chap/.local/share/chezmoi`)
- `65f3a92` — Waybar Mocha palette (`mocha.css`) + config (`config.jsonc`) + styles (`style.css`).
- `45f22d2` — Mako Mocha config (`dot_config/mako/config`).
- `c4d3ab2` — `executable_niri-powermenu` script (fuzzel-based power menu).
- `a0d0067` — Niri keybinds: `Super+X` (powermenu), `Mod+Alt+L` (swaylock), `Mod+N` (makoctl dismiss), `Ctrl+Alt+Del` (gnome-system-monitor). **Note:** this commit also swept up pre-existing working-tree changes that removed DMS `include`s and rewrote media keys with `wpctl`/`playerctl`/`brightnessctl` — a ~200+/200− diff. End state is correct; commit message undersells the scope. User chose to leave it as-is.
- `a372c6e` — Niri startup spawns: `vicinae server`, `blueman-applet`, `nm-applet --indicator`, `swaybg` with Iron Giant wallpaper.
- `ec27509` — Deleted stale `dot_config/niri/dms/` subdir (8 files).
- `c04d624` — Removed `window-rule { match tiled-state=true … }` because niri 25.11 rejected it as unknown property. Cosmetic rule; safe to drop.
- **Not pushed yet.**

### System changes (non-git)
- `dms.service` (user unit) masked via `systemctl --user mask dms.service`. `Wants=dms.service` on `niri.service` is now a no-op. Rollback: `systemctl --user unmask dms.service`.
- Chezmoi apply has been run scoped per path (waybar, mako, niri, local/bin). A full `chezmoi apply` was previously blocked by a conflict on `dot_config/mango/config.conf`; we `--force`d that one path to resolve. No other conflicts remain.

### Verified clean
- `niri validate` against `~/.config/niri/config.kdl` → **config is valid**.
- All file-write tasks passed spec-compliance + code-quality subagent reviews.

## Pre-reboot checklist

The user needs `fuzzel`, `swaybg`, `blueman`, `network-manager-applet` installed. Two paths — can do both for belt-and-suspenders:

### Path A (fast, for immediate testing): rpm-ostree layer

```bash
rpm-ostree install fuzzel swaybg blueman network-manager-applet
# reboot when prompted
```

Layer installs on top of current deployment. Active after reboot. Later, when the image catches up, remove the layers:

```bash
rpm-ostree uninstall fuzzel swaybg blueman network-manager-applet
```

### Path B (production, takes ~15-30 min of CI):

```bash
cd /var/home/chap/Projects/bluefin-tcl
git push
# wait for https://github.com/chaptastic/bluefin-tcl/actions to complete
rpm-ostree upgrade
# reboot when prompted
```

The workflow builds 3 matrix variants (`recipe-bluefin.yml`, `recipe-bazzite.yml`, `recipe-bazzite-mini.yml`). The user's current deployment is `ghcr.io/chaptastic/bazzite-mini-tcl:latest`.

**The user said "I'll rebuild and reboot" — they chose the CI path.** Confirm by checking `rpm-ostree status` shows a newer digest than `sha256:af3c76ef5ee75513fe4e93426c5d336bede6c937009c7bfb97e14b349538fa67` (the 2026-04-06 deployment).

## What's pending (for the next session)

### Task 5 — Visual verify waybar
After login to niri:
- Bar appears at top, 30px, slightly translucent.
- Left: workspace numbers, active one mauve-underlined. Window title italic, subtext1 color.
- Center: date + time in mauve bold (`Thu Apr 23 · 21:30` format).
- Right: idle, CPU, memory, pulseaudio (with icon), bluetooth, network, battery, tray.
- Icon glyphs (power, wifi, battery) must render — no tofu. PragmataPro should have Nerd Font glyphs.

Sanity: `pgrep -af waybar` should return exactly one process.

### Task 7 — Test mako notifications
```bash
notify-send "Test" "Normal notification"          # mauve border, 5s
notify-send -u low "Low" "Dim border, faster"     # overlay0 border, 3s
notify-send -u critical "Critical" "Sticky, red"  # red border, no auto-dismiss
makoctl dismiss                                    # dismiss the critical one
```

### Task 13 — Session smoke test
Check all background processes are up:
```bash
pgrep -af "waybar|mako|vicinae|blueman-applet|nm-applet|swaybg"
```
Expected: one process per name (vicinae shows as daemon, not "server").

Keybind tests:
- `Mod+space` → vicinae instant-open (daemon mode — no cold-start delay)
- `Super+X` → fuzzel powermenu. Test "Lock" option; log back in. **Do not** test Reboot/Shutdown/Log Out yet.
- `Mod+Alt+L` → swaylock directly.
- `Mod+N` → (send test notif first) dismisses it.
- `Ctrl+Alt+Delete` → gnome-system-monitor window.
- Click waybar bluetooth module → `blueman-manager` opens.
- Click waybar network module → `nm-connection-editor` opens.
- Click pulseaudio → mutes; right-click → `pavucontrol`.
- Media/volume/brightness keys behave (pre-existing — sanity only).

Wallpaper: Iron Giant should be on screen (swaybg).

### Task 14 — Sleep/resume stability
```bash
# Save any work first
systemctl suspend
# Wake, log back in. Verify waybar visible, clock current, mako responsive:
notify-send "Resume test" "from cycle N"
```
Repeat 3 times. Then scan logs:
```bash
journalctl --user -b | grep -iE "waybar|mako|coredump|segfault" | head -40
```
Expected: no `coredump` / `segfault` for waybar/mako.

### Task 15 — Push chezmoi
```bash
cd /home/chap/.local/share/chezmoi
git log --oneline -10   # review pending commits
git push
```
If remote rejects (diverged), stop and ask. Don't force-push.

### Task 16 — Push bluefin-tcl
If not already done as part of the rebuild path:
```bash
cd /var/home/chap/Projects/bluefin-tcl
git push
```

## Troubleshooting — things that might go wrong

### Waybar crashes or doesn't appear
- Check logs: `journalctl --user -b _COMM=waybar -n 50` (niri `spawn-at-startup` sends output to user journal).
- Run manually to see full output: `pkill -x waybar; waybar 2>&1 | head -40`.
- If `niri/workspaces` or `niri/window` module is unknown, waybar is too old. Current install is 0.14.0 which is fine. If for some reason it drops back to pre-0.10.4, fall back to the `custom/` module pattern in the plan's Task 5, Step 6.

### Mako doesn't show notifications
- `systemctl --user restart mako` (if there's a user service) or `pkill -x mako; mako &`.
- `makoctl history` to see if notifications were received but not displayed.
- Check `~/.config/mako/config` exists — `ls -la ~/.config/mako/`.

### Fuzzel powermenu doesn't work
- `which fuzzel` — confirm installed.
- `which niri-powermenu` — should be `~/.local/bin/niri-powermenu`.
- Run `niri-powermenu` directly from terminal to see any error.
- `bash -x ~/.local/bin/niri-powermenu` to trace execution.

### Iron Giant wallpaper doesn't show
- Confirm file exists: `ls -la "/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png"`.
- `pgrep -af swaybg` — should show the process with the image path.
- Run manually: `swaybg -i "/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png" -m fill`.

### Bluetooth/network tray icons missing
- `pgrep -af "blueman-applet|nm-applet"` — should show both.
- Some trays need waybar's tray module to have loaded first. If icons never appear, try `systemctl --user restart xdg-desktop-portal` then relaunch the applets.
- Check `blueman`/`network-manager-applet` packages are actually installed: `rpm -q blueman network-manager-applet`.

### Niri fails to load config
- `niri validate` should say "config is valid". If not, read the error.
- **We already fixed the known `tiled-state` issue.** If a new error appears, the user may have had other unanticipated working-tree changes.
- Worst-case rollback: `systemctl --user unmask dms.service` + `systemctl --user start dms.service` to get back to the DMS-driven shell temporarily.

### DMS keeps starting anyway
- `systemctl --user is-enabled dms.service` → must say `masked`.
- If somehow it's running: `systemctl --user stop dms.service; systemctl --user mask dms.service`.

### Something else broke and you need emergency rollback
- Chezmoi commits: `cd ~/.local/share/chezmoi; git log --oneline` — revert whichever commit with `git revert <sha>` and `chezmoi apply` scoped to the affected path.
- Niri config only: `chezmoi apply ~/.config/niri/config.kdl` against a rolled-back source.
- Last-resort: `cd ~/.local/share/chezmoi; git checkout 51c7053 -- dot_config/niri/config.kdl` to revert niri config to initial-commit state (don't actually do this without reading it first).

## Open concerns (non-blocking)

- **Chezmoi conflict on `dot_config/mango/config.conf`** — pre-existing. We `--force`d mango but only the mango path; no other conflicts. User mentioned they're planning a mangowm config pass next, so this self-resolves.
- **Task 9 commit message scope** — commit `a0d0067`'s message says "Add niri keybinds…" but actually bundles a config refactor. User accepted as-is; noted here for record.
- **Vicinae subcommand form** — spec says `vicinae server` (daemon) and `vicinae toggle` (client). Existing niri binds already use `vicinae toggle` without issue. `vicinae server` is untested until niri launches it at startup. If vicinae doesn't come up, check actual subcommand names: `vicinae --help`.
- **Wallpaper path portability** — hardcoded `/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png`. Fine for this user; would need chezmoi templating for multi-host.

## Success criteria (from spec)

- [x] waybar + mako configs shipped
- [x] fuzzel-based powermenu script shipped
- [x] Niri keybinds bound to standard CLI tools
- [x] Niri startup spawns wired for daemon + applets + wallpaper
- [x] `dms/` subdir removed
- [x] `dms.service` masked
- [x] `niri validate` passes
- [ ] Bar and notifications appear on niri login
- [ ] All modules visibly work
- [ ] PragmataPro icons render
- [ ] Theme harmonizes with Iron Giant
- [ ] Keybinds trigger expected actions
- [ ] Vicinae instant via daemon
- [ ] No crashes across 3 sleep/resume cycles
- [ ] All changes committed AND pushed (pushes still pending)

## Quick resume commands for next session

```bash
# Where are we?
cd /home/chap/.local/share/chezmoi && git log --oneline -7
cd /var/home/chap/Projects/bluefin-tcl && git log --oneline -3

# Is the new image deployed?
rpm-ostree status | head -10

# Are the packages present now?
rpm -q fuzzel swaybg blueman network-manager-applet

# Is DMS still masked?
systemctl --user is-enabled dms.service

# Are the right processes running in the new niri session?
pgrep -af "waybar|mako|vicinae|blueman-applet|nm-applet|swaybg"

# Niri config still valid?
niri validate
```

If all of those look right, proceed with Tasks 5, 7, 13, 14, 15, 16 from the plan.
