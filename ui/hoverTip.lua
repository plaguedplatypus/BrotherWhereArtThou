local hoverTip = {}
local firstTipCategory = 120
local overlay, target, tip, bossRows

-- Keep one tooltip outside the Plugin Hub's clipped dock. Its own dynamic ID
-- category avoids the shared top layer's exhausted category 0, and changing
-- text does not create more components as the dock scrolls or resizes.
local function create()
    local parent = ui.Interfaces:GetComponent(
        id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        or ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    if not parent then return false end
    if overlay and parent:GetChild(overlay.categoryID, overlay.dynamicID) == overlay then
        return true
    end
    if tip then tip:Destroy() end
    overlay, target, tip, bossRows = nil, nil, nil, nil
    -- A category can itself be full in a long-running client. A failed frame
    -- is removed before trying another, so a tooltip cannot break the dock.
    for category = firstTipCategory, 235 do
        local layer
        local ok, newTarget, newTip = pcall(function()
            layer = ui.Layer.new(parent, category)
            layer:SetSize(0, 0, 1, 1)
            layer.clickthrough = true
            local anchor = ui.Layer.new(layer)
            anchor.hidden = true
            local frame = prettyui.Tooltip.attach(anchor, layer, { text = "Item" })
            frame.label.font = id.Font.MUSEO_SANS_11PT_REGULAR
            frame.label.alignHorizontal = ui.AlignMode.CENTRE
            frame.label.alignVertical = ui.AlignMode.CENTRE
            return anchor, frame
        end)
        if ok then
            overlay, target, tip = layer, newTarget, newTip
            return true
        end
        if layer then layer:Destroy() end
        if not tostring(newTarget):find("Failed to create", 1, true) then
            error(newTarget)
        end
    end
    return false
end

local function hideBossRows()
    if not bossRows then return end
    for _, row in ipairs(bossRows) do
        row.label.hidden = true
        row.line.hidden = true
    end
end

-- Reuse the shared PrettyUI frame; only its contents change for run details.
local function createBossRows(bosses)
    if bossRows then return end
    bossRows = {}
    local font = config.Font.MUSEO_SANS_11PT_REGULAR
    for index, boss in ipairs(bosses) do
        local x = 10 + ((index - 1) % 2) * 88
        local y = 12 + math.floor((index - 1) / 2) * 17
        local label = ui.Text.new(tip.root)
        label:SetPos(x, y)
        label:SetSize(78, 16)
        label.content = boss.name
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR
        label.maxLines = 1
        label.clickthrough = true
        label.hidden = true

        local line = ui.Line.new(tip.root)
        line:SetPos(x, y + 8)
        line:SetSize(math.min(76, font:GetStringWidth(boss.name, false)), 1)
        line.width = 1
        line.colour = Vector4.new(1, 0.15, 0.15, 1)
        line.clickthrough = true
        line.hidden = true
        bossRows[index] = { label = label, line = line }
    end
end

-- Measure wrapped text with the font actually drawn, then position the tip
-- from screen coordinates so scrolled loot slots and dock icons agree.
function hoverTip.show(x, y, width, height, label, maxWidth)
    if not create() then return end
    hideBossRows()
    tip.label.hidden = false
    local font = config.Font.MUSEO_SANS_11PT_REGULAR
    local tipWidth = math.min(maxWidth, math.max(90,
        font:GetStringWidthMultiline(label, maxWidth - 16, false, false, false) + 24))
    local textHeight = font:GetStringHeightAndLineCount(label,
        tipWidth - 16, font.baseline, false, false, false)
    local origin = overlay.xyGlobal
    target:SetPos(x - origin.x, y - origin.y)
    target:SetSize(width, height)
    tip.options.width = tipWidth
    tip.options.height = textHeight + 16
    tip:SetText(label)
    tip:Show()
end

function hoverTip.showSlain(x, y, width, height, bosses, slain,
    showAkrisae, showLinza)
    if not create() then return end
    createBossRows(bosses)
    tip.options.width = 188
    tip.options.height = 96
    tip:SetText("")
    tip.label.hidden = true
    for index, boss in ipairs(bosses) do
        local row = bossRows[index]
        local unlocked = (boss.id ~= "akrisae" or showAkrisae)
            and (boss.id ~= "linza" or showLinza)
        row.label.hidden = false
        row.label.colour = not unlocked and Vector4.new(0.50, 0.48, 0.45, 1)
            or slain[boss.id] and Vector4.new(0.65, 0.63, 0.61, 1)
            or Vector4.new(1, 0.90, 0.68, 1)
        row.line.hidden = not slain[boss.id]
    end
    local origin = overlay.xyGlobal
    target:SetPos(x - origin.x, y - origin.y)
    target:SetSize(width, height)
    tip:Show()
end

-- Hide the shared tooltip when its hovered icon leaves or the dock scrolls.
function hoverTip.hide()
    if tip then tip:Hide() end
end

-- Release the persistent tooltip only when the plugin unloads.
function hoverTip.stop()
    if tip then tip:Destroy() end
    local parent = ui.Interfaces:GetComponent(
        id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        or ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    if overlay and parent
        and parent:GetChild(overlay.categoryID, overlay.dynamicID) == overlay then
        overlay:Destroy()
    end
    overlay, target, tip, bossRows = nil, nil, nil, nil
end

return hoverTip
