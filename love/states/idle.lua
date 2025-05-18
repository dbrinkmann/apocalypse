local Logger = require("logger")

CharacterStates.IdleState = {
    name = "Idle",
    display = "Idle",

    init = function(self, conn, connectionStateTable)
    end,

    update = function(self, conn, connectionStateTable, messages)
        if connectionStateTable.lastRefreshCharacterStateTime == 0 or love.timer.getTime() - connectionStateTable.lastRefreshCharacterStateTime > 10 then
            --Logger.debug("[IDLE]["..conn.id.."] REFRESHING STATS")
            connectionStateTable.lastRefreshCharacterStateTime = love.timer.getTime()
            return "RefreshCharacterState"
        end
    end,
}