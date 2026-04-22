-- Short Put Credit Spread (dte={dte}, width={width}, short_delta={short_delta}, pt={pt_pct}, sl={sl_pct})
sim_params.archive = "SPX"
sim_params.tick_interval = "day"
sim_params.starting_cash = 40000
sim_params.end_date = "2026-04-22"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5

local dte = 45
local width = 10
local short_delta = -15
local pt_pct = 0.5   -- 50% of entry credit
local sl_pct = 2.0   -- 200% of entry credit
local qty = 1

local EXIT_COLORS = { PT = "#4caf50", SL = "#e53935", DTE = "#9e9e9e" }

-- Entry: every Monday, only when 10-day EMA > 30-day EMA (uptrend filter).
if date.day_of_week == "Mon" and MA:EMA(10) > MA:EMA(30) then
    -- Tag the trade with its entry date so the risk graph tab labels it by date.
    local trade = portfolio:new_trade(tostring(date))
    trade:add_leg(Put("SP", Delta(short_delta), dte, -qty))
    local sp = trade:leg("SP")
    if sp then
        trade:add_leg(Put("LP", Strike(sp.strike - width), dte, qty))
        local lp = trade:leg("LP")
        local dist = sp.strike - lp.strike
        -- Reject malformed fills so credit-based PT/SL stays meaningful.
        if math.abs(dist - width) > 2 or trade.cash <= 0 then
            trade:erase("bad_fill")
        else
            -- Stash entry credit (positive for a credit spread, net of commission/slippage).
            O[trade.id] = trade.cash
        end
    end
end

-- Management: PT at 50% of credit, SL at 200% of credit, flush near expiration.
-- On every exit, plot trade PnL on the main chart (colored by reason) and
-- snapshot a risk graph on SL exits (capped at 200 per run).
O.sl_graphs = O.sl_graphs or 0
for _, trade in portfolio:trades() do
    local entry_credit = O[trade.id]
    local reason = nil
    if entry_credit and entry_credit > 0 then
        if trade.pnl >= pt_pct * entry_credit then
            reason = "PT"
        elseif trade.pnl <= -sl_pct * entry_credit then
            reason = "SL"
        elseif trade.dte < 2 then
            reason = "DTE"
        end
    elseif trade.dte < 2 then
        reason = "DTE"
    end

    if reason then
        plots:add("main_trade_pnl", trade.pnl, "scatter", {
            date = tostring(date),
            color = EXIT_COLORS[reason],
            trace = reason,
            symbol = "circle",
            hovertext = string.format("%s %s pnl=%.0f", tostring(date), reason, trade.pnl),
        })
        if reason == "SL" and O.sl_graphs < 195 then
            trade:risk_graph()
            O.sl_graphs = O.sl_graphs + 1
        end
        trade:close(reason)
    end
end

plots:add("n_open_trades", portfolio.n_open_trades, "histogram", {bins = 20, color = "#8bc34a"})
