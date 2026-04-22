-- Dynamic Delta Adjustment (dte={dte}, qty={qty})
-- Opens a simple two-leg structure and changes delta bias by day of week as conditions evolve.
-- Check the User Plots tab for the starting-theta vs final-pnl outcome scatter.
sim_params.spread_cost = 0.5 -- // 0.5 is mid. Use 0.6 or higher for less favorable pricing.
local dte = 50
local qty = 1
if date.day_of_week == "Mon" and portfolio.n_open_trades < 3 then
    local trade = portfolio:new_trade()
    trade:add_leg(Put("ShortPut", Delta(-30), dte, -qty))
    trade:add_leg(Put("LongPut", Delta(-50), dte, qty))
    -- Save entry theta so we can relate setup quality to final outcome.
    O[trade.id] = { start_theta = trade.theta }
    -- First ~200 print lines are shown in the JavaScript console (Ctrl+Shift+J).
    print("opened dynamic delta trade", trade.id, "theta", trade.theta)
end

for _, trade in portfolio:trades() do
    if trade.pnl > 1000 then
        local theta = O[trade.id] and O[trade.id].start_theta or 0
        plots:add("starting theta vs final pnl", theta, "scatter", {x=trade.pnl, symbol="o"})
        trade:close("Profit Target")
    elseif trade.pnl < -1000 then
        local theta = O[trade.id] and O[trade.id].start_theta or 0
        plots:add("starting theta vs final pnl", theta, "scatter", {x=trade.pnl, symbol="x"})
        trade:close("Stop Loss")
    elseif date.day_of_week == "Mon" then
        -- Add directional bias early in week, then mean-revert by Friday.
        trade:adjust(TradeDelta(-3), "ShortPut")
    elseif date.day_of_week == "Fri" then
        trade:adjust(TradeDelta(2), "ShortPut")
    else
        trade:adjust(TradeDelta(0), "ShortPut")
    end
end
