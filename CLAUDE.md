# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is a strategy-authoring workspace for **OptionForge** (https://option-forge.com), a hosted Lua-based options backtesting platform. There is no local source code, build system, or test suite — `.lua` files here are written to be pasted into the OptionForge web UI (`/forge/` for single runs, `/grid-search/` for parameter sweeps). Scripts do **not** execute locally.

Work in this repo almost always means: reading/writing Lua strategies against the OptionForge API, or updating the API reference snapshots in `docs/`.

## Where the API is documented

- `docs/brief_api.txt` — one-page dense cheat sheet. Start here to orient.
- `docs/api_context.md` — comprehensive API reference (SYSTEM-style prompt context: full API surface, Important Guidelines, Common Patterns, Output Format). Use for deep lookups after `brief_api.txt`.
- `docs/*.lua` — runnable reference strategies (`balanced_butterfly`, `put_credit_spread`, `dynamic_delta`, `put_back_ratio`). Mirror their structure when writing new strategies.
- `docs/urls.txt` — hosted docs at `option-forge.com/docs/` are authoritative if the local snapshots drift.
- `docs/api_docs.txt` — older long-form reference, superseded by `api_context.md`. Kept for archival lookups.

## Lua dialect

Scripts run on **Luau** (Roblox's Lua dialect), not stock Lua. Syntax expectations should match Luau.

## Core execution model

Things that aren't obvious from any single file:

- **The whole script body runs on every tick.** Gate entries with conditions (e.g. `date.day_of_week == "Mon" and portfolio.n_open_trades < 5`); run exits/adjustments unconditionally inside `for _, trade in portfolio:trades() do ... end`.
- **Object model is Portfolio → Trade → Leg.** Trades hold legs created with `Put(name, selector, dte, qty)` or `Call(...)`. Trade greeks/IV are qty-weighted aggregates across their open legs.
- **Legs are placed via Selectors, not option symbols**: `Delta(n)`, `Strike(n)`, `Mid(n)`, `Theta(n)`, `Vega(n)`, `Gamma(n)`, `TradeDelta(n)`. `TradeDelta(n)` adjusts a named leg so the *whole trade's* delta equals `n` (not the leg's delta).
- **Method vs field access is easy to get wrong**: Trade values like `trade.pnl`, `trade.delta`, `trade.dte`, `trade.dit`, `trade.iv` are **fields** (no parens). Portfolio greeks like `portfolio:delta()`, `portfolio:pnl()`, `portfolio:iv()` are **methods** (with parens). `portfolio.n_open_trades` is the exception — it's a field.
- **`O` is a global table that persists across ticks** — the standard place to stash per-trade state, usually keyed by `trade.id` (e.g. `O[trade.id] = { initial_theta = trade.theta }`).
- **Guard `nil`**: `last_trade` may be nil; `trade:leg(name)` returns nil when the leg isn't present. Full `trade:close()` / `trade:erase()` invalidate the trade handle (peel closes don't).
- **`portfolio:history()` is expensive** — don't call it every tick.
- **`trade:risk_graph()` is capped at 200 per run.**

## Script conventions (mirror these)

- **First-line comment becomes the run title**, with `{expr}` interpolation of top-level locals: `-- Put Credit Spread (dte={dte}, qty={qty})`. Escape literal braces with `\{` `\}`. A top-level `return` prevents placeholder resolution.
- **`sim_params` assignments must be top-level** — only top-level lines starting with `sim_params` are applied before the run. Don't bury them in functions or conditionals.
- **Canonical shape**: `sim_params` block → top-level strategy parameters (`local dte`, `local qty`) → entry gate → management loop over `portfolio:trades()`.
- **Close-reason strings double as User Counts keys.** Keep labels short and consistent across a strategy: `"PT"`, `"SL"`, `"DIT"`, `"DTE"`. `portfolio:count(key, inc)` adds custom counters.
- **Use `trade:erase(reason)` for malformed fills** (bad widths, pathological PnL from bad data) so they don't pollute run statistics. Use `trade:close(reason)` for real exits.
- **`plots:add(title, y, type, opts)`** titles prefixed with `main_` go on the underlying chart's second y-axis (scatter only); everything else goes to the User Plots tab.

## Authoring workflow

- New strategies: the user invokes `/strategy <idea>` — see `.claude/commands/strategy.md`. It runs a thorough Q&A intake, then writes to `strategies/<name>.lua`.
- Iterations: the user runs the script on option-forge.com/forge/ and comes back with observations. Revise the existing `.lua` file in place — no versioned copies, no changelog comments.
- Finished strategies live in `strategies/`. Reference implementations live in `docs/*.lua`.

## MCP servers

`.claude/settings.local.json` enables **`context7`**. Use it for fetching up-to-date library/CLI documentation (including Luau) rather than relying on training data.
