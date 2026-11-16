#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPO="mtmn/knit"
OUTPUT="bootstrap"
CONFIG=".github/dotslash-config.json"

die() {
    echo "error: $*" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || die "jq not found"
command -v dotslash >/dev/null 2>&1 || die "dotslash not found"
[ -f "$CONFIG" ] || die "no config file at $CONFIG"

current=$(git tag --list 'v[0-9]*' --sort=-v:refname | head -n1)
usage="$(basename "$0") <tag> [--repo=owner/name] [--dist=dir] [--output=dir] (${current:-none})"

tag=""
dist=""
for arg in "$@"; do
    case "$arg" in
    --repo=*) REPO=${arg#*=} ;;
    --dist=*) dist=${arg#*=} ;;
    --output=*) OUTPUT=${arg#*=} ;;
    -*) die "unknown flag: $arg" ;;
    *)
        [ -z "$tag" ] || die "unexpected argument: $arg"
        tag="$arg"
        ;;
    esac
done

[ -n "$tag" ] || die "$usage"
echo "$tag" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)*$' ||
    die "'$tag' is not a semantic version tag"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

assets=()
if [ -n "$dist" ]; then
    [ -d "$dist" ] || die "no directory at $dist"
    for file in "$dist"/*.tar.gz; do
        [ -e "$file" ] || continue
        assets+=("${file##*/}")
    done
else
    mapfile -t assets < <(gh release view "$tag" --repo="$REPO" \
        --json assets -q '.assets[] | select(.state == "uploaded") | .name' | sort)
fi
[ "${#assets[@]}" -gt 0 ] || die "no archives for $tag in $REPO"

for name in $(jq -r '.outputs | keys[]' "$CONFIG"); do
    rows="$tmp/$name.tsv"
    : >"$rows"

    while IFS=$'\t' read -r platform regex path; do
        if [ -z "$regex" ] || [ -z "$path" ]; then
            die "$platform needs both a regex and a path"
        fi

        asset=""
        for candidate in "${assets[@]}"; do
            if echo "$candidate" | grep -qE "$regex"; then
                asset="$candidate"
                break
            fi
        done
        [ -n "$asset" ] || die "$platform has no archive matching $regex"
        echo "$asset" | grep -qE '\.tar\.gz$' || die "$asset is not a .tar.gz archive"

        if [ -n "$dist" ]; then
            file="$dist/$asset"
        else
            file="$tmp/$asset"
            [ -f "$file" ] || gh release download "$tag" --repo="$REPO" --pattern "$asset" --output "$file"
        fi

        size=$(wc -c <"$file" | tr -d ' ')
        digest=$(dotslash -- b3sum "$file" | cut -d' ' -f1)
        echo "$platform $asset $size bytes" >&2
        printf '%s\t%s\t%s\t%s\t%s\n' \
            "$platform" "$size" "$digest" "${asset%.tar.gz}/$path" "$asset" >>"$rows"
    done < <(jq -r --arg n "$name" \
        '.outputs[$n].platforms | to_entries[] | "\(.key)\t\(.value.regex)\t\(.value.path)"' "$CONFIG")

    mkdir -p "$OUTPUT"
    {
        echo '#!/usr/bin/env dotslash'
        echo
        jq -Rn --arg name "$name" --arg repo "$REPO" --arg tag "$tag" '
            {name: $name,
             platforms: ([inputs | split("\t") as $r |
                {key: $r[0],
                 value: {
                    size: ($r[1] | tonumber),
                    hash: "blake3",
                    digest: $r[2],
                    format: "tar.gz",
                    path: $r[3],
                    providers: [
                        {url: ("https://github.com/" + $repo + "/releases/download/" + $tag + "/" + $r[4])},
                        {type: "github-release", repo: $repo, tag: $tag, name: $r[4]}
                    ]
                 }}] | from_entries)}
        ' <"$rows"
    } >"$OUTPUT/$name"
    chmod 755 "$OUTPUT/$name"
    echo "wrote $OUTPUT/$name" >&2
done
