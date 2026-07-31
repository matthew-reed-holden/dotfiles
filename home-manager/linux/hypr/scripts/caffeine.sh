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
    systemd-run --user --unit="$UNIT" \
        --description="$mode|$end|$label" \
        --property=CollectMode=inactive-or-failed \
        --property=ExecStopPost="/usr/bin/bash $SELF _stopped" \
        systemd-inhibit --what=idle:sleep --who=caffeine --why="$label" \
        "$@" >/dev/null
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

    echo "$fails failure(s)"
    return $(( fails > 0 ))
}

case "${1:-}" in
    on)       cmd_on ;;
    off)      cmd_off ;;
    toggle)   cmd_toggle ;;
    for)      shift; cmd_for   "${1:-}" ;;
    until)    shift; cmd_until "${1:-}" ;;
    _stopped) cmd_stopped ;;
    selftest) selftest ;;
    *)        echo "usage: caffeine.sh {on|off|toggle|for <span>|until <time>|selftest}" >&2; exit 2 ;;
esac
