local sarcophagus = {}

-- The client gives each sarcophagus a tile footprint but no model height.
-- This box uses that footprint and a fixed height around the stone lid.
local boxHeight = 150
local boxPositions = {
    Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 0, -0.5),
    Vector3.new(0.5, 0, 0.5), Vector3.new(-0.5, 0, 0.5),
    Vector3.new(-0.5, 1, -0.5), Vector3.new(0.5, 1, -0.5),
    Vector3.new(0.5, 1, 0.5), Vector3.new(-0.5, 1, 0.5)
}
local box = ShapeData.new()
box.positions = boxPositions
box.lines = {
    0, 1, 1, 2, 2, 3, 3, 0,
    4, 5, 5, 6, 6, 7, 7, 4,
    0, 4, 1, 5, 2, 6, 3, 7
}

local fill = ShapeData.new()
fill.positions = boxPositions
-- Leave the bottom open to avoid another translucent layer over the model.
fill.tris = {
    4, 5, 6, 4, 6, 7,
    0, 1, 5, 0, 5, 4,
    1, 2, 6, 1, 6, 5,
    2, 3, 7, 2, 7, 6,
    3, 0, 4, 3, 4, 7
}

local cross = ShapeData.new()
cross.positions = {
    Vector3.new(-0.35, 0, -0.35), Vector3.new(0.35, 0, 0.35),
    Vector3.new(-0.35, 0, 0.35), Vector3.new(0.35, 0, -0.35)
}
cross.lines = { 0, 1, 2, 3 }

local run, selected, tunnel, marker, caption
local slain = {}
local markerTime = 0

-- Match a sarcophagus to its brother using the game's loc config names.
local function brotherFor(loc)
    local config = loc.config and loc.config.configName
    local parent = loc.parentConfig and loc.parentConfig.configName
    local name = config and (config:match("^BARROWS_IMP_(%u+)_SARCOPHAGUS$")
        or config:match("^MAH5_BARROW_(%u+)_SARCOPHAGUS$"))
    if name then return name:lower() end

    -- Linza's Kindred Spirits sarcophagus uses a different config family.
    -- Check its active and parent configs because a multi-loc can change after
    -- the fight, while its displayed object remains a sarcophagus.
    local displayName = loc.displayName
    local isSarcophagus = displayName
        and displayName:lower():find("sarcophagus", 1, true)
    for _, source in ipairs({ config or "", parent or "" }) do
        if (isSarcophagus or source:find("SARCOPHAGUS", 1, true))
            and (source:find("LINZA", 1, true) or source:find("SISTER_", 1, true)) then
            return "linza"
        end
    end
    return nil
end

-- Turn a loc's tile footprint into a box centred over its stone lid.
local function placeFor(loc)
    local corner = loc.coordGrid:ToCoordFine(false).position
    local x = corner.x + loc.width * 256
    local z = corner.z + loc.length * 256
    local ground, available = World.GetGroundHeight(loc.coordGrid.level, x, z)
    if not available then return nil end

    return {
        loc = loc,
        origin = Vector3.new(x, ground + 30, z),
        size = Vector3.new(loc.width * 512, boxHeight, loc.length * 512)
    }
end

-- Collect the current tunnel sarcophagus and each slain brother's sarcophagus.
-- The Linza fallback below handles her shared crypt when the config lacks a name.
function sarcophagus.scan()
    tunnel, slain = nil, {}
    selected = run.selected
    if not Player.IsAvailable() then return end
    local player = Player.GetEntity()
    if not player then return end

    local findLinza = run.slain.linza == true
    local found = LocList.Filter({
        coordGrid = player.coordGrid, range = 25, sameLevel = true,
        func = function(candidate)
            if candidate.isHidden then return false end
            local brother = brotherFor(candidate)
            if brother then
                return brother == selected or run.slain[brother] == true
                    or (findLinza and brother == "ahrim")
            end
            return findLinza and candidate.displayName
                and candidate.displayName:lower():find("sarcophagus", 1, true) ~= nil
        end
    })
    local ahrim, unknown, linzaFound = nil, {}, false
    for _, loc in ipairs(found) do
        local brother = brotherFor(loc)
        local place = placeFor(loc)
        if place then
            if brother == "ahrim" then ahrim = loc end
            if run.slain[brother] then
                place.brother = brother
                slain[#slain + 1] = place
                if brother == "linza" then linzaFound = true end
            elseif brother == selected then
                tunnel = place
            elseif not brother then
                unknown[#unknown + 1] = place
            end
        end
    end

    -- Linza shares Ahrim's crypt. If her sarcophagus has no recognizable
    -- config name, the one other sarcophagus beside Ahrim is hers.
    if findLinza and not linzaFound and ahrim and #unknown == 1 then
        local loc = unknown[1].loc
        local dx = loc.coordGrid.x - ahrim.coordGrid.x
        local dz = loc.coordGrid.z - ahrim.coordGrid.z
        if dx * dx + dz * dz <= 20 * 20 then
            unknown[1].brother = "linza"
            slain[#slain + 1] = unknown[1]
        end
    end
end

-- Draw red crosses for slain brothers and a filled gold box for the tunnel.
-- Its caption and chevron are separate UI components projected from the box.
local function draw(drawEvent)
    markerTime = (markerTime + drawEvent.timeDeltaSecs) % 1.2
    if marker then marker.hidden = true end
    if caption then caption.hidden = true end
    for _, place in ipairs(slain) do
        if place.loc.isValid and run.slain[place.brother] then
            ShapeList.Draw({
                shapeData = cross,
                translation = Vector3.new(place.origin.x,
                    place.origin.y + boxHeight * 0.5, place.origin.z),
                scale = place.size,
                colour = 0xFF3030DD,
                lineWidth = 8,
                ignoreDepth = true
            })
        end
    end

    if not tunnel or not tunnel.loc.isValid or selected ~= run.selected
        or run.slain[selected] then return end

    local origin, size = tunnel.origin, tunnel.size

    ShapeList.Draw({
        shapeData = fill,
        translation = origin,
        scale = size,
        colour = 0xF4C15C30,
        ignoreDepth = true
    })

    ShapeList.Draw({
        shapeData = box,
        translation = origin,
        scale = size,
        colour = 0xF4C15CDD,
        lineWidth = 3,
        ignoreDepth = true
    })

    if not marker or not caption then return end
    local parent = marker.parent
    if not parent then return end
    local screenOrigin = parent.xyGlobal
    local captionPoint = ScreenConvert.Vector3ToScreen(
        Vector3.new(origin.x, origin.y + boxHeight * 0.5, origin.z))
    if captionPoint then
        local x = captionPoint.x - screenOrigin.x
        local y = captionPoint.y - screenOrigin.y
        if x >= 46 and x < parent.width - 46 and y >= 8
            and y < parent.height - 8 then
            caption:SetPos(math.floor(x - 46), math.floor(y - 8))
            caption.hidden = false
        end
    end

    local point = ScreenConvert.Vector3ToScreen(
        Vector3.new(origin.x, origin.y + boxHeight + 100, origin.z))
    if not point then return end
    local x = point.x - screenOrigin.x
    local y = point.y - screenOrigin.y
    if x < 14 or x >= parent.width - 14
        or y < 18 or y >= parent.height then return end

    marker:SetPos(math.floor(x - 14), math.floor(y - 18))
    local pulse = 0.5 + 0.5 * math.cos(markerTime * math.pi * 2 / 1.2)
    marker.alpha = 0.35 + pulse * 0.65
    marker.hidden = false
end

function sarcophagus.start(data)
    run = data
    Event.Draw.Subscribe("barrowsTunnelSarcophagusBox", draw)
end

-- Put the tunnel chevron and caption beneath normal interface windows.
function sarcophagus.update()
    if selected ~= run.selected then sarcophagus.scan() end
    if marker and not ui.Interfaces:GetInterface(marker.interfaceID) then
        marker, caption = nil, nil
    end
    if marker then return end

    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_BOTTOM)
    if not parent then return end
    marker = ui.Sprite.new(parent)
    marker:SetSize(38, 28)
    marker.spriteID = id.Sprite.WALK_MARKER_DEFAULT
    marker.clickthrough = true
    marker.hidden = true

    caption = ui.Text.new(parent)
    caption:SetSize(92, 16)
    caption.content = "[Tunnel]"
    caption.font = id.Font.MENU_FONT_SMALL
    caption:AlignTo(ui.AlignMode.CENTRE)
    caption.maxLines = 1
    caption.isShadowed = true
    caption.colour = Vector4.new(1, 0.86, 0.48, 1)
    caption.clickthrough = true
    caption.hidden = true
end

function sarcophagus.stop()
    Event.Draw.Unsubscribe("barrowsTunnelSarcophagusBox")
    if marker then marker:Destroy() end
    if caption then caption:Destroy() end
    marker, caption, tunnel = nil, nil, nil
    slain = {}
end

return sarcophagus
