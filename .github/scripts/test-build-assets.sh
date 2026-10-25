#!/bin/sh
# Attaches a test build's packages to the draft pre-release "test-builds", so they can be
# downloaded while the Actions artifact storage is full (redesign/TEST_BUILDS.md). One asset per
# branch and package kind, "<branch>--<kind>": the next build of the same branch replaces it. The
# asset's label names the built file and the run. Runs only for test builds (never from a release
# workflow); needs GH_TOKEN with contents: write.
# usage: test-build-assets.sh <kind>=<file> ...   (a file that does not exist is skipped)
set -eu

TAG=test-builds
BRANCH=$(printf '%s' "${GITHUB_REF_NAME:?}" | tr -c 'A-Za-z0-9._-' '-')
RUN="run ${GITHUB_RUN_NUMBER:-?} (${GITHUB_SHA:-?})"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

uploads=""
for pair in "$@"; do
    kind=${pair%%=*}
    file=${pair#*=}
    [ -f "$file" ] || { echo "skipped $kind: $file not built"; continue; }
    asset="$TMP/$BRANCH--$kind"
    cp "$file" "$asset"
    uploads="$uploads $asset"
    echo "$BRANCH--$kind: $(basename "$file"), $RUN"
done
[ -n "$uploads" ] || { echo "nothing to attach"; exit 0; }

if ! gh release view "$TAG" >/dev/null 2>&1; then
    gh release create "$TAG" --draft --prerelease --title "Test builds (not a release)" --notes \
"Test builds for the PC session, attached by build-windows and build-linux (redesign/TEST_BUILDS.md).
One asset per branch and package kind, <branch>--<kind>; the next build of the same branch replaces it.
Not a release: never publish this draft."
fi

for asset in $uploads; do
    name=$(basename "$asset")
    kind=${name#*--}
    for pair in "$@"; do
        [ "${pair%%=*}" = "$kind" ] && label="$(basename "${pair#*=}"), $RUN"
    done
    gh release upload "$TAG" "$asset#$label" --clobber
done
echo "Attached to the draft pre-release \"$TAG\":$(for a in $uploads; do printf ' %s' "$(basename "$a")"; done)" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
