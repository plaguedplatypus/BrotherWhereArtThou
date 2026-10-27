local puzzle = {}

local answerSlots = {
    id.Component.BARROWS_PUZZLE__BARROWS_ANSA,
    id.Component.BARROWS_PUZZLE__BARROWS_ANSB,
    id.Component.BARROWS_PUZZLE__BARROWS_ANSC
}

-- The game moves answer models between the three slots. These models match
-- the four Barrows patterns: left arrow, clockwise and rising grey space,
-- and decreasing sides (square).
local answers = {
    [id.Model.IF_GAME_BARROWS_PUZZLE1_SEQ1] = id.Model.IF_GAME_BARROWS_PUZZLE1_ANSA,
    [id.Model.IF_GAME_BARROWS_PUZZLE2_SEQ1] = id.Model.IF_GAME_BARROWS_PUZZLE2_ANSA,
    [id.Model.IF_GAME_BARROWS_PUZZLE3_SEQ1] = id.Model.IF_GAME_BARROWS_PUZZLE3_ANSA,
    [id.Model.IF_GAME_BARROWS_PUZZLE4_SEQ1] = id.Model.IF_GAME_BARROWS_PUZZLE4_ANSA
}

local highlightedSlot, highlightedModel, normalEnvironment
local marker

-- Restore the game's original lighting when the puzzle closes or changes.
local function clear()
    if highlightedSlot then
        local current = ui.Interfaces:GetComponent(highlightedSlot)
        if current and current.modelID1 == highlightedModel then
            current.environment = normalEnvironment
        end
    end
    highlightedSlot, highlightedModel, normalEnvironment = nil, nil, nil
end

-- Light the correct model and point to it with a chevron, so the answer can
-- still be found without relying on colour. The model remains clickable.
function puzzle.update()
    if marker and not ui.Interfaces:GetInterface(marker.interfaceID) then marker = nil end
    local window = ui.Interfaces:GetComponent(id.Component.BARROWS_PUZZLE__MAINMODAL_WINDOW)
    if not window or not window.visibleGlobal then
        clear()
        if marker then marker.hidden = true end
        return
    end

    local sequence = ui.Interfaces:GetComponent(id.Component.BARROWS_PUZZLE__BARROWS_SEQ1)
    local answerID = sequence and answers[sequence.modelID1]
    local answer, answerSlot
    if answerID then
        for _, slot in ipairs(answerSlots) do
            local component = ui.Interfaces:GetComponent(slot)
            if component and component.visibleGlobal and component.modelID1 == answerID then
                answer, answerSlot = component, slot
                break
            end
        end
    end

    if answerSlot ~= highlightedSlot or answerID ~= highlightedModel then clear() end
    if not answer then
        if marker then marker.hidden = true end
        return
    end
    if not highlightedSlot then
        highlightedSlot, highlightedModel = answerSlot, answerID
        normalEnvironment = answer.environment
    end
    local green = answer.environment
    green.ambient = 1.2
    green.contrast = 3
    green.sunRGB = Vector3.new(0.12, 1, 0.2)
    answer.environment = green

    if not marker then
        local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        if not parent then return end
        -- The shared top layer can exhaust category 0's dynamic IDs; keep the
        -- puzzle marker in its own category without changing its draw layer.
        marker = ui.Sprite.new(parent, 1)
        marker:SetSize(38, 28)
        marker.spriteID = id.Sprite.WALK_MARKER_DEFAULT
        marker.clickthrough = true
    end

    local point = answer.xyGlobal
    local origin = marker.parent.xyGlobal
    marker:SetPos(math.floor(point.x - origin.x + (answer.width - 38) / 2),
        math.floor(point.y - origin.y - 12))
    marker.hidden = false
end

-- Restore any lit answer before removing the puzzle marker on unload.
function puzzle.stop()
    clear()
    if marker then marker:Destroy() end
    marker = nil
end

return puzzle
