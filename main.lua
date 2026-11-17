local accountStore = require("barrows/accountStore")
local run = require("barrows/run")
local barrowsPanel = require("ui/barrowsPanel")
local dock = require("ui/dock")
local hoverTip = require("ui/hoverTip")
local loot = require("ui/loot")
local mounds = require("ui/mounds")
local puzzle = require("ui/puzzle")
local sarcophagus = require("ui/sarcophagus")
local tunnels = require("ui/tunnels")

local data = {}
accountStore.load(data)
local accountKey
local gameReady = Player.IsAvailable()

local pending = {}

-- Persist the shared run and rebuild the dock on the next logic tick.
local function save()
    accountStore.save(accountKey, data)
    dock.invalidate()
end

local function scanOverlays()
    mounds.scan()
    sarcophagus.scan()
    tunnels.scan()
end

-- Swap accounts before reading kill flags or processing queued dock actions.
-- Clearing overlay scans also removes the previous character's world marks.
local function setAccount(key)
    if key == accountKey then return end
    loot.destroy()
    accountKey = key
    accountStore.load(data, key)
    pending = {}
    dock.reset()
    run.reset(key ~= nil)
    scanOverlays()
end

-- UI callbacks queue changes so a component is never destroyed in its own hook.
local function queue(action)
    pending[#pending + 1] = action
end

run.start(data, save, dock.invalidate)
dock.start(data, run.status, queue, save)
mounds.start(data)
sarcophagus.start(data)
tunnels.start(data)

local function onLootInventory(event)
    if accountKey then run.onLootInventory(event) end
end
Event.InventoryAdded.Subscribe("barrowsLootAdded", onLootInventory)
Event.InventoryUpdated.Subscribe("barrowsLootUpdated", onLootInventory)

Event.VarTransmit.Subscribe("barrowsTunnelKills", function(event)
    run.onVarTransmit(event, queue)
end)
Event.MiniMenuEntrySelected.Subscribe("barrowsTunnelSarcophagus", run.onMenuSelected)
Event.GameStateChanged.Subscribe("barrowsTunnelGameState", function(event)
    if event.newState == GameState.GAME then
        gameReady = true
        run.requestSync()
    else
        gameReady = false
        setAccount(nil)
    end
end)
Event.ContentLayerReady.Subscribe("barrowsTunnelContent", function(event)
    dock.open(event.component)
end)
Event.Logic.Subscribe("barrowsTunnelLogic", function()
    dock.rememberScroll()
    setAccount(gameReady and accountStore.currentKey() or nil)
    if accountKey then
        if run.update() then scanOverlays() end
        local actions = pending
        pending = {}
        for _, action in ipairs(actions) do action() end
        run.captureOpenChest()
    else
        pending = {}
    end
    dock.update()
    loot.update(data.lootRuns)
    mounds.update()
    puzzle.update()
    sarcophagus.update()
    tunnels.update()
end)

log("Breaking into the crypt!")

-- Release event hooks and restore the game's Barrows panel on unload.
function PluginShutdown()
    barrowsPanel.restore()
    Event.InventoryAdded.Unsubscribe("barrowsLootAdded")
    Event.InventoryUpdated.Unsubscribe("barrowsLootUpdated")
    Event.VarTransmit.Unsubscribe("barrowsTunnelKills")
    Event.MiniMenuEntrySelected.Unsubscribe("barrowsTunnelSarcophagus")
    Event.GameStateChanged.Unsubscribe("barrowsTunnelGameState")
    Event.ContentLayerReady.Unsubscribe("barrowsTunnelContent")
    Event.Logic.Unsubscribe("barrowsTunnelLogic")
    mounds.stop()
    puzzle.stop()
    sarcophagus.stop()
    tunnels.stop()
    hoverTip.hide()
    loot.destroy()
    dock.stop()
    hoverTip.stop()
end
