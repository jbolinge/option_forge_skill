---
description: Design and write a new OptionForge Lua strategy through thorough Q&A
argument-hint: <brief description of the strategy idea, e.g. "iron condor weekly 20-delta shorts">
---

You are designing a new OptionForge Lua strategy for the user. The deliverable is a single `.lua` file in `strategies/` that the user will paste into https://option-forge.com/forge/ and run.

## Initial idea from user

$ARGUMENTS

If the above is empty, ask the user to describe the strategy they want before proceeding.

## Process

### 1. Ground yourself in the API

Before asking anything, read:
- `docs/brief_api.txt` — full cheat sheet, read end-to-end
- `docs/api_docs.txt` — reference only the sections relevant to what the user described
- At least one existing `docs/*.lua` example that resembles the user's idea (structure, management style)

This is load-bearing. Do NOT ask questions or write code before reading these.

### 2. Run a thorough intake

Cover every category below. Skip re-asking anything the user already specified in their seed — just echo your understanding and move on. Group questions in batches of 2–4 (not one at a time, not all at once). Use `AskUserQuestion` for items with clear multiple-choice answers (underlying, day-of-week, yes/no); use plain-text questions for open-ended items (exact strike relationships, custom logic).

Categories:

- **Strategy concept** — structure type (spread / fly / condor / ratio / naked / etc.), directional bias, one-sentence rationale
- **Underlying & archive** — `sim_params.archive` (SPX / VIX / NDX / RUT / other), `sim_params.tick_interval` (day / hour / 15-minute / etc.), `sim_params.tick_time`
- **Legs** — for each leg: side (Put/Call), selector (`Delta`, `Strike`, `Mid`, `Theta`, `Vega`, `Gamma`, or `TradeDelta`), DTE, quantity (negative = short). Relationships between legs (e.g. long put 50 points below short put strike)
- **Entry conditions** — day-of-week gate, time-of-day, technical filters (`MA:EMA(n) > MA:SMA(m)`), volatility gates, `portfolio.n_open_trades` cap, minimum gap since `last_trade`, `user.*` CSV signals
- **Exit rules** — profit target (absolute $, % of credit/debit, multiple of entry theta, etc.), stop loss, DIT cap, DTE cap, greek-based exits (e.g. `trade.theta < 0`), leg-specific closes
- **Adjustments** — delta-hedge thresholds (`math.abs(trade.delta) > N` → `trade:adjust(TradeDelta(0), "LEG")`), rolls, one-time hedges added on breach (see `balanced_butterfly.lua`)
- **Sizing** — fixed qty, scale with account, concurrent-trade cap
- **Sim params** — `starting_cash`, `start_date`, `end_date`, `commission`, `slippage`, `spread_cost`
- **Diagnostics** — what to `plots:add`, whether to call `trade:risk_graph()` at entry (budget is 200/run), custom `portfolio:count()` events, `trade:export()`

### 3. Confirm before writing

Summarize the full spec in a short bulleted list and ask for confirmation. Revise if the user pushes back. Only proceed to code after explicit sign-off.

### 4. Write the script

Write to `strategies/<snake_case_name>.lua`. The filename should come from the strategy concept, not the user's seed text (e.g. `put_credit_spread_ema_filter.lua`).

Follow all conventions from `CLAUDE.md` and the `docs/*.lua` examples:

- First line is a comment with the run title and `{param}` interpolation of top-level locals: `-- Put Credit Spread EMA Filter (dte={dte}, qty={qty})`
- Only top-level lines starting with `sim_params` are applied before the run. Keep them top-level — do not nest under functions or conditionals.
- Canonical shape: `sim_params` block → top-level strategy parameters (`local dte = 45`, `local qty = 2`) → entry gate → `for _, trade in portfolio:trades() do ... end` management loop.
- Use `trade:erase("reason")` for malformed fills (bad widths, pathological PnL from bad data). Use `trade:close("reason")` for real exits. Close-reason strings double as User Counts keys — keep them short and consistent (`"PT"`, `"SL"`, `"DIT"`, `"DTE"`).
- Guard `nil`: `last_trade`, `trade:leg(name)`, `O[trade.id]` can all be nil.
- Field vs method access: `trade.pnl`, `trade.delta`, `trade.dte`, `trade.dit`, `trade.iv` are **fields** (no parens). `portfolio:delta()`, `portfolio:pnl()`, `portfolio:iv()` are **methods** (with parens). `portfolio.n_open_trades` is a field.
- `TradeDelta(n)` on `trade:adjust(..., "LEG")` makes the *whole trade's* delta equal `n`, not the leg's.
- Don't call `portfolio:history()` per tick — it's expensive.
- `trade:risk_graph()` is capped at 200 calls per run.

### 5. Hand off

After writing, tell the user:
- The file path
- That this is iteration 1 — they should paste the contents into https://option-forge.com/forge/ and run it
- To come back with run observations (close-reason counts, PnL distribution, unexpected behavior) for the next iteration

## Iteration

If the user returns with run results and change requests:
- Revise the existing file in place. No versioning, no changelog comments — overwrite is fine (they prefer option (a)).
- Apply the same diligence: if a change is ambiguous, ask clarifying questions before editing. Don't silently guess.
- Keep the run-title comment's `{param}` placeholders in sync with any renamed/added top-level locals.
