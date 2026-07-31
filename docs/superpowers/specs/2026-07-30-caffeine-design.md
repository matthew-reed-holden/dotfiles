# Caffeine — idle inhibitor with waybar module

**Date:** 2026-07-30
**Host:** shadowfax (Arch + Hyprland)
**Status:** approved, ready for implementation plan

A mac-`caffeinate` equivalent for Hyprland: keep the system awake on demand,
driven from a rofi menu and surfaced as a coffee-cup indicator in waybar.

## Goals

- Prevent idle lock, DPMS blank, and suspend for a chosen span.
- Drive it from a waybar module that mirrors the existing power button:
  left click opens a rofi menu, right click is the quick action.
- Show state at a glance: empty cup when idle, full cup when caffeinated.
- Work from the shell too, without a second code path.

## Non-goals

- No daemon, no background poller, no persistent state file.
- No "keep awake while audio plays" detection. Add later if manual
  caffeinating for video becomes a habit.
- No reason/why prompt. The label is derived from the mode.

## Mechanism

A single transient systemd user unit named `caffeine.service` wraps
`systemd-inhibit`:

```sh
systemd-run --user --unit=caffeine \
  --description="<mode>|<end_epoch>|<label>" \
  --property=CollectMode=inactive-or-failed \
  --property=ExecStopPost="/usr/bin/bash <script> _stopped" \
  systemd-inhibit --what=idle:sleep --who=caffeine --why="<label>" \
  <holder>
```

`ExecStopPost` invokes the script through an explicit `bash` rather than
running it directly, so the mode of the source file is irrelevant. Repo
convention keeps scripts at 644 and lets `home.file` set `executable = true`
at install time; a direct `ExecStopPost=<script>` on a 644 file fails the
whole start job.

There is no matching `ExecStartPost`. During `ExecStartPost` the unit is
still `activating`, so a hook that gates on `is-active` sees "not
caffeinated" and does nothing. The start-side notification and waybar signal
therefore run client-side, immediately after `systemd-run` returns — which
it does only once the start job has completed and the unit reports `active`.

`<holder>` is the only thing that varies by mode — it is the process whose
lifetime defines the caffeinated span:

| Mode        | Holder                          |
| ----------- | ------------------------------- |
| indefinite  | `sleep infinity`                |
| for / until | `sleep <seconds>`               |
| while app   | `tail --pid=<pid> -f /dev/null` |
| while cmd   | `tail --pid=<pid> -f /dev/null` |

`while <cmd>` runs the command in the caller's own shell and points the
holder at its PID, rather than running the command inside the unit. The
command keeps the caller's terminal and exit code, waybar repaints
immediately instead of at command exit, and both `while` variants collapse
to one holder shape.

### Why this shape

`--what=idle:sleep` covers both halves of the ask. hypridle honors logind
idle inhibitors — its `ignore_systemd_inhibit` defaults to false — so the
lock and DPMS listeners in `hypr/hypridle.conf` stop firing. The `sleep`
component blocks `systemctl suspend`, which is inert on this desktop but
makes the script portable to a laptop unchanged.

The unit is the single source of truth. Liveness is
`systemctl --user show -P ActiveState caffeine`; the details live in its
`Description`. There is no pidfile and no state file to drift out of sync.
When the holder exits the unit exits, the inhibitor is released, and
`CollectMode=inactive-or-failed` garbage-collects the unit even if it
failed. Expiry, manual stop, and menu-driven stop all arrive at the same
`ExecStopPost` hook, so one code path handles the release notification and
waybar repaint no matter what ended the span.

Verified live on shadowfax: the unit starts, `systemd-inhibit --list`
reports `caffeine ... sleep:idle ... block`, `Description` round-trips, and
`systemctl --user stop` leaves no residue.

### Description encoding

`Description` is `<mode>|<end_epoch>|<label>`:

- `on|0|indefinite`
- `for|1753999999|until 17:00`
- `while|0|firefox`

`end_epoch` is `0` when there is no deadline. Timed modes carry the absolute
wall-clock end, so the countdown is computed at read time and needs no ticking
state.

## CLI surface

One script at `~/.local/bin/caffeine.sh`. The menu is the no-arg default, so
the shell interface costs nothing extra.

```
caffeine.sh                      # rofi menu (default)
caffeine.sh on                   # indefinite
caffeine.sh off
caffeine.sh toggle               # right-click binding
caffeine.sh for <timespan>       # 2h, 90min, 45s — systemd-analyze timespan
caffeine.sh until <time>         # 17:00, "tomorrow 9am" — date -d
caffeine.sh while <cmd...>       # caffeinated for the command's lifetime
caffeine.sh while --pid <pid>    # caffeinated until that PID exits
caffeine.sh status               # notification + one line on stdout
caffeine.sh waybar               # JSON for the module
caffeine.sh _stopped             # internal, ExecStopPost hook
caffeine.sh selftest             # assert round-trip
```

Starting while already active stops the existing unit first, then starts the
new one. State never stacks, and there is no "already caffeinated" error case
to handle.

`while <cmd>` backgrounds the command in the caller's shell, holds the lock
against its PID, waits for it, releases the lock, and exits with the
command's own status. The background job needs an explicit `<&0` — a
non-interactive bash otherwise redirects background stdin from `/dev/null`,
which would break any interactive command.

### Parsing and validation

- `for` delegates to `systemd-analyze timespan` for both validation and
  conversion to seconds.
- `until` delegates to `date -d`. A time that has already passed today rolls
  forward to tomorrow.
- A rejected value notifies with a short message, passes the parser's own
  error text through to stderr, and exits non-zero without touching the unit.

## Menu

`rofi -dmenu -i -p "Caffeine" -config ~/.config/rofi/config-compact.rasi`,
the same invocation `hypr/scripts/power-menu.sh` already uses.

The main menu is a fixed six entries. It does not branch on current state —
"Decaffeinate" while already off is a harmless no-op, and a stable menu
preserves muscle memory.

```
󰆓  Decaffeinate
󰅶  Caffeinate
󰥔  Caffeinate for…
󰅐  Caffeinate until…
󰄉  Caffeinate while…
󰋼  Status
```

Decaffeinate is listed first so the `*Decaffeinate` glob in the dispatch
`case` cannot be shadowed by the `*Caffeinate` one.

`rofi -dmenu` exits 1 when dismissed, so every menu capture needs `|| true`
under `set -e` or the script dies before its empty-selection guard runs.

Submenus:

- **for…** — `15m / 30m / 1h / 2h / 4h / 8h / Custom…`. `Custom…` opens a
  free-text rofi prompt.
- **until…** — `12:00 / 17:00 / 23:59 / Custom…`, same custom fallback.
- **while…** — open windows from `hyprctl clients -j | jq`, rendered as
  `class — title` and resolved to that window's PID, plus
  `Custom command…` at the bottom for the free-text branch.

Dismissing any menu or submenu (empty selection) exits without changing state.

All six glyphs exist in `Symbols Nerd Font Mono`. `config-compact.rasi` sets
`Work Sans 11` for list entries, so the icons render through pango's font
fallback rather than the declared family — the existing `power-menu.sh` is
text-only and does not exercise this. If fallback misses, drop the icons and
use bare labels, matching `power-menu.sh`.

## Waybar module

```jsonc
"custom/caffeine": {
    "format":         "{}",
    "return-type":    "json",
    "exec":           "~/.local/bin/caffeine.sh waybar",
    "interval":       15,
    "signal":         8,
    "on-click":       "~/.local/bin/caffeine.sh",
    "on-click-right": "~/.local/bin/caffeine.sh toggle"
}
```

`interval: 15` advances the countdown. `signal: 8` (RTMIN+8) gives an instant
repaint on every state change — the script fires `pkill -RTMIN+8 waybar`
after starting a unit and again inside `_stopped`. No other module in
`config.jsonc` uses a signal.

Rendered states:

| State      | Text        | Class    |
| ---------- | ----------- | -------- |
| off        | `󰆓`         | `idle`   |
| indefinite | `󰅶`         | `active` |
| timed      | `󰅶 1h42m`   | `active` |
| while app  | `󰅶 firefox` | `active` |

Icons are `nf-md-cup_outline` (U+F0193) for off and `nf-md-coffee` (U+F0176)
for on — a hollow cup with no steam becoming a filled cup with steam. Both
glyphs are present in `NotoSansM Nerd Font Mono`, the family `style.css`
already sets.

Countdown format: `1h42m` above an hour, `42m` under it, `<1m` in the final
minute.

The tooltip carries mode, label, and remaining time, then
`Left: menu  Right: toggle` — the same convention as `custom/exit`.

Placement in `modules-right`: between `custom/notification` and
`custom/exit`.

## Notifications

`notify-send` via swaync, which is already running:

- On start — `Caffeinated` with the derived label (`indefinite`,
  `until Thu 17:00`, `while firefox`). Fired client-side from `start()`,
  not from a unit hook.
- On stop or expiry — `Decaffeinated`, fired from `_stopped` so both paths
  are covered by one hook.
- On `status` — current mode, label, and remaining time; also echoed to
  stdout for shell use.

## Files

New:

- `home-manager/linux/hypr/scripts/caffeine.sh`

Edited:

- `home-manager/linux/waybar/config.jsonc` — module block, `modules-right` entry
- `home-manager/linux/waybar/style.css` — `#custom-caffeine` idle (`@outline`)
  and `.active` (`@tertiary`) rules, joining the existing
  `#custom-updates, #custom-notification, #custom-exit` pill block. The
  stylesheet uses M3 semantic color names, not raw catppuccin ones, because
  matugen regenerates `colors.css` on wallpaper change.
- `home-manager/linux/default.nix` — `home.file.".local/bin/caffeine.sh"`
  with `executable = true`, alongside the existing `power-menu.sh` entry
- `home-manager/linux/hypr/conf/keybindings.conf` — `SUPER SHIFT, C` opens the
  menu; no existing binding uses it
- `packages.txt` — add `libnotify`

## Packages

`libnotify` is the one addition, for `notify-send`. It is currently present
on shadowfax only as a transitive dependency, and this config would be the
first thing to reference the binary directly.

`systemd-inhibit`, `systemd-run`, `tail`, `jq`, `rofi-wayland`, and `hypridle`
are all installed and already listed.

The script follows the Linux packaging convention for this repo: pacman owns
every binary, home-manager only writes config and drops the script on `PATH`
via `home.file`.

## Testing

`caffeine.sh selftest` — one `assert`-based function run against real systemd,
no framework:

1. `for 30s` → unit is active, `systemd-inhibit --list` contains a
   `caffeine` entry with `sleep:idle`, and the computed remaining time lands
   in 25–31s.
2. `off` → unit is gone and the inhibitor is released.
3. `for banana` and `until banana` → non-zero exit, no unit created.

The rejection cases matter most: they are the only branches where a parse
failure could otherwise start a unit with a garbage deadline.

## Deferred

- "While audio or video plays" detection via PipeWire. It needs a polling
  loop, which is the first real complexity in this design. Add it if manual
  caffeinating before every video becomes routine.
- Per-mode units. One named unit covers every mode.
- A state file. The unit `Description` is the truth.
