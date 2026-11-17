local bosses = require("barrows/bosses")
local chest = require("barrows/chest")
local barrowsPanel = require("ui/barrowsPanel")
local loot = require("ui/loot")

local run = {}
-- The dock reads this status. A nil count means the game has yet to supply it.
local status = { akrisaeQuestKnown = false, linzaQuestKnown = false }
run.status = status
local data, save, invalidate
local sarcophagusTimeoutTicks = 500
local sarcophagusPollTicks = 5
local resyncIntervalTicks = 50
local killsPerPrestige = 60000
local syncPending = true
local syncTicks = 0
local waitingForReset = false
local sarcophagusTicks = 0
local pendingSarcophagus

-- Linza cannot lead to the tunnels. Once only one eligible brother remains,
-- that brother identifies the tunnel even before its prompt is seen.
local function remaining()
    local count, last = 0, nil
    for _, brother in ipairs(bosses.tunnelOrder) do
        if (brother.id ~= "akrisae" or data.showAkrisae) and not data.slain[brother.id] then
            count, last = count + 1, brother.id
        end
    end
    return count, last
end

-- Reset the run after the chest closes, keeping Linza KC and chest history.
local function clearRun()
    -- Inventory updates can arrive before the last kill flag is reconciled.
    -- Save the final slain list before resetting the live run.
    if chest.recordSlain(data) then loot.invalidate() end
    data.selected = nil
    data.slain = {}
    data.chestOpen = false
    data.lootCaptured = false
    pendingSarcophagus = nil
    sarcophagusTicks = 0
    -- Wait for separate boss flags to clear before accepting the next run.
    waitingForReset = true
    save()
end

-- Reconcile the saved run with the game's kill flags and quest unlocks. Both
-- optional bosses follow their quests rather than manual settings. The
-- 0x10000 bit marks an opened chest; the packed count starting at 0x20000 is a
-- fallback for Akrisae when his own flag is unavailable. Run this after reload
-- too, since VarTransmit may not send the current values.
local function syncSlain()
    local killsVar = var.VarPlayer.BARROWS_KILLS
    local kills = killsVar and killsVar.value
    local akrisaeFlag = var.VarPlayer.MAH5_KILLED_BARROWS_AKRISAE
    local akrisaeKilled = akrisaeFlag and akrisaeFlag.value
    local linzaFlag = var.VarPlayer.SISTER_KILLED_LINZA
    local linzaKilled = linzaFlag and linzaFlag.value
    local changed = false
    local playerAvailable = Player.IsAvailable()
    if playerAvailable and kills ~= nil then
        local chestOpen = math.floor(kills / 0x10000) % 2 == 1
        if chestOpen and not waitingForReset and not data.chestOpen then
            data.chestOpen = true
            changed = true
        elseif not chestOpen and kills == 0 and data.chestOpen then
            -- The chest bit rises before the final brother spawns. The run ends
            -- when the chest closes and the game's packed kill flags reset.
            clearRun()
            return
        end
    end
    if playerAvailable then
        local ritual = config.Quest.FromID(194)
        if ritual and ritual.name == "Ritual of the Mahjarrat"
            and ritual.hasFinishedQuest ~= nil then
            if not status.akrisaeQuestKnown then
                status.akrisaeQuestKnown = true
                invalidate()
            end
            if data.showAkrisae ~= ritual.hasFinishedQuest then
                data.showAkrisae = ritual.hasFinishedQuest
                if not data.showAkrisae then
                    if data.selected == "akrisae" then data.selected = nil end
                    data.slain.akrisae = nil
                end
                changed = true
            end
        end
        local kindred = config.Quest.FromID(384)
        if kindred and kindred.name == "Kindred Spirits"
            and kindred.hasFinishedQuest ~= nil then
            if not status.linzaQuestKnown then
                status.linzaQuestKnown = true
                invalidate()
            end
            if data.showLinza ~= kindred.hasFinishedQuest then
                data.showLinza = kindred.hasFinishedQuest
                if not data.showLinza then data.slain.linza = nil end
                changed = true
            end
        end
    end
    if waitingForReset then
        if not playerAvailable or kills ~= 0
            or akrisaeKilled == 1 or linzaKilled == 1 then
            if changed then save() end
            return
        end
        waitingForReset = false
    end
    local originalCount = 0
    for _, brother in ipairs(bosses.tunnelOrder) do
        if brother.mask then
            local slain
            if kills then
                slain = math.floor(kills / brother.mask) % 2 == 1
            else
                local flag = var.VarPlayer["BARROWS_KILLED_" .. brother.id:upper()]
                slain = flag and flag.value == 1
            end
            if slain then
                originalCount = originalCount + 1
                if not data.slain[brother.id] then
                    data.slain[brother.id] = true
                    changed = true
                end
            end
        end
    end
    if data.showAkrisae then
        local slain
        if akrisaeKilled ~= nil then
            -- This bit was observed as 0 on a fresh run and 1 after his kill.
            slain = akrisaeKilled == 1
        elseif kills and not data.showLinza then
            -- Linza also raises the packed count, so this fallback needs her hidden.
            slain = math.floor(kills / 0x20000) > originalCount
        end
        if slain ~= nil and slain ~= (data.slain.akrisae == true) then
            data.slain.akrisae = slain or nil
            changed = true
        end
    end
    if linzaKilled ~= nil then
        -- This bit reset to 0 on a fresh run after being 1 for Linza's kill.
        local slain = linzaKilled == 1
        -- Keep the counted bit across reloads while the kill flag is set.
        -- It resets only when the game clears the flag.
        if playerAvailable and slain and not data.linzaCounted then
            data.linzaKills = data.linzaKills + 1
            data.linzaCounted = true
            changed = true
        elseif playerAvailable and not slain and data.linzaCounted then
            data.linzaCounted = false
            changed = true
        end
        if slain ~= (data.slain.linza == true) then
            data.slain.linza = slain or nil
            changed = true
        end
    end
    if changed then
        if not data.selected then
            local count, last = remaining()
            if count == 1 then data.selected = last end
        end
        save()
    end
end

-- The Beasts counter resets at 60,000 when prestiged. Include completed
-- prestiges so this dock readout remains a lifetime Barrows Brothers KC.
local function syncBarrowsCount()
    local killsVar = var.VarPlayer.BSLAY_KILLS_BARROWS
    local prestigeVar = var.VarPlayer.BSLAY_PRESTIGE_BARROWS
    local kills = killsVar and killsVar.value
    local prestige = prestigeVar and prestigeVar.value
    if kills == nil or prestige == nil then return end
    local count = kills + prestige * killsPerPrestige
    if count ~= status.barrowsCount then
        status.barrowsCount = count
        invalidate()
    end
end

-- A sarcophagus search alone does not confirm the tunnel. Wait for the game's
-- hidden-tunnel prompt before assigning it to that brother.
local function checkTunnelPrompt()
    if not pendingSarcophagus then return end
    -- The hidden-tunnel prompt was observed on label 3 of interface 1186.
    local prompt = ui.Interfaces:GetComponent(1186, 3)
    if not prompt or prompt.type ~= ui.ComponentType.LABEL
        or not prompt.visibleGlobal
        or not prompt.content:lower():find("hidden tunnel", 1, true) then
        return
    end
    local mound = pendingSarcophagus
    pendingSarcophagus = nil
    sarcophagusTicks = 0
    if data.selected ~= mound then
        data.selected = mound
        save()
    end
end

function run.start(sharedData, saveRun, invalidateDock)
    data, save, invalidate = sharedData, saveRun, invalidateDock
end

-- Account changes clear transient readings. The account store reloads data in place.
function run.reset(hasAccount)
    syncPending = hasAccount
    syncTicks = 0
    status.akrisaeQuestKnown, status.linzaQuestKnown = false, false
    waitingForReset = false
    pendingSarcophagus, sarcophagusTicks = nil, 0
    status.creatureCount, status.barrowsCount = nil, nil
end

function run.requestSync()
    syncPending = true
end

local function captureChest()
    local changed, newEntry = chest.capture(data)
    if newEntry then loot.resetScroll() end
    if changed then
        loot.invalidate()
        save()
    end
end

-- BARROWS_INV is populated before Bank All or Take All empties it. Capture
-- the server update immediately so a quick claim cannot skip the reward.
function run.onLootInventory(event)
    if event.inv.configName == "BARROWS_INV" then
        captureChest()
    end
end

function run.onVarTransmit(event, queue)
    local configName = event.var.configName
    if configName == "BARROWS_KILLS"
        or configName:match("^BARROWS_KILLED_%a+$")
        or configName == "MAH5_KILLED_BARROWS_AKRISAE"
        or configName == "SISTER_KILLED_LINZA" then
        queue(syncSlain)
    elseif configName == "BSLAY_KILLS_BARROWS"
        or configName == "BSLAY_PRESTIGE_BARROWS" then
        queue(syncBarrowsCount)
    end
end

-- A Search action names the brother, but its hidden-tunnel dialog arrives
-- later. Keep that brother for the logic poll and check again on Continue,
-- then discard it so another dialog cannot confirm the wrong sarcophagus.
function run.onMenuSelected(event)
    local entry = event.entry
    if entry.actionEntryType == MiniMenuEntryType.LOC
        and entry.verbText == "Search"
        and entry.subjectText:find("Sarcophagus", 1, true) then
        local loc = entry.locData
        if loc then
            local configName = loc.config.configName
            local brother = configName:match("^BARROWS_IMP_(%u+)_SARCOPHAGUS$")
                or configName:match("^MAH5_BARROW_(%u+)_SARCOPHAGUS$")
            local mound = brother and brother:lower()
            pendingSarcophagus = bosses.byId[mound] and mound ~= "linza" and mound or nil
            sarcophagusTicks = pendingSarcophagus and sarcophagusTimeoutTicks or 0
        end
    elseif pendingSarcophagus and entry.componentData then
        local component = entry.componentData.component
        if component.interfaceID == 1186 and entry.verbText == "Continue" then
            checkTunnelPrompt()
            pendingSarcophagus = nil
            sarcophagusTicks = 0
        end
    end
end

-- Return true when the periodic world overlay scans are due.
function run.update()
    local creatures = barrowsPanel.read()
    if creatures ~= nil and creatures ~= status.creatureCount then
        status.creatureCount = creatures
        invalidate()
    end
    if sarcophagusTicks > 0 then
        sarcophagusTicks = sarcophagusTicks - 1
        if sarcophagusTicks % sarcophagusPollTicks == 0 then checkTunnelPrompt() end
        if sarcophagusTicks == 0 then pendingSarcophagus = nil end
    end
    if syncPending then
        syncPending = false
        syncSlain()
        syncBarrowsCount()
    end
    -- A plugin reload can occur before the client has populated its VarPlayers.
    syncTicks = syncTicks + 1
    if syncTicks >= resyncIntervalTicks then
        syncTicks = 0
        syncSlain()
        syncBarrowsCount()
        return true
    end
end

function run.captureOpenChest()
    if data.chestOpen then captureChest() end
end

return run
