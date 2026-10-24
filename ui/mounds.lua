local mounds = {}

local moundOrder = { "verac", "dharok", "ahrim", "torag", "guthan", "karil" }
local labelMounds = {
    { id = "verac", name = "Verac", mound = "verac", style = "melee" },
    { id = "akrisae", name = "Akrisae", mound = "verac", style = "magic" },
    { id = "dharok", name = "Dharok", mound = "dharok", style = "melee" },
    { id = "ahrim", name = "Ahrim", mound = "ahrim", style = "magic" },
    { id = "linza", name = "Linza", mound = "ahrim", style = "melee" },
    { id = "torag", name = "Torag", mound = "torag", style = "melee" },
    { id = "guthan", name = "Guthan", mound = "guthan", style = "melee" },
    { id = "karil", name = "Karil", mound = "karil", style = "ranged" }
}
local styleSprites = {
    melee = id.Sprite.HITMARK_ICON_MELEE,
    ranged = id.Sprite.HITMARK_ICON_RANGED,
    magic = id.Sprite.HITMARK_ICON_MAGIC
}

local run, coords, labelsRoot, labels
local spadeCount
local markerTime = 0

-- Draw the red X over a slain brother's style icon and strike through its name.
local function redLine(parent, x, y, width, height, invert)
    local line = ui.Line.new(parent)
    line:SetPos(x, y)
    line:SetSize(width, height)
    line.invert = invert or false
    line.width = 2
    line.colour = Vector4.new(1, 0.15, 0.15, 1)
    line.clickthrough = true
    return line
end

-- Use the incoming combat style beside each mound name.
local function styleIcon(parent, style)
    local icon = ui.Sprite.new(parent)
    icon:SetPos(1, 4)
    icon:SetSize(16, 16)
    icon.spriteID = styleSprites[style]
    icon.clickthrough = true
    return icon
end

-- Find the six surface spades and assign their tile positions to the original
-- brothers. Akrisae and Linza share Verac's and Ahrim's mounds respectively.
function mounds.scan()
    coords = nil
    if not Player.IsAvailable() then return end
    local entity = Player.GetEntity()
    if not entity then return end
    local player = entity.coordGrid
    -- The Barrows surface is at 3566,3287. Crypts and other spades are excluded.
    if player.level ~= 0 or math.abs(player.x - 3566) > 45
        or math.abs(player.z - 3287) > 45 then return end

    local spades = LocList.Filter({
        coordGrid = player, range = 50, sameLevel = true,
        func = function(loc)
            local tile = loc.coordGrid
            if tile.x < 3548 or tile.x > 3583
                or tile.z < 3270 or tile.z > 3303 then return false end
            for _, op in pairs(loc.config.opNames) do
                if op:find("Dig-with", 1, true) then return true end
            end
            return false
        end
    })
    if #spades ~= spadeCount then
        spadeCount = #spades
        log("Barrows Tunnel: mound spades found=" .. spadeCount)
    end
    if #spades ~= 6 then return end

    -- North to south gives two northern mounds, Ahrim, two southern
    -- mounds, then Karil. Sort each pair west to east for their names.
    table.sort(spades, function(a, b)
        local left, right = a.coordGrid, b.coordGrid
        return left.z == right.z and left.x < right.x or left.z > right.z
    end)
    if spades[1].coordGrid.x > spades[2].coordGrid.x then
        spades[1], spades[2] = spades[2], spades[1]
    end
    if spades[4].coordGrid.x > spades[5].coordGrid.x then
        spades[4], spades[5] = spades[5], spades[4]
    end
    coords = {}
    for index, id in ipairs(moundOrder) do
        coords[id] = spades[index].coordGrid
    end
end

-- Build one reusable label per boss on the plugin's bottom layer so normal
-- interface windows draw above the names.
local function buildLabels()
    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_BOTTOM)
    if not parent then return end
    local root = ui.Layer.new(parent)
    root:SetSize(0, 0, 1, 1)
    root.clickthrough = true
    local built = {}
    for _, entry in ipairs(labelMounds) do
        local tag = ui.Layer.new(root)
        tag:SetSize(92, 22)
        tag.clickthrough = true
        tag.hidden = true

        local backing = ui.Rectangle.new(tag)
        backing:SetSize(92, 22)
        backing.fill = true
        backing.colour = Vector4.new(0, 0, 0, 0.30)
        backing.clickthrough = true

        local frame = ui.Rectangle.new(tag)
        frame:SetSize(92, 22)
        frame.fill = false
        frame.outlineThickness = 1
        frame.colour = Vector4.new(0.58, 0.48, 0.31, 0.75)
        frame.clickthrough = true

        local icon = styleIcon(tag, entry.style)

        local name = ui.Text.new(tag)
        name:SetPos(15, 0)
        name:SetSize(73, 22)
        name.content = entry.name
        name.font = id.Font.MENU_FONT_SMALL
        name:AlignTo(ui.AlignMode.CENTRE)
        name.maxLines = 1
        name.isShadowed = true
        name.clickthrough = true

        local marks = {
            redLine(tag, 4, 6, 10, 10),
            redLine(tag, 4, 6, 10, 10, true),
            redLine(tag, 19, 11, 67, 1)
        }
        for _, mark in ipairs(marks) do mark.hidden = true end

        local tunnel = ui.Text.new(root)
        tunnel:SetSize(92, 16)
        tunnel.content = "[Tunnel]"
        tunnel.font = id.Font.MENU_FONT_SMALL
        tunnel:AlignTo(ui.AlignMode.CENTRE)
        tunnel.maxLines = 1
        tunnel.isShadowed = true
        tunnel.colour = Vector4.new(1, 0.86, 0.48, 1)
        tunnel.clickthrough = true
        tunnel.hidden = true

        -- The game's walk chevron points at the tunnel name.
        local marker = ui.Sprite.new(root)
        marker:SetSize(38, 28)
        marker.spriteID = id.Sprite.WALK_MARKER_DEFAULT
        marker.clickthrough = true
        marker.hidden = true

        built[entry.id] = {
            root = tag, name = name, backing = backing, frame = frame, icon = icon,
            marks = marks, tunnel = tunnel, marker = marker
        }
    end
    labels = built
    labelsRoot = root
end

-- Project each mound into the current camera view. Shared mounds stack two
-- labels, and the selected one reserves room for its chevron and caption.
local function draw(drawEvent)
    if not labelsRoot or not labels then return end
    local parent = labelsRoot.parent
    if not parent then return end
    local screenOrigin = parent.xyGlobal
    markerTime = (markerTime + drawEvent.timeDeltaSecs) % 1.2
    local pulse = 0.5 + 0.5 * math.cos(markerTime * math.pi * 2 / 1.2)
    for _, entry in ipairs(labelMounds) do
        local label = labels[entry.id]
        local coord = coords and coords[entry.mound]
        local point = coord and ScreenConvert.CoordGridToScreen(coord, 600)
        local pointX = point and point.x - screenOrigin.x
        local unlocked = entry.id ~= "akrisae" or run.showAkrisae
        unlocked = unlocked and (entry.id ~= "linza" or run.showLinza)
        local selected = run.selected == entry.id
        local above = (entry.id == "verac" and run.showAkrisae)
            or (entry.id == "ahrim" and run.showLinza)
        -- Reserve space for the chevron and tunnel caption on shared mounds.
        local lowerSelected = (entry.id == "verac" and run.selected == "akrisae")
            or (entry.id == "ahrim" and run.selected == "linza")
        local y = point and math.floor(point.y - screenOrigin.y
            - (above and (lowerSelected and 76 or 56) or 34)
            - ((selected or lowerSelected) and 18 or 0))
        local onScreen = unlocked and pointX ~= nil and pointX >= 46
            and pointX < parent.width - 46 and y >= 0
            and y + (selected and 38 or 22) <= parent.height
        if label.root.hidden == onScreen then label.root.hidden = not onScreen end
        if not onScreen then label.marker.hidden = true end
        label.tunnel.hidden = not (onScreen and selected)
        if onScreen then
            local x = math.floor(pointX - 46)
            if label.root.x ~= x or label.root.y ~= y then
                label.root:SetPos(x, y)
            end
            if selected and (label.tunnel.x ~= x or label.tunnel.y ~= y + 22) then
                label.tunnel:SetPos(x, y + 22)
            end
            local slain = run.slain[entry.id] == true
            if selected and y >= 18 then
                if label.marker.x ~= x + 32 or label.marker.y ~= y - 18 then
                    label.marker:SetPos(x + 32, y - 18)
                end
                label.marker.alpha = 0.35 + pulse * 0.65
                label.marker.hidden = false
            else
                label.marker.hidden = true
            end
            if label.slain ~= slain or label.selected ~= selected then
                label.slain, label.selected = slain, selected
                label.name.colour = selected and Vector4.new(1, 0.92, 0.56, 1)
                    or slain and Vector4.new(0.65, 0.63, 0.61, 1)
                    or Vector4.new(1, 0.90, 0.68, 1)
                label.backing.colour = selected and Vector4.new(0.42, 0.29, 0.04, 0.50)
                    or Vector4.new(0, 0, 0, 0.30)
                label.frame.colour = selected and Vector4.new(1, 0.78, 0.29, 1)
                    or Vector4.new(0.58, 0.48, 0.31, 0.75)
                label.icon.hidden = slain
                for _, mark in ipairs(label.marks) do mark.hidden = not slain end
            end
        end
    end
end

-- Log selected Dig-with actions to help identify surface spades in the client.
local function logSpade(event)
    local entry = event.entry
    if entry.verbText ~= "Dig-with" or entry.subjectText ~= "Spade" then return end
    local loc = entry.locData
    if loc then
        log("Barrows Tunnel: spade loc=" .. loc.config.configName
            .. " tile=" .. loc.coordGridX .. "," .. loc.coordGridZ)
    else
        log("Barrows Tunnel: spade action type=" .. tostring(entry.actionEntryType))
    end
end

-- Use the shared run for labels and subscribe to draw and Dig-with events.
function mounds.start(data)
    run = data
    Event.Draw.Subscribe("barrowsTunnelLabels", draw)
    Event.MiniMenuEntrySelected.Subscribe("barrowsTunnelSpade", logSpade)
end

-- Rebuild labels after the game replaces their parent interface.
function mounds.update()
    if labelsRoot and not ui.Interfaces:GetInterface(labelsRoot.interfaceID) then
        labelsRoot, labels = nil, nil
    end
    if not labelsRoot then buildLabels() end
end

-- Remove mound hooks and labels when the plugin unloads.
function mounds.stop()
    Event.Draw.Unsubscribe("barrowsTunnelLabels")
    Event.MiniMenuEntrySelected.Unsubscribe("barrowsTunnelSpade")
    if labelsRoot then labelsRoot:Destroy() end
    labelsRoot, labels = nil, nil
end

return mounds
