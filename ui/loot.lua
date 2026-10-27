local hoverTip = require("ui/hoverTip")

local loot = {}
local window, tabs
local runs
local isOpen = false
local dirty = false
local activeTab = 1
local scrollY = { 0, 0 }
local shownWidth, shownHeight
local resizeWait = 0
local scrollStep = 36

-- Keep the largest quantity seen for each reward while the chest is open.
-- Bank All and Take All remove items from BARROWS_INV, so later snapshots
-- must not erase the reward already recorded for this run.
function loot.capture(run, save)
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

    local items
    if run.lootCaptured then
        items = run.lootRuns[#run.lootRuns]
        if not items then return end -- Loot was cleared during this chest visit.
    else
        items = {}
        run.lootRuns[#run.lootRuns + 1] = items
        run.lootCaptured = true
        loot.resetScroll()
    end

    local changed = #items == 0
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
    if changed then
        dirty = true
        save()
    end
end

-- Start a different character or a new chest at the top of both lists.
function loot.resetScroll()
    scrollY[1], scrollY[2] = 0, 0
    if tabs then
        hoverTip.hide()
        tabs:GetPage(1):SetScrollPosition(0)
        tabs:GetPage(2):SetScrollPosition(0)
    end
end

-- PrettyUI owns the tab pages and scrollbars; the loot slots have no drag hooks.
local function clearTabs()
    if not tabs then return end
    hoverTip.hide()
    for index = 1, 2 do
        scrollY[index] = tabs:GetPage(index).scrollY or 0
    end
    tabs:Destroy()
    tabs = nil
end

-- Close the independent loot window when changing accounts or unloading.
function loot.destroy()
    clearTabs()
    if window then window:Destroy() end
    window, runs = nil, nil
    isOpen, dirty = false, false
    activeTab, scrollY = 1, { 0, 0 }
    shownWidth, shownHeight = nil, nil
    resizeWait = 0
end

-- The game can remove the interface before Lua sees it. Release PrettyUI's
-- scroll hooks without trying to destroy children the game already removed.
local function forget()
    hoverTip.hide()
    if tabs then pcall(tabs.Destroy, tabs) end
    window, tabs, runs = nil, nil, nil
    isOpen = false
    shownWidth, shownHeight = nil, nil
end

-- One canvas draws empty and filled slot backgrounds without native children.
-- Only real items need a sprite and mouse hooks; none need drag listeners.
local function gridHeight(count, columns)
    local rows = math.ceil(count / columns)
    return rows * 40 + math.max(0, rows - 1) * 2
end

local function addGrid(page, canvas, items, columns, top)
    local slotSize, gap, inset = 40, 2, 14
    local rows = math.ceil(#items / columns)
    local function onWheel(_, delta)
        hoverTip.hide()
        local previous = page.scrollY
        page:ScrollBy(delta * scrollStep)
        return page.scrollY == previous
    end
    for index = 1, rows * columns do
        local x = inset + ((index - 1) % columns) * (slotSize + gap)
        local y = top + math.floor((index - 1) / columns) * (slotSize + gap)
        canvas:AddSprite(x, y, slotSize, slotSize,
            id.Sprite.RS3_ICON_SLOT_40PX_1, 0xFFFFFFFF)

        local item = items[index]
        if item then
            local obj = config.Obj.FromID(math.floor(item.id))
            if obj then
                local slot = ui.Layer.new(page.content)
                slot:SetPos(x, y)
                slot:SetSize(slotSize, slotSize)
                local sprite = ui.Sprite.new(slot)
                sprite:SetPos(4, 4)
                sprite:SetSize(32, 32)
                sprite:SetAssociatedObject(math.tointeger(obj.id))
                sprite.associatedObjectQuantity = math.tointeger(item.count)
                sprite.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.MULTIPLE
                sprite.clickthrough = true

                local label = (obj.name or "Unknown item") .. " x" .. item.count
                -- Hovered slots must forward wheel input to their scrollable tab.
                slot:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
                slot:Subscribe(ui.Hook.ONMOUSEOVER, function()
                    -- A scrolled child's xyGlobal does not reflect the viewport offset.
                    local point = page.viewport.xyGlobal
                    hoverTip.show(point.x + x, point.y + y - page.scrollY,
                        slotSize, slotSize, label, 190)
                    return true
                end)
                slot:Subscribe(ui.Hook.ONMOUSELEAVE, function()
                    hoverTip.hide()
                    return true
                end)
            end
        end
    end
    return top + gridHeight(#items, columns)
end

-- Each run records its largest chest snapshot; sum those saved quantities
-- without changing the history used by the Per Run tab.
local function combinedItems()
    local items, byId = {}, {}
    for runIndex = #runs, 1, -1 do
        for _, item in ipairs(runs[runIndex]) do
            local total = byId[item.id]
            if total then
                total.count = total.count + item.count
            else
                total = { id = item.id, count = item.count }
                byId[item.id] = total
                items[#items + 1] = total
            end
        end
    end
    return items
end

-- Rebuild the two pages when loot or the window width changes.
local function build()
    clearTabs()
    local width, height = window.viewport.width, window.viewport.height
    local columns = math.max(1, math.floor((width - 32) / 38))
    tabs = window:AddTabs({
        { text = "Per Run" }, { text = "Combined" }
    }, {
        height = math.max(1, height - 16),
        activeIndex = activeTab,
        scrollStep = scrollStep,
        -- PrettyUI's default tab-page inset leaves extra space below the tabs.
        contentLayout = { startY = 4 },
        onChange = function(_, index)
            hoverTip.hide()
            activeTab = index
        end
    })

    local perRun = tabs:GetPage(1)
    if #runs == 0 then
        perRun:AddText("No Barrows chest loot recorded yet.")
    else
        local cols = math.min(6, columns)
        local contentHeight = 4
        for _, items in ipairs(runs) do
            contentHeight = contentHeight + 24 + gridHeight(#items, cols) + 24
        end
        contentHeight = contentHeight - 24 + 14
        local canvas = ui.Canvas.new(perRun.content)
        canvas:SetSize(width, contentHeight)
        canvas.clickthrough = true
        local y = 4
        for index = #runs, 1, -1 do
            local items = runs[index]
            perRun:AddTitle({ text = "Run " .. index, y = y, height = 22 })
            y = addGrid(perRun, canvas, items, cols, y + 24)
            if index > 1 then
                perRun:AddDivider({ y = y - 22 })
                y = y + 24
            end
        end
        perRun:SetContentHeight(contentHeight)
    end

    local combined = tabs:GetPage(2)
    combined:AddTitle({ text = "Current runs: " .. #runs, y = 4, height = 22 })
    local items = combinedItems()
    if #items > 0 then
        local cols = math.min(6, columns)
        local bottom = 28 + gridHeight(#items, cols) + 14
        local canvas = ui.Canvas.new(combined.content)
        canvas:SetSize(width, bottom)
        canvas.clickthrough = true
        addGrid(combined, canvas, items, cols, 28)
        combined:SetContentHeight(bottom)
    else
        combined:AddText({ text = "No Barrows chest loot recorded yet.", y = 28 })
    end

    perRun:SetScrollPosition(scrollY[1])
    combined:SetScrollPosition(scrollY[2])
    shownWidth, shownHeight = width, height
    resizeWait = 0
    dirty = false
end

-- The backpack button opens a draggable, resizable window outside the Hub.
function loot.open(savedRuns)
    runs = savedRuns
    if not window then
        local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
        if not gameArea then return end
        window = prettyui.Window.new(gameArea, {
            title = "Barrows Loot",
            x = -220, y = -200, xAnchor = 0.5, yAnchor = 0.5,
            width = 300, height = 400,
            resizable = true, minWidth = 300, minHeight = 180,
            scrollable = false,
            -- PrettyUI otherwise leaves 12 units above the first content row.
            layout = { startY = -4 },
            onClose = function()
                hoverTip.hide()
                isOpen = false
            end,
        })
        dirty = true
    end
    isOpen = true
    window:Show()
    loot.update(savedRuns)
end

-- Resize after dragging settles; new loot rebuilds the open pages immediately.
function loot.update(savedRuns)
    if not window then return end
    if not ui.Interfaces:GetInterface(window.content.interfaceID) then
        forget()
        return
    end
    if runs ~= savedRuns then
        runs = savedRuns
        loot.resetScroll()
        dirty = true
    end
    if not isOpen then return end
    if not tabs then build(); return end

    local width, height = window.viewport.width, window.viewport.height
    if width ~= shownWidth or height ~= shownHeight then
        shownWidth, shownHeight = width, height
        resizeWait = 3
        dirty = true
    elseif resizeWait > 0 then
        resizeWait = resizeWait - 1
    end
    if resizeWait == 0 and dirty then build() end
end

return loot
