#!/bin/sh
# Release file names that GitHub keeps exactly as they are (redesign/FIX_DEB_ASSET_NAME_NOTES.md).
# GitHub renames an uploaded release file whose name has other characters than letters, digits,
# ".", "-" and "_", or starts or ends with ".": "cone-player_1.1.2~beta2_amd64.deb" was stored as
# "cone-player_1.1.2.beta2_amd64.deb", and SHA256SUMS.txt named a file that did not exist.
#   release-asset-names.sh check <file>...         fails for a name GitHub would change
#   release-asset-names.sh verify <tag> <file>...  after the upload: every file is on the release
#                                                  under its own name and size, and every line of
#                                                  a SHA256SUMS.txt among them names one of them
#                                                  (needs GH_TOKEN and GH_REPO)
set -eu

safe() {
    case "$1" in
        .*|*.) return 1 ;;
        *[!A-Za-z0-9._-]*) return 1 ;;
    esac
    return 0
}

mode=${1:?usage: $0 check <file>... | verify <tag> <file>...}
shift
case "$mode" in
check)
    bad=0
    for f in "$@"; do
        n=$(basename "$f")
        if safe "$n"; then
            echo "ok: $n"
        else
            echo "::error::GitHub would rename the release file \"$n\" (only letters, digits, \".\", \"-\" and \"_\" are kept); name it so, or SHA256SUMS.txt and the notes name a file that is not there"
            bad=1
        fi
    done
    exit $bad
    ;;
verify)
    tag=${1:?usage: $0 verify <tag> <file>...}
    shift
    assets=$(gh release view "$tag" --json assets --jq '.assets[] | "\(.name) \(.size)"')
    echo "On $tag:"
    echo "$assets" | sed 's/^/  /'
    bad=0
    for f in "$@"; do
        n=$(basename "$f")
        size=$(wc -c < "$f" | tr -d ' ')
        if ! echo "$assets" | grep -qxF "$n $size"; then
            echo "::error::$n ($size bytes) is not on the release $tag under that name and size"
            bad=1
        fi
        if [ "$n" = SHA256SUMS.txt ]; then
            # "<hash>  <name>" lines
            while read -r _ name; do
                [ -n "$name" ] || continue
                if ! echo "$assets" | cut -d' ' -f1 | grep -qxF "$name"; then
                    echo "::error::SHA256SUMS.txt names $name, which is not on the release $tag"
                    bad=1
                fi
            done < "$f"
        fi
    done
    [ $bad = 0 ] && echo "every file is on $tag under its own name; SHA256SUMS.txt names only files that are there"
    exit $bad
    ;;
*)
    echo "usage: $0 check <file>... | verify <tag> <file>..." >&2
    exit 2
    ;;
esac
