#!/bin/bash
#
# Prepares a release: writes the SHA256 of each file in source/ into aether-glass.plg.
# Unraid checks every downloaded file against these, so a file that changed on GitHub
# after the release (by accident or on purpose) is refused instead of installed.
#
# Usage, from the repo folder:
#   tools/release.sh            update the SHA256 lines for the version already in the .plg
#   tools/release.sh 2026.11.02 also set a new version first
#
# Then commit, tag the commit with the version (git tag 2026.11.02), and push the
# commit and the tag.  The .plg downloads files from the tag, so the tag must exist.

set -euo pipefail
cd "$(dirname "$0")/.."
PLG=aether-glass.plg

if [ $# -ge 1 ]; then
    [[ "$1" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}[a-z]?$ ]] || { echo "version must look like 2026.11.02"; exit 1; }
    sed -i.bak "s|<!ENTITY version   \"[^\"]*\">|<!ENTITY version   \"$1\">|" "$PLG"
    rm -f "$PLG.bak"
fi

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

grep '<!ENTITY version' "$PLG"
xmllint --noout --noent "$PLG" && echo "$PLG parses cleanly"
