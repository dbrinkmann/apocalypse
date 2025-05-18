local Logger = require("logger")

function strip_ansi(str)
    -- Remove all ANSI escape sequences
    return str:gsub("\27%[[%d;]*m", "")
end

function is_stat_pattern(msg, connectionStateTable)
    -- this returns true if this is the prompt line with the stats
    -- example: [1;37m<[0m [1;31m508H[0m [1;32m158M[0m [1;33m289V[0m [1;36m236464X[0m [0;33m14375SP[0m [1;37m>[0m 

    -- Strip ANSI codes and match on clean string
    local clean_msg = strip_ansi(msg)
    --Logger.debug("[Helpers] Clean message: " .. clean_msg)
    
    -- Pattern explanation:
    -- < - Start symbol
    -- %d+H - Health number
    -- %d+M - Mana number
    -- %d+V - Vitality number
    -- %d+X - Experience number
    -- %d+SP - Stamina points
    -- > - End symbol
    --Logger.debug("[Helpers] Clean message: " .. clean_msg)
    local health, mana, vitality, xp, sp = clean_msg:match("^< (%d+)H (%d+)M (%d+)V (%d+)X (%d+)SP >")
    --Logger.debug("[Helpers] Extracted stats: " .. tostring(health) .. " " .. tostring(mana) .. " " .. tostring(vitality) .. " " .. tostring(xp) .. " " .. tostring(sp))
    
    --Logger.debug("[Helpers] Extracted stats: " .. tostring(health) .. " " .. tostring(mana) .. " " .. tostring(vitality) .. " " .. tostring(xp) .. " " .. tostring(sp))
    if health and mana and vitality and xp and sp then
        -- Initialize stats table if it doesn't exist
        if not connectionStateTable.localView.characterStats then
            connectionStateTable.localView.characterStats = {}
        end
        
        -- Update stats
        connectionStateTable.localView.characterStats.hp.current = tonumber(health)
        connectionStateTable.localView.characterStats.mana.current = tonumber(mana)
        connectionStateTable.localView.characterStats.vitality.current = tonumber(vitality)        
        connectionStateTable.localView.characterStats.xp.current = tonumber(xp)
        connectionStateTable.localView.characterStats.sp = tonumber(sp)
        
        return true
    end
    return false
end