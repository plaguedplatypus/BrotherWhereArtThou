local hoverTip = {}
local overlayParent, overlay, target, tip, bossRows

local function hasOverlay()
    return overlay and ui.Interfaces:GetInterface(overlayParent.interfaceID)
        and overlayParent:GetChild(overlay.categoryID, overlay.dynamicID) == overlay
end

-- Remove the custom children before hiding or reusing the PrettyUI frame.
local function clearBossRows()
    if not bossRows then return end
    for _, row in ipairs(bossRows) do
        row.line:Destroy()
        row.label:Destroy()
    end
    bossRows = nil
end

-- The attachment may outlive its native parent during logout or a UI rebuild.
function hoverTip.stop()
    if hasOverlay() then
        clearBossRows()
        if tip then tip:Destroy() end
        overlay:Destroy()
    elseif tip then
        pcall(tip.Destroy, tip)
    end
    overlayParent, overlay, target, tip, bossRows = nil, nil, nil, nil, nil
end

-- Keep the attachment outside the Plugin Hub's clipped dock.
local function create()
    local parent = ui.Interfaces:GetComponent(
        id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        or ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    if not parent then return false end
    if tip and parent == overlayParent and hasOverlay() then return true end
    hoverTip.stop()

    overlayParent = parent
    overlay = prettyui.NewComponent(ui.Layer, parent, { categoryID = "auto" })
    overlay:SetSize(0, 0, 1, 1)
    overlay.clickthrough = true
    target = prettyui.NewComponent(ui.Layer, overlay)
    target:SetSize(0, 0)
    target.hidden = true
    tip = prettyui.Tooltip.attach(target, overlay,
        { text = "Item", placement = "above", boundsMargin = 0 })
    return true
end

-- Boss rows belong to the current native tooltip frame.
local function createBossRows(bosses)
    if bossRows then return end
    local rows = {}
    local root = tip.root
    local font = config.Font.MUSEO_SANS_11PT_REGULAR
    for index, boss in ipairs(bosses) do
        local x = 10 + ((index - 1) % 2) * 88
        local y = 12 + math.floor((index - 1) / 2) * 17
        local label = prettyui.NewComponent(ui.Text, root)
        label:SetPos(x, y)
        label:SetSize(78, 16)
        label.content = boss.name
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR
        label.maxLines = 1
        label.clickthrough = true
        label.hidden = true

        local line = prettyui.NewComponent(ui.Line, root)
        line:SetPos(x, y + 8)
        line:SetSize(math.min(76, font:GetStringWidth(boss.name, false)), 1)
        line.width = 1
        line.colour = Vector4.new(1, 0.15, 0.15, 1)
        line.clickthrough = true
        line.hidden = true
        rows[index] = { label = label, line = line }
    end
    bossRows = rows
end

-- Centre tooltips over their targets, shifting them inward at screen edges.
-- PrettyUI adds 6 pixels around the anchor, so callers shift it by 3.
local function place(x, y, width, tipWidth)
    local origin = overlay.xyGlobal
    local left = x - origin.x + (width - tipWidth) / 2
    target:SetPos(math.max(0, math.min(left, overlay.width - tipWidth)),
        y - origin.y)
end

-- Measure wrapped text with the font actually drawn, then position the tip
-- from screen coordinates so scrolled loot slots and dock icons agree.
function hoverTip.show(x, y, width, label, maxWidth)
    if not create() then return end
    clearBossRows()
    local font = config.Font.MUSEO_SANS_11PT_REGULAR
    local tipWidth = math.min(maxWidth, math.max(21,
        font:GetStringWidthMultiline(label, maxWidth - 16, false, false, false) + 16))
    local textHeight = font:GetStringHeightAndLineCount(label,
        tipWidth - 16, font.baseline, false, false, false)
    place(x, y + 3, width, tipWidth)
    tip.options.placement = "above"
    tip.options.width = tipWidth
    tip.options.height = textHeight + 10
    local text = tip.label
    text.font = id.Font.MUSEO_SANS_11PT_REGULAR
    text.alignHorizontal = ui.AlignMode.CENTRE
    text.alignVertical = ui.AlignMode.CENTRE
    text.hidden = false
    tip:SetText(label)
    tip:Show()
end

function hoverTip.showSlain(x, y, width, height, bosses, slain,
    showAkrisae, showLinza)
    if not create() then return end
    place(x, y + height - 3, width, 188)
    tip.options.placement = "below"
    tip.options.width = 188
    tip.options.height = 96
    tip:SetText("")
    tip.label.hidden = true
    createBossRows(bosses)
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
    tip:Show()
end

-- Hide the shared tooltip when its hovered icon leaves or the dock scrolls.
function hoverTip.hide()
    if not tip then return end
    if hasOverlay() then
        clearBossRows()
        tip:Hide()
    else
        hoverTip.stop()
    end
end

return hoverTip
