#!/usr/bin/env bash
# generate-docs.sh - Generate file listings for documentation
# Usage: ./scripts/generate-docs.sh

set -euo pipefail

echo "=== STUDIO File Listings ==="
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "## Scripts (scripts/)"
echo '```'
for f in scripts/*.sh; do
    name=$(basename "$f")
    # Extract first comment line as description
    desc=$(grep -m1 '^#.*-' "$f" 2>/dev/null | sed 's/^#[[:space:]]*//' | cut -d'-' -f2- | sed 's/^[[:space:]]*//' || echo "")
    if [ -n "$desc" ]; then
        printf "%-28s %s\n" "$name" "$desc"
    else
        echo "$name"
    fi
done
echo '```'
echo ""

echo "## Schemas (schemas/)"
echo '```'
ls -1 schemas/*.json 2>/dev/null | xargs -I{} basename {} | sort
echo '```'
echo ""

echo "## Commands (commands/)"
echo '```'
for f in commands/*.md; do
    name=$(basename "$f" .md)
    echo "/$name"
done
echo '```'
echo ""

echo "## Agents (agents/)"
echo '```'
ls -1 agents/*.yaml 2>/dev/null | xargs -I{} basename {} .yaml | sort
echo '```'
echo ""

echo "## Skills (skills/)"
echo '```'
ls -1 skills/*.yaml 2>/dev/null | xargs -I{} basename {} .yaml | sort
echo '```'
echo ""

echo "## Data (data/)"
echo '```'
find data -type f -name "*.yaml" -o -name "*.json" 2>/dev/null | sort
find data -type d -mindepth 1 2>/dev/null | sort
echo '```'
echo ""

echo "## Hooks"
echo '```'
jq -r '.hooks[].event' hooks/hooks.json 2>/dev/null | sort -u
echo '```'
echo ""

echo "---"
echo "Copy relevant sections into docs as needed."
