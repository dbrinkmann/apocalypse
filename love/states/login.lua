local Logger = require("logger")

-- Login states
local LOGIN_STATE = {
    INITIAL = 0,
    SENT_NAME = 1,
    SENT_PASSWORD = 2,
    SENT_EMPTY = 3,
    WAITING_RECONNECT = 4,
    SENT_RECONNECT = 5,
    WAITING_WELCOME = 6,
    SENT_MENU_CHOICE = 7,
    COMPLETE = 8
}

CharacterStates.LoginState = {
    name = "Login",
    display = "Logging In",

    step = LOGIN_STATE.INITIAL,

    init = function(self, conn, connectionStateTable)
    end,

    update = function(self, conn, connectionStateTable, message)
        if self.step == LOGIN_STATE.INITIAL then
            -- look for a message that contains "By what name do you wish to be known?"
            if message and message:match("By what name do you wish to be known?") then
                --Logger.debug("[LOGIN]["..conn.id.."] FOUND NAME QUESTION")
                table.insert(conn.outgoing, connectionStateTable["character"])
                self.step = LOGIN_STATE.SENT_NAME
                Logger.debug("[LOGIN]["..conn.id.."] SENDING NAME "..tostring(message))
            end
        elseif self.step == LOGIN_STATE.SENT_NAME then
            -- Send password
            table.insert(conn.outgoing, connectionStateTable["password"])
            self.step = LOGIN_STATE.SENT_PASSWORD
            Logger.debug("[LOGIN]["..conn.id.."] SENDING PASSWORD "..tostring(message))
        elseif self.step == LOGIN_STATE.SENT_PASSWORD then
            -- Send empty line
            table.insert(conn.outgoing, "")
            self.step = LOGIN_STATE.SENT_EMPTY
            Logger.debug("[LOGIN]["..conn.id.."] SENDING EMPTY LINE "..tostring(message))
        end
        
        if self.step == LOGIN_STATE.SENT_EMPTY then
            --Logger.debug("[LOGIN]["..conn.id.."] LOOKING FOR RECONNECT "..tostring(message))
            if message and (message:match("Reconnecting.") or message:match("You take over your own body, already in use!")) then
                --Logger.debug("[LOGIN]["..conn.id.."] WAITING FOR RECONNECT")
                self.step = LOGIN_STATE.WAITING_RECONNECT
            elseif message and message:match("Welcome to Apocalypse VI!") then
                table.insert(conn.outgoing, "")
                self.step = LOGIN_STATE.WAITING_WELCOME
            end
        elseif self.step == LOGIN_STATE.WAITING_RECONNECT then
            Logger.debug("[LOGIN]["..conn.id.."] SENDING RECONNECT")
            -- Send 'l' for reconnect
            table.insert(conn.outgoing, "l")
            self.step = LOGIN_STATE.COMPLETE

            return {newState = "RefreshCharacterState", removeMessage = true}
        elseif self.step == LOGIN_STATE.WAITING_WELCOME then
            -- Send menu choice '1'
            Logger.debug("[LOGIN]["..conn.id.."] SENDING MENU CHOICE 1")
            table.insert(conn.outgoing, "1")
            self.step = LOGIN_STATE.SENT_MENU_CHOICE
        elseif self.step == LOGIN_STATE.SENT_MENU_CHOICE then
            -- Login complete
            Logger.debug("[LOGIN]["..conn.id.."] LOGIN COMPLETE")
            self.step = LOGIN_STATE.COMPLETE

            return {newState = "RefreshCharacterState", removeMessage = true}
        end

        return {newState = nil, removeMessage = true}
    end,
}