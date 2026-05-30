#!/usr/bin/env bash
#
# Cut a KwaaiNet GUI release.
#
# Bumps the pubspec version, commits it, and pushes a `vX.Y.Z` tag — which
# triggers .github/workflows/release.yml to build all three platforms and
# publish a GitHub Release with the archives attached.
#
# Usage:
#   scripts/release.sh patch        # 1.0.0 -> 1.0.1   (default)
#   scripts/release.sh minor        # 1.0.0 -> 1.1.0
#   scripts/release.sh major        # 1.0.0 -> 2.0.0
#   scripts/release.sh 1.4.2        # set an explicit version
#   scripts/release.sh --dry-run patch
#
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
BUMP="patch"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    patch|minor|major) BUMP="$arg" ;;
    [0-9]*.[0-9]*.[0-9]*) BUMP="explicit"; EXPLICIT="$arg" ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ── Preconditions ──────────────────────────────────────────────────────────
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
  echo "Refusing to release from '$branch' — switch to main first." >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty — commit or stash changes first." >&2
  exit 1
fi
git fetch origin --quiet
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Local main is not in sync with origin/main — pull/push first." >&2
  exit 1
fi

# ── Compute the new version ──────────────────────────────────────────────────
# pubspec version is "X.Y.Z+BUILD"; the tag and release use the X.Y.Z part.
current="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//; s/\+.*//')"
IFS='.' read -r major minor patch <<<"$current"

case "$BUMP" in
  major) new="$((major + 1)).0.0" ;;
  minor) new="${major}.$((minor + 1)).0" ;;
  patch) new="${major}.${minor}.$((patch + 1))" ;;
  explicit) new="$EXPLICIT" ;;
esac
tag="v${new}"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag $tag already exists." >&2
  exit 1
fi

echo "Releasing: $current -> $new   (tag $tag)"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would update pubspec, commit, tag $tag, and push."
  exit 0
fi

# ── Bump, commit, tag, push ──────────────────────────────────────────────────
# Reset the build number to 1 on each release (X.Y.Z+1).
sed -i.bak -E "s/^version:.*/version: ${new}+1/" pubspec.yaml && rm -f pubspec.yaml.bak

git add pubspec.yaml
git commit -m "release: ${tag}"
git tag -a "$tag" -m "KwaaiNet GUI ${tag}"
git push origin main
git push origin "$tag"

echo ""
echo "Pushed $tag. Watch the release build:"
echo "  https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/actions/workflows/release.yml"
