#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH="main"
REMOTE="github"
REPO="mtmn/knit"

die() {
    echo "error: $*" >&2
    exit 1
}

update_version_file() {
    local version="$1"
    [ -f info/version.go ] || return 0
    sed -i "s/^var Version = \".*\"/var Version = \"$version\"/" info/version.go
    git add info/version.go
}

generate_dotslash() {
    local tag="$1"
    scripts/generate-dotslash.sh "$tag" --repo="$REPO" --dist=dist
}

command -v git >/dev/null 2>&1 || die "git not found"
command -v goreleaser >/dev/null 2>&1 || die "goreleaser not found"

current=$(git tag --list 'v[0-9]*' --sort=-v:refname | head -n1)
current=${current#v}
usage="$(basename "$0") <version> [--push] [--no-publish] (${current:-none})"

version=""
push=0
publish=1
for arg in "$@"; do
    case "$arg" in
    --push) push=1 ;;
    --no-publish) publish=0 ;;
    -*) die "unknown flag: $arg" ;;
    *)
        [ -z "$version" ] || die "unexpected argument: $arg"
        version="$arg"
        ;;
    esac
done

[ -n "$version" ] || die "$usage"
echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)*$' ||
    die "'$version' is not a semantic version"

[ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] || die "not on $BRANCH branch"
[ -z "$(git status --porcelain)" ] || die "working tree is dirty"
git rev-parse -q --verify "refs/tags/v$version" >/dev/null 2>&1 && die "tag v$version already exists"

update_version_file "$version"

if [ -n "$(git diff --cached --name-only)" ]; then
    git commit -m "chore: release v$version"
fi
git tag -a "v$version" -m "v$version"

if [ "$push" -eq 1 ]; then
    git push "$REMOTE" "$BRANCH" --follow-tags
fi

if [ "$publish" -eq 1 ]; then
    goreleaser release --clean
else
    goreleaser release --clean --skip=publish
fi

generate_dotslash "v$version"

if [ -n "$(git status --porcelain bootstrap)" ]; then
    git add bootstrap
    git commit -m "chore: pin dotslash to v$version"
    if [ "$push" -eq 1 ]; then
        git push "$REMOTE" "$BRANCH"
    fi
fi
