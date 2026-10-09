#!/bin/bash
# release.sh - Version update script (for CI, called from .github/workflows/release.yml)
#
# Usage:
#   ./scripts/release.sh patch   # 1.0.2 -> 1.0.3
#   ./scripts/release.sh minor   # 1.0.2 -> 1.1.0
#   ./scripts/release.sh major   # 1.0.2 -> 2.0.0
#
# Process:
#   1. Validate bump type
#   2. Calculate new version from lib/split_test_rb/version.rb
#   3. Check for duplicate tags
#   4. Update version in lib/split_test_rb/version.rb
#   5. Commit & create tag & push

set -euo pipefail

BUMP_TYPE="${1:-}"

if [[ -z "$BUMP_TYPE" ]]; then
  echo "❌ Please specify bump type"
  echo "Usage: ./scripts/release.sh [major|minor|patch]"
  exit 1
fi

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "❌ Invalid bump type (must be one of: major, minor, patch)"
  exit 1
fi

VERSION_FILE="lib/split_test_rb/version.rb"

# Get current version
CURRENT=$(ruby -r "./${VERSION_FILE}" -e 'puts SplitTestRb::VERSION')
echo "Current version: $CURRENT"

# Parse version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Calculate new version
case "$BUMP_TYPE" in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_MINOR=0
    NEW_PATCH=0
    ;;
  minor)
    NEW_MAJOR=$MAJOR
    NEW_MINOR=$((MINOR + 1))
    NEW_PATCH=0
    ;;
  patch)
    NEW_MAJOR=$MAJOR
    NEW_MINOR=$MINOR
    NEW_PATCH=$((PATCH + 1))
    ;;
esac

VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
echo "New version: $VERSION ($BUMP_TYPE)"

# Check for duplicate tag
TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "❌ Tag $TAG already exists"
  exit 1
fi

echo ""
echo "📝 Updating version..."

# Update lib/split_test_rb/version.rb
ruby -i -pe "sub(/VERSION = '.*'/, \"VERSION = '${VERSION}'\")" "$VERSION_FILE"

echo "📝 Committing changes..."
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$VERSION_FILE"
git commit -m "Update version to ${VERSION}"

echo "⬆️  Pushing commit..."
git push

echo "🏷️  Creating tag $TAG..."
git tag "$TAG"

echo "⬆️  Pushing tag $TAG..."
git push origin "$TAG"

echo ""
echo "✅ Version update complete: $TAG"

# Output version for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=$VERSION" >> "$GITHUB_OUTPUT"
fi
