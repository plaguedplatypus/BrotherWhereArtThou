local didHide = false

-- Read the game's Barrows overlay and hide it only after its header confirms
-- interface 24 still has the expected layout.
local function read()
    local panel = ui.Interfaces:GetComponent(24, 1)
    local header = ui.Interfaces:GetComponent(24, 6)
    local brothers = ui.Interfaces:GetComponent(24, 7)
    local creatures = ui.Interfaces:GetComponent(24, 10)
    if not panel or not header or not brothers or not creatures
        or header.type ~= ui.ComponentType.LABEL
        or brothers.type ~= ui.ComponentType.LABEL
        or creatures.type ~= ui.ComponentType.LABEL
        or header.content ~= "Brothers slain:" then return nil, nil end

    if header.visibleGlobal and not panel.hidden then
        panel.hidden = true
        didHide = true
    end
    -- After looting, the hidden game panel can leave 9999 in this field.
    -- Keep the last real count until the game starts reporting a new run.
    if creatures.content == "9999" then return brothers.content, nil end
    return brothers.content, creatures.content
end

-- Return control of the built-in panel to the game when the plugin unloads.
local function restore()
    if not didHide then return end
    local panel = ui.Interfaces:GetComponent(24, 1)
    if panel and panel.hidden then panel.hidden = false end
    didHide = false
end

return { read = read, restore = restore }
