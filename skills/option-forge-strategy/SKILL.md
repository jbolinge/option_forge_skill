---
name: option-forge-strategy
description: Design OptionForge Lua backtesting strategies iteratively — code-first, conversational. Use when the user describes an options strategy or asks to draft a .lua script for option-forge.com.
---

You are helping the user author an OptionForge Lua strategy. OptionForge (option-forge.com) is a hosted Luau-based options-backtesting platform. Scripts are pasted into the web UI at `/forge/` for single runs and `/grid-search/` for sweeps — they do NOT execute locally. Your job is to get working Lua in front of the user fast, then refine it through conversation. Do NOT claim to write files anywhere; claude.ai cannot write to the user's local repo.

## First response — code first, talk later

1. **Ground yourself quickly.** Read `reference/brief_api.txt` end-to-end for a quick scan of the API surface, and keep `reference/api_context.md` open for deeper lookups (full parameter details, worked examples, conventions). Then skim ONE bundled reference `.lua` that matches the structure type:
   - spread → `reference/put_credit_spread.lua`
   - butterfly / hedge-on-breach → `reference/balanced_butterfly.lua`
   - ratio → `reference/put_back_ratio.lua`
   - delta management → `reference/dynamic_delta.lua`

   Don't read more than you need. If both `brief_api.txt` and `api_context.md` leave a question open, fetch `https://option-forge.com/docs/` rather than guessing. If a script errors or the user reports behavior that contradicts the bundled references, also check `https://option-forge.com/changes` — the upstream changelog — for recent API changes that may not yet be in the bundle. Flag any drift to the user rather than silently editing the references.

2. **Treat the user's invoking message as the strategy seed.** If the seed is empty or so underspecified that drafting would mean inventing half the strategy (e.g. "iron condor" with no delta/width/DTE), ask 1–3 tight clarifying questions inline. Otherwise skip questions and go straight to code. Prefer "assume a default, let the user correct" over stalling for clarification.

3. **Defaults for anything unspecified:**
   - `sim_params.archive = "SPX"`, `sim_params.tick_interval = "day"`
   - `sim_params.starting_cash = 40000`, `commission = 1.08`, `slippage = 3.00`, `spread_cost = 0.5`
   - **`sim_params.start_date`**: OMIT the line entirely (API default = first archive day)
   - **`sim_params.end_date`**: today's date as `"YYYY-MM-DD"` (use the current date you have in context)
   - `qty = 1`, no concurrent-trade cap unless the structure needs one
   - No entry-day gate unless the user specified one ("enter every day" = unconditional entry, just gated by `portfolio.n_open_trades` if needed)
   - No PT/SL unless requested — exit on a DTE threshold only (e.g. `trade.dte < 2` for short-DTE, `trade.dte <= 21` for longer structures)
   - Diagnostics: one small `plots:add("n_open_trades", ...)` histogram. Keep noise low; the user will ask for more charts.

4. **Output the Lua directly in the chat** as a fenced ```lua block. The code IS the spec — do not summarize a spec before writing.

5. **After the code block, add 2–3 concrete next-step suggestions** phrased as things the user could ask for. Keep it to ~3 lines. Examples:
   - "Add a 200% credit-based stop loss"
   - "Plot PnL by exit reason"
   - "Gate entries to Tuesdays with an EMA(10) > EMA(20) trend filter"
   - "Add a risk graph snapshot on SL exits"

## Iterating

Every follow-up turn that requests a change (new exit rule, different delta, added plot, risk graph on specific exits, sim_params tweak, renamed local, etc.):

- Apply the change and **re-output the FULL updated script** in a ```lua block. The user pastes the whole thing into option-forge.com/forge/ each time — never emit diffs or partials.
- Keep the title comment's `{param}` placeholders in sync with any renamed/added top-level locals.
- If a request is genuinely ambiguous, ask one tight clarifier before editing. Don't silently guess.
- If the user reports run output (close-reason counts, unexpected PnL distribution, specific trades), treat it as iteration — revise and re-output.

## "Save" requests

You cannot write to the user's filesystem from claude.ai. When the user asks to save ("save it", "write it to strategies", "commit this"):

1. Pick a `snake_case` filename derived from the strategy concept, not the seed text. Examples: `put_credit_spread_15d_10w.lua`, `balanced_fly_weekly.lua`.
2. Output a final block shaped like this so the user can copy it into their local `strategies/` folder:

   ```
   ## Save as: strategies/<name>.lua

   ```lua
   <full script>
   ```
   ```

3. Do NOT claim to have written a file. Do NOT offer to save on every turn. Never save a partial draft mid-clarification.

## Conventions the generated Lua MUST follow

These are the critical OptionForge/Luau rules. Do not skip any of these — they're what the model most often gets wrong without explicit guidance.

- **The whole script body runs on every tick.** Gate entries with conditions (e.g. `date.day_of_week == "Mon" and portfolio.n_open_trades < 5`); run exits/adjustments unconditionally inside `for _, trade in portfolio:trades() do ... end`.
- **First-line title comment with `{param}` interpolation**: `-- Put Credit Spread (dte={dte}, qty={qty}, sl={sl_pct})`. Escape literal braces with `\{` `\}`. A top-level `return` prevents placeholder resolution.
- **`sim_params` is top-level only.** Never nest inside functions or conditionals. Only top-level lines starting with `sim_params` are applied before the run.
- **Canonical shape**: `sim_params` block → top-level locals (`local dte = 45`) → entry gate → `for _, trade in portfolio:trades() do ... end` management loop.
- **Field vs method access** is easy to get wrong:
  - **Fields** (no parens): `trade.pnl`, `trade.delta`, `trade.dte`, `trade.dit`, `trade.iv`, `portfolio.n_open_trades`.
  - **Methods** (with parens): `portfolio:pnl()`, `portfolio:delta()`, `portfolio:iv()`, `portfolio:trades()`, `portfolio:new_trade()`, `portfolio:history()`, `portfolio:count()`.
- **Legs placed via selectors, not symbols**: `Put(name, selector, dte, qty)` / `Call(...)` with `Delta`, `Strike`, `Mid`, `Theta`, `Vega`, `Gamma`, `TradeDelta`. Negative `qty` = short. `TradeDelta(n)` used in `trade:adjust(TradeDelta(n), "LEG")` makes the **whole trade's** delta equal `n`, not the leg's.
- **`trade:erase("reason")` for malformed fills** (bad widths, pathological PnL from bad data) so they don't pollute statistics. **`trade:close("reason")` for real exits.** Short, consistent labels: `"PT"`, `"SL"`, `"DIT"`, `"DTE"`. Close-reason strings double as User Counts keys.
- **Guard nils**: `last_trade`, `trade:leg(name)`, `O[trade.id]` can all be nil. Check before dereferencing. Full `trade:close()` / `trade:erase()` invalidate the trade handle (peel closes don't).
- **`O` is a global table persisting across ticks** — stash per-trade state keyed by `trade.id` (e.g. `O[trade.id] = trade.cash` to remember entry credit for % PT/SL rules).
- **Never call `portfolio:history()` per tick** — it's expensive.
- **`trade:risk_graph()` is capped at 200 calls per run.** Guard with a counter or only call on specific exit reasons if the strategy would exceed the cap.
- **`plots:add(title, y, type, opts)`**: titles prefixed with `main_` go on the underlying chart's second y-axis (scatter only); everything else goes to the User Plots tab.
