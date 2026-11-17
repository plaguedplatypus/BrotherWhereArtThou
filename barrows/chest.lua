local bosses = require("barrows/bosses").displayOrder

local chest = {}

local function updateSlain(entry, run)
    local changed = false
    for _, boss in ipairs(bosses) do
        if run.slain[boss.id] and not entry.slain[boss.id] then
            entry.slain[boss.id] = true
            changed = true
        end
    end
    local showAkrisae = run.showAkrisae or entry.slain.akrisae == true
    local showLinza = run.showLinza or entry.slain.linza == true
    if entry.showAkrisae ~= showAkrisae or entry.showLinza ~= showLinza then
        entry.showAkrisae, entry.showLinza = showAkrisae, showLinza
        changed = true
    end
    return changed
end

-- Keep the largest quantity seen for each reward while the chest is open.
-- Bank All and Take All remove items from BARROWS_INV, so later snapshots
-- must not erase the reward already recorded for this run.
-- Return whether history changed and whether a new row was added.
function chest.capture(run)
    local invType = config.Inv.BARROWS_INV
    local inv = invType and Inventory.Find(invType)
    -- The live Inv proxy uses isValid; the published property list also names
    -- valid, but that value is absent in the current client.
    if not inv or not inv.isValid then return end

    local found, order = {}, {}
    local slots = inv:GetSlots() or {}
    for index = 1, inv.slotCount do
        local slot = slots[index]
        if slot and slot.obj and slot.obj.id > 0 and slot.count > 0 then
            local itemId = slot.obj.id
            if not found[itemId] then order[#order + 1] = itemId end
            found[itemId] = (found[itemId] or 0) + slot.count
        end
    end
    if not next(found) then return end

    local entry
    local newEntry = not run.lootCaptured
    if newEntry then
        entry = { items = {}, slain = {} }
        run.lootRuns[#run.lootRuns + 1] = entry
        run.lootCaptured = true
    else
        entry = run.lootRuns[#run.lootRuns]
        if not entry then return end -- Loot was cleared during this chest visit.
    end

    local items = entry.items
    local changed = updateSlain(entry, run) or #items == 0
    for _, item in ipairs(items) do
        local count = found[item.id]
        if count and count > item.count then
            item.count = count
            changed = true
        end
        found[item.id] = nil
    end
    for _, itemId in ipairs(order) do
        if found[itemId] then
            items[#items + 1] = { id = itemId, count = found[itemId] }
            changed = true
        end
    end
    return changed, newEntry
end

-- A final kill update may follow the chest inventory event. Keep only
-- confirmed kills, and never add a history row for an unrecorded quick loot.
function chest.recordSlain(run)
    if not run.lootCaptured then return end
    local entry = run.lootRuns[#run.lootRuns]
    return entry and updateSlain(entry, run)
end

return chest
