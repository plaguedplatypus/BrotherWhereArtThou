local hoverTip = {}
local firstTipCategory = 120
local overlay, target, tip

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
    overlay, target, tip = nil, nil, nil
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

-- Measure wrapped text with the font actually drawn, then position the tip
-- from screen coordinates so scrolled loot slots and dock icons agree.
function hoverTip.show(x, y, width, height, label, maxWidth)
    if not create() then return end
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
    overlay, target, tip = nil, nil, nil
end

return hoverTip
