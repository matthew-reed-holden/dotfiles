#!/usr/bin/env bash
# caffeine.sh — a mac-`caffeinate` equivalent for Hyprland.
#
# Holds a systemd-inhibit lock inside a transient user unit. The unit IS
# the state: liveness is its ActiveState, the details are encoded in its
# Description as "<mode>|<end_epoch>|<label>". When the holder process
# exits, the unit exits, the lock is released, and CollectMode garbage
# collects the unit.
#
# hypridle honours logind idle inhibitors (ignore_systemd_inhibit
# defaults to false), so --what=idle:sleep silences the lock and DPMS
# listeners in hypr/hypridle.conf as well as blocking suspend.
#
# Design: docs/superpowers/specs/2026-07-30-caffeine-design.md

set -euo pipefail

UNIT=caffeine
# Resolves to the repo checkout during development and to the home-manager
# symlink's store path once installed. Either way systemd can exec it.
SELF=$(readlink -f "${BASH_SOURCE[0]}")
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
WAYBAR_SIG=8

# ponytail: ephemeral coordination flag, not state. Suppresses the
# "Decaffeinated" toast when a start is merely replacing a running unit.
# The unit Description remains the only source of truth.
REPLACING="$RUNTIME/caffeine.replacing"

ICON_OFF=$'\U000F0193'   # nf-md-cup_outline — hollow cup, no steam
ICON_ON=$'\U000F0176'    # nf-md-coffee      — filled cup, steam

ROFI_CFG="$HOME/.config/rofi/config-compact.rasi"

active() { systemctl --user -q is-active "$UNIT.service" 2>/dev/null; }

# Sets $mode $end $label. Returns 1 when not caffeinated. The active()
# guard matters: systemd reports a synthetic Description equal to the unit
# name for units it has never seen, which would otherwise parse as garbage.
read_state() {
    active || return 1
    local d
    d=$(systemctl --user show -P Description "$UNIT.service" 2>/dev/null)
    IFS='|' read -r mode end label <<<"$d"
    [ -n "${mode:-}" ] && [ -n "${end:-}" ]
}

notify() {
    notify-send -a Caffeine \
        -h string:x-canonical-private-synchronous:caffeine \
        "$1" "${2:-}" 2>/dev/null || true
}

signal_waybar() { pkill "-RTMIN+$WAYBAR_SIG" waybar 2>/dev/null || true; }

# start <mode> <end_epoch> <label> <holder...>
#
# The hook runs through an explicit bash so the 644 source file works as an
# ExecStopPost target. systemd-run blocks until the start job completes, so
# by the time it returns the unit is active and the toast/signal below are
# safe — which is why there is no ExecStartPost counterpart.
start() {
    local mode=$1 end=$2 label=$3
    shift 3
    if active; then
        : >"$REPLACING"
        systemctl --user stop "$UNIT.service"
    fi
    # Report systemd-run's status rather than signal_waybar's. Callers that
    # test start (cmd_while does, to keep set -e from abandoning its forked
    # child) would otherwise always see success, because notify and
    # signal_waybar both end in `|| true` — and would announce
    # "Caffeinated" for a unit that never started.
    if ! systemd-run --user --unit="$UNIT" \
        --description="$mode|$end|$label" \
        --property=CollectMode=inactive-or-failed \
        --property=ExecStopPost="/usr/bin/bash $SELF _stopped" \
        systemd-inhibit --what=idle:sleep --who=caffeine --why="$label" \
        "$@" >/dev/null
    then
        return 1
    fi
    notify "Caffeinated" "$label"
    signal_waybar
}

cmd_on()  { start on 0 indefinite sleep infinity; }

cmd_off() {
    if active; then systemctl --user stop "$UNIT.service"; fi
}

cmd_toggle() {
    if active; then cmd_off; else cmd_on; fi
}

# Delegates both validation and conversion to systemd-analyze, which
# accepts "2h", "90min", "45s", "1h30m" and prints its own error text.
parse_timespan() {
    local out us
    if ! out=$(systemd-analyze timespan "$1" 2>&1); then
        printf '%s\n' "$out" >&2
        return 1
    fi
    us=$(awk '/μs:/{print $2}' <<<"$out")
    if [ -z "$us" ]; then
        echo "could not parse timespan '$1'" >&2
        return 1
    fi
    echo $(( us / 1000000 ))
}

cmd_for() {
    local secs
    if ! secs=$(parse_timespan "${1:-}"); then
        notify "Caffeine" "Bad duration: ${1:-}"
        return 1
    fi
    if [ "$secs" -le 0 ]; then
        notify "Caffeine" "Duration must be greater than zero"
        return 1
    fi
    start for "$(( $(date +%s) + secs ))" "for $1" sleep "$secs"
}

cmd_until() {
    local out target now
    # Capture rather than discard, so the parser's own message reaches
    # stderr — same contract as parse_timespan's.
    if ! out=$(date -d "${1:-}" +%s 2>&1); then
        printf '%s\n' "$out" >&2
        notify "Caffeine" "Bad time: ${1:-}"
        return 1
    fi
    target=$out
    now=$(date +%s)
    # ponytail: naive +1 day rollover, ignores DST. Fine for a wake lock;
    # switch to `date -d "tomorrow $1"` if an hour of drift ever matters.
    if [ "$target" -le "$now" ]; then target=$(( target + 86400 )); fi
    # Weekday in the label so a rolled-over or "tomorrow 9am" target does
    # not read identically to one later today.
    start until "$target" "until $(date -d "@$target" '+%a %H:%M')" \
          sleep $(( target - now ))
}

# Both variants collapse to the same holder: tail exits the instant the
# watched pid does, which releases the lock. Running the command in the
# caller's own shell (rather than inside the unit) keeps its terminal and
# its exit code, and lets waybar repaint immediately instead of at exit.
# CAFFEINE_LABEL overrides the derived label. The menu's custom-command
# branch sets it, because it invokes `bash -c "<cmd>"` and would otherwise
# label every custom command "bash".
cmd_while() {
    local pid rc=0
    if [ "${1:-}" = --pid ]; then
        pid=${2:-}
        if ! kill -0 "$pid" 2>/dev/null; then
            notify "Caffeine" "No such process: $pid"
            return 1
        fi
        start while 0 \
              "${CAFFEINE_LABEL:-$(ps -p "$pid" -o comm= 2>/dev/null || echo "pid $pid")}" \
              tail --pid="$pid" -f /dev/null
        return 0
    fi

    if [ $# -eq 0 ]; then
        echo "usage: caffeine.sh while <cmd...>" >&2
        return 1
    fi

    # <&0 is load-bearing: a non-interactive bash redirects a background
    # job's stdin from /dev/null, which would break any interactive command.
    "$@" <&0 &
    pid=$!
    # Testing start's status keeps set -e from killing the script here and
    # abandoning the child we just forked. The command is what the user
    # cares about; the lock is the accessory, so a failed lock warns rather
    # than taking the command down with it.
    if ! start while 0 "${CAFFEINE_LABEL:-$(basename "$1")}" \
              tail --pid="$pid" -f /dev/null; then
        echo "caffeine: lock failed, running uncaffeinated" >&2
    fi
    wait "$pid" || rc=$?
    cmd_off
    return "$rc"
}

fmt_remaining() {
    local s=$1 h m
    if [ "$s" -lt 60 ]; then echo "<1m"; return; fi
    h=$(( s / 3600 ))
    m=$(( (s % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then echo "${h}h${m}m"; else echo "${m}m"; fi
}

# jq builds the JSON so labels containing quotes, backslashes, or newlines
# cannot break waybar's parser.
cmd_waybar() {
    local text tip class left
    if read_state; then
        class=active
        case "$mode" in
            for|until)
                left=$(( end - $(date +%s) ))
                if [ "$left" -lt 0 ]; then left=0; fi
                text="$ICON_ON $(fmt_remaining "$left")"
                tip="Caffeinated $label — $(fmt_remaining "$left") left"
                ;;
            while)
                text="$ICON_ON $label"
                tip="Caffeinated while $label is running"
                ;;
            *)
                text="$ICON_ON"
                tip="Caffeinated — indefinite"
                ;;
        esac
    else
        class=idle
        text="$ICON_OFF"
        tip="Not caffeinated"
    fi
    jq -nc --arg t "$text" --arg c "$class" \
           --arg tip "$tip"$'\n'"Left: menu  Right: toggle" \
           '{text: $t, alt: $c, class: $c, tooltip: $tip}'
}

cmd_status() {
    local line left
    if read_state; then
        line="Caffeinated — $label"
        if [ "$end" != 0 ]; then
            left=$(( end - $(date +%s) ))
            if [ "$left" -lt 0 ]; then left=0; fi
            line="$line ($(fmt_remaining "$left") left)"
        fi
    else
        line="Not caffeinated"
    fi
    notify "Caffeine" "$line"
    echo "$line"
}

# ExecStopPost hook. Running the release side from systemd rather than the
# client means expiry, manual stop, and menu-driven stop all converge here.
cmd_stopped() {
    if [ -e "$REPLACING" ]; then
        rm -f "$REPLACING"
    else
        notify "Decaffeinated"
    fi
    signal_waybar
}

# Extra args are forwarded so menu_while can add -format i.
rofi_menu() {
    local prompt=$1; shift
    rofi -dmenu -i -p "$prompt" -config "$ROFI_CFG" "$@"
}

# Free-text prompt. Empty stdin means rofi has no list to match against, so
# it returns whatever was typed.
rofi_input() { rofi -dmenu -p "$1" -config "$ROFI_CFG" </dev/null; }

# Every rofi capture needs `|| true`: rofi -dmenu exits 1 when dismissed,
# which would otherwise kill the script through set -e before the guard
# below ever runs.
menu_for() {
    local c
    c=$(printf '15m\n30m\n1h\n2h\n4h\n8h\nCustom…\n' | rofi_menu "Caffeinate for") || true
    if [ -z "$c" ]; then return 0; fi
    if [ "$c" = "Custom…" ]; then c=$(rofi_input "Timespan (e.g. 90min)") || true; fi
    if [ -z "$c" ]; then return 0; fi
    cmd_for "$c"
}

menu_until() {
    local c
    c=$(printf '12:00\n17:00\n23:59\nCustom…\n' | rofi_menu "Caffeinate until") || true
    if [ -z "$c" ]; then return 0; fi
    if [ "$c" = "Custom…" ]; then c=$(rofi_input "Time (e.g. 17:00)") || true; fi
    if [ -z "$c" ]; then return 0; fi
    cmd_until "$c"
}

menu_while() {
    local rows=() idx cmd
    # No -u: single-process apps share one pid across all their windows, so
    # deduping on the label would hide real windows and buy nothing.
    mapfile -t rows < <(
        hyprctl clients -j \
            | jq -r '.[] | select(.pid > 0) | "\(.pid)\t\(.class) — \(.title)"' \
            | sort -t$'\t' -k2
    )
    rows+=($'0\tCustom command…')

    # -format i sidesteps having to smuggle the pid through rofi's output:
    # the index maps straight back into rows.
    idx=$(printf '%s\n' "${rows[@]}" | cut -f2- | rofi_menu "Caffeinate while" -format i) || return 0
    if [ -z "$idx" ] || [ "$idx" -lt 0 ]; then return 0; fi

    local pid=${rows[$idx]%%$'\t'*}
    if [ "$pid" = 0 ]; then
        cmd=$(rofi_input "Command") || true
        if [ -z "$cmd" ]; then return 0; fi
        CAFFEINE_LABEL="${cmd%% *}" cmd_while bash -c "$cmd"
    else
        cmd_while --pid "$pid"
    fi
}

menu() {
    local choice
    # Fixed six entries, deliberately not branching on current state — a
    # stable menu preserves muscle memory, and Decaffeinate while already
    # off is a no-op. Decaffeinate is listed first so its glob cannot be
    # shadowed by the Caffeinate pattern.
    choice=$(printf '%s\n' \
        "$ICON_OFF  Decaffeinate" \
        "$ICON_ON  Caffeinate" \
        $'\U000F0954  Caffeinate for…' \
        $'\U000F0150  Caffeinate until…' \
        $'\U000F0109  Caffeinate while…' \
        $'\U000F02FC  Status' \
        | rofi_menu Caffeine) || true
    case "$choice" in
        *Decaffeinate)        cmd_off ;;
        *"Caffeinate for…")   menu_for ;;
        *"Caffeinate until…") menu_until ;;
        *"Caffeinate while…") menu_while ;;
        *Status)              cmd_status ;;
        *Caffeinate)          cmd_on ;;
        *)                    return 0 ;;
    esac
}

selftest() {
    fails=0
    pass() { printf '  %-44s ok\n'   "$1"; }
    fail() { printf '  %-44s FAIL\n' "$1"; fails=$((fails+1)); }

    echo "caffeine selftest"

    cmd_off || true
    sleep 0.5
    if active; then fail "starts with no unit"; else pass "starts with no unit"; fi

    cmd_on
    sleep 0.5
    if active; then pass "on: unit active"; else fail "on: unit active"; fi
    if systemd-inhibit --list | grep -q 'caffeine.*sleep:idle'; then
        pass "on: inhibitor holds sleep:idle"
    else
        fail "on: inhibitor holds sleep:idle"
    fi
    if read_state && [ "$mode" = on ] && [ "$end" = 0 ]; then
        pass "on: description parses as on|0"
    else
        fail "on: description parses as on|0"
    fi

    cmd_off
    sleep 0.5
    if active; then fail "off: unit gone"; else pass "off: unit gone"; fi
    if systemd-inhibit --list | grep -q 'caffeine.*sleep:idle'; then
        fail "off: inhibitor released"
    else
        pass "off: inhibitor released"
    fi

    cmd_for 30s
    sleep 0.5
    if read_state && [ "$mode" = for ]; then
        pass "for: mode is for"
    else
        fail "for: mode is for"
    fi
    left=$(( end - $(date +%s) ))
    if [ "$left" -ge 25 ] && [ "$left" -le 31 ]; then
        pass "for 30s: end epoch lands in 25-31s"
    else
        fail "for 30s: end epoch lands in 25-31s (got $left)"
    fi
    cmd_off
    sleep 0.5

    if cmd_for banana 2>/dev/null; then
        fail "for: rejects unparseable timespan"
    else
        pass "for: rejects unparseable timespan"
    fi
    if active; then
        fail "for: rejected input starts no unit"
    else
        pass "for: rejected input starts no unit"
    fi

    if cmd_until banana 2>/dev/null; then
        fail "until: rejects unparseable time"
    else
        pass "until: rejects unparseable time"
    fi
    if active; then
        fail "until: rejected input starts no unit"
    else
        pass "until: rejected input starts no unit"
    fi

    cmd_until 23:59
    sleep 0.5
    if read_state && [ "$mode" = until ] && [ "$end" -gt "$(date +%s)" ]; then
        pass "until: end epoch is in the future"
    else
        fail "until: end epoch is in the future"
    fi
    cmd_off
    sleep 0.5

    sleep 5 &
    holdpid=$!
    cmd_while --pid "$holdpid"
    sleep 0.5
    if read_state && [ "$mode" = while ] && [ "$end" = 0 ]; then
        pass "while --pid: mode is while|0"
    else
        fail "while --pid: mode is while|0"
    fi
    kill "$holdpid" 2>/dev/null || true
    wait "$holdpid" 2>/dev/null || true
    sleep 1.5
    if active; then
        fail "while --pid: unit dies with the process"
    else
        pass "while --pid: unit dies with the process"
    fi

    # A pid that is guaranteed dead rather than a large number that might
    # happen to be live.
    true &
    deadpid=$!
    wait "$deadpid" 2>/dev/null || true
    if cmd_while --pid "$deadpid" 2>/dev/null; then
        fail "while --pid: rejects a dead pid"
    else
        pass "while --pid: rejects a dead pid"
    fi

    cmd_while sleep 2
    sleep 0.5
    if active; then
        fail "while <cmd>: releases when the command exits"
    else
        pass "while <cmd>: releases when the command exits"
    fi

    if [ "$(fmt_remaining 30)"   = "<1m"  ]; then pass "fmt: 30s"   ; else fail "fmt: 30s"   ; fi
    if [ "$(fmt_remaining 2520)" = "42m"  ]; then pass "fmt: 2520s" ; else fail "fmt: 2520s" ; fi
    if [ "$(fmt_remaining 6120)" = "1h42m" ]; then pass "fmt: 6120s"; else fail "fmt: 6120s"; fi

    cmd_off
    sleep 0.5
    if [ "$(cmd_waybar | jq -r .class)" = idle ]; then
        pass "waybar: idle class when off"
    else
        fail "waybar: idle class when off"
    fi
    if [ "$(cmd_waybar | jq -r .text)" = "$ICON_OFF" ]; then
        pass "waybar: hollow cup when off"
    else
        fail "waybar: hollow cup when off"
    fi

    cmd_for 1h
    sleep 0.5
    if [ "$(cmd_waybar | jq -r .class)" = active ]; then
        pass "waybar: active class when on"
    else
        fail "waybar: active class when on"
    fi
    if cmd_waybar | jq -e '.text | test("^\\S+ [0-9]+h?[0-9]*m$")' >/dev/null; then
        pass "waybar: timed text carries a countdown"
    else
        fail "waybar: timed text carries a countdown"
    fi
    if cmd_waybar | jq -e . >/dev/null; then
        pass "waybar: emits valid JSON"
    else
        fail "waybar: emits valid JSON"
    fi
    cmd_off
    sleep 0.5

    start while 0 'weird "quoted" label' sleep 5
    sleep 0.5
    if cmd_waybar | jq -e . >/dev/null; then
        pass "waybar: JSON survives quotes in the label"
    else
        fail "waybar: JSON survives quotes in the label"
    fi
    cmd_off
    sleep 0.5

    echo "$fails failure(s)"
    return $(( fails > 0 ))
}

case "${1:-menu}" in
    menu)     menu ;;
    on)       cmd_on ;;
    off)      cmd_off ;;
    toggle)   cmd_toggle ;;
    for)      shift; cmd_for   "${1:-}" ;;
    until)    shift; cmd_until "${1:-}" ;;
    while)    shift; cmd_while "$@" ;;
    status)   cmd_status ;;
    waybar)   cmd_waybar ;;
    _stopped) cmd_stopped ;;
    selftest) selftest ;;
    *)        echo "usage: caffeine.sh {on|off|toggle|for <span>|until <time>|while <cmd>|status|waybar|selftest}" >&2; exit 2 ;;
esac
