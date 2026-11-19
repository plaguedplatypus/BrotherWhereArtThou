local bosses = require("barrows/bosses").displayOrder
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

function loot.invalidate()
    dirty = true
end

-- Start a new chest or a replaced history at the top of both lists.
function loot.resetScroll()
    scrollY[1], scrollY[2] = 0, 0
    if tabs then
        hoverTip.hide()
        tabs:GetPage(1):SetScrollPosition(0)
        tabs:GetPage(2):SetScrollPosition(0)
    end
end

-- PrettyUI owns the tab pages and scrollbars.
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
-- Only real items need a sprite and mouse hooks.
local function gridHeight(count, columns)
    local rows = math.ceil(count / columns)
    return rows * 40 + math.max(0, rows - 1) * 2
end

local function scroll(page, delta)
    hoverTip.hide()
    local previous = page.scrollY
    page:ScrollBy(delta * scrollStep)
    return page.scrollY == previous
end

local function addGrid(page, canvas, items, columns, top)
    local slotSize, gap, inset = 40, 2, 14
    local rows = math.ceil(#items / columns)
    for index = 1, rows * columns do
        local x = inset + ((index - 1) % columns) * (slotSize + gap)
        local y = top + math.floor((index - 1) / columns) * (slotSize + gap)
        canvas:AddSprite(x, y, slotSize, slotSize,
            id.Sprite.RS3_ICON_SLOT_40PX_1, 0xFFFFFFFF)

        local item = items[index]
        if item then
            local obj = config.Obj.FromID(math.floor(item.id))
            if obj then
                local slot = prettyui.NewComponent(ui.Layer, page.content)
                slot:SetPos(x, y)
                slot:SetSize(slotSize, slotSize)
                local sprite = prettyui.NewComponent(ui.Sprite, slot)
                sprite:SetPos(4, 4)
                sprite:SetSize(32, 32)
                sprite:SetAssociatedObject(math.tointeger(obj.id))
                sprite.associatedObjectQuantity = math.tointeger(item.count)
                sprite.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.MULTIPLE
                sprite.clickthrough = true

                local label = (obj.name or "Unknown item") .. " x" .. item.count
                -- Hovered slots must forward wheel input to their scrollable tab.
                slot:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
                    return scroll(page, delta)
                end)
                slot:Subscribe(ui.Hook.ONMOUSEOVER, function()
                    -- A scrolled child's xyGlobal does not reflect the viewport offset.
                    local point = page.viewport.xyGlobal
                    hoverTip.show(point.x + x, point.y + y - page.scrollY,
                        slotSize, label, 190)
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
        for _, item in ipairs(runs[runIndex].items) do
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

local function runTitle(entry, index)
    local title = "Run " .. index
    local slain = entry.slain
    local count = 0
    for _, boss in ipairs(bosses) do
        if slain[boss.id] then count = count + 1 end
    end
    if count == 1 and slain.linza then return title .. "  -  Linza Run" end

    local total = 6 + ((entry.showAkrisae or slain.akrisae) and 1 or 0)
        + ((entry.showLinza or slain.linza) and 1 or 0)
    return title .. "  -  Brothers slain: " .. count .. "/" .. total
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
        for _, entry in ipairs(runs) do
            contentHeight = contentHeight + 24 + gridHeight(#entry.items, cols) + 24
        end
        contentHeight = contentHeight - 24 + 14
        local canvas = prettyui.NewComponent(ui.Canvas, perRun.content)
        canvas:SetSize(width, contentHeight)
        canvas.clickthrough = true
        local y = 4
        for index = #runs, 1, -1 do
            local entry = runs[index]
            local title = perRun:AddTitle({
                text = runTitle(entry, index), y = y, height = 22
            })
            title.enabled = true
            title:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
                return scroll(perRun, delta)
            end)
            title:Subscribe(ui.Hook.ONMOUSEOVER, function()
                local point = perRun.viewport.xyGlobal
                hoverTip.showSlain(point.x + title.x + 70,
                    point.y + title.y - perRun.scrollY,
                    150, title.height, bosses, entry.slain,
                    entry.showAkrisae, entry.showLinza)
                return true
            end)
            title:Subscribe(ui.Hook.ONMOUSELEAVE, function()
                hoverTip.hide()
                return true
            end)
            y = addGrid(perRun, canvas, entry.items, cols, y + 24)
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
        local canvas = prettyui.NewComponent(ui.Canvas, combined.content)
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
            categoryID = "auto",
            title = "Barrows Loot",
            x = -220, y = -200, xAnchor = 0.5, yAnchor = 0.5,
            width = 300, height = 400,
            resizable = true, minWidth = 300, minHeight = 180,
            respectInterfaceLock = false,
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
