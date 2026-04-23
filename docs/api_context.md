[SYSTEM]
<API REFERENCE> (for your reference only, NOT the user's request) ---

## Lua API Docs

## OptionForge Lua API Documentation
This page documents the OptionForge Lua API. For the main app, see OptionForge. For parameter sweeps, see
        Grid Search.

## Table of Contents
- General
- Portfolio Management
- Trade Operations
- Leg Management
- Leg Properties
- Option Selectors
- Moving Averages
- Global Variables
- Plotting
- Complete Examples

## General
Your script runs on every tick. Gate entries, but usually manage exits and adjustments every tick.
The quick example below covers most common patterns.
Run title templates: the first-line comment (-- ...)
            becomes the run title and supports interpolation like
                {dte},
                {sim_params.starting_cash}, or
                {dte + 5}.
                Use \{ and \} for literal braces.
                A top-level return can prevent local placeholders from resolving.

## Quick Example (See Complete Examples for more)

```lua
-- Put Credit Spread (dte={dte}, qty={qty})

-- Optional sim params (defaults: $40k and full archive date range)
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.end_date = "2023-12-29"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5 -- optional, 0..1 (1 = buy ask/sell bid, 0.5 = mid)
dte = 90
qty = 1

if date.day_of_week == "Mon" and portfolio.n_open_trades < 5 then
    trade = portfolio:new_trade()
    trade:add_leg(Put("SP", Delta(-10), dte, -qty))
    -- use the short put strike to place the long put 50 points lower
    sp_strike = trade:leg("SP").strike
    trade:add_leg(Put("LP", Strike(sp_strike - 50), dte, qty))
    print(trade)
end
-- manage open trades every tick
for _, trade in portfolio:trades() do
    if trade.pnl > 200 or trade.pnl < -500 then
        trade:close(trade.pnl > 0 and "PT" or "SL") -- PT or SL
    elseif trade.dit > 50 or trade.dte < 20 then
        trade:close("DIT")
    end
end
```

## Portfolio Management

## portfolio:new_trade(tag?)
Creates a new empty trade in the portfolio, optionally tagged with a string.
Returns: Trade object

## portfolio.n_open_trades
Number of open trades in the portfolio.
Returns: number

## portfolio:trades(tag?)
Returns an iterator over open trades in the portfolio (yields index, trade). If tag is provided, only trades with an exact matching tag are yielded. nil returns all open trades.
Returns: iterator over Trade objects

```lua
for _, trade in portfolio:trades() do
    print(trade.pnl)
end
```

## portfolio:history()
Returns the PnL history of the portfolio.
Returns: table of numbers

```lua
local history = portfolio:history()
for i, pnl in ipairs(history) do print(i, pnl) end
```

## portfolio:pnl()
Current portfolio profit and loss.
Returns: number

## portfolio:value()
Current portfolio value (PnL + starting cash).
Returns: number

## portfolio:delta() / portfolio:gamma() / portfolio:vega() / portfolio:theta()
Current portfolio greeks.
Returns: number

```lua
if portfolio:delta() > 10 then -- Adjust if delta too high
    -- Hedging logic
end
```

## portfolio:iv()
Vega-weighted average implied volatility across all open legs in the portfolio. Same semantics as
                trade.iv but aggregated across all trades from raw numerator/denominator (not a mean of per-trade IVs).
Returns: number

## portfolio:last_trade()
Most recently opened trade.
Returns: Trade object

## portfolio:count(key: string, inc: option[number])
Counts custom events for the final User Counts table.
Note: trade:close("reason") already increments that reason.
Parameters: key (string) - key to count, inc (number) - amount to increment by

```lua
portfolio:count("ManualEvent", 2) -- increment the count of "ManualEvent" by 2
portfolio:count("ManualEvent") -- increment the count of "ManualEvent" by 1
portfolio:count("ManualEvent", -1) -- decrement the count of "ManualEvent" by 1
```

## portfolio:trade(id)
Trade by ID.
Parameters: id (number) - ID of the trade
Returns: Trade object

## Trade Operations

## trade.pnl
Profit and loss of the trade.
Returns: number

## trade.mid
Current mid value of the trade (sum of leg mid prices with quantity and multiplier).
Returns: number

```lua
if trade.mid < -2000 then trade:close() end
```

## trade.cash
Cash used or made from the trade.
Returns: number

## trade:risk_graph()
Adds the trade to the Risk Graph tab. Up to 200 graphs are allowed per run.
Returns: table

```lua
if trade.pnl < - 5000 -- let's see what's happening
    trade:risk_graph()
end
```

## trade:export()
Marks the trade for inclusion in the ONE/OptionNet export CSV download. Idempotent

## trade.dit
Maximum days in trade.
Returns: number

## trade.dte
Minimum days to expiration of the trade.
Returns: number

```lua
if trade.dte < 7 then trade:close() end
```

## trade.id
Id of the trade.
Returns: number

## trade.delta / trade.gamma / trade.vega / trade.theta
Trade-level greeks. Each is the signed, quantity-weighted sum across open legs (times contract multiplier).
Returns: number

```lua
if math.abs(trade.delta) > 5 then
    -- adjust the leg named LP to make the trade delta neutral (0). Accounts for quantity of named leg.
    trade:adjust(TradeDelta(0), "LP")
end
```

## trade.iv
Vega-weighted average implied volatility across open legs. Chosen so that
                trade.vega * (trade.iv - prev_trade.iv) approximates the vega bucket in tick-level PnL
                attribution. Returns 0 when total vega is near zero (e.g. no open legs, or longs and shorts cancel).
For skew-sensitive analysis, read per-leg IV via trade:leg(name).iv instead.
Returns: number

```lua
-- per-tick PnL decomposition against user-maintained prev state.
local p = prev[trade.id]
if p then
    local dS = underlying_price - p.underlying_price
    p.delta_pnl = p.delta_pnl + p.delta * dS
    p.gamma_pnl = p.gamma_pnl + 0.5 * p.gamma * dS * dS
    p.vega_pnl  = p.vega_pnl  + p.vega  * (trade.iv  - p.iv) * 100
    p.theta_pnl = p.theta_pnl + p.theta * (trade.dit - p.dit)
else
    p = { delta_pnl = 0, gamma_pnl = 0, vega_pnl = 0, theta_pnl = 0 }
    prev[trade.id] = p
end
-- snapshot current state so next tick can diff against it
p.underlying_price, p.dit, p.iv = underlying_price, trade.dit, trade.iv
p.delta, p.gamma, p.vega, p.theta = trade.delta, trade.gamma, trade.vega, trade.theta
```

## trade:close(option[string], option[table])
Closes all legs in the trade, or partially closes specific legs when a table is provided.
Parameters: reason (string) - optional reason label
Passing a reason also increments that key in User Counts.
Parameters: peel (table) - optional map of leg_name => qty_to_reduce. Qty sign is ignored.

```lua
if trade.pnl > 500 then trade:close("ProfitTargetHit") end
trade:close("scale-down", { UL = 1, shorts = 2, LL = 1 })
-- NOTE: full close/erase invalidates the trade handle, but peel closes keep it open.
```

## trade:erase(option[string])
Removes the trade and its commissions. Useful for bad data or invalid setups.
Parameters: reason (string) - optional reason label
Passing a reason increments that key in User Counts. Without a reason, erase is incremented for backward compatibility.

## trade:add_leg(TradeLeg)
Adds a new leg to the trade.
Parameters: TradeLeg (created using Put() or Call())
Leg names must be unique within an open trade.

```lua
trade:add_leg(Call("LC", Delta(30), 30, 1))
trade:add_leg(Put("SP", Delta(-30), 30, -1))
```

## trade:close_leg(name: str, option[erase: bool])
Closes one leg.
name (string) - name of the leg to close
erase (boolean) - optional, default false. If true, the leg is treated as if it never existed.

```lua
local lc = trade:leg("LC")
if lc ~= nil and lc.mid > 500 then
    trade:close_leg(lc.name)
end
```

## trade:adjust(selector, name)
Adjusts a leg of the trade using a selector.
Parameters:
- selector: Selector to use for adjustment
- name (string): Name of the leg to adjust
Returns: boolean (success)

```lua
-- Adjust leg "LP" to make trade delta -5. Accounts for quantity of named leg.
trade:adjust(TradeDelta(-5), "LP")
```

## trade:leg(name)
Gets a specific leg by name, or nil when that leg is not present.
Parameters: name (string) - name of the leg
Returns: Leg object or nil

```lua
local my_leg = trade:leg("LC")
print(my_leg.strike, my_leg.mid, my_leg.mid_pnl)
```

## trade:legs()
Returns an iterator over the trade's current open legs (yields index, leg).
Returns: iterator over Leg objects

```lua
for _, leg in trade:legs() do
    print(leg.name, leg.qty, leg.strike)
end
```

## Leg Management

## Put(name, selector, dte, qty)
Creates a put option leg.
Parameters:
- name (string): Identifier for the leg
- selector: Option selector (Delta, Strike, etc.)
- dte (number): Days to expiration
- qty (number): Quantity (negative for short)

```lua
local short_put = Put("SP", Delta(-30), 45, -1)
```

## Call(name, selector, dte, qty)
Creates a call option leg.
Parameters: Same as Put()

## Leg Properties

## leg.delta / leg.gamma / leg.vega / leg.theta / leg.iv
Greeks and implied volatility of the leg.
Returns: number

```lua
local leg_delta = trade:leg("LC").delta
```

## leg.dte
Days to expiration of the leg.
Returns: number

## leg.expiration
Expiration date of the leg as a string.
Returns: string

## leg.mid
Current mid price of the leg.
Returns: number

## leg.mid_pnl
Gross mid-to-mid leg PnL. Excludes spread_cost, commission, and slippage.
Returns: number

## leg.spread
Approximate bid/ask spread of the leg.
Returns: number

## leg.name
Name of the leg.
Returns: string

## leg.qty
Quantity of the leg.
Returns: number

## leg.side
Side of the leg ("put" or "call").
Returns: string

## leg.strike
Strike price of the leg.
Returns: number

## Option Selectors

## Delta(number)
Selects an option by delta value (use negative for puts).

```lua
Call("LC", Delta(30.0), 30, 1)
Put("SP", Delta(-30), 30, -1)
```

## TradeDelta(number)
Adjusts a leg to achieve a specific trade-level delta. Accounts for quantity.

```lua
trade:adjust(TradeDelta(-5), "LP")
```

## Strike(number)
Selects an option by strike price.

```lua
Call("ATM", Strike(underlying_price), 30, 1)
```

## Mid(number)
Selects an option by mid price.

```lua
Call("Cheap", Mid(1.0), 30, 10)
```

## Theta(number)
Selects an option by theta value.

```lua
Call("HighDecay", Theta(-0.5), 30, -1)
```

## Vega(number)
Selects an option by vega value.

```lua
Call("VolSensitive", Vega(0.2), 45, 1)
```

## Gamma(number)
Selects an option by gamma value.

```lua
Call("HighGamma", Gamma(0.05), 15, 1)
```

## Moving Averages

## MA:EMA(period)
Returns: number. The EMA of the underlying price over the last period elements.

```lua
local ema = MA:EMA(20)
print(ema) -- 20-day EMA of underlying price
```

## MA:SMA(period)
Returns: number. The SMA of the underlying price over the last period elements.

## Global Variables

## underlying_price
Current price of the underlying asset (index/stock/ETF).
Type: number

```lua
if underlying_price < 20 then -- VIX is low
    -- Enter positions
end
```

## date
simulation date with attributes: day_of_week, day, month, year, hour, minute, second
Type: date

```lua
if date.day_of_week == "Mon" and date.hour == 10 then -- Entry on Monday at 10am EST
    -- Enter positions
    -- Manage positions
end
```

## last_trade
Last trade opened. May be nil if no trades have been opened yet or if most recent trade has been closed.
Type: Trade

```lua
if last_trade ~= nil and last_trade.dit >= 3 then
    -- open new trade ... not shown.
end
```

## O
Global writable table that persists between ticks.

```lua
-- store a per-trade value and compare against it on later ticks
if trade.pnl > O[trade.id] + 400 then
    trade:close()
end
O[trade.id] = trade.pnl
```

## user
Table populated from your CSV indicator data. Column headers become fields, e.g.
                user.signal.
Type: table
Set sim_params.csv to a public URL.
CSV format (public URL):

```lua
datetime,signal,vol
2025-10-12 10:30:00,0.42,18.1
2025-10-12 10:31:00,0.38,18.3
```
The engine uses the matching row, or the closest earlier row. If none exists, the value is
                nil. A warning is printed when the chosen row is older than the previous tick in the interval.
CSV user data requires an active subscription.
Limits: max 12 columns, max 35,000 rows, numeric values only
                (f32), and valid Lua identifier column names. The datetime
                column is required and must be named datetime or
                Date (case-insensitive). Accepted formats:
                YYYY-MM-DD,
                YYYY-MM-DD HH:MM, or YYYY-MM-DD HH:MM:SS
                with no timezone. Date-only values are treated as 23:59:59 to avoid lookahead.
                Value column headers are case-sensitive (user.ATR != user.atr).

```lua
if user.signal and user.signal > 0.5 then
    -- trade logic
end
```

## sim_params
Simulation parameters. Set these before running (top-level assignments).
Type: SimParameters
Fields:
- starting_cash (number): starting portfolio cash (default 40000)
- start_date (string or nil): "YYYY-MM-DD" (default nil = first
                    archive day)
- end_date (string or nil): "YYYY-MM-DD" (default nil = last archive
                    day)
- commission (number): per-contract commission (default 1.08)
- slippage (number): per-contract slippage (default 3.00)
- spread_cost (number): fill aggressiveness in [0,1]; 1.0 = buy ask/sell bid, 0.5 = mid, 0.0 = buy bid/sell ask (default 0.5). This is additive with sim_params.slippage.
- archive (string or nil): named archive (for example "SPX",
                    "VIX", "NDX", "RUT", or "SPX-30" for 30-minute SPX data),
                    requires server-side archive registry configuration
- csv (string or nil): public CSV URL for user data (see
                    CSV User Data)
- tick_interval (string): "day", "1-day", "hour", "1-hour", or
                    minutes ("1-minute", "5-minute", "15-minute", "30-minute"). The resolution available depends on the
                    archive. Defaults to "day".
- tick_time (number or "HH:MM"): daily sample time in HHMM (default
                    1000). Use "10:30" to specify a time string. Use
                    9999 to pick a random available time per run. If the chosen time is
                    not present anywhere in the archive, the run errors. If missing on a given day, the nearest tick is
                    used and a warning is logged.

```lua
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.end_date = "2023-12-29"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5
```

```lua
-- Daily ticks at 10:00 (or nearest available that day)
-- Available named archives commonly include "SPX", "VIX", "NDX", "RUT", and "SPX-30" (30-minute SPX)
sim_params.archive = "SPX"
sim_params.tick_interval = "day"
sim_params.tick_time = "10:00"

-- Random daily time (one random time per run)
-- sim_params.tick_time = 9999

-- Hourly ticks
-- sim_params.tick_interval = "hour"

-- 15-minute ticks
-- sim_params.tick_interval = "15"
-- sim_params.tick_interval = "15-minute"
```

## Plotting (advanced, but useful)

## plots:add(title, y, plot_type, opts)
Creates custom plots from Lua data. Use trace to add multiple series to one plot.
Titles starting with "main_" plot on the main chart's second y-axis.
                Only scatter plots are supported there.
                Other plots go to User Plots.
Parameters:
- title (string): Title of the plot
- y (number): Value to plot
- plot_type (string): Type of plot. "histogram", "scatter", "bar"
- opts (table): Options for the plot. "bins" (number), "color" (string), "symbol" (string), "date"
                    (string), "hovertext" (string), "trace" (string)

```lua
plots:add("n_trades", portfolio.n_open_trades, "histogram", {bins = 20, color="red"})
plots:add("n_trades_time", portfolio.n_open_trades, "scatter", {
    date=tostring(date),
    color="#E500E5",
    symbol="x",
    hovertext=string.format("%s open=%d", tostring(date), portfolio.n_open_trades)
})
plots:add("debit", trade.cash, "histogram")
```

```lua
for _, trade in portfolio:trades() do
    plots:add("trade_pnl", trade.pnl, "scatter", {
        date=tostring(date),
        trace=tostring(trade.id),
        hovertext=string.format("trade=%s pnl=%.2f dit=%d", tostring(trade.id), trade.pnl, trade.dit)
    })
end
```

```lua
if portfolio.n_open_trades < MAX_TRADES and (portfolio:last_trade() == nil or portfolio:last_trade().dit > 2) then 
    O[trade.id] = trade.theta
end
for _, trade in portfolio:trades() do
    if math.abs(trade.pnl) > 10000 or trade.dit > 50 then
        plots:add("starting theta vs final pnl", O[trade.id], "scatter", {x=trade.pnl, symbol='o'})
        trade:close()
    end
end
```

## Complete Examples

## Put Credit Spread Strategy

```lua
-- Put Credit Spread Example (dte={dte}, qty={qty})
-- Optional sim params (defaults: $40k and full archive date range)
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.end_date = "2023-12-29"
sim_params.commission = 1.08
sim_params.slippage = 3.00
dte = 45
qty = 2

if date.day_of_week == "Tue" and portfolio.n_open_trades < 5 and MA:EMA(10) > MA:EMA(20) then
    trade = portfolio:new_trade()
    trade:add_leg(Put("SP", Delta(-10), dte, -qty))
    -- use the short put strike to place the long put
    local sp = trade:leg("SP")
    trade:add_leg(Put("LP", Strike(sp.strike - 50), dte, qty))
    print(trade)
    -- erase malformed fills so they do not affect stats
    local dist = sp.strike - trade:leg("LP").strike
    if dist > 75 or dist < 25 then trade:erase() end 
end
for _, trade in portfolio:trades() do
    if math.abs(trade.pnl) > 10000 then
       trade:erase()
    elseif trade.pnl > 300 or trade.pnl < -2000 then
        trade:close(trade.pnl > 0 and "PT" or "SL")
    elseif trade.dte < 2 then
        trade:close("Days in Trade")
    end
end
```

## Balanced Butterfly With Delta Hedge

```lua
-- Balanced Butterfly with Delta Hedge (dte={dte}, qty={qty})
-- Optional sim params (defaults: $40k and full archive date range)
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.commission = 1.08
sim_params.slippage = 3.00
local dte = 90
local qty = 20

if date.day_of_week == "Mon" and (last_trade == nil or last_trade.dit > 2) and portfolio.n_open_trades < 4 then
    local trade = portfolio:new_trade()
    trade:add_leg(Put("UL", Delta(-45), dte, qty))
    -- cache legs when their strikes are reused below
    local ul = trade:leg("UL")
    trade:add_leg(Put("SP", Strike(ul.strike - 50), dte, -2 * qty))
    local sp = trade:leg("SP")
    local width = ul.strike - sp.strike
    trade:add_leg(Put("LL", Strike(sp.strike - width), dte, qty))
    trade:add_leg(Call("LC", TradeDelta(0), dte - 30, 1))
    -- keep only the intended 50-wide butterfly
    if width ~= 50 then
        trade:erase()
    else
        -- save entry theta for the profit target rule
        O[trade.id] = { initial_theta = trade.theta }
        trade:risk_graph()
        print(trade)
    end
end

for _, trade in portfolio:trades() do
    local initial_theta = O[trade.id].initial_theta
    if trade.dit >= 35 then
        trade:close("DIT")
    elseif trade.dte <= 30 then
        trade:close("DTE")
    elseif trade.pnl > 30 * initial_theta then
        trade:close("PT")
    elseif trade.pnl < -0.5 * underlying_price then
        trade:close("SL")
    elseif trade.theta < 0 then
        trade:close("low theta")
    else
        -- add a hedge only once after price moves below the short strike
        local sp = trade:leg("SP")
        if underlying_price < sp.strike and trade:leg("HP") == nil then
            trade:add_leg(Put("HP", Mid(1.0), trade.dte, 1))
            portfolio:count("hedge added")
        elseif math.abs(trade.delta) > 5 then
            -- use UL to bring the whole trade back toward flat delta
            trade:adjust(TradeDelta(0), "UL")
        end
    end
end
```

## Dynamic Delta Adjustment

```lua
-- Dynamic Delta Adjustment (dte={dte}, qty={qty})
local dte = 30
local qty = 1
if date.day_of_week == "Mon" and portfolio.n_open_trades < 3 then
    local trade = portfolio:new_trade()
    trade:add_leg(Put("ShortPut", Delta(-30), dte, -qty))
    trade:add_leg(Put("LongPut", Delta(-50), dte, qty))
end

for _, trade in portfolio:trades() do
    if trade.pnl > 1000 then
        trade:close("Profit Target")
    elseif trade.pnl < -1000 then
        trade:close("Stop Loss")
    elseif date.day_of_week == "Mon" then
        trade:adjust(TradeDelta(-3), "ShortPut")
    elseif date.day_of_week == "Fri" then
        trade:adjust(TradeDelta(2), "ShortPut")
    else
        trade:adjust(TradeDelta(0), "ShortPut")
    end
end
```

## Put Back Ratio

```lua
-- Put Back Ratio (dte={dte}, short_qty={short_qty}, long_qty={long_qty})
local short_qty = 2
local long_qty = 3
local dte = 45
if date.day_of_week == "Tue" then
    trade = portfolio:new_trade()
    trade:add_leg(Put("SP", Delta(-2), dte, -short_qty))
    sp_mid = trade:leg("SP").mid
    print("sp_mid:", sp_mid)
    -- size the long put from the short put's premium
    trade:add_leg(Put("LP", Mid(sp_mid / long_qty - 1.0), dte, long_qty))
    print(trade)
end
for _, trade in portfolio:trades() do
    if trade.pnl > 1000 or trade.pnl < -2000 then
        trade:close(trade.pnl > 0 and "PT" or "SL")
    end
end
```


## CSV User Data Guide

## CSV User Data
This guide explains how to bring external indicators into the OptionForge options backtester
        with CSV files and use them directly inside Lua strategy logic.
You can provide a public CSV file with custom indicators. OptionForge loads it once per account
        and exposes the columns as Lua globals under user.

## CSV Format
The first column must be named datetime or
        Date (case-insensitive) and use
        YYYY-MM-DD,
        YYYY-MM-DD HH:MM, or
        YYYY-MM-DD HH:MM:SS with no timezone.
        Date-only values are treated as 23:59:59 to avoid accidental lookahead
        (“seeing the future”).

```lua
datetime,signal,vol
2025-10-12 10:30:00,0.42,18.1
2025-10-12 10:31:00,0.38,18.3
```
Column headers become fields on user, e.g. user.signal.
Value column headers are case-sensitive (e.g., ATR maps to
        user.ATR, not user.atr).

## How Values Are Picked
For each tick, OptionForge looks for the row with the same timestamp. If it does not exist,
        it uses the closest row that precedes the current tick. If no prior row exists, the value is
        nil.
A warning is printed if the row used is older than the previous tick of the current interval.
        This avoids false alarms on weekend gaps for daily data.

## Lua Usage

```lua
sim_params.csv = "https://example.com/indicators.csv"

if user.signal and user.signal > 0.5 then
    -- trade logic
end
```

## Limits
- Requires an active subscription
- Max 12 columns
- Max 35,000 rows (about 10 years at 30-minute intervals)
- Values must be numeric (f32)
- Column names must be valid Lua identifiers (letters, digits, underscore; cannot start with a digit)

## Caching & Refresh
- Cached locally per account for 3 hours
- If your data changes, publish it at a new URL to refresh immediately
- It will be converted on first use to an efficient binary format. Subsequent uses in the cache time will be very fast

## Reproducible Scripts
Set sim_params.csv at the top of your script so the URL travels with the code.
        This makes runs fully reproducible without any UI settings.

</API REFERENCE>

## Important Guidelines
1. script runs on EVERY tick. always include conditions to control when trades open (e.g., days since last_trade, number of open trades)
2. Always include a trade management loop that checks all open trades for stop-loss, profit-target, DTE limits, etc.
3. Use concise, but descriptive leg names: "SP" (short put)
4. Where possible, use a SHORT title template on the first line (e.g., "-- PutCreditSpread dte={dte}, qty={qty}").
5. Include concise comments explaining the logic
6. use NEGATIVE deltas for puts (e.g., Delta(-10) for a 10-delta put)
7. use TradeDelta(0) to get to flat (0) delta.
8. Quantity: use NEGATIVE quantity for short positions (e.g., -1 for selling)
9. If context includes an execution error with a line number, fix that line first and keep changes minimal.
10. When using mid, it's often necessary to divide by 100 e.g. Mid(starting_theta/100.0) 

## Common Patterns
- Example open condition: `(last_trade ~= nil and last_trade.dit >= 2) and portfolio.n_open_trades < 5 then`
- Profit target: `if trade.pnl > target then trade:close("PT") end`
- Stop loss: `if trade.pnl < -maxLoss then trade:close("SL") end`
- DTE exit: `if trade.dte < 7 then trade:close("DTE") end`
- flat delta: instead of adjusting after add leg, use TradeDelta where appropriate `trade:add_leg(Put("my_put", TradeDelta(0), dte, qty))` can get the trade to flat delta. Or we can lean with `TradeDelta(-5)`
    
## Output Format
When providing code, return valid lua (luau) code.
When the user asks for modifications to existing code, provide the complete updated script, not just the changes.
Code should always be in '```' code-fences.

[USER]
Use this context from the current editor state:

Current script in editor:
```lua
-- Broken Wing Put Butterfly w/ PT, SL, and Roll-to-Balanced (dte={dte}, qty={qty}, upper={upper_width}, lower={lower_width})
-- Short 2x puts at 25 delta. Upper long +50, lower long -75 (broken downside wing). Credit-only entry.
-- Roll: if short delta magnitude drops to 10 or less, move lower long up to match upper width (balanced),
-- only if the roll can be done for a debit <= opening credit.
-- PT: 10% of theoretical max profit. SL: 50% of wing-width difference.
-- Diagnostic: "attempted_cash" scatter shows every Monday's net premium, traced by accept/reject reason.
sim_params.starting_cash = 40000
sim_params.end_date = "2026-04-22"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5

local dte = 60
local qty = 1
local short_delta = -25
local upper_width = 50
local lower_width = 75
local wing_diff = lower_width - upper_width
local sl_amount = 0.5 * wing_diff * 100 * qty
local pt_pct = 0.10

if date.day_of_week == "Mon" then
    local trade = portfolio:new_trade()
    trade:add_leg(Put("S", Delta(short_delta), dte, -2 * qty))
    local s = trade:leg("S")
    if s == nil then
        trade:erase("no_short")
    else
        trade:add_leg(Put("UL", Strike(s.strike + upper_width), dte, qty))
        trade:add_leg(Put("LL", Strike(s.strike - lower_width), dte, qty))
        local ul = trade:leg("UL")
        local ll = trade:leg("LL")

        local reason = nil
        if ul == nil or ll == nil then
            reason = "missing_leg"
        elseif (ul.strike - s.strike) ~= upper_width or (s.strike - ll.strike) ~= lower_width then
            reason = "bad_widths"
        elseif trade.cash <= 0 then
            reason = "debit"
        end

        plots:add("attempted_cash", trade.cash, "scatter", {
            date = tostring(date),
            trace = reason or "opened",
            hovertext = string.format("%s cash=%.2f %s", tostring(date), trade.cash, reason or "opened")
        })

        if reason then
            trade:erase(reason)
        else
            O.open_count = (O.open_count or 0) + 1
            local track = (O.open_count % 10 == 0)
            local max_profit = upper_width * 100 * qty + trade.cash
            local pt_amount = pt_pct * max_profit
            O[trade.id] = {
                adjusted = false,
                track_rg = track,
                entry_credit = trade.cash,
                pt_amount = pt_amount,
            }
            if track then trade:risk_graph() end
            plots:add("entry_credit", trade.cash, "scatter", {
                date = tostring(date),
                hovertext = string.format("%s credit=%.2f id=%d", tostring(date), trade.cash, trade.id)
            })
            portfolio:count("opened")
        end
    end
end

for _, trade in portfolio:trades() do
    local state = O[trade.id]
    local adjusted = state and state.adjusted or false
    local bucket = adjusted and "adjusted" or "unadjusted"
    local pt_amount = (state and state.pt_amount) or math.huge

    local close_reason = nil
    if trade.dte < 1 then
        close_reason = "EXP"
    elseif trade.pnl >= pt_amount then
        close_reason = "PT"
    elseif trade.pnl <= -sl_amount then
        close_reason = "SL"
    end

    if close_reason then
        if state and state.track_rg then trade:risk_graph() end
        plots:add("pnl_at_close", trade.pnl, "scatter", {
            date = tostring(date),
            trace = bucket,
            hovertext = string.format("%s pnl=%.2f %s reason=%s", tostring(date), trade.pnl, bucket, close_reason)
        })
        if adjusted then
            plots:add("pnl_dist_adjusted", trade.pnl, "histogram", {bins = 20})
        else
            plots:add("pnl_dist_unadjusted", trade.pnl, "histogram", {bins = 20})
        end
        trade:close(close_reason .. "_" .. (adjusted and "adj" or "no_adj"))
    else
        local s = trade:leg("S")
        local ll = trade:leg("LL")
        if s and ll and state and not state.adjusted and math.abs(s.delta) <= 10 then
            local cash_before = trade.cash
            local orig_ll_strike = ll.strike
            local new_ll_strike = s.strike - upper_width

            trade:close_leg("LL")
            trade:add_leg(Put("LL2", Strike(new_ll_strike), trade.dte, qty))

            local roll_cost = cash_before - trade.cash
            if roll_cost > state.entry_credit then
                trade:close_leg("LL2")
                trade:add_leg(Put("LL_r", Strike(orig_ll_strike), trade.dte, qty))
                portfolio:count("roll_too_expensive")
            else
                state.adjusted = true
                state.roll_cost = roll_cost
                portfolio:count("rolled_to_balanced")
            end
        end
    end
end

plots:add("n_open_trades", portfolio.n_open_trades, "histogram", {bins = 20})
```
