#!/bin/bash
#
# Prepares a release: writes the version, the update channel and the SHA256 of each file
# in source/ into aether-glass.plg.  Unraid checks every downloaded file against these
# hashes, so a file that changed on GitHub after the release (by accident or on purpose)
# is refused instead of installed.
#
# Two channels, picked from the git branch you're on:
#   main  the default for everyone (Community Apps and the README's install link).
#         Files download from the version's tag, so a release needs that tag.
#         Versions look like 2026.11.02 (or 2026.11.02a for a second one that day).
#   dev   opt-in testing builds.  Servers that installed the dev .plg check the dev
#         branch for updates.  Versions get "-dev" on the end automatically, so the
#         Plugins page shows which channel a server is on.
# Both channels download files from the version's tag.  A tag is a fresh address
# GitHub hasn't cached, so a build installs right after it's pushed; a branch address
# can serve the previous files for ~5 minutes and fail the SHA256 check.
#
# Usage, from the repo folder:
#   tools/release.sh            update the SHA256 lines for the version already in the .plg
#   tools/release.sh 2026.11.02 also set a new version first
#
# Then commit, tag the commit with the version (2026.11.02, or 2026.11.02-dev on dev),
# and push the commit and the tag.

set -euo pipefail
cd "$(dirname "$0")/.."
PLG=aether-glass.plg
REPO_RAW='\&repo;'

branch="$(git rev-parse --abbrev-ref HEAD)"
case "$branch" in
    main) channel=main ;;
    dev)  channel=dev ;;
    *)    echo "releases are made from main or dev, not '$branch'"; exit 1 ;;
esac

if [ $# -ge 1 ]; then
    version="${1%-dev}"
    [[ "$version" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}[a-z]?$ ]] || { echo "version must look like 2026.11.02"; exit 1; }
    [ "$channel" = dev ] && version="$version-dev"
    sed -i.bak "s|<!ENTITY version   \"[^\"]*\">|<!ENTITY version   \"$version\">|" "$PLG"
    rm -f "$PLG.bak"
fi

# The version already in the .plg must suit this branch (a dev merge can leave "-dev" on main)
current="$(sed -n 's|<!ENTITY version   "\([^"]*\)">|\1|p' "$PLG")"
if [ "$channel" = main ] && [[ "$current" == *-dev ]]; then
    echo "main can't ship a -dev version ($current): pass a new version, e.g. tools/release.sh 2026.11.02"; exit 1
fi
if [ "$channel" = dev ] && [[ "$current" != *-dev ]]; then
    echo "dev builds need a -dev version ($current): pass one, e.g. tools/release.sh 2026.11.02"; exit 1
fi

# Point the update check at this channel, and the file downloads at the version's tag
src="$REPO_RAW/\&version;/source"
sed -i.bak \
    -e "s|<!ENTITY src       \"[^\"]*\">|<!ENTITY src       \"$src\">|" \
    -e "s|pluginURL=\"[^\"]*\"|pluginURL=\"$REPO_RAW/$channel/aether-glass.plg\"|" \
    "$PLG"
rm -f "$PLG.bak"
grep -q "pluginURL=\"&repo;/$channel/aether-glass.plg\"" "$PLG" || { echo "failed to set the update channel"; exit 1; }
echo "channel  $channel"

# entity name -> file in source/
set_sha() {
    local entity="$1" file="source/$2" sum
    sum="$(shasum -a 256 "$file" | cut -d' ' -f1)"
    sed -i.bak "s|<!ENTITY $entity \( *\)\"[0-9a-f]*\">|<!ENTITY $entity \1\"$sum\">|" "$PLG"
    rm -f "$PLG.bak"
    grep -q "$sum" "$PLG" || { echo "failed to set $entity"; exit 1; }
    echo "$entity  $sum  $2"
}

set_sha sha_css     aether-glass.css
set_sha sha_login   aether-glass-login.css
set_sha sha_logging aether-glass-logging.css
set_sha sha_apply   apply.sh
set_sha sha_page    AetherGlass.page
set_sha sha_icon    aether-glass.png

grep '<!ENTITY version' "$PLG"
xmllint --noout --noent "$PLG" && echo "$PLG parses cleanly"
