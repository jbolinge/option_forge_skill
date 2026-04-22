-- Put Credit Spread (dte={dte}, qty={qty})
-- Sells a trend-filtered put credit spread and closes on PT/SL or near expiration.
-- Check the User Plots tab for open-trades exposure diagnostics over time.
-- {dte} and {qty} are filled with the values from the script. useful for keeping title up-to-date with actual parameters.
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.end_date = "2023-12-29"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5 -- // 0.5 is mid. Use 0.6 or higher for less favorable pricing.
local dte = 45
local qty = 2

-- Trend filter helps avoid selling premium into weak momentum.
if date.day_of_week == "Tue" and portfolio.n_open_trades < 5 and MA:EMA(10) > MA:EMA(20) then
    trade = portfolio:new_trade()
    trade:add_leg(Put("SP", Delta(-10), dte, -qty))
    local sp = trade:leg("SP")
    trade:add_leg(Put("LP", Strike(sp.strike - 50), dte, qty))
    local dist = sp.strike - trade:leg("LP").strike
    -- Reject malformed fills so results are comparable run-to-run.
    if dist > 75 or dist < 25 then trade:erase() end
    -- First ~200 print lines are shown in the JavaScript console (Ctrl+Shift+J).
    print("opened PCS", trade.id, "width", dist)
end

-- Keep diagnostics visible in User Plots for exposure monitoring.
plots:add("n_trades", portfolio.n_open_trades, "histogram", {bins = 20, color = "#8bc34a"})
plots:add("n_trades_time", portfolio.n_open_trades, "scatter", {date=tostring(date), color="#4dd0e1", symbol="x"})

for _, trade in portfolio:trades() do
    if math.abs(trade.pnl) > 10000 then
       trade:erase()
    elseif trade.pnl > 300 or trade.pnl < -2000 then
        trade:close(trade.pnl > 0 and "PT" or "SL")
    elseif trade.dte < 2 then
        trade:close("Days in Trade")
    end
end
