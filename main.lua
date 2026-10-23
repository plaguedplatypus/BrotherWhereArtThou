-- This file owns saved run state and the dock. The world overlays share that
-- state; the puzzle reads its live interface, and barrowsPanel reads the game's
-- creature count.
local barrowsPanel = require("ui/barrowsPanel")
local mounds = require("ui/mounds")
local puzzle = require("ui/puzzle")
local sarcophagus = require("ui/sarcophagus")
local tunnels = require("ui/tunnels")
local storageName = "barrowsTunnelV1"
-- BARROWS_KILLS packs the six original brothers into separate low bits.
-- Akrisae and Linza use their own VarPlayers, so they have no masks here.
local brothers = {
    { id = "verac", name = "Verac", mask = 0x20 },
    { id = "akrisae", name = "Akrisae" },
    { id = "dharok", name = "Dharok", mask = 0x2 },
    { id = "ahrim", name = "Ahrim", mask = 0x1 },
    { id = "torag", name = "Torag", mask = 0x10 },
    { id = "guthan", name = "Guthan", mask = 0x4 },
    { id = "karil", name = "Karil", mask = 0x8 }
}
local dockOrder = {
    { id = "ahrim", name = "Ahrim" },
    { id = "torag", name = "Torag" },
    { id = "dharok", name = "Dharok" },
    { id = "verac", name = "Verac" },
    { id = "guthan", name = "Guthan" },
    { id = "karil", name = "Karil" },
    { id = "akrisae", name = "Akrisae" },
    { id = "linza", name = "Linza" }
}
local names = {}
for _, brother in ipairs(brothers) do names[brother.id] = brother.name end

local data = {
    selected = nil, slain = {}, showAkrisae = false, showLinza = false,
    chestOpen = false, linzaKills = 0, linzaCounted = false
}
local saved = PersistentDB:GetStructuredData(storageName)
if type(saved) == "table" then
    if names[saved.selected] then data.selected = saved.selected end
    if saved.showAkrisae == true then data.showAkrisae = true end
    if saved.showLinza == true then data.showLinza = true end
    if saved.chestOpen == true then data.chestOpen = true end
    if type(saved.linzaKills) == "number" and saved.linzaKills >= 0
        and saved.linzaKills < math.huge then
        data.linzaKills = math.floor(saved.linzaKills)
    end
    if saved.linzaCounted == true then data.linzaCounted = true end
    if type(saved.slain) == "table" then
        for id in pairs(names) do
            if saved.slain[id] == true then data.slain[id] = true end
        end
        if saved.slain.linza == true then data.slain.linza = true end
    end
end
if not data.showAkrisae then
    if data.selected == "akrisae" then data.selected = nil end
    data.slain.akrisae = nil
end

local contentParent, contentRoot, infoTip
local pending = {}
local contentDirty = true
local syncPending = true
local syncTicks = 0
local akrisaeQuestKnown, linzaQuestKnown = false, false
local waitingForReset = false
local sarcophagusTicks = 0
local pendingSarcophagus
local creatureCount

local function save()
    PersistentDB:SetStructuredData(storageName, data)
    contentDirty = true
end

-- UI callbacks queue changes so a component is never destroyed in its own hook.
local function queue(action)
    pending[#pending + 1] = action
end

local function text(parent, value, x, y, width, height)
    local label = ui.Text.new(parent)
    label:SetPos(x, y)
    label:SetSize(width, height)
    label.content = value
    label.font = id.Font.MUSEO_SANS_15PT_REGULAR
    label.maxLines = 2
    label.clickthrough = true
    return label
end

local function button(parent, label, x, y, width, height, action)
    local control = ui.Button.new(parent)
    control:SetPos(x, y)
    control:SetSize(width, height)
    control.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    control.label = label
    control:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
        queue(action)
    end)
    return control
end

-- Linza cannot lead to the tunnels. Once only one eligible brother remains,
-- that brother identifies the tunnel even before its prompt is seen.
local function remaining()
    local count, last = 0, nil
    for _, brother in ipairs(brothers) do
        if (brother.id ~= "akrisae" or data.showAkrisae) and not data.slain[brother.id] then
            count, last = count + 1, brother.id
        end
    end
    return count, last
end

-- Clear the current run while leaving the lifetime Linza count intact.
local function clearRun()
    data.selected = nil
    data.slain = {}
    data.chestOpen = false
    pendingSarcophagus = nil
    sarcophagusTicks = 0
    -- A manual clear can happen while the previous run's kill flags are set.
    waitingForReset = true
    save()
end

-- Reconcile the saved run with the game's kill flags and quest unlocks. The
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
            if not akrisaeQuestKnown then
                akrisaeQuestKnown = true
                contentDirty = true
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
            if not linzaQuestKnown then
                linzaQuestKnown = true
                contentDirty = true
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
    for _, brother in ipairs(brothers) do
        if brother.mask then
            local slain
            if kills then
                slain = math.floor(kills / brother.mask) % 2 == 1
            else
                local status = var.VarPlayer["BARROWS_KILLED_" .. brother.id:upper()]
                slain = status and status.value == 1
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
        -- Keep the counted bit across reloads and manual clears while the kill
        -- flag is set. It resets only when the game clears the flag.
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

local function redLine(parent, x, y, width, height, invert)
    local line = ui.Line.new(parent)
    line:SetPos(x, y)
    line:SetSize(width, height)
    line.invert = invert or false
    line.width = 2
    line.colour = Vector4.new(1, 0.15, 0.15, 1)
    line.clickthrough = true
    return line
end

local function hideInfoTip()
    if infoTip then infoTip:Destroy() end
    infoTip = nil
end

-- Put quest tooltips on the top-level plugin layer so the dock cannot clip them.
local function showInfoTip(icon, name, message)
    hideInfoTip()
    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    if not parent then return end
    local width, height = 248, 70
    local point, origin = icon.xyGlobal, parent.xyGlobal
    local x = math.max(4, math.min(parent.width - width - 4,
        math.floor(point.x - origin.x - width - 8)))
    local y = math.max(4, math.min(parent.height - height - 4,
        math.floor(point.y - origin.y - 6)))
    local tip = ui.Layer.new(parent)
    tip:SetPos(x, y)
    tip:SetSize(width, height)
    tip.clickthrough = true
    local backing = ui.Rectangle.new(tip)
    backing:SetSize(width, height)
    backing.fill = true
    backing.colour = Vector4.new(0.07, 0.06, 0.05, 1)
    backing.clickthrough = true
    local border = ui.Rectangle.new(tip)
    border:SetSize(width, height)
    border.fill = false
    border.outlineThickness = -1
    border.colour = Vector4.new(0.65, 0.52, 0.31, 1)
    border.clickthrough = true
    local heading = text(tip, name, 10, 6, width - 20, 20)
    heading.colour = Vector4.new(1, 0.86, 0.58, 1)
    text(tip, message, 10, 29, width - 20, 37)
    tip:MoveToFront()
    infoTip = tip
end

local function infoIcon(root, width, y, name, message)
    local icon = ui.Layer.new(root)
    icon:SetPos(width - 29, y + 1)
    icon:SetSize(18, 18)
    icon.clickthrough = false
    local sprite = ui.Sprite.new(icon)
    sprite:SetSize(18, 18)
    sprite.spriteID = id.Sprite.RS3_ICON_INFO_21PX_2
    sprite.clickthrough = true
    icon:Subscribe(ui.Hook.ONMOUSEOVER, function()
        showInfoTip(icon, name, message)
    end)
    icon:Subscribe(ui.Hook.ONMOUSELEAVE, hideInfoTip)
end

local function divider(root, width, y)
    local line = ui.Rectangle.new(root)
    line:SetPos(8, y)
    line:SetSize(width - 16, 1)
    line.fill = true
    line.colour = Vector4.new(0.37, 0.34, 0.29, 0.85)
    line.clickthrough = true
end

local function dockBosses(root, width)
    local cellWidth = math.floor((width - 16) / 3)
    local total, slain = 0, 0
    for index, boss in ipairs(dockOrder) do
        local x = 8 + ((index - 1) % 3) * cellWidth
        local y = 35 + math.floor((index - 1) / 3) * 18
        local unlocked = boss.id ~= "akrisae" or data.showAkrisae
        unlocked = unlocked and (boss.id ~= "linza" or data.showLinza)
        local selected = unlocked and data.selected == boss.id
        if unlocked then
            total = total + 1
            if data.slain[boss.id] then slain = slain + 1 end
        end
        if selected then
            local backing = ui.Rectangle.new(root)
            backing:SetPos(x - 3, y + 1)
            backing:SetSize(cellWidth + 2, 16)
            backing.fill = true
            backing.colour = Vector4.new(0.42, 0.29, 0.04, 0.50)
            backing.clickthrough = true

            local frame = ui.Rectangle.new(root)
            frame:SetPos(x - 3, y + 1)
            frame:SetSize(cellWidth + 2, 16)
            frame.fill = false
            frame.outlineThickness = 1
            frame.colour = Vector4.new(1, 0.78, 0.29, 1)
            frame.clickthrough = true
        end
        local mark = ui.Rectangle.new(root)
        mark:SetPos(x, y + 7)
        mark:SetSize(4, 4)
        mark.colour = unlocked and Vector4.new(0.92, 0.72, 0.34, 1)
            or Vector4.new(0.45, 0.44, 0.42, 1)
        mark.clickthrough = true
        local label = text(root, boss.name,
            x + 7, y, cellWidth - 7, 18)
        label.font = id.Font.NOTO_SANS_13PT_BOLD_OUTLINE
        label.maxLines = 1
        label.colour = selected and Vector4.new(1, 0.92, 0.56, 1)
            or data.slain[boss.id] and Vector4.new(0.65, 0.63, 0.61, 1)
            or not unlocked and Vector4.new(0.55, 0.53, 0.51, 1)
            or Vector4.new(1, 0.90, 0.68, 1)
        if data.slain[boss.id] then
            redLine(root, x + 7, y + 9, cellWidth - 10, 1)
        end
    end
    divider(root, width, 91)
    text(root, "Brothers slain: " .. slain .. "/" .. total, 8, 94, width - 16, 20)
    text(root, "Creatures slain: " .. (creatureCount or "?"), 8, 115, width - 16, 20)
    divider(root, width, 137)
end

local function overviewPage(root, width, height)
    dockBosses(root, width)
    if akrisaeQuestKnown then
        text(root, "Akrisae: " .. (data.showAkrisae and "Unlocked" or "Missing quest"),
            8, 139, width - 43, 23)
    else
        button(root, "Show Akrisae: " .. (data.showAkrisae and "On" or "Off"),
            8, 139, width - 43, 24, function()
                data.showAkrisae = not data.showAkrisae
                if not data.showAkrisae then
                    if data.selected == "akrisae" then data.selected = nil end
                    data.slain.akrisae = nil
                end
                save()
            end)
    end
    if linzaQuestKnown then
        text(root, "Linza: " .. (data.showLinza and "Unlocked" or "Missing quest"),
            8, 162, width - 43, 23)
    else
        button(root, "Show Linza: " .. (data.showLinza and "On" or "Off"),
            8, 162, width - 43, 24, function()
                data.showLinza = not data.showLinza
                save()
            end)
    end
    text(root, "Linza KC: " .. data.linzaKills, 8, 185, width - 16, 18)
    button(root, "Clear run", 8, height - 30, 100, 24, clearRun)
    infoIcon(root, width, 139, "Akrisae", "Requires Ritual of the Mahjarrat.")
    infoIcon(root, width, 162, "Linza",
        "Requires Kindred Spirits. Linza cannot lead underground.")
end

-- Rebuild the dock after state or size changes. UI actions are queued so the
-- old component tree is never destroyed from one of its own callbacks.
local function buildContent()
    if not contentParent then return end
    hideInfoTip()
    if contentRoot then contentRoot:Destroy() end
    local root = ui.Layer.new(contentParent)
    root:SetSize(contentParent.width, contentParent.height)
    contentRoot = root
    local width, height = contentParent.width, contentParent.height
    local title = text(root, "BROTHER WHERE ART THOU", 8, 5, width - 16, 18)
    title.font = id.Font.CINZEL_12PT_BOLD
    title.colour = Vector4.new(0.95, 0.75, 0.38, 1)
    title.alignVertical = ui.AlignMode.CENTRE
    title.maxLines = 1
    overviewPage(root, width, height)
    contentDirty = false
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
    log("Barrows Tunnel: tunnel confirmed at " .. names[mound])
end

mounds.start(data)
sarcophagus.start(data)
tunnels.start(data)

Event.VarTransmit.Subscribe("barrowsTunnelKills", function(event)
    local configName = event.var.configName
    if configName == "BARROWS_KILLS"
        or configName:match("^BARROWS_KILLED_%a+$")
        or configName == "MAH5_KILLED_BARROWS_AKRISAE"
        or configName == "SISTER_KILLED_LINZA" then
        queue(syncSlain)
    end
end)
-- A Search action names the brother, but its hidden-tunnel dialog arrives
-- later. Keep that brother for the logic poll and check again on Continue,
-- then discard it so another dialog cannot confirm the wrong sarcophagus.
Event.MiniMenuEntrySelected.Subscribe("barrowsTunnelSarcophagus", function(event)
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
            pendingSarcophagus = mound and names[mound] and mound or nil
            sarcophagusTicks = pendingSarcophagus and 500 or 0
        end
    elseif pendingSarcophagus and entry.componentData then
        local component = entry.componentData.component
        if component.interfaceID == 1186 and entry.verbText == "Continue" then
            checkTunnelPrompt()
            pendingSarcophagus = nil
            sarcophagusTicks = 0
        end
    end
end)
Event.GameStateChanged.Subscribe("barrowsTunnelGameState", function(event)
    if event.newState == GameState.GAME then syncPending = true end
end)
Event.ContentLayerReady.Subscribe("barrowsTunnelContent", function(event)
    hideInfoTip()
    contentParent = event.component
    contentRoot = nil
    contentDirty = true
end)
Event.Logic.Subscribe("barrowsTunnelLogic", function()
    local _, creatures = barrowsPanel.read()
    if creatures ~= nil and creatures ~= creatureCount then
        creatureCount = creatures
        contentDirty = true
    end
    if sarcophagusTicks > 0 then
        sarcophagusTicks = sarcophagusTicks - 1
        if sarcophagusTicks % 5 == 0 then checkTunnelPrompt() end
        if sarcophagusTicks == 0 then pendingSarcophagus = nil end
    end
    if syncPending then
        syncPending = false
        syncSlain()
    end
    -- A plugin reload can occur before the client has populated its VarPlayers.
    syncTicks = syncTicks + 1
    if syncTicks >= 50 then
        syncTicks = 0
        syncSlain()
        mounds.scan()
        sarcophagus.scan()
        tunnels.scan()
    end
    local actions = pending
    pending = {}
    for _, action in ipairs(actions) do action() end
    if contentParent and not ui.Interfaces:GetInterface(contentParent.interfaceID) then
        hideInfoTip()
        contentParent, contentRoot = nil, nil
    end
    if contentParent and (contentDirty or contentRoot.width ~= contentParent.width
        or contentRoot.height ~= contentParent.height) then buildContent() end
    mounds.update()
    puzzle.update()
    sarcophagus.update()
    tunnels.update()
end)

function PluginShutdown()
    barrowsPanel.restore()
    Event.VarTransmit.Unsubscribe("barrowsTunnelKills")
    Event.MiniMenuEntrySelected.Unsubscribe("barrowsTunnelSarcophagus")
    Event.GameStateChanged.Unsubscribe("barrowsTunnelGameState")
    Event.ContentLayerReady.Unsubscribe("barrowsTunnelContent")
    Event.Logic.Unsubscribe("barrowsTunnelLogic")
    mounds.stop()
    puzzle.stop()
    sarcophagus.stop()
    tunnels.stop()
    hideInfoTip()
    if contentRoot then contentRoot:Destroy() end
end
