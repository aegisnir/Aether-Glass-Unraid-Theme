#!/bin/bash
#
# Aether Glass :: applies the theme to the Unraid webGUI.
# Unofficial theme, not made or endorsed by Lime Technology.
#
# Adds the theme CSS to the end of two of Unraid's own stylesheets:
#   themes/black.css    every normal page, plus the reboot/shutdown page
#   default-cases.css   the login page (the only stylesheet it loads)
# and inserts a <style> block into one standalone page:
#   logging.htm         the legacy openBox() popup (e.g. a plugin's "Downloading Package"
#                       window), which loads no stylesheet at all
#
# These are the RAM copies Unraid unpacks from its boot image on every boot, so the
# edits vanish on restart and the stock files on the flash drive are never changed.
# The plugin runs this script at every boot (plugins reinstall from
# /boot/config/plugins/ on each boot).
#
# Failsafes:
#   - Update pause: the theme only loads on the Unraid version you approved.  On first
#     install, and after any Unraid update, it stays off (stock look) until you check
#     the stock UI and click Approve on the Settings page.
#   - Kill switch: if /boot/config/plugins/aether-glass/DISABLED exists, the theme never
#     loads.  Works from the flash drive plugged into another computer.
#   - Exact restore: before its first change in each boot, the script saves an untouched
#     copy of each stock file in RAM (/tmp), and removing the theme copies it back byte
#     for byte.  If that copy is gone, it falls back to cutting out the block between
#     the START/END markers.
#   - Boot mode always exits 0: a failed plugin install script makes Unraid move the
#     plugin aside, and a theme problem should never do that.
#
# Usage (Unraid terminal; the Settings page runs the same commands):
#   apply.sh              boot mode: turn on only if approved and not disabled
#   apply.sh --approve    approve this Unraid version and turn the theme on
#   apply.sh --disable    kill switch on, back to stock (stays off across reboots)
#   apply.sh --enable     kill switch off (still needs this version approved)
#   apply.sh --remove     back to stock right now (until the next boot)
#   apply.sh --status     show what is on and why
#   apply.sh --effects preset=balanced
#   apply.sh --effects motion=hover glass=all glow=all
#                         pick how much motion, frosted glass and glow to use (see
#                         "Effects" below); saved on the flash drive, applied right away
#
# Results go to the syslog under the tag "aether-glass".

PLUGIN=aether-glass

# Run as root, so use only the system's own tools, never a same-named file in the
# current folder.
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin

# The AG_* overrides below exist only so the script can be tested against a fake folder
# tree on another computer.  On a real Unraid server they are ignored: the webGUI can set
# environment variables for scripts it runs, and those must not be able to point this
# root script at other files.
if [ -f /etc/unraid-version ]; then
    unset AG_CFG AG_STYLES AG_PAGES AG_VERSION_FILE AG_DISPLAY_CFG AG_GO AG_STOCK AG_LOCK AG_PLG
fi

CFG="${AG_CFG:-/boot/config/plugins/$PLUGIN}"
STYLES="${AG_STYLES:-/usr/local/emhttp/plugins/dynamix/styles}"
PAGES="${AG_PAGES:-/usr/local/emhttp}"
VERSION_FILE="${AG_VERSION_FILE:-/etc/unraid-version}"
DISPLAY_CFG="${AG_DISPLAY_CFG:-/boot/config/plugins/dynamix/dynamix.cfg}"
GO="${AG_GO:-/boot/config/go}"
PLG="${AG_PLG:-/boot/config/plugins/$PLUGIN.plg}"
STOCK="${AG_STOCK:-/tmp/$PLUGIN-stock}"
LOCK="${AG_LOCK:-/var/lock/$PLUGIN.lock}"
NOTIFY=/usr/local/emhttp/webGui/scripts/notify
APPROVED="$CFG/approved-version"
KILL="$CFG/DISABLED"
EFFECTS="$CFG/effects.cfg"
START='/* AETHER-GLASS-START */'
END='/* AETHER-GLASS-END */'
# HTML pages: the theme goes in as a <style> block just before </head>, fenced by HTML
# comments (a CSS-style comment outside <style> would show up as text on the page)
HSTART='<!-- AETHER-GLASS-START -->'
HEND='<!-- AETHER-GLASS-END -->'

say() {
    echo "$PLUGIN: $1"
    logger -t "$PLUGIN" "$1" 2>/dev/null
}

# Unraid bell notification; ignored if the notify script isn't there
notify() {
    [ -x "$NOTIFY" ] && "$NOTIFY" -e "Aether Glass theme" -s "$1" -d "$2" -i "warning" >/dev/null 2>&1
}

current_version() {
    sed -n 's/^version="\(.*\)"$/\1/p' "$VERSION_FILE" 2>/dev/null
}

# An older hand-installed copy of this theme ran from the go file.  If its line is still
# there, both would theme the same files, so this plugin stays out of the way until the
# line is removed.
legacy_install() {
    grep -qF "aether-theme/apply.sh" "$GO" 2>/dev/null
}

# The folder for the untouched stock copies.  /tmp is shared, so refuse a folder this
# script doesn't own or one that is a link to somewhere else, and keep it private (700).
stock_dir() {
    if [ -L "$STOCK" ] || { [ -e "$STOCK" ] && [ ! -O "$STOCK" ]; }; then
        say "refusing: $STOCK is a link or not owned by this user"
        return 1
    fi
    mkdir -p -m 700 "$STOCK"
}

# Name of the saved stock copy for a stylesheet, e.g. themes/black.css -> themes_black.css
stock_copy() {
    echo "$STOCK/$(echo "$1" | tr / _)"
}

# Save an untouched copy of a stylesheet, once per boot, only while it is still stock
save_stock() {
    local f="$1" copy
    copy="$(stock_copy "$f")"
    [ -f "$copy" ] && return 0
    grep -qF "$START" "$STYLES/$f" && return 0
    stock_dir && cp -p "$STYLES/$f" "$copy"
}

# Put a stylesheet back to stock: exact copy if we have one, otherwise cut out the marked block
restore() {
    local f="$1" dst="$STYLES/$1" copy tmp
    grep -qF "$START" "$dst" || return 0
    copy="$(stock_copy "$f")"
    if [ -f "$copy" ]; then
        cat "$copy" > "$dst"
        return
    fi
    tmp="$(mktemp)" || return 1
    awk -v s="$START" -v e="$END" '
        $0 == s { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip
    ' "$dst" > "$tmp" && cat "$tmp" > "$dst"
    rm -f "$tmp"
}

# ---- Effects ----------------------------------------------------------------------------
# Three effects, each with levels (the CSS explains what each level changes):
#   motion  everywhere | hover | still
#   glass   all | panels | off
#   glow    all | static | off
# Presets set all three at once.  "balanced" is the default.
# The choice is saved in effects.cfg as three fixed lines.  The theme CSS keeps every
# level's rules behind media conditions that never match on their own; effects_filter
# switches the chosen ones on in the copy being installed.  The CSS file itself is
# never changed, and the browser still only receives CSS.

DEFAULT_MOTION=hover DEFAULT_GLASS=all DEFAULT_GLOW=all

# preset name -> "motion glass glow", or nothing for an unknown name
preset_levels() {
    case "$1" in
        best)     echo "everywhere all all" ;;
        balanced) echo "hover all all" ;;
        fast)     echo "hover panels static" ;;
        fastest)  echo "still off off" ;;
    esac
}

# Which preset (if any) a set of levels matches, else "custom"
levels_preset() {
    local p
    for p in best balanced fast fastest; do
        [ "$(preset_levels "$p")" = "$1 $2 $3" ] && { echo "$p"; return; }
    done
    echo custom
}

valid_level() {
    case "$1=$2" in
        motion=everywhere|motion=hover|motion=still) return 0 ;;
        glass=all|glass=panels|glass=off) return 0 ;;
        glow=all|glow=static|glow=off) return 0 ;;
    esac
    return 1
}

# Read effects.cfg into MOTION, GLASS, GLOW.  Anything missing or not one of the known
# values falls back to the default, so a damaged file can't break the theme.
read_effects() {
    local key val
    MOTION=$DEFAULT_MOTION GLASS=$DEFAULT_GLASS GLOW=$DEFAULT_GLOW
    [ -f "$EFFECTS" ] || return 0
    while IFS='=' read -r key val; do
        valid_level "$key" "$val" || continue
        case "$key" in
            motion) MOTION=$val ;;
            glass)  GLASS=$val ;;
            glow)   GLOW=$val ;;
        esac
    done < "$EFFECTS"
}

# Copy CSS from stdin to stdout with the chosen levels switched on
effects_filter() {
    local args=()
    read_effects
    case "$MOTION" in
        everywhere) args+=(-e 's/(aether-motion-everywhere)/all/g') ;;
        still)      args+=(-e 's/(prefers-reduced-motion: reduce)/all/g') ;;
    esac
    case "$GLASS" in
        panels) args+=(-e 's/(aether-glass-panels)/all/g') ;;
        off)    args+=(-e 's/(prefers-reduced-transparency: reduce)/all/g') ;;
    esac
    case "$GLOW" in
        static) args+=(-e 's/(aether-glow-static)/all/g') ;;
        off)    args+=(-e 's/(aether-glow-off)/all/g') ;;
    esac
    if [ ${#args[@]} -eq 0 ]; then cat; else sed "${args[@]}"; fi
}

# --effects: check every argument against the known values before saving anything
set_effects() {
    local arg key val m="" g="" w="" levels
    [ $# -gt 0 ] || { say "effects: nothing given; e.g. --effects preset=balanced"; return 1; }
    for arg in "$@"; do
        key="${arg%%=*}" val="${arg#*=}"
        if [ "$arg" = preset=custom ]; then
            continue   # "Custom" on the Settings page: keep the fine-tuned levels as they are
        elif [ "$key" = preset ]; then
            levels="$(preset_levels "$val")"
            [ -n "$levels" ] || { say "effects: unknown preset '$val'; nothing changed"; return 1; }
            read -r m g w <<< "$levels"
        elif valid_level "$key" "$val"; then
            case "$key" in motion) m=$val ;; glass) g=$val ;; glow) w=$val ;; esac
        else
            say "effects: unknown setting '$arg'; nothing changed"
            return 1
        fi
    done
    read_effects
    m="${m:-$MOTION}" g="${g:-$GLASS}" w="${w:-$GLOW}"
    mkdir -p "$CFG" || return 1
    printf 'motion=%s\nglass=%s\nglow=%s\n' "$m" "$g" "$w" > "$EFFECTS.tmp" && mv "$EFFECTS.tmp" "$EFFECTS" || return 1
    say "effects: $(levels_preset "$m" "$g" "$w") (motion $m, glass $g, glow $w)"
}

# add <css file in CFG> <stylesheet under STYLES>
add() {
    local src="$CFG/$1" dst="$STYLES/$2"
    if [ ! -f "$dst" ]; then
        say "SKIPPED $2: not found (an Unraid update may have renamed it)"
        return
    fi
    if [ ! -f "$src" ]; then
        say "SKIPPED $2: $src is missing"
        return
    fi
    # No safe stock copy means no exact restore later, so leave the file alone
    if ! save_stock "$2"; then
        say "SKIPPED $2: couldn't save a stock copy first"
        return
    fi
    restore "$2"
    # start the block on its own line even if the stock file has no final newline
    [ -n "$(tail -c 1 "$dst")" ] && printf '\n' >> "$dst"
    { printf '%s\n' "$START"; effects_filter < "$src"; printf '\n%s\n' "$END"; } >> "$dst"
    say "applied $1 to $2"
}

# --- HTML pages (logging.htm) ---------------------------------------------------------
# Same idea as the stylesheets: save a stock copy once per boot, strip any old block,
# then insert fresh.  The saved copy is named page_<name> so it can't clash with the
# stylesheet copies.

page_copy() {
    echo "$STOCK/page_$(echo "$1" | tr / _)"
}

# Put a page back to stock: exact copy if we have one, otherwise cut out the marked block
restore_page() {
    local f="$1" dst="$PAGES/$1" copy tmp
    grep -qF "$HSTART" "$dst" || return 0
    copy="$(page_copy "$f")"
    if [ -f "$copy" ]; then
        cat "$copy" > "$dst"
        return
    fi
    tmp="$(mktemp)" || return 1
    awk -v s="$HSTART" -v e="$HEND" '
        $0 == s { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip
    ' "$dst" > "$tmp" && cat "$tmp" > "$dst"
    rm -f "$tmp"
}

# add_page <css file in CFG> <page under PAGES>
add_page() {
    local src="$CFG/$1" dst="$PAGES/$2" copy tmp
    if [ ! -f "$dst" ]; then
        say "SKIPPED $2: not found (an Unraid update may have renamed it)"
        return
    fi
    if [ ! -f "$src" ]; then
        say "SKIPPED $2: $src is missing"
        return
    fi
    # Only insert where it is unambiguous: a line that is exactly </head>.  If an update
    # changes the page so that line is gone, leave the page alone rather than guess.
    if ! grep -qxE '[[:space:]]*</head>[[:space:]]*' "$dst"; then
        say "SKIPPED $2: no line that is just </head> (page layout changed?)"
        return
    fi
    # The CSS goes inside a <style> tag on a webGUI page.  A "</style" in it would end the
    # tag early and let the rest run as page markup (for example a script), so refuse it.
    if grep -qi '</style' "$src"; then
        say "SKIPPED $2: $1 contains </style, which isn't allowed inside a style block"
        return
    fi
    copy="$(page_copy "$2")"
    if [ ! -f "$copy" ] && ! grep -qF "$HSTART" "$dst"; then
        if ! { stock_dir && cp -p "$dst" "$copy"; }; then
            say "SKIPPED $2: couldn't save a stock copy first"
            return
        fi
    fi
    restore_page "$2"
    tmp="$(mktemp)" || return 1
    # Print the block right before the first </head> line, and every line as it was
    awk -v s="$HSTART" -v e="$HEND" -v css="$src" '
        !done && $0 ~ /^[[:space:]]*<\/head>[[:space:]]*$/ {
            print s
            print "<style>"
            while ((getline line < css) > 0) print line
            print "</style>"
            print e
            done = 1
        }
        { print }
    ' "$dst" > "$tmp" && cat "$tmp" > "$dst"
    rm -f "$tmp"
    say "applied $1 to $2"
}

add_all() {
    if legacy_install; then
        say "not applied: $GO still runs the old hand-installed theme (aether-theme/apply.sh).  Remove that line, then reboot or click Approve."
        return
    fi
    add aether-glass.css themes/black.css
    add aether-glass-login.css default-cases.css
    add_page aether-glass-logging.css logging.htm
}

remove_all() {
    local f
    for f in themes/black.css default-cases.css; do
        [ -f "$STYLES/$f" ] && restore "$f"
    done
    [ -f "$PAGES/logging.htm" ] && restore_page logging.htm
    say "removed: the webGUI is back to stock"
}

show_status() {
    local f approved
    approved="$(cat "$APPROVED" 2>/dev/null)"
    # The theme's own version, read from the installed .plg (its <!ENTITY version "..."> line)
    echo "Theme version:     $(sed -n 's/^<!ENTITY version *"\([^"]*\)">.*/\1/p' "$PLG" 2>/dev/null | head -1 | grep . || echo unknown)"
    echo "Unraid version:    ${VERSION:-unknown}"
    echo "Approved version:  ${approved:-none yet}"
    echo "Kill switch:       $([ -f "$KILL" ] && echo ON || echo off)"
    read_effects
    echo "Effects:           $(levels_preset "$MOTION" "$GLASS" "$GLOW") (motion $MOTION, glass $GLASS, glow $GLOW)"
    if grep -q '^theme="black"' "$DISPLAY_CFG" 2>/dev/null; then
        echo "Display theme:     Black"
    else
        echo "Display theme:     not Black (main pages stay stock; pick Black in Settings -> Display Settings)"
    fi
    legacy_install && echo "Old install:       the go file still runs aether-theme/apply.sh; remove that line"
    for f in themes/black.css default-cases.css; do
        if grep -qF "$START" "$STYLES/$f" 2>/dev/null; then
            echo "$f: themed"
        else
            echo "$f: stock"
        fi
    done
    if grep -qF "$HSTART" "$PAGES/logging.htm" 2>/dev/null; then
        echo "logging.htm: themed"
    else
        echo "logging.htm: stock"
    fi
}

# Boot mode: every check must pass, otherwise the stock look stays
boot() {
    local approved
    approved="$(cat "$APPROVED" 2>/dev/null)"
    if [ -f "$KILL" ]; then
        say "kill switch is on; leaving the stock look"
        remove_all
    elif [ -z "$VERSION" ]; then
        say "can't read the Unraid version; leaving the stock look"
        remove_all
    elif [ -z "$approved" ]; then
        say "not approved yet: open Settings -> Aether Glass and click Approve to turn it on"
        remove_all
    elif [ "$VERSION" != "$approved" ]; then
        say "paused: Unraid is $VERSION but the theme was approved on $approved"
        notify "Theme paused after Unraid update" \
            "Unraid is now $VERSION, so the theme is off.  Check the stock UI, then click Approve in Settings -> Aether Glass."
        remove_all
    else
        add_all
    fi
}

# One change at a time: the Settings page and the boot run never edit the files together.
# --status only reads, so it skips the lock and the Settings page never waits on it.
if [ "$1" != "--status" ] && { exec 9>"$LOCK"; } 2>/dev/null && command -v flock >/dev/null; then
    flock -w 30 9
fi

VERSION="$(current_version)"

case "$1" in
    "")
        boot
        exit 0
        ;;
    --approve)
        if [ -z "$VERSION" ]; then
            say "can't read the Unraid version from $VERSION_FILE; nothing changed"
            exit 1
        fi
        if [ -f "$KILL" ]; then
            say "kill switch is on; turn the theme on first"
            exit 1
        fi
        mkdir -p "$CFG" && echo "$VERSION" > "$APPROVED"
        say "approved for Unraid $VERSION"
        add_all
        ;;
    --disable)
        mkdir -p "$CFG" && touch "$KILL"
        say "kill switch on: the theme stays off, even after a reboot"
        remove_all
        ;;
    --enable)
        rm -f "$KILL"
        say "kill switch off"
        boot
        ;;
    --remove)
        remove_all
        ;;
    --status)
        show_status
        ;;
    --effects)
        shift
        set_effects "$@" || exit 1
        boot   # re-applies with the new effects, if the theme is on (approved, not disabled)
        ;;
    *)
        echo "usage: apply.sh [--approve | --disable | --enable | --remove | --status | --effects preset=NAME | --effects motion=X glass=X glow=X]"
        exit 1
        ;;
esac
