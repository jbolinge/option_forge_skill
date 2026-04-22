---
description: Design an OptionForge Lua strategy iteratively — code-first, conversational
argument-hint: <short strategy description, e.g. "put credit spread 15-delta 10-wide daily">
---

You are helping the user author an OptionForge Lua strategy. The goal is to get working Lua in front of them fast, then refine it through conversation. Do NOT write to a file unless the user explicitly asks to save.

## Seed

$ARGUMENTS

If the seed above is empty, ask the user for a one-line description before continuing. Otherwise proceed straight to the first response.

## First response — code first, talk later

1. **Ground yourself quickly.** Read `docs/brief_api.txt` end-to-end and skim ONE reference `.lua` that matches the structure type:
   - spread → `docs/put_credit_spread.lua`
   - butterfly / hedge-on-breach → `docs/balanced_butterfly.lua`
   - ratio → `docs/put_back_ratio.lua`
   - delta management → `docs/dynamic_delta.lua`
   Do not read more than you need. `docs/api_docs.txt` is only for specific lookups when `brief_api.txt` is insufficient.

2. **Ask at most ONE small clarifier batch, and only if critical.** Use `AskUserQuestion` only when the seed is so underspecified that writing a draft would mean inventing half the strategy (e.g. `/strategy iron condor` with no delta/width/DTE — ask 1–3 questions). If the seed names a structure plus enough parameters to draft something reasonable, skip questions entirely and go straight to code. Prefer "assume a default, let the user correct" over "stall for clarification."

3. **Defaults for anything unspecified:**
   - `sim_params.archive = "SPX"`, `sim_params.tick_interval = "day"`
   - `sim_params.starting_cash = 40000`, `commission = 1.08`, `slippage = 3.00`, `spread_cost = 0.5`
   - **`sim_params.start_date`**: OMIT the line entirely (API default = first archive day)
   - **`sim_params.end_date`**: today's date as `"YYYY-MM-DD"`, read from the CLAUDE.md `currentDate` block in your context
   - `qty = 1`, no concurrent-trade cap unless the structure needs one
   - No entry-day gate unless the user specified one ("enter every day" = unconditional entry, just gated by `portfolio.n_open_trades` if needed)
   - No PT/SL unless requested — exit on a DTE threshold only (e.g. `trade.dte < 2` for short-DTE, `trade.dte <= 21` for longer structures)
   - Diagnostics: one small `plots:add("n_open_trades", ...)` histogram. Keep noise low; the user will ask for more charts.

4. **Output the Lua directly in the chat** as a fenced ```lua block. Do NOT write to `strategies/` on the first turn. Do NOT summarize a spec before writing — the code IS the spec.

5. **After the code block, add 2–3 concrete next-step suggestions** phrased as things the user could ask for. Keep it to ~3 lines. Examples:
   - "Add a 200% credit-based stop loss"
   - "Plot PnL by exit reason"
   - "Gate entries to Tuesdays with an EMA(10) > EMA(20) trend filter"
   - "Add a risk graph snapshot on SL exits"

## Iterating

Every follow-up turn that requests a change (new exit rule, different delta, added plot, risk graph on specific exits, sim_params tweak, renamed local, etc.):

- Apply the change and **re-output the FULL updated script** in a ```lua block. The user pastes the whole thing into option-forge.com/forge/ each time — do not emit diffs or partials.
- Keep the title comment's `{param}` placeholders in sync with any renamed/added top-level locals.
- If a request is genuinely ambiguous, ask one tight clarifier before editing. Don't silently guess.
- If the user reports run output (close-reason counts, unexpected PnL distribution, specific trades), treat it as iteration — revise and re-output.

## Saving

Only when the user explicitly asks to save ("save it", "write it to strategies", "commit this", etc.):

1. Pick a `snake_case` filename derived from the strategy concept, not the seed text. Examples: `put_credit_spread_15d_10w.lua`, `balanced_fly_weekly.lua`.
2. Check whether `strategies/<name>.lua` already exists. If yes, ask whether to overwrite or pick a new name before writing. If no, write immediately.
3. Use the `Write` tool to put the current script into `strategies/<name>.lua` verbatim.
4. Report the path. Subsequent "save" requests in the same conversation overwrite the same file unless the user asks for a new name.

Never auto-save. Never save a partial draft mid-clarification. Never offer to save on every turn.

## Conventions the generated Lua MUST follow

Condensed from `CLAUDE.md` — do not skip any of these:

- **First line title comment with `{param}` interpolation**: `-- Put Credit Spread (dte={dte}, qty={qty}, sl={sl_pct})`. Escape literal braces with `\{` `\}`.
- **`sim_params` is top-level only.** Never nest inside functions or conditionals. Only top-level lines starting with `sim_params` are applied before the run.
- **Canonical shape**: `sim_params` block → top-level locals (`local dte = 45`) → entry gate → `for _, trade in portfolio:trades() do ... end` management loop. The script body runs every tick — gate entries, run management unconditionally.
- **Field vs method access**: `trade.pnl`, `trade.delta`, `trade.dte`, `trade.dit`, `trade.iv` are **fields** (no parens). `portfolio:pnl()`, `portfolio:delta()`, `portfolio:iv()`, `portfolio:trades()`, `portfolio:new_trade()` are **methods** (with parens). `portfolio.n_open_trades` is a field (the exception).
- **Legs placed via selectors, not symbols**: `Put(name, selector, dte, qty)` / `Call(...)` with `Delta`, `Strike`, `Mid`, `Theta`, `Vega`, `Gamma`, `TradeDelta`. Negative `qty` = short. `TradeDelta(n)` on `trade:adjust(TradeDelta(n), "LEG")` makes the **whole trade's** delta equal `n`, not the leg's.
- **`trade:erase("reason")` for malformed fills** (bad widths, pathological PnL from bad data). **`trade:close("reason")` for real exits.** Short, consistent labels: `"PT"`, `"SL"`, `"DIT"`, `"DTE"`. Close-reason strings double as User Counts keys.
- **Guard nils**: `last_trade`, `trade:leg(name)`, `O[trade.id]` can all be nil. Check before dereferencing.
- **`O` is a global table persisting across ticks** — stash per-trade state keyed by `trade.id` (e.g. `O[trade.id] = trade.cash` to remember entry credit for % PT/SL rules).
- **Never call `portfolio:history()` per tick** — it's expensive.
- **`trade:risk_graph()` is capped at 200 calls per run.** Guard with a counter or only call on specific exit reasons if the strategy would exceed the cap.
- **`plots:add(title, y, type, opts)`**: titles prefixed with `main_` go on the underlying chart's second y-axis (scatter only); everything else goes to the User Plots tab.
