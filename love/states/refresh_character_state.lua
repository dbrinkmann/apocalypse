local Logger = require("logger")
require("helpers")

local REFRESH_CHARACTER_STATE = {
    START = 0,
    READING = 1,
    PROCESSING = 2,
    COMPLETE = 3
}

-- Define line patterns and their processing functions
local ATT_LINE_PATTERNS = {
    [1] = {pattern = "=================================%[Condition%]=================================", process = function() end},
    [2] = {pattern = "Class: (%w+) %((%w+)%)%s+Race: (%w+)%s+Size: (%w+)", 
           process = function(conn, connectionStateTable, class, subclass, race, size)
               connectionStateTable.localView.characterStats.class = class
               connectionStateTable.localView.characterStats.subclass = subclass
               connectionStateTable.localView.characterStats.race = race
               connectionStateTable.localView.characterStats.size = size
           end},
    [3] = {pattern = "Sex: (%w+)%s+Age: (%-?%d+)%((%-?%d+)%)%s+Years%s+(%-?%d+)%s+Months%s+(%-?%d+)%s+Days",
           process = function(conn, connectionStateTable, sex, age, maxAge, years, months, days)
               connectionStateTable.localView.characterStats.sex = sex
               connectionStateTable.localView.characterStats.age = tonumber(age)
               connectionStateTable.localView.characterStats.maxAge = tonumber(maxAge)
           end},
    [4] = {pattern = "Carried Weight: (%-?%d+) lbs%s+Items Carried: (%-?%d+)",
           process = function(conn, connectionStateTable, weight, items)
               connectionStateTable.localView.characterStats.weight = tonumber(weight)
               connectionStateTable.localView.characterStats.items = tonumber(items)
           end},
    [5] = {pattern = "Hunger: (%-?%d+)%s+Thirst: (%-?%d+)%s+Drunk: (%-?%d+)",
           process = function(conn, connectionStateTable, hunger, thirst, drunk)
               connectionStateTable.localView.characterStats.hunger = tonumber(hunger)
               connectionStateTable.localView.characterStats.thirst = tonumber(thirst)
               connectionStateTable.localView.characterStats.drunk = tonumber(drunk)
           end},
    [6] = {pattern = "CharacterTrait: %[(.+)%]",
           process = function(conn, connectionStateTable, trait)
               connectionStateTable.localView.characterStats.trait = trait
           end},
    [7] = {pattern = "Trait Effect:%s+%[(.+)%]",
           process = function(conn, connectionStateTable, effect)
               connectionStateTable.localView.characterStats.traitEffect = effect
           end},
    [8] = {pattern = "==================================%[H/M/V%]===================================", process = function() end},
    [9] = {pattern = "You have %[(%-?%d+)/(%-?%d+)%] HP, %[(%-?%d+)/(%-?%d+)%] Mana, and %[(%-?%d+)/(%-?%d+)%] V",
           process = function(conn, connectionStateTable, hp, maxHp, mana, maxMana, vitality, maxVitality)
               connectionStateTable.localView.characterStats.hp.current = tonumber(hp)
               connectionStateTable.localView.characterStats.hp.max = tonumber(maxHp)
               connectionStateTable.localView.characterStats.mana.current = tonumber(mana)
               connectionStateTable.localView.characterStats.mana.max = tonumber(maxMana)
               connectionStateTable.localView.characterStats.vitality.current = tonumber(vitality)
               connectionStateTable.localView.characterStats.vitality.max = tonumber(maxVitality)
           end},
    [10] = {pattern = "Gains per tick: %+(%-?%d+) HP, %+(%-?%d+) Mana, and %+(%-?%d+) V",
            process = function(conn, connectionStateTable, hpGain, manaGain, vitalityGain)
                connectionStateTable.localView.characterStats.hp.gain = tonumber(hpGain)
                connectionStateTable.localView.characterStats.mana.gain = tonumber(manaGain)
                connectionStateTable.localView.characterStats.vitality.gain = tonumber(vitalityGain)
            end},
    [11] = {pattern = "==============================%[Physical Combat%]==============================", process = function() end},
    [12] = {pattern = "You have (%-?%d+) armor points and your AC is (%-?%d+) %((%-?%d+) to (%-?%d+) scale%)%.",
            process = function(conn, connectionStateTable, armor, ac, minAc, maxAc)
                connectionStateTable.localView.characterStats.armor = tonumber(armor)
                connectionStateTable.localView.characterStats.ac = tonumber(ac)
                connectionStateTable.localView.characterStats.acRange = {min = tonumber(minAc), max = tonumber(maxAc)}
            end},
    [13] = {pattern = "Your base Thac0 is (%-?%d+) with (%-?%d+) Hit and (%-?%d+) Damage bonuses%.",
            process = function(conn, connectionStateTable, thac0, hitBonus, damageBonus)
                connectionStateTable.localView.characterStats.thac0 = tonumber(thac0)
                connectionStateTable.localView.characterStats.hitBonus = tonumber(hitBonus)
                connectionStateTable.localView.characterStats.damageBonus = tonumber(damageBonus)
            end},
    [14] = {pattern = "Weapon Proficiency Bonus:%s+Primary %[%+?(%-?%d+)/%+?(%-?%d+)%]%s+Secondary %[%+?(%-?%d+)/%+?(%-?%d+)%]",
            process = function(conn, connectionStateTable, primaryHit, primaryDamage, secondaryHit, secondaryDamage)
                connectionStateTable.localView.characterStats.weaponProficiency = {
                    primary = {hit = tonumber(primaryHit), damage = tonumber(primaryDamage)},
                    secondary = {hit = tonumber(secondaryHit), damage = tonumber(secondaryDamage)}
                }
            end},
    [15] = {pattern = "Attacks: (%-?%d+) attacks %((%-?%d+) rounds%)%.%s+Crit Damage:%+(%-?%d+)%%%s+Crit Chance: (%-?%d+)%%",
            process = function(conn, connectionStateTable, attacks, rounds, critDamage, critChance)
                connectionStateTable.localView.characterStats.attacks = {
                    count = tonumber(attacks),
                    rounds = tonumber(rounds),
                    critDamage = tonumber(critDamage),
                    critChance = tonumber(critChance)
                }
            end},
    [16] = {pattern = "===============================%[Ability Score%]===============================", process = function() end},
    [17] = {pattern = "Maximum Abilities:%s+Str%[(%-?%d+)%]%s+Int%[(%-?%d+)%]%s+Wis%[(%-?%d+)%]%s+Dex%[(%-?%d+)%]%s+Con%[(%-?%d+)%]%s+Char%[(%-?%d+)%]",
            process = function(conn, connectionStateTable, str, int, wis, dex, con, char)
                connectionStateTable.localView.characterStats.abilities = {
                    max = {
                        str = tonumber(str),
                        int = tonumber(int),
                        wis = tonumber(wis),
                        dex = tonumber(dex),
                        con = tonumber(con),
                        char = tonumber(char)
                    }
                }
            end},
    [18] = {pattern = "Modified Abilities:%s+Str%[(%-?%d+)%]%s+Int%[(%-?%d+)%]%s+Wis%[(%-?%d+)%]%s+Dex%[(%-?%d+)%]%s+Con%[(%-?%d+)%]%s+Char%[(%-?%d+)%]",
            process = function(conn, connectionStateTable, str, int, wis, dex, con, char)
                connectionStateTable.localView.characterStats.abilities.modified = {
                    str = tonumber(str),
                    int = tonumber(int),
                    wis = tonumber(wis),
                    dex = tonumber(dex),
                    con = tonumber(con),
                    char = tonumber(char)
                }
            end},
    [19] = {pattern = "Natural Abilities:%s+Str%[(%-?%d+)%]%s+Int%[(%-?%d+)%]%s+Wis%[(%-?%d+)%]%s+Dex%[(%-?%d+)%]%s+Con%[(%-?%d+)%]%s+Char%[(%-?%d+)%]",
            process = function(conn, connectionStateTable, str, int, wis, dex, con, char)
                connectionStateTable.localView.characterStats.abilities.natural = {
                    str = tonumber(str),
                    int = tonumber(int),
                    wis = tonumber(wis),
                    dex = tonumber(dex),
                    con = tonumber(con),
                    char = tonumber(char)
                }
            end},
    [20] = {pattern = "===============================%[Saving Throws%]===============================", process = function() end},
    [21] = {pattern = "Saving Throws:%s+Para%[(%-?%d+)%]%s+Rod%[(%-?%d+)%]%s+Petr%[(%-?%d+)%]%s+Breath%[(%-?%d+)%]%s+Spell%[(%-?%d+)%]",
            process = function(conn, connectionStateTable, para, rod, petr, breath, spell)
                connectionStateTable.localView.characterStats.savingThrows = {
                    para = tonumber(para),
                    rod = tonumber(rod),
                    petr = tonumber(petr),
                    breath = tonumber(breath),
                    spell = tonumber(spell)
                }
            end},
    [22] = {pattern = "==============================%[Spell Modifiers%]==============================", process = function() end},
    [23] = {pattern = "Fire:%s+(%-?%d+)%s+Elec:%s+(%-?%d+)%s+Sonc:%s+(%-?%d+)%s+Pois:%s+(%-?%d+)%s+Cold:%s+(%-?%d+)%s+Acid:%s+(%-?%d+)%s+Gas%s+:%s+(%-?%d+)",
            process = function(conn, connectionStateTable, fire, elec, sonc, pois, cold, acid, gas)
                connectionStateTable.localView.characterStats.spellModifiers = {
                    fire = tonumber(fire),
                    elec = tonumber(elec),
                    sonc = tonumber(sonc),
                    pois = tonumber(pois),
                    cold = tonumber(cold),
                    acid = tonumber(acid),
                    gas = tonumber(gas)
                }
            end},
    [24] = {pattern = "Divn:%s+(%-?%d+)%s+Lght:%s+(%-?%d+)%s+Sumn:%s+(%-?%d+)%s+Life:%s+(%-?%d+)%s+Fear:%s+(%-?%d+)%s+Shdw:%s+(%-?%d+)%s+Heal:%s+(%-?%d+)",
            process = function(conn, connectionStateTable, divn, lght, sumn, life, fear, shdw, heal)
                connectionStateTable.localView.characterStats.spellModifiers = connectionStateTable.localView.characterStats.spellModifiers or {}
                connectionStateTable.localView.characterStats.spellModifiers.divn = tonumber(divn)
                connectionStateTable.localView.characterStats.spellModifiers.lght = tonumber(lght)
                connectionStateTable.localView.characterStats.spellModifiers.sumn = tonumber(sumn)
                connectionStateTable.localView.characterStats.spellModifiers.life = tonumber(life)
                connectionStateTable.localView.characterStats.spellModifiers.fear = tonumber(fear)
                connectionStateTable.localView.characterStats.spellModifiers.shdw = tonumber(shdw)
                connectionStateTable.localView.characterStats.spellModifiers.heal = tonumber(heal)
            end},
    [25] = {pattern = "All%-Spell Damage:%s+(%-?%d+)%s+Crit Damage:%+(%-?%d+)%%%s+Crit Chance:%s+(%-?%d+)%%",
            process = function(conn, connectionStateTable, damage, critDamage, critChance)
                connectionStateTable.localView.characterStats.spellModifiers = connectionStateTable.localView.characterStats.spellModifiers or {}
                connectionStateTable.localView.characterStats.spellModifiers.allDamage = tonumber(damage)
                connectionStateTable.localView.characterStats.spellModifiers.critDamage = tonumber(critDamage)
                connectionStateTable.localView.characterStats.spellModifiers.critChance = tonumber(critChance)
            end},
    [26] = {pattern = "==========================%[Elemental Resistances%]===========================", process = function() end},
    [27] = {pattern = "Fire:%s+(%-?%d+)%s+Elec:%s+(%-?%d+)%s+Sonc:%s+(%-?%d+)%s+Pois:%s+(%-?%d+)%s+Cold:%s+(%-?%d+)%s+Acid:%s+(%-?%d+)%s+Gas%s+:%s+(%-?%d+)",
            process = function(conn, connectionStateTable, fire, elec, sonc, pois, cold, acid, gas)
                connectionStateTable.localView.characterStats.elementalResistances = {
                    fire = tonumber(fire),
                    elec = tonumber(elec),
                    sonc = tonumber(sonc),
                    pois = tonumber(pois),
                    cold = tonumber(cold),
                    acid = tonumber(acid),
                    gas = tonumber(gas)
                }
            end},
    [28] = {pattern = "Lght:(%-?%d+)%s+Sumn:%s*(%-?%d+)%s+Life:%s*(%-?%d+)%s+Fear:%s*(%-?%d+)%s+Shdw:%s*(%-?%d+)%s+Divn:%s*(%-?%d+)",
            process = function(conn, connectionStateTable, lght, sumn, life, fear, shdw, divn)
                connectionStateTable.localView.characterStats.elementalResistances = connectionStateTable.localView.characterStats.elementalResistances or {}
                connectionStateTable.localView.characterStats.elementalResistances.lght = tonumber(lght)
                connectionStateTable.localView.characterStats.elementalResistances.sumn = tonumber(sumn)
                connectionStateTable.localView.characterStats.elementalResistances.life = tonumber(life)
                connectionStateTable.localView.characterStats.elementalResistances.fear = tonumber(fear)
                connectionStateTable.localView.characterStats.elementalResistances.shdw = tonumber(shdw)
                connectionStateTable.localView.characterStats.elementalResistances.divn = tonumber(divn)
            end},
    [29] = {pattern = "============================%[Physical Resistances%]=============================", process = function() end},
    [30] = {pattern = "Slsh:%s+(%-?%d+)%s+Pier:%s+(%-?%d+)%s+Blgn:%s+(%-?%d+)%s+Lgnd:%s+(%-?%d+)",
            process = function(conn, connectionStateTable, slsh, pier, blgn, lgnd)
                connectionStateTable.localView.characterStats.physicalResistances = {
                    slsh = tonumber(slsh),
                    pier = tonumber(pier),
                    blgn = tonumber(blgn),
                    lgnd = tonumber(lgnd)
                }
            end},
    [31] = {pattern = "=================================%[Followers%]===================================", process = function() end},
    [32] = {pattern = "You are being followed by:",
            process = function() end},
    [33] = {pattern = "Total levels of charmies:",
            process = function() end}
}

CharacterStates.RefreshCharacterState = {
    name = "RefreshCharacterState",
    display = "Refreshing Stats",
    step = REFRESH_CHARACTER_STATE.START,
    currentLine = 1,

    init = function(self, conn, connectionStateTable)
        self.currentLine = 1
    end,

    -- Returns table with new states or nil if no new state and a boolean if we should remove the message for display
    update = function(self, conn, connectionStateTable, message)
        if self.step == REFRESH_CHARACTER_STATE.START then
            table.insert(conn.outgoing, "att")
            self.step = REFRESH_CHARACTER_STATE.READING
            Logger.debug("[REFRESH_CHARACTER_STATE]["..conn.id.."] SENDING ATT")
        elseif self.step == REFRESH_CHARACTER_STATE.READING then
            if message then
                local clean_msg = strip_ansi(message)
                --Logger.debug("[Parser] Clean message: " .. clean_msg)
                
                if clean_msg:match("=================================%[Condition%]=================================") then
                    self.step = REFRESH_CHARACTER_STATE.PROCESSING
                    self.currentLine = self.currentLine + 1
                    --Logger.debug("[REFRESH_CHARACTER_STATE]["..conn.id.."] FOUND CONDITION HEADER")
                    return {newState = nil, removeMessage = true}
                end
            end
        elseif self.step == REFRESH_CHARACTER_STATE.PROCESSING then
            if message then
                local clean_msg = strip_ansi(message)
                --Logger.debug("[Parser] Clean message: " .. clean_msg)
                
                -- Get the pattern for current line
                local linePattern = ATT_LINE_PATTERNS[self.currentLine]
                if linePattern then
                    local matches = {clean_msg:match(linePattern.pattern)}
                    if #matches > 0 then
                        --Logger.debug("[REFRESH_CHARACTER_STATE]["..conn.id.."] MATCH "..linePattern.pattern)
                        -- Call the processing function with all matches
                        linePattern.process(conn, connectionStateTable, unpack(matches))
                        self.currentLine = self.currentLine + 1
                        
                        -- If we've processed all lines, move to complete state
                        if self.currentLine > #ATT_LINE_PATTERNS then
                            self.step = REFRESH_CHARACTER_STATE.COMPLETE
                            Logger.debug("[REFRESH_CHARACTER_STATE]["..conn.id.."] COMPLETE")
                            return {newState = "Idle", removeMessage = true}
                        end

                        return {newState = nil, removeMessage = true}
                    else
                        Logger.debug("[ERROR][REFRESH_CHARACTER_STATE]["..conn.id.."] NO MATCH "..linePattern.pattern)
                    end
                end
            end
        end
        
        return {newState = nil, removeMessage = false}
    end
}