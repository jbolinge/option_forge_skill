-- SPX Naked Put (delta={delta_target}, dte={dte}, qty={qty}, pt={pt_pct}, sl={sl_pct})
sim_params.archive = "SPX"
sim_params.tick_interval = "day"
sim_params.starting_cash = 250000
sim_params.start_date = "2019-01-02"
sim_params.end_date = "2026-04-22"
sim_params.commission = 1.08
sim_params.slippage = 3.00
sim_params.spread_cost = 0.5

local dte = 120
local delta_target = -15
local qty = 1
local pt_pct = 0.60
local sl_pct = 2.00
local dte_close = 21

local trade = portfolio:new_trade()
trade:add_leg(Put("SP", Delta(delta_target), dte, -qty))
O[trade.id] = trade.cash
plots:add("entry_credit", trade.cash, "histogram", {bins = 30, color = "#8bc34a"})

plots:add("n_open_trades_time", portfolio.n_open_trades, "scatter", {
    date = tostring(date),
    color = "#4dd0e1",
    symbol = "x",
    hovertext = string.format("%s open=%d", tostring(date), portfolio.n_open_trades),
})

for _, t in portfolio:trades() do
    local credit = O[t.id] or 0
    if math.abs(t.pnl) > 100000 then
        t:erase()
    elseif credit > 0 and t.pnl > pt_pct * credit then
        plots:add("pnl_by_reason", t.pnl, "scatter", {
            date = tostring(date), color = "#4caf50", symbol = "circle",
            hovertext = string.format("PT id=%d pnl=%.2f credit=%.2f dit=%d", t.id, t.pnl, credit, t.dit),
        })
        t:close("PT")
    elseif credit > 0 and t.pnl < -sl_pct * credit then
        plots:add("pnl_by_reason", t.pnl, "scatter", {
            date = tostring(date), color = "#f44336", symbol = "x",
            hovertext = string.format("SL id=%d pnl=%.2f credit=%.2f dit=%d", t.id, t.pnl, credit, t.dit),
        })
        t:close("SL")
    elseif t.dte <= dte_close then
        plots:add("pnl_by_reason", t.pnl, "scatter", {
            date = tostring(date), color = "#9e9e9e", symbol = "square",
            hovertext = string.format("DTE id=%d pnl=%.2f credit=%.2f dit=%d", t.id, t.pnl, credit, t.dit),
        })
        t:close("DTE")
    end
end
