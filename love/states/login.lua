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

    update = function(self, conn, connectionStateTable, messages)
        if self.step == LOGIN_STATE.INITIAL then
            -- Send character name
            table.insert(conn.outgoing, connectionStateTable["character"])
            self.step = LOGIN_STATE.SENT_NAME
            Logger.debug("[LOGIN]["..conn.id.."] SENDING NAME")
        elseif self.step == LOGIN_STATE.SENT_NAME then
            -- Send password
            table.insert(conn.outgoing, connectionStateTable["password"])
            self.step = LOGIN_STATE.SENT_PASSWORD
            Logger.debug("[LOGIN]["..conn.id.."] SENDING PASSWORD")
        elseif self.step == LOGIN_STATE.SENT_PASSWORD then
            -- Send empty line
            table.insert(conn.outgoing, "")
            self.step = LOGIN_STATE.SENT_EMPTY
            Logger.debug("[LOGIN]["..conn.id.."] SENDING EMPTY LINE")
        elseif self.step == LOGIN_STATE.SENT_EMPTY then
            for _, msg in ipairs(messages) do
                if msg:match("Reconnecting.") or msg:match("You take over your own body, already in use!") then
                    Logger.debug("[LOGIN]["..conn.id.."] WAITING FOR RECONNECT")
                    self.step = LOGIN_STATE.WAITING_RECONNECT
                    break
                elseif msg:match("Welcome to Apocalypse VI!") then
                    table.insert(conn.outgoing, "")
                    self.step = LOGIN_STATE.WAITING_WELCOME
                    break
                end
            end
        elseif self.step == LOGIN_STATE.WAITING_RECONNECT then
            Logger.debug("[LOGIN]["..conn.id.."] SENDING RECONNECT")
            -- Send 'l' for reconnect
            table.insert(conn.outgoing, "l")
            self.step = LOGIN_STATE.COMPLETE

            return "RefreshCharacterState"
        elseif self.step == LOGIN_STATE.WAITING_WELCOME then
            -- Send menu choice '1'
            Logger.debug("[LOGIN]["..conn.id.."] SENDING MENU CHOICE 1")
            table.insert(conn.outgoing, "1")
            self.step = LOGIN_STATE.SENT_MENU_CHOICE
        elseif self.step == LOGIN_STATE.SENT_MENU_CHOICE then
            -- Login complete
            Logger.debug("[LOGIN]["..conn.id.."] LOGIN COMPLETE")
            self.step = LOGIN_STATE.COMPLETE

            return "RefreshCharacterState"
        end
    end,
}