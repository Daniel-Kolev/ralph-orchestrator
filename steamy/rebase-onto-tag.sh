#!/usr/bin/env bash
# Rebase the steamy patch commits onto a new upstream tag and build.
# Usage: ./steamy/rebase-onto-tag.sh <tag>
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:?usage: $0 <upstream-tag>}"
base_branch="steamy/${tag#v}"

git fetch upstream --tags
git branch --list "$base_branch" | grep -q . && { echo "branch $base_branch already exists"; exit 1; }
git checkout -b "$base_branch" "$tag"
echo "--- rebasing $(git rev-list --count v${tag#v}..steamy/$(git -C . describe --tags --abbrev=0 steamy/v2.12.0 2>/dev/null || echo v2.12.0) 2>/dev/null || echo 2) patch commits onto $tag"
git log --oneline "$tag".."$(git for-each-ref refs/heads/steamy/v2.12.0 --format='%(refname:short)')" --reverse | head -20
# cherry-pick the patch commits from the previous steamy branch, in order
for c in $(git log --reverse --format=%h "$tag^".."steamy/v2.12.0" 2>/dev/null | head -20); do
  git cherry-pick "$c" || {
    echo "CONFLICT on $c — resolve, git cherry-pick --continue, then rerun the build"; exit 1
  }
done
echo "--- done. branch $base_branch carries the steamy patches on $tag"
git log --oneline -5
