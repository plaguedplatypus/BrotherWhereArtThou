local bossOrder = require("barrows/bosses").displayOrder
local hoverTip = require("ui/hoverTip")
local loot = require("ui/loot")
local ribbonToggle = require("ui/ribbonToggle")
local settings = require("ui/settings")

local dock = {}
local run, status, queue, save
local contentParent, contentRoot, contentView
local contentScroll = 0
local page = "overview"
local contentDirty = true
local seenWidth, seenHeight
local resizeWait = 0
local resizeQuietTicks = 3
local contentMissingTicks = 0

-- Make dock text click through so it cannot intercept nearby controls.
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

-- Draw the red strike used for slain brothers in the dock.
local function redLine(parent, x, y, width, height)
    local line = ui.Line.new(parent)
    line:SetPos(x, y)
    line:SetSize(width, height)
    line.invert = false
    line.width = 2
    line.colour = Vector4.new(1, 0.15, 0.15, 1)
    line.clickthrough = true
end

-- Quest requirements use PrettyUI's compact game-style tooltip frame.
local function infoIcon(root, width, y, name, message)
    local icon = ui.Layer.new(root)
    icon:SetPos(width - 29, y + 1)
    icon:SetSize(18, 18)
    local sprite = ui.Sprite.new(icon)
    sprite:SetSize(18, 18)
    sprite.spriteID = id.Sprite.RS3_ICON_INFO
    sprite.clickthrough = true
    local label = name .. "<br>" .. message
    icon:Subscribe(ui.Hook.ONMOUSEOVER, function()
        local point = icon.xyGlobal
        hoverTip.show(point.x, point.y, icon.width, label, 190)
        return true
    end)
    icon:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        hoverTip.hide()
        return true
    end)
end

-- Separate the dock's brother list from its counts and quest details.
local function divider(root, width, y)
    local line = ui.Rectangle.new(root)
    line:SetPos(8, y)
    line:SetSize(width - 16, 1)
    line.fill = true
    line.colour = Vector4.new(0.37, 0.34, 0.29, 0.85)
    line.clickthrough = true
end

-- Show all brothers, including locked ones, with slain and tunnel marks.
local function dockBosses(root, width, columns, rowOffset)
    local cellWidth = math.floor((width - 16) / columns)
    local total, slain = 0, 0
    for index, boss in ipairs(bossOrder) do
        local x = 8 + ((index - 1) % columns) * cellWidth
        local y = 35 + math.floor((index - 1) / columns) * 18
        local unlocked = boss.id ~= "akrisae" or run.showAkrisae
        unlocked = unlocked and (boss.id ~= "linza" or run.showLinza)
        local selected = unlocked and run.selected == boss.id
        if unlocked then
            total = total + 1
            if run.slain[boss.id] then slain = slain + 1 end
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
            or run.slain[boss.id] and Vector4.new(0.65, 0.63, 0.61, 1)
            or not unlocked and Vector4.new(0.55, 0.53, 0.51, 1)
            or Vector4.new(1, 0.90, 0.68, 1)
        if run.slain[boss.id] then
            redLine(root, x + 7, y + 9, cellWidth - 10, 1)
        end
    end
    divider(root, width, 91 + rowOffset)
    text(root, "Brothers slain: " .. slain .. "/" .. total,
        8, 97 + rowOffset, width - 16, 20)
    text(root, "Creatures slain: " .. (status.creatureCount or "?"),
        8, 118 + rowOffset, width - 16, 20)
    divider(root, width, 140 + rowOffset)
end

-- Show quest status for the optional bosses when the game supplies it.
local function overviewPage(root, width, columns, rowOffset)
    dockBosses(root, width, columns, rowOffset)
    local akrisaeStatus = "Unknown"
    if status.akrisaeQuestKnown then
        akrisaeStatus = run.showAkrisae and "Unlocked" or "Missing quest"
    end
    text(root, "Akrisae: " .. akrisaeStatus, 8, 146 + rowOffset, width - 43, 23)
    local linzaStatus = "Unknown"
    if status.linzaQuestKnown then
        linzaStatus = run.showLinza and "Unlocked" or "Missing quest"
    end
    text(root, "Linza: " .. linzaStatus, 8, 169 + rowOffset, width - 43, 23)
    divider(root, width, 194 + rowOffset)
    text(root, "Barrows KC: " .. (status.barrowsCount or "?"),
        8, 200 + rowOffset, width - 16, 18)
    if run.showLinzaKC then
        text(root, "Linza KC: " .. run.linzaKills,
            8, 220 + rowOffset, width - 16, 18)
    end
    infoIcon(root, width, 146 + rowOffset, "Akrisae", "Requires Ritual of the Mahjarrat.")
    infoIcon(root, width, 169 + rowOffset, "Linza",
        "Requires Kindred Spirits.")
end

-- The Hub can replace its content child without unloading the interface.
local function hasContentUi()
    return contentParent and contentRoot
        and ui.Interfaces:GetInterface(contentParent.interfaceID)
        and contentRoot.parent == contentParent
        and contentParent:GetChild(contentRoot.categoryID,
            contentRoot.dynamicID) == contentRoot
end

-- Rebuild the dock after state or size changes. UI actions are queued so the
-- old component tree is never destroyed from one of its own callbacks.
local function buildContent()
    if not contentParent then return end
    if contentParent.width < 1 or contentParent.height < 1 then return end
    hoverTip.hide()
    ribbonToggle.detach()
    if contentView then
        contentView:Destroy()
        contentView = nil
    end
    if contentRoot then contentRoot:Destroy() end
    local root = ui.Layer.new(contentParent)
    root:SetSize(contentParent.width, contentParent.height)
    contentRoot = root
    -- The Hub clips a short dock. Scroll the page while its navigation stays put.
    local view = prettyui.SimpleView.new(root, {
        x = 0, y = 0, width = contentParent.width,
        height = math.max(1, contentParent.height - 32), scrollStep = 24
    })
    contentView = view
    -- Classic's narrow fixed panel needs another row for the eight brothers.
    local columns = contentParent.width < 285 and 2 or 3
    local rowOffset = (math.ceil(#bossOrder / columns) - 3) * 18
    local pageHeight = page == "settings" and 214 or 244 + rowOffset
    view:SetContentHeight(math.max(view.root.height, pageHeight))
    local width = view.contentWidth
    local owner = view.content
    local title = text(owner,
        page == "settings" and "SETTINGS" or "BROTHER WHERE ART THOU",
        8, 5, width - 8, 18)
    title.font = id.Font.CINZEL_12PT_BOLD
    title.colour = Vector4.new(0.95, 0.75, 0.38, 1)
    title.alignVertical = ui.AlignMode.CENTRE
    title.maxLines = 1
    if page == "settings" then
        settings.build(owner, width, run, queue, save)
    else
        overviewPage(owner, width, columns, rowOffset)
    end
    view:SetScrollPosition(contentScroll)

    -- The backpack opens a separate loot window; the settings cog still
    -- changes pages inside the Hub and becomes a back arrow there.
    local function nav(x, spriteId, action)
        local button = ui.Button.new(root)
        button:SetPos(x, contentParent.height - 30)
        button:SetSize(26, 26)
        button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        button:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            queue(action)
        end)
        -- Buttons are not containers, so the icon sits on top and clicks through.
        local icon = ui.Sprite.new(root)
        icon:SetPos(x + 3, contentParent.height - 27)
        icon:SetSize(20, 20)
        icon.spriteID = spriteId
        icon.clickthrough = true
    end
    nav(4, id.Sprite.RS3_MENU_ICON_BACKPACK_NORMAL, function()
        loot.open(run.lootRuns)
    end)
    nav(contentParent.width - 30, page == "settings" and id.Sprite.RS3_ICON_BACK_32PX_0
        or id.Sprite.RS3_ICON_PLUGIN_HUB_SETTINGS_ACTIVE, function()
        page = page == "settings" and "overview" or "settings"
        contentScroll = 0
        contentDirty = true
    end)
    ribbonToggle.attach(contentParent, queue, hasContentUi, buildContent)
    contentDirty = false
end

-- Read shared run state and status when rebuilding. Queue UI actions so they
-- can run after the current hook returns.
function dock.start(data, overviewStatus, queueAction, saveRun)
    run, status, queue, save = data, overviewStatus, queueAction, saveRun
end

-- Remember the old page's scroll before account changes or queued actions.
function dock.rememberScroll()
    if contentView and hasContentUi() then contentScroll = contentView.scrollY end
end

function dock.reset()
    page = "overview"
    contentScroll = 0
    contentDirty = true
end

function dock.invalidate()
    contentDirty = true
end

function dock.open(parent)
    hoverTip.hide()
    ribbonToggle.close()
    if hasContentUi() then
        if contentView then
            contentScroll = contentView.scrollY
            contentView:Destroy()
        end
        contentRoot:Destroy()
    end
    contentParent = parent
    contentRoot, contentView = nil, nil
    contentDirty = true
    seenWidth, seenHeight = contentParent.width, contentParent.height
    resizeWait = 0
    contentMissingTicks = 0
    -- The Hub has already cleared this layer, so redraw it immediately.
    buildContent()
end

function dock.update()
    -- A switched Hub page can leave its old parent alive after our dock is
    -- cleared. A brief child lookup miss during resize should not close it.
    if contentParent and not ui.Interfaces:GetInterface(contentParent.interfaceID) then
        hoverTip.hide()
        ribbonToggle.close()
        contentParent, contentRoot, contentView = nil, nil, nil
    elseif contentRoot and not hasContentUi() then
        contentMissingTicks = contentMissingTicks + 1
        if contentMissingTicks >= resizeQuietTicks then
            hoverTip.hide()
            ribbonToggle.close()
            contentParent, contentRoot, contentView = nil, nil, nil
        end
    else
        contentMissingTicks = 0
    end
    -- The Hub can keep this parent alive after switching plugins. Only resize
    -- our dock while its child still belongs to the active content layer.
    if contentParent and (not contentRoot or hasContentUi()) then
        local width, height = contentParent.width, contentParent.height
        if width ~= seenWidth or height ~= seenHeight then
            seenWidth, seenHeight = width, height
            resizeWait = resizeQuietTicks
            contentDirty = true
            -- Keep an owned dock visible while the Hub changes its size.
            if contentRoot and width > 0 and height > 0 then
                contentRoot:SetSize(width, height)
            end
        elseif resizeWait > 0 then
            resizeWait = resizeWait - 1
        end
        if not contentRoot or (resizeWait == 0 and (contentDirty
            or contentRoot.width ~= width or contentRoot.height ~= height)) then
            buildContent()
        end
    end
end

-- Release Hub layout changes before destroying the dock we own.
function dock.stop()
    ribbonToggle.close()
    if hasContentUi() then
        if contentView then contentView:Destroy() end
        contentRoot:Destroy()
    end
    contentParent, contentRoot, contentView = nil, nil, nil
end

return dock
