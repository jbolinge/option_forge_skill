-- Put Back Ratio (dte={dte}, short_qty={short_qty}, long_qty={long_qty})
-- Builds a put back-ratio by linking long-leg pricing to short-premium economics.
-- Check the User Plots tab for the debit histogram to inspect entry cost distribution.
sim_params.spread_cost = 0.5 -- // 0.5 is mid. Use 0.6 or higher for less favorable pricing.
local short_qty = 2
local long_qty = 3
local dte = 45

if date.day_of_week == "Tue" then
    trade = portfolio:new_trade()
    trade:add_leg(Put("SP", Delta(-2), dte, -short_qty))
    sp_mid = trade:leg("SP").mid
    -- Tie long-leg cost to short premium so ratio stays economically balanced. Should get
    -- $100 credit each trade.
    trade:add_leg(Put("LP", Mid(short_qty * sp_mid / long_qty - 1/long_qty), dte, long_qty))
    plots:add("debit", trade.cash, "histogram", {bins = 30, color = "#ffb74d"})
    -- First ~200 print lines are shown in the JavaScript console (Ctrl+Shift+J).
    print("opened put back ratio", trade.id, "sp_mid", sp_mid)
end

for _, trade in portfolio:trades() do
    if trade.pnl > 1000 or trade.pnl < -2000 then
        trade:close(trade.pnl > 0 and "PT" or "SL")
    end
end
