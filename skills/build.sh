#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

rm -f option-forge-strategy.zip

cp ../docs/brief_api.txt option-forge-strategy/reference/
cp ../docs/api_context.md option-forge-strategy/reference/
cp ../docs/put_credit_spread.lua option-forge-strategy/reference/
cp ../docs/balanced_butterfly.lua option-forge-strategy/reference/
cp ../docs/put_back_ratio.lua option-forge-strategy/reference/
cp ../docs/dynamic_delta.lua option-forge-strategy/reference/

zip -r option-forge-strategy.zip option-forge-strategy >/dev/null
echo "Built: $(pwd)/option-forge-strategy.zip"
unzip -l option-forge-strategy.zip
