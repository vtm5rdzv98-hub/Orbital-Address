#!/usr/bin/env bash
# Reconstruct the pinned Three.js runtime files omitted by the global build/ ignore rule.
set -euo pipefail

cd "$(dirname "$0")/.."
vendor="site/knight-eps-phase12/viewer/vendor/three/build"
if [[ -s "$vendor/three.module.js" && -s "$vendor/three.core.js" ]]; then
  exit 0
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/orbital-three.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT

# Use the same r176 version documented for the viewer. The full npm package
# supplies both entrypoint and core; fetching only three.module.js is insufficient.
archive="$(npm pack three@0.176.0 --pack-destination "$tmp" --silent)"
for file in three.module.js three.core.js; do
  tar -xzOf "$tmp/$archive" "package/build/$file" > "$tmp/$file"
  if [[ ! -s "$tmp/$file" ]]; then
    printf 'Could not extract %s from Three.js 0.176.0.\n' "$file" >&2
    exit 1
  fi
done

mkdir -p "$vendor"
cp "$tmp/three.module.js" "$tmp/three.core.js" "$vendor/"
printf 'Prepared pinned Three.js r176 vendor builds for local use.\n'
