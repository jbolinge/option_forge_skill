-- Balanced Butterfly (dte={dte}, qty={qty})
-- Opens a balanced put butterfly with a small call hedge and manages exits with theta-aware rules.
-- Check the User Plots tab for the per-trade PnL scatter, and Risk Graphs for entry snapshots.
-- Note that the {dte} and {qty} in the title are filled with values from the script.
sim_params.starting_cash = 40000
sim_params.start_date = "2019-01-02"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5 -- // 0.5 is mid. Use 0.6 or higher for less favorable pricing.
local dte = 90
local qty = 20

-- Space out entries so each structure has time to evolve.
if date.day_of_week == "Mon" and (last_trade == nil or last_trade.dit > 2) and portfolio.n_open_trades < 4 then
    local trade = portfolio:new_trade()
    trade:add_leg(Put("UL", Delta(-45), dte, qty))
    local ul = trade:leg("UL")
    trade:add_leg(Put("SP", Strike(ul.strike - 50), dte, -2 * qty))
    local sp = trade:leg("SP")
    local width = ul.strike - sp.strike
    trade:add_leg(Put("LL", Strike(sp.strike - width), dte, qty))
    trade:add_leg(Call("LC", TradeDelta(0), dte - 30, 1))
    -- Enforce symmetry; missing strikes can create distorted structures.
    if width ~= 50 then
        trade:erase()
    else
        -- Use opening theta as a size-aware profit target anchor.
        O[trade.id] = { initial_theta = trade.theta }
        trade:risk_graph()
        -- First ~200 print lines are shown in the JavaScript console (Ctrl+Shift+J).
        print("opened butterfly", trade.id, "theta", trade.theta)
    end
end

for _, trade in portfolio:trades() do
    plots:add("trade_pnl", trade.pnl, "scatter", {
        date=tostring(date),
        trace=tostring(trade.id),
        hovertext=string.format("trade=%s pnl=%.2f dit=%d theta=%.2f", tostring(trade.id), trade.pnl, trade.dit, trade.theta)
    })

    local initial_theta = O[trade.id] and O[trade.id].initial_theta or 0
    if trade.dit >= 35 then
        trade:close("DIT")
    elseif trade.dte <= 30 then
        trade:close("DTE")
    elseif initial_theta > 0 and trade.pnl > 30 * initial_theta then
        trade:close("PT")
    elseif trade.pnl < -0.5 * underlying_price then
        trade:close("SL")
    elseif trade.theta < 0 then
        trade:close("low theta")
    else
        local sp = trade:leg("SP")
        -- Add a one-time hedge only after price breaches short strike.
        if underlying_price < sp.strike and trade:leg("HP") == nil then
            trade:add_leg(Put("HP", Mid(1.0), trade.dte, 1))
            portfolio:count("hedge added")
            print("hedge added", trade.id, "spot", underlying_price)
        elseif math.abs(trade.delta) > 5 then
            -- Normalize delta drift with UL so sizing stays consistent.
            trade:adjust(TradeDelta(0), "UL")
        end
    end
end
