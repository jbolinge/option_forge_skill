#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

rm -f option-forge-strategy.zip

# Refresh the auto-generated docs snapshot from option-forge.com if possible.
# Falls back to whatever is already on disk if offline.
if command -v python3 >/dev/null 2>&1; then
    python3 ../tools/fetch_docs.py || echo "fetch_docs.py failed; using existing option-forge-docs.md"
fi

cp ../docs/brief_api.txt option-forge-strategy/reference/
cp ../docs/api_context.md option-forge-strategy/reference/
cp ../docs/option-forge-docs.md option-forge-strategy/reference/
cp ../docs/put_credit_spread.lua option-forge-strategy/reference/
cp ../docs/balanced_butterfly.lua option-forge-strategy/reference/
cp ../docs/put_back_ratio.lua option-forge-strategy/reference/
cp ../docs/dynamic_delta.lua option-forge-strategy/reference/

zip -r option-forge-strategy.zip option-forge-strategy >/dev/null
echo "Built: $(pwd)/option-forge-strategy.zip"
unzip -l option-forge-strategy.zip
