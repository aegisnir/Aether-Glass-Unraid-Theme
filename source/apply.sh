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
#   apply.sh --appearance bars=status accent=#7c5cff
#   apply.sh --appearance reset
#                         pick how the theme looks: bar style and colours (see "Appearance"
#                         below); saved on the flash drive, applied right away
#
# Results go to the syslog under the tag "aether-glass".

PLUGIN=aether-glass

# Run as root, so use only the system's own tools, never a same-named file in the
# current folder.
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
# Plain "C" rules for text, so checks like "six hex digits" mean exactly 0-9 and a-f everywhere
export LC_ALL=C

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
APPEARANCE="$CFG/appearance.cfg"
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
#   motion  everywhere | titles | hover | still   (the holographic shimmer on titles)
#   glass   all | panels | menus | off
#   glow    all | static | off
# Presets set all three at once.  "balanced" is the default.
# The choice is saved in effects.cfg as three fixed lines.  The theme CSS keeps every
# level's rules behind media conditions that never match on their own; effects_filter
# switches the chosen ones on in the copy being installed, by putting "all, " in front of the
# condition: "(aether-glass-menus)" becomes "all, (aether-glass-menus)", which always matches
# but keeps the name, so the optional benchmark on the Settings page can still find it.  The
# CSS file itself is never changed, and the browser still only receives CSS.

DEFAULT_MOTION=hover DEFAULT_GLASS=all DEFAULT_GLOW=all

# preset name -> "motion glass glow", or nothing for an unknown name
preset_levels() {
    case "$1" in
        best)     echo "everywhere all all" ;;
        balanced) echo "hover all all" ;;
        fast)     echo "hover menus static" ;;
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
        motion=everywhere|motion=titles|motion=hover|motion=still) return 0 ;;
        glass=all|glass=panels|glass=menus|glass=off) return 0 ;;
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

# ---- Appearance ---------------------------------------------------------------------------
# Looks that cost nothing in speed, so they live apart from Effects (and its presets):
#   bars      status | spectrum   usage bars: one colour per bar from its value (the
#                                 default), or the older full-width green -> red gradient
#   accent, base, panel, glow, good, warning, critical
#             a colour each, written #rrggbb: the seven colours the whole theme is worked out
#             from (see the top of aether-glass.css)
#   reset     (no value) every colour back to the theme's own; bars stays as it is
# Saved in appearance.cfg as fixed "key=value" lines.
#   - bars is switched on in the installed copy the same way as the Effects levels: the CSS
#     keeps the non-default look behind a media condition that never matches on its own,
#     "(aether-bars-spectrum)", and only the fixed sed command below is ever run.
#   - Colours are the one place a user types a free value, so they are held to one strict
#     rule: exactly "#" and six hex digits, nothing else.  Anything else is refused and
#     nothing is saved.  They are checked again every time the file is read (it lives on the
#     flash drive and can be edited by hand), and they only ever reach the theme as
#     "--aether-NAME: #rrggbb;" lines in a block after the theme's own CSS.  A value never
#     goes into a command, a sed pattern or anything that runs.
# The Settings page sends each colour as two arguments ("accent=" then "#7c5cff"), because a
# colour picker can only send the colour itself; both spellings are accepted.

DEFAULT_BARS=status
COLOUR_KEYS="accent base panel glow good warning critical"

valid_appearance() {
    case "$1=$2" in
        bars=status|bars=spectrum) return 0 ;;
    esac
    return 1
}

is_colour_key() {
    case "$1" in
        accent|base|panel|glow|good|warning|critical) return 0 ;;
    esac
    return 1
}

# Exactly "#" and six hex digits.  Prints it in lower case.
valid_hex() {
    [[ "$1" =~ ^#[0-9a-fA-F]{6}$ ]] || return 1
    printf '%s' "$1" | tr 'A-F' 'a-f'
}

# The colour saved for a key (empty for "the theme's own").  No eval: a fixed case per key.
colour_get() {
    case "$1" in
        accent) printf '%s' "$C_ACCENT" ;;   base) printf '%s' "$C_BASE" ;;
        panel) printf '%s' "$C_PANEL" ;;     glow) printf '%s' "$C_GLOW" ;;
        good) printf '%s' "$C_GOOD" ;;       warning) printf '%s' "$C_WARNING" ;;
        critical) printf '%s' "$C_CRITICAL" ;;
    esac
}
colour_set() {
    case "$1" in
        accent) C_ACCENT=$2 ;;   base) C_BASE=$2 ;;   panel) C_PANEL=$2 ;;   glow) C_GLOW=$2 ;;
        good) C_GOOD=$2 ;;       warning) C_WARNING=$2 ;;   critical) C_CRITICAL=$2 ;;
    esac
}

# Read appearance.cfg into BARS and the C_* colours.  Anything missing or not valid falls
# back to the default, so a damaged or hand-edited file can't break the theme.
read_appearance() {
    local key val hex k
    BARS=$DEFAULT_BARS
    for k in $COLOUR_KEYS; do colour_set "$k" ""; done
    [ -f "$APPEARANCE" ] || return 0
    while IFS='=' read -r key val; do
        if valid_appearance "$key" "$val"; then
            BARS=$val
        elif is_colour_key "$key" && hex="$(valid_hex "$val")"; then
            colour_set "$key" "$hex"
        fi
    done < "$APPEARANCE"
}

# Text colour for accent-filled buttons: white while it stands out at least 3:1 against the
# accent (WCAG's bar for bold labels), otherwise near-black.  Same rule as the Settings page.
accent_ink() {
    awk -v h="$1" 'function lin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        function hx(s) { return index("0123456789abcdef", substr(s, 1, 1)) * 16 + index("0123456789abcdef", substr(s, 2, 1)) - 17 }
        BEGIN { L = 0.2126 * lin(hx(substr(h, 2, 2))) + 0.7152 * lin(hx(substr(h, 4, 2))) + 0.0722 * lin(hx(substr(h, 6, 2)))
                print (1.05 / (L + 0.05) >= 3) ? "#ffffff" : "#0b0b10" }'
}

# The CSS block with the saved colours, printed after the theme's own CSS so it wins.  Nothing
# at all when every colour is the theme's own.  "html:has(#login)" covers the login page,
# whose copy of the theme sets its colours on that selector.
colours_css() {
    local k v any=""
    for k in $COLOUR_KEYS; do [ -n "$(colour_get "$k")" ] && any=1; done
    [ -n "$any" ] || return 0
    printf '\n/* Aether Glass: colours set in Settings -> Aether Glass -> Appearance */\nhtml:root, html:has(#login) {\n'
    for k in $COLOUR_KEYS; do
        v="$(colour_get "$k")"
        if [ -n "$v" ]; then printf '    --aether-%s: %s;\n' "$k" "$v"; fi
    done
    [ -n "$C_ACCENT" ] && printf '    --aether-accent-ink: %s;\n' "$(accent_ink "$C_ACCENT")"
    printf '}\n'
}

# --appearance: check every argument before saving anything
set_appearance() {
    local key val hex k b="" reset="" new_keys="" new_vals=""
    [ $# -gt 0 ] || { say "appearance: nothing given; e.g. --appearance bars=status accent=#7c5cff"; return 1; }
    while [ $# -gt 0 ]; do
        if [ "$1" = reset ]; then
            reset=1; shift; continue
        fi
        key="${1%%=*}" val="${1#*=}"
        # "accent=" followed by "#7c5cff" as the next argument (the Settings page's form)
        if [ "$1" = "$key=" ] && is_colour_key "$key" && [ $# -ge 2 ]; then
            val="$2"; shift
        fi
        if valid_appearance "$key" "$val"; then
            b=$val
        elif is_colour_key "$key" && hex="$(valid_hex "$val")"; then
            new_keys="$new_keys $key" new_vals="$new_vals $hex"
        else
            say "appearance: '$1' isn't a known setting or a #rrggbb colour; nothing changed"
            return 1
        fi
        shift
    done
    read_appearance
    BARS="${b:-$BARS}"
    if [ -n "$reset" ]; then
        for k in $COLOUR_KEYS; do colour_set "$k" ""; done
    fi
    set -- $new_vals
    for k in $new_keys; do colour_set "$k" "$1"; shift; done
    mkdir -p "$CFG" || return 1
    {
        printf 'bars=%s\n' "$BARS"
        for k in $COLOUR_KEYS; do
            if [ -n "$(colour_get "$k")" ]; then printf '%s=%s\n' "$k" "$(colour_get "$k")"; fi
        done
    } > "$APPEARANCE.tmp" && mv "$APPEARANCE.tmp" "$APPEARANCE" || return 1
    say "appearance: $(appearance_summary)"
}

# One line for --status and the log, e.g. "bars status, colours theme" or
# "bars status, colours accent #10b981 base #02110c"
appearance_summary() {
    local k v cols=""
    for k in $COLOUR_KEYS; do
        v="$(colour_get "$k")"
        [ -n "$v" ] && cols="$cols $k $v"
    done
    printf 'bars %s, colours%s' "$BARS" "${cols:- theme}"
}

# Copy CSS from stdin to stdout with the chosen Effects levels and Appearance looks switched on
effects_filter() {
    local args=()
    read_effects
    read_appearance
    case "$MOTION" in
        everywhere) args+=(-e 's/(aether-motion-everywhere)/all, &/g') ;;
        titles)     args+=(-e 's/(aether-motion-titles)/all, &/g') ;;
        still)      args+=(-e 's/(prefers-reduced-motion: reduce)/all, &/g') ;;
    esac
    case "$GLASS" in
        panels) args+=(-e 's/(aether-glass-panels)/all, &/g') ;;
        menus)  args+=(-e 's/(aether-glass-menus)/all, &/g') ;;
        off)    args+=(-e 's/(prefers-reduced-transparency: reduce)/all, &/g') ;;
    esac
    case "$GLOW" in
        static) args+=(-e 's/(aether-glow-static)/all, &/g') ;;
        off)    args+=(-e 's/(aether-glow-off)/all, &/g') ;;
    esac
    case "$BARS" in
        spectrum) args+=(-e 's/(aether-bars-spectrum)/all, &/g') ;;
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
    read_appearance
    { printf '%s\n' "$START"; effects_filter < "$src"; colours_css; printf '\n%s\n' "$END"; } >> "$dst"
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
    local src="$CFG/$1" dst="$PAGES/$2" copy tmp css
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
    # The page gets the saved colours too, in the same <style> block (only #rrggbb values)
    read_appearance
    css="$(mktemp)" || return 1
    { cat "$src"; colours_css; } > "$css"
    copy="$(page_copy "$2")"
    if [ ! -f "$copy" ] && ! grep -qF "$HSTART" "$dst"; then
        if ! { stock_dir && cp -p "$dst" "$copy"; }; then
            say "SKIPPED $2: couldn't save a stock copy first"
            rm -f "$css"
            return
        fi
    fi
    restore_page "$2"
    tmp="$(mktemp)" || { rm -f "$css"; return 1; }
    # Print the block right before the first </head> line, and every line as it was
    awk -v s="$HSTART" -v e="$HEND" -v css="$css" '
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
    rm -f "$tmp" "$css"
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
    read_appearance
    echo "Appearance:        $(appearance_summary)"
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
    --appearance)
        shift
        set_appearance "$@" || exit 1
        boot   # re-applies with the new look, if the theme is on (approved, not disabled)
        ;;
    *)
        echo "usage: apply.sh [--approve | --disable | --enable | --remove | --status | --effects preset=NAME | --effects motion=X glass=X glow=X | --appearance bars=status|spectrum NAME=#rrggbb ... | --appearance reset]"
        exit 1
        ;;
esac
