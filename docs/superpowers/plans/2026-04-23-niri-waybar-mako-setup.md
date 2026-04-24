# Niri Waybar + Mako Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace DankMaterialShell with a stable waybar + mako desktop bar/notifications stack on niri, themed Catppuccin Mocha, with a fuzzel-based power menu and the user's muscle-memory keybinds preserved via standard CLI tools.

**Architecture:** Two-repo deploy. Package installs land in the bluebuild recipe (`bluefin-tcl`); config files land in chezmoi dotfiles (`/home/chap/.local/share/chezmoi/`). Waybar/mako styled through a shared Catppuccin Mocha palette file for single-point palette swaps. Niri's existing `config.kdl` already uses direct CLI tools for media/volume/brightness and routes `Mod+space` to vicinae; this plan adds the missing keybinds (`Super+X`, `Mod+Alt+L`, `Mod+N`, `Ctrl+Alt+Del`) and startup spawns (`vicinae server`, `blueman-applet`, `nm-applet`, `swaybg`), then deletes the stale `dms/` subdirectory.

**Tech Stack:** waybar, mako, fuzzel, swaybg, swaylock, blueman, network-manager-applet, niri, vicinae, bash, chezmoi, bluebuild (YAML recipe).

**Spec:** `docs/superpowers/specs/2026-04-23-niri-waybar-mako-setup-design.md`

---

## File Structure

**bluefin-tcl repo** (`/var/home/chap/Projects/bluefin-tcl/`):
- `recipes/recipe-bazzite-mini.yml` — add 4 packages to the dnf install list

**chezmoi repo** (`/home/chap/.local/share/chezmoi/`):
- `dot_config/waybar/mocha.css` — new, Catppuccin Mocha palette variables
- `dot_config/waybar/config.jsonc` — replace, module layout + behavior
- `dot_config/waybar/style.css` — replace, references mocha palette
- `dot_config/mako/config` — new (new directory)
- `dot_config/niri/config.kdl` — add 4 keybinds and 4 spawn-at-startup entries
- `dot_config/niri/dms/` — delete entirely (stale DMS-regenerated duplicates)
- `dot_local/bin/executable_niri-powermenu` — new, fuzzel-based bash script

---

## Task 1: Add required packages to the bluebuild recipe

**Files:**
- Modify: `recipes/recipe-bazzite-mini.yml`

**Context:** The recipe already has `waybar`, `mako`, `swaylock`, and `vicinae`. We need to add four more to support the new setup.

- [ ] **Step 1: Inspect the current package block**

Run: `grep -n -B1 -A30 "^        packages:$" recipes/recipe-bazzite-mini.yml | head -80`

Find the block under `- type: rpm-ostree` → `install:` → `packages:` that lists packages like `waybar`, `mako`, `swaylock`. The new entries go in that same flat list.

- [ ] **Step 2: Add the four packages**

Using the `Edit` tool, find an existing entry like `- swaylock` and add immediately after it:

```yaml
        - fuzzel
        - swaybg
        - blueman
        - network-manager-applet
```

Match the indentation of neighboring package lines exactly (the recipe uses 8-space indent for list items under `packages:`).

- [ ] **Step 3: Verify the YAML still parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('recipes/recipe-bazzite-mini.yml'))" && echo OK`

Expected output: `OK`

- [ ] **Step 4: Verify the packages are present**

Run: `grep -E "^\s+- (fuzzel|swaybg|blueman|network-manager-applet)$" recipes/recipe-bazzite-mini.yml`

Expected: four lines, one per package.

- [ ] **Step 5: Commit**

```bash
git add recipes/recipe-bazzite-mini.yml
git commit -m "Add fuzzel, swaybg, blueman, network-manager-applet to mini recipe

These back the new niri waybar + mako setup replacing DMS."
```

---

## Task 2: Write the Catppuccin Mocha palette file

**Files:**
- Create: `/home/chap/.local/share/chezmoi/dot_config/waybar/mocha.css`

**Context:** Central palette file used by both `style.css` directly and referenced conceptually by the mako config (mako gets literal hex values since it doesn't do @define-color). Swapping to Macchiato/Latte later is a one-file change here.

- [ ] **Step 1: Create the palette file**

Using `Write`, create `/home/chap/.local/share/chezmoi/dot_config/waybar/mocha.css` with:

```css
/* Catppuccin Mocha palette — https://github.com/catppuccin/waybar */
@define-color rosewater #f5e0dc;
@define-color flamingo  #f2cdcd;
@define-color pink      #f5c2e7;
@define-color mauve     #cba6f7;
@define-color red       #f38ba8;
@define-color maroon    #eba0ac;
@define-color peach     #fab387;
@define-color yellow    #f9e2af;
@define-color green     #a6e3a1;
@define-color teal      #94e2d5;
@define-color sky       #89dceb;
@define-color sapphire  #74c7ec;
@define-color blue      #89b4fa;
@define-color lavender  #b4befe;
@define-color text      #cdd6f4;
@define-color subtext1  #bac2de;
@define-color subtext0  #a6adc8;
@define-color overlay2  #9399b2;
@define-color overlay1  #7f849c;
@define-color overlay0  #6c7086;
@define-color surface2  #585b70;
@define-color surface1  #45475a;
@define-color surface0  #313244;
@define-color base      #1e1e2e;
@define-color mantle    #181825;
@define-color crust     #11111b;
```

- [ ] **Step 2: Verify file exists and has 26 color definitions**

Run: `grep -c "^@define-color" /home/chap/.local/share/chezmoi/dot_config/waybar/mocha.css`

Expected: `26`

- [ ] **Step 3: Commit (staged later with config.jsonc and style.css)**

Hold this commit — Tasks 2, 3, 4 are all waybar files and will commit together in Task 4.

---

## Task 3: Write the waybar config.jsonc

**Files:**
- Replace: `/home/chap/.local/share/chezmoi/dot_config/waybar/config.jsonc`

**Context:** Defines bar geometry, module ordering, per-module behavior. JSONC (JSON with comments) is waybar's native format.

- [ ] **Step 1: Replace the config file**

Using `Write`, overwrite `/home/chap/.local/share/chezmoi/dot_config/waybar/config.jsonc` with:

```jsonc
// Niri top bar — Catppuccin Mocha
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "spacing": 4,
  "margin-top": 0,
  "margin-bottom": 0,

  "modules-left": [
    "niri/workspaces",
    "niri/window"
  ],

  "modules-center": [
    "clock"
  ],

  "modules-right": [
    "idle_inhibitor",
    "cpu",
    "memory",
    "pulseaudio",
    "bluetooth",
    "network",
    "battery",
    "tray"
  ],

  "niri/workspaces": {
    "format": "{index}",
    "format-icons": {
      "active": "",
      "default": ""
    }
  },

  "niri/window": {
    "format": "{title}",
    "max-length": 60,
    "separate-outputs": true
  },

  "clock": {
    "format": "{:%a %b %-d · %H:%M}",
    "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
  },

  "idle_inhibitor": {
    "format": "{icon}",
    "format-icons": {
      "activated": "",
      "deactivated": ""
    }
  },

  "cpu": {
    "format": " {usage}%",
    "interval": 2,
    "tooltip": true
  },

  "memory": {
    "format": " {percentage}%",
    "interval": 2,
    "tooltip-format": "{used:0.1f}G / {total:0.1f}G"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": " muted",
    "format-icons": {
      "headphone": "",
      "default": ["", "", ""]
    },
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-click-right": "pavucontrol",
    "scroll-step": 3
  },

  "bluetooth": {
    "format": "",
    "format-disabled": "󰂲",
    "format-connected": " {num_connections}",
    "tooltip-format": "{controller_alias}\n{num_connections} connected",
    "tooltip-format-connected": "{controller_alias}\n{num_connections} connected\n\n{device_enumerate}",
    "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
    "on-click": "blueman-manager"
  },

  "network": {
    "format-wifi": " {signalStrength}%",
    "format-ethernet": "󰈀",
    "format-disconnected": "󰖪",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ipaddr}",
    "tooltip-format-ethernet": "{ifname}\n{ipaddr}",
    "on-click": "nm-connection-editor"
  },

  "battery": {
    "states": {
      "warning": 20,
      "critical": 10
    },
    "format": "{icon} {capacity}%",
    "format-charging": " {capacity}%",
    "format-plugged": " {capacity}%",
    "format-icons": ["", "", "", "", ""]
  },

  "tray": {
    "icon-size": 16,
    "spacing": 10
  }
}
```

- [ ] **Step 2: Verify valid JSON (ignoring // comments)**

Run:
```bash
sed 's|//.*||' /home/chap/.local/share/chezmoi/dot_config/waybar/config.jsonc | python3 -c "import sys, json; json.load(sys.stdin)" && echo OK
```

Expected: `OK`

(The `sed` strips `//` line comments; waybar accepts JSONC but `json.load` does not.)

- [ ] **Step 3: Verify all 12 modules are declared**

Run:
```bash
python3 -c "
import json, re
data = json.loads(re.sub(r'//.*', '', open('/home/chap/.local/share/chezmoi/dot_config/waybar/config.jsonc').read()))
all_mods = set(data['modules-left'] + data['modules-center'] + data['modules-right'])
needed = {'niri/workspaces','niri/window','clock','idle_inhibitor','cpu','memory','pulseaudio','bluetooth','network','battery','tray'}
missing = needed - all_mods
print('OK' if not missing else f'MISSING: {missing}')
"
```

Expected: `OK`

---

## Task 4: Write the waybar style.css

**Files:**
- Replace: `/home/chap/.local/share/chezmoi/dot_config/waybar/style.css`

**Context:** GTK3 CSS. Uses the Mocha palette via `@import`. Hand-tuned sizes to address "weird sizing" complaint from brainstorming.

- [ ] **Step 1: Replace the stylesheet**

Using `Write`, overwrite `/home/chap/.local/share/chezmoi/dot_config/waybar/style.css` with:

```css
@import "mocha.css";

* {
  font-family: "PragmataPro", "PragmataPro Mono Liga", monospace;
  font-size: 11pt;
  min-height: 0;
  border: none;
  border-radius: 0;
}

window#waybar {
  background-color: alpha(@base, 0.92);
  color: @text;
  border-bottom: 1px solid @surface0;
  transition: background-color 0.3s ease-in-out;
}

window#waybar.hidden {
  opacity: 0.2;
}

tooltip {
  background: @mantle;
  border: 1px solid @mauve;
  border-radius: 6px;
}

tooltip label {
  color: @text;
  padding: 4px 8px;
}

/* Module common */
#workspaces,
#window,
#clock,
#idle_inhibitor,
#cpu,
#memory,
#pulseaudio,
#bluetooth,
#network,
#battery,
#tray {
  padding: 0 8px;
  margin: 0 2px;
  color: @text;
}

/* Workspaces */
#workspaces button {
  padding: 0 6px;
  color: @subtext1;
  background: transparent;
  border-bottom: 2px solid transparent;
}

#workspaces button.active {
  color: @text;
  border-bottom: 2px solid @mauve;
}

#workspaces button.urgent {
  color: @red;
  border-bottom: 2px solid @red;
}

#workspaces button:hover {
  background: @surface0;
  box-shadow: none;
  text-shadow: none;
}

/* Window title */
#window {
  color: @subtext1;
  font-style: italic;
}

/* Clock gets mauve tint */
#clock {
  color: @mauve;
  font-weight: bold;
}

/* Idle inhibitor on/off states */
#idle_inhibitor.activated {
  color: @mauve;
}

#idle_inhibitor.deactivated {
  color: @subtext1;
}

/* CPU / memory muted by default */
#cpu,
#memory {
  color: @subtext1;
}

/* Pulseaudio */
#pulseaudio.muted {
  color: @overlay0;
}

/* Bluetooth */
#bluetooth.disabled,
#bluetooth.off {
  color: @overlay0;
}

#bluetooth.connected {
  color: @blue;
}

/* Network */
#network.disconnected {
  color: @red;
}

#network.wifi {
  color: @text;
}

/* Battery states */
#battery.warning:not(.charging) {
  color: @yellow;
}

#battery.critical:not(.charging) {
  color: @red;
  animation: blink 1s steps(2) infinite;
}

#battery.charging,
#battery.plugged {
  color: @green;
}

@keyframes blink {
  to { color: @text; }
}

/* Tray */
#tray {
  padding: 0 6px;
}

#tray > .passive {
  -gtk-icon-effect: dim;
}

#tray > .needs-attention {
  -gtk-icon-effect: highlight;
}
```

- [ ] **Step 2: Verify palette variables are referenced, not hex literals**

Run:
```bash
grep -E "#[0-9a-fA-F]{3,6}" /home/chap/.local/share/chezmoi/dot_config/waybar/style.css
```

Expected: no matches. (All colors go through `@name` references from mocha.css.)

- [ ] **Step 3: Verify the mocha import is present**

Run: `head -1 /home/chap/.local/share/chezmoi/dot_config/waybar/style.css`

Expected: `@import "mocha.css";`

- [ ] **Step 4: Commit waybar files together**

```bash
cd /home/chap/.local/share/chezmoi
git add dot_config/waybar/mocha.css dot_config/waybar/config.jsonc dot_config/waybar/style.css
git commit -m "Replace waybar config with Catppuccin Mocha + niri modules

Adds Mocha palette as a separate @import-able file, rewrites config
with niri-native workspace/window modules and the full right-side
module set (cpu, memory, bluetooth, network, etc.), and restyles with
hand-tuned sizing (30px bar, 11pt PragmataPro)."
```

---

## Task 5: Deploy waybar via chezmoi and verify it launches

**Files:**
- Creates/updates: `~/.config/waybar/{mocha.css,config.jsonc,style.css}`

**Context:** First live test. If waybar doesn't start or rejects the config, this is where we catch it.

- [ ] **Step 1: Apply chezmoi**

Run: `chezmoi apply`

Expected: no errors. Check that the files landed:

```bash
ls -la ~/.config/waybar/
```

Expected: `config.jsonc`, `style.css`, `mocha.css` all present.

- [ ] **Step 2: Kill any existing waybar**

Run: `pkill -x waybar; sleep 1; pgrep -x waybar && echo "STILL RUNNING" || echo "stopped"`

Expected: `stopped`

- [ ] **Step 3: Launch waybar in the foreground to catch parse errors**

Run: `waybar 2>&1 | head -30`

Let it run for 5 seconds. Expected: no `Error` or `CRITICAL` lines. A few `[info]` lines about modules initializing is normal. Press `Ctrl+C` to stop.

If you see errors about unknown modules (e.g., `niri/workspaces` not recognized), skip to the fallback note at the end of this task.

- [ ] **Step 4: Launch waybar in the background**

Run: `waybar &>/dev/null & disown`

Then visually verify on screen:
- Bar appears at top, ~30px tall, slightly translucent.
- Left: workspace numbers, active one has a mauve underline. Focused window title visible.
- Center: date and time in mauve, e.g., `Thu Apr 23 · 21:30`.
- Right: icons for idle, CPU, memory, audio, bluetooth, network, battery, plus tray.

- [ ] **Step 5: Confirm PragmataPro rendered**

Check the bar's font — it should look like PragmataPro (narrow, monospace). Icon glyphs (power, wifi, battery) must render — no squares/tofu. If they're tofu, confirm PragmataPro is installed and has Nerd Font glyphs (the user has stated this is the case; if broken, escalate).

- [ ] **Step 6: (Fallback) If `niri/workspaces` or `niri/window` are unknown**

This means the packaged waybar is older than 0.10.4. Check version:

```bash
waybar --version
```

If fallback is needed, replace the two modules with custom scripts. Edit `~/.config/waybar/config.jsonc` and `~/.local/share/chezmoi/dot_config/waybar/config.jsonc` (keep them in sync) to swap:

```jsonc
  "modules-left": [
    "custom/niri-workspaces",
    "custom/niri-window"
  ],

  "custom/niri-workspaces": {
    "exec": "niri msg --json event-stream | jq --unbuffered -rc 'select(.WorkspaceActivated) | .WorkspaceActivated.id'",
    "format": "{}",
    "restart-interval": 1
  },
  "custom/niri-window": {
    "exec": "niri msg --json event-stream | jq --unbuffered -rc 'select(.WindowFocusChanged) | .WindowFocusChanged.title // \"\"'",
    "format": "{}"
  }
```

If you hit this fallback, commit the change with message "Fall back to custom niri modules for older waybar". Otherwise skip.

---

## Task 6: Write the mako config

**Files:**
- Create: `/home/chap/.local/share/chezmoi/dot_config/mako/config`

**Context:** Mako uses INI-like syntax. Per-urgency sections use `[criteria]` headers. We use literal hex values here (mako doesn't support @define-color).

- [ ] **Step 1: Create the mako config**

Using `Write`, create `/home/chap/.local/share/chezmoi/dot_config/mako/config` with:

```ini
# Catppuccin Mocha — matches waybar mocha.css
font=PragmataPro 11
anchor=top-right
margin=10,10,10,10
padding=12
border-size=2
border-radius=6
default-timeout=5000
max-icon-size=48
max-visible=4
layer=overlay

background-color=#181825
text-color=#cdd6f4
border-color=#cba6f7
progress-color=over #585b70

[urgency=low]
border-color=#6c7086
default-timeout=3000

[urgency=normal]
border-color=#cba6f7

[urgency=critical]
border-color=#f38ba8
default-timeout=0
```

- [ ] **Step 2: Verify file exists and syntax looks right**

Run:
```bash
grep -c "^border-color=" /home/chap/.local/share/chezmoi/dot_config/mako/config
```

Expected: `4` (global + 3 urgency-scoped).

---

## Task 7: Deploy and test mako

- [ ] **Step 1: Apply chezmoi**

Run: `chezmoi apply && ls -la ~/.config/mako/`

Expected: `config` file present.

- [ ] **Step 2: Restart mako**

Run: `pkill -x mako; sleep 1; mako &>/dev/null & disown; sleep 1; pgrep -x mako`

Expected: a process ID (mako is running).

- [ ] **Step 3: Test normal notification**

Run: `notify-send "Test" "Mocha theming should be visible"`

Expected: notification appears top-right with dark background, mauve left border, 2px thick, PragmataPro font. Auto-dismisses after 5 seconds.

- [ ] **Step 4: Test low urgency (shorter timeout, dimmer border)**

Run: `notify-send -u low "Low urgency" "Dismisses faster, dimmer border"`

Expected: same look but overlay0 (gray) border; dismisses after 3 seconds.

- [ ] **Step 5: Test critical (sticky, red border)**

Run: `notify-send -u critical "Critical" "Should be sticky and red-bordered"`

Expected: red border; does NOT auto-dismiss. Dismiss manually:

```bash
makoctl dismiss
```

- [ ] **Step 6: Commit mako config**

```bash
cd /home/chap/.local/share/chezmoi
git add dot_config/mako/config
git commit -m "Add mako config with Catppuccin Mocha theming

Mauve border for normal, red for critical (sticky), overlay0 for low.
PragmataPro 11pt to match waybar. Anchor top-right with 10px margin to
clear the new waybar bar."
```

---

## Task 8: Write the niri-powermenu script

**Files:**
- Create: `/home/chap/.local/share/chezmoi/dot_local/bin/executable_niri-powermenu`

**Context:** Bash script invoked from the `Super+X` keybind. Chezmoi's `executable_` filename prefix makes the target file executable on apply.

- [ ] **Step 1: Create the script**

Using `Write`, create `/home/chap/.local/share/chezmoi/dot_local/bin/executable_niri-powermenu` with:

```bash
#!/usr/bin/env bash
# Power menu for niri — pick an action via fuzzel.
set -euo pipefail

choice=$(printf '%s\n' Lock Suspend Reboot Shutdown "Log Out" \
  | fuzzel --dmenu --prompt "Power » " --lines 5)

case "$choice" in
  Lock)      exec swaylock -f ;;
  Suspend)   exec systemctl suspend ;;
  Reboot)    exec systemctl reboot ;;
  Shutdown)  exec systemctl poweroff ;;
  "Log Out") exec niri msg action quit --skip-confirmation ;;
  "")        exit 0 ;;
  *)         printf 'Unknown choice: %q\n' "$choice" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Lint the script**

Run: `bash -n /home/chap/.local/share/chezmoi/dot_local/bin/executable_niri-powermenu && echo OK`

Expected: `OK`

- [ ] **Step 3: Apply chezmoi**

Run: `chezmoi apply && ls -la ~/.local/bin/niri-powermenu`

Expected: file is present and has `x` (executable) in its permissions.

- [ ] **Step 4: Dry-run the fuzzel prompt (manual)**

Run: `niri-powermenu`

Expected: fuzzel prompt appears with 5 options. Press `Escape` to dismiss without selecting anything — script should exit cleanly.

Do NOT select anything that would power off / reboot / log out yet. Lock is safe to test if desired.

- [ ] **Step 5: Commit**

```bash
cd /home/chap/.local/share/chezmoi
git add dot_local/bin/executable_niri-powermenu
git commit -m "Add niri-powermenu script

Fuzzel-based dmenu-style picker for Lock / Suspend / Reboot / Shutdown
/ Log Out. Bound to Super+X in the next commit."
```

---

## Task 9: Add the missing keybinds to niri config.kdl

**Files:**
- Modify: `/home/chap/.local/share/chezmoi/dot_config/niri/config.kdl`

**Context:** The main `config.kdl` (line 243–387) already has a `binds { … }` block with media/volume/brightness using `wpctl`/`playerctl`/`brightnessctl`, plus `Mod+space` → vicinae. We're adding four more binds that were previously in `dms/binds.kdl` but used DMS IPC.

- [ ] **Step 1: Find the anchor in the binds block**

Run:
```bash
grep -n "// Launchers" /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl
```

Expected: one line, approximately line 244.

- [ ] **Step 2: Insert the four new binds**

Using `Edit`, find:

```
    // Launchers
    Mod+space hotkey-overlay-title="Vicinae" { spawn "vicinae" "toggle"; }
```

Replace with:

```
    // Launchers
    Mod+space hotkey-overlay-title="Vicinae" { spawn "vicinae" "toggle"; }
    Super+X hotkey-overlay-title="Power Menu" { spawn "niri-powermenu"; }
    Mod+Alt+L hotkey-overlay-title="Lock Screen" { spawn "swaylock" "-f"; }
    Mod+N hotkey-overlay-title="Dismiss Notifications" { spawn "makoctl" "dismiss" "--all"; }
    Ctrl+Alt+Delete hotkey-overlay-title="Task Manager" { spawn "gnome-system-monitor"; }
```

- [ ] **Step 3: Validate the niri config**

Run: `niri validate --config /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl`

Expected: no output / exit code 0. If the command fails with a parse error, the edit above broke something — re-read the file and fix the affected region.

- [ ] **Step 4: Verify all four binds are present**

Run:
```bash
grep -E "Super\+X|Mod\+Alt\+L|Mod\+N |Ctrl\+Alt\+Delete" /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl
```

Expected: four matching lines.

---

## Task 10: Add the spawn-at-startup entries

**Files:**
- Modify: `/home/chap/.local/share/chezmoi/dot_config/niri/config.kdl`

**Context:** The config already has `spawn-at-startup "waybar"` and `spawn-at-startup "mako"` on lines 126–127. We add vicinae daemon, blueman-applet, nm-applet, and swaybg next to them.

- [ ] **Step 1: Find the anchor**

Run:
```bash
grep -n "// Startup processes" /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl
```

Expected: one line, approximately line 125.

- [ ] **Step 2: Expand the startup block**

Using `Edit`, find:

```
// Startup processes
spawn-at-startup "waybar"
spawn-at-startup "mako"
```

Replace with:

```
// Startup processes
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "vicinae" "server"
spawn-at-startup "blueman-applet"
spawn-at-startup "nm-applet" "--indicator"
spawn-at-startup "swaybg" "-i" "/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png" "-m" "fill"
```

- [ ] **Step 3: Validate**

Run: `niri validate --config /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl`

Expected: exit code 0.

- [ ] **Step 4: Verify the wallpaper path**

Run: `ls -la "/var/home/chap/wallpapers/Day-to-Day/Iron Giant - Night.png"`

Expected: file exists. If it's missing or the path is wrong, ask the user before proceeding — don't silently change the path.

- [ ] **Step 5: Apply and commit**

Run: `chezmoi apply`

Then:

```bash
cd /home/chap/.local/share/chezmoi
git add dot_config/niri/config.kdl
git commit -m "Add niri keybinds and startup spawns for new shell stack

Binds: Super+X (powermenu), Mod+Alt+L (swaylock), Mod+N (makoctl
dismiss), Ctrl+Alt+Delete (gnome-system-monitor).

Startup: vicinae daemon, blueman-applet, nm-applet, swaybg with Iron
Giant wallpaper."
```

---

## Task 11: Delete the stale dms/ subdirectory

**Files:**
- Delete: `/home/chap/.local/share/chezmoi/dot_config/niri/dms/` (recursively)

**Context:** The dms/ subdir holds DMS-regenerated duplicates of colors, layout, outputs, windowrules, etc. The main config.kdl does NOT `include` them — they are dead files. All substantive content (keybinds, outputs, colors, window rules) is already in the main config.

- [ ] **Step 1: Confirm the main config does not include dms/ files**

Run:
```bash
grep -n "include" /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl
```

Expected: no output or only unrelated matches. (Niri uses `include "…"` to pull in subfiles. If any `include "dms/…"` appears, STOP and surface this — the plan's assumption is wrong and we need to port content first.)

- [ ] **Step 2: List what's getting deleted**

Run:
```bash
ls -la /home/chap/.local/share/chezmoi/dot_config/niri/dms/
```

Expected: 7 or 8 .kdl files. Confirm this matches what we expect (alttab, binds, colors, empty_cursor, layout, outputs, windowrules, wpblur).

- [ ] **Step 3: Delete the subdirectory**

Run:
```bash
rm -rf /home/chap/.local/share/chezmoi/dot_config/niri/dms/
```

Expected: no output.

- [ ] **Step 4: Confirm the main config still validates**

Run: `niri validate --config /home/chap/.local/share/chezmoi/dot_config/niri/config.kdl`

Expected: exit code 0.

- [ ] **Step 5: Apply and verify target also empty**

Run:
```bash
chezmoi apply
ls -la ~/.config/niri/dms/ 2>&1
```

Expected: `No such file or directory`. (Chezmoi removes managed files that no longer exist in source.)

If `~/.config/niri/dms/` still exists because chezmoi doesn't prune unmanaged directories, remove it manually:

```bash
rm -rf ~/.config/niri/dms/
```

- [ ] **Step 6: Commit**

```bash
cd /home/chap/.local/share/chezmoi
git add -A dot_config/niri/
git commit -m "Remove stale DMS-regenerated niri subconfigs

The dms/ subdirectory held auto-regenerated duplicates of colors,
layout, outputs, and windowrules that the main config.kdl did not
include. Main config already has equivalent settings."
```

---

## Task 12: Disable DMS via systemd user unit masking

**Files:**
- Possibly creates: symlink at `~/.config/systemd/user/dms.service` (via mask)

**Context:** The user has confirmed that DMS is launched via a systemd `Wants=` directive on the niri service. The cleanest fix is to **mask** the DMS user service — this creates a symlink to `/dev/null` so the service can never start, even when pulled in by `Wants=`. Masking is reversible (`systemctl --user unmask`).

- [ ] **Step 1: Identify the DMS unit name**

Run:
```bash
systemctl --user list-unit-files --no-pager 2>&1 | grep -iE "dms|dankshell|dankmaterial"
```

Expected: one or more unit names — typically `dms.service`. Note the exact name; subsequent steps use `<dms-unit>` as a placeholder.

If multiple DMS-related units appear (e.g., `dms.service` + `dms-greeter.service`), mask them all.

- [ ] **Step 2: Confirm it's pulled in by niri.service**

Run:
```bash
systemctl --user show niri.service --property=Wants --property=Requires 2>&1
systemctl --user list-dependencies niri.service 2>&1 | grep -i dms
```

Expected: DMS unit appears in the `Wants=` list or dependency tree. If it doesn't, the launch mechanism is different from what the user described — surface this and stop before masking.

- [ ] **Step 3: Stop the currently running DMS**

Run:
```bash
systemctl --user stop <dms-unit>
pgrep -af "^dms\b|dankshell|quickshell.*dms" 2>&1
```

Expected: no DMS processes remaining.

- [ ] **Step 4: Mask the unit**

Run:
```bash
systemctl --user mask <dms-unit>
```

Expected: output like `Created symlink /home/chap/.config/systemd/user/<dms-unit> → /dev/null.`

- [ ] **Step 5: Confirm the mask is in effect**

Run:
```bash
systemctl --user is-enabled <dms-unit>
```

Expected: `masked`

Then verify the niri service no longer pulls DMS in:

```bash
systemctl --user list-dependencies niri.service 2>&1 | grep -i dms
```

Expected: DMS line shows as `masked` or is absent.

- [ ] **Step 6: Document**

Record the exact unit name(s) masked, in case the user wants to reverse this later with `systemctl --user unmask <dms-unit>`.

**Rollback:** `systemctl --user unmask <dms-unit> && systemctl --user start <dms-unit>`. The mask only applies at the user level; the package remains installed.

---

## Task 13: Full session smoke test

**Files:** none — this is a runtime verification task.

**Context:** End-to-end check that the new setup actually works in a fresh niri session.

- [ ] **Step 1: Log out of niri**

Either via the power menu (`Super+X` → `Log Out`) if it's working, or manually: `niri msg action quit --skip-confirmation`.

Log back in.

- [ ] **Step 2: Visual inventory**

After login, confirm:
- Waybar appears at top with all modules.
- Iron Giant wallpaper is visible (swaybg worked).
- Bluetooth and network applet icons appear in the waybar tray.

Check background processes:

```bash
pgrep -af "waybar|mako|vicinae|blueman-applet|nm-applet|swaybg"
```

Expected: one process per name.

- [ ] **Step 3: Test launcher keybind**

Press `Mod+space`. Expected: vicinae opens instantly (daemon mode — no cold-start delay).

- [ ] **Step 4: Test the new keybinds**

- `Mod+N` — send a test notification first (`notify-send test hi`), then press `Mod+N`. Expected: notification dismissed.
- `Ctrl+Alt+Delete` — gnome-system-monitor window opens.
- `Mod+Alt+L` — swaylock takes over. Log back in with password. Confirm nothing broke.
- `Super+X` — powermenu appears. Pick `Lock` to verify the script. Do NOT pick reboot/shutdown yet.

- [ ] **Step 5: Test waybar click targets**

- Click the bluetooth module → `blueman-manager` opens.
- Click the network module → `nm-connection-editor` opens.
- Click pulseaudio → mutes. Right-click → `pavucontrol` opens.

- [ ] **Step 6: Test media/volume/brightness keys**

If on a laptop keyboard with those keys: verify each still works. (These bindings haven't changed — sanity check only.)

---

## Task 14: Sleep/resume stability test

**Context:** The original motivation. Verify the new stack survives suspend/resume cycles, unlike DMS.

- [ ] **Step 1: Save your work**

Close or save anything important before triggering suspend.

- [ ] **Step 2: Sleep/resume cycle 1**

Run: `systemctl suspend`

Wake the machine. Log back in if locked. Verify:
- Waybar still visible and responsive.
- Clock shows current time.
- Mako responds to `notify-send test`.

- [ ] **Step 3: Sleep/resume cycle 2**

Repeat. Same checks.

- [ ] **Step 4: Sleep/resume cycle 3**

Repeat. Same checks.

- [ ] **Step 5: Check logs for crashes**

Run:
```bash
journalctl --user -b -u "*" | grep -iE "waybar|mako|coredump|segfault" | head -40
```

Expected: no `coredump` or `segfault` entries for waybar/mako. Informational log lines are fine.

If any crash is found, capture output and surface to user — the spec flagged this as the critical test.

---

## Task 15: Final chezmoi push

**Files:** none new — just pushing the accumulated commits.

- [ ] **Step 1: Review pending commits**

```bash
cd /home/chap/.local/share/chezmoi
git log --oneline -10
```

Expected to see (approximately): powermenu script, niri bind additions, niri startup additions, dms/ removal, mako config, waybar files.

- [ ] **Step 2: Push to the chezmoi remote**

Run: `git push`

Expected: success. If the remote rejects (e.g., diverged), stop and ask the user — don't force-push.

---

## Task 16: Push bluefin-tcl recipe change

**Files:** none new.

- [ ] **Step 1: Review the bluefin-tcl commit**

```bash
cd /var/home/chap/Projects/bluefin-tcl
git log --oneline -5
```

Expected: the "Add fuzzel, swaybg, blueman, network-manager-applet" commit at the top, plus earlier spec/plan commits.

- [ ] **Step 2: Push**

Run: `git push`

Expected: success. Image rebuild is user-triggered; this plan does not invoke it.

- [ ] **Step 3: Report completion to user**

Summarize for the user:
- All chezmoi commits pushed.
- Recipe change pushed; next image rebuild will pick up the four new packages.
- DMS package is still installed (rollback preserved); removing it from the recipe is a separate follow-up.
- Note any unresolved findings from Task 12 (DMS autostart source).
