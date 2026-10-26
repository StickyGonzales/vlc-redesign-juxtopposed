#!/bin/bash
# release.yml: refuse to release anything but verified code (the redesign branch), and check the
# version. Environment: EVENT (push or workflow_dispatch), REF, REF_NAME, INPUT_VERSION,
# INPUT_PRERELEASE, GITHUB_SHA. Writes version and prerelease to GITHUB_OUTPUT.
set -euo pipefail

fail()
{
    echo "::error::$*"
    exit 1
}

git fetch --quiet origin redesign
REDESIGN=$(git rev-parse origin/redesign)

case "$EVENT" in
push)
    # a pushed tag: its commit must be on redesign
    VERSION=$REF_NAME
    PRERELEASE=true
    git merge-base --is-ancestor "$GITHUB_SHA" "$REDESIGN" \
        || fail "tag $VERSION points at $GITHUB_SHA, which is not on the redesign branch: only verified code (redesign) is released. Delete the tag (git push origin :refs/tags/$VERSION) and tag a redesign commit."
    ;;
workflow_dispatch)
    VERSION=$INPUT_VERSION
    PRERELEASE=${INPUT_PRERELEASE:-true}
    [ "$REF" = refs/heads/redesign ] \
        || fail "started from $REF: start the release from the redesign branch (Run workflow, 'Use workflow from: redesign')."
    git merge-base --is-ancestor "$GITHUB_SHA" "$REDESIGN" \
        || fail "$GITHUB_SHA is not on the redesign branch."
    if git rev-parse --quiet --verify "refs/tags/$VERSION" >/dev/null; then
        fail "the tag $VERSION already exists: pick a new version, or delete the old release and its tag first."
    fi
    ;;
*)
    fail "unexpected event $EVENT"
    ;;
esac

[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] \
    || fail "version '$VERSION' is not like v0.1.0 or v0.2.0-beta.1"

echo "Releasing $VERSION from $GITHUB_SHA (on redesign, head $REDESIGN), pre-release: $PRERELEASE"
{
    echo "version=$VERSION"
    echo "prerelease=$PRERELEASE"
} >> "$GITHUB_OUTPUT"
