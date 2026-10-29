local tunnels = {}

-- Barrows has eight outer rooms around the chest. These tile centres and door
-- positions come from the client's Barrows door locations, not the minimap.
local rooms = {
    { x = 3534.5, z = 9711.5 }, -- northwest
    { x = 3551.5, z = 9711.5 }, -- north
    { x = 3568.5, z = 9711.5 }, -- northeast
    { x = 3568.5, z = 9694.5 }, -- east
    { x = 3568.5, z = 9677.5 }, -- southeast
    { x = 3551.5, z = 9677.5 }, -- south
    { x = 3534.5, z = 9677.5 }, -- southwest
    { x = 3534.5, z = 9694.5 }  -- west
}
-- Each letter is the game's parent config for a passage. A, B, H and P
-- connect corner rooms through the outer corridors, bypassing a middle room.
local passages = {
    { id = "D", from = 1, to = 2, points = { { x = 3543, z = 9711.5 } } },
    { id = "F", from = 2, to = 3, points = { { x = 3560, z = 9711.5 } } },
    { id = "G", from = 3, to = 4, points = { { x = 3568.5, z = 9703 } } },
    { id = "M", from = 4, to = 5, points = { { x = 3568.5, z = 9686 } } },
    { id = "O", from = 5, to = 6, points = { { x = 3560, z = 9677.5 } } },
    { id = "N", from = 6, to = 7, points = { { x = 3543, z = 9677.5 } } },
    { id = "K", from = 7, to = 8, points = { { x = 3534.5, z = 9686 } } },
    { id = "C", from = 8, to = 1, points = { { x = 3534.5, z = 9703 } } },
    { id = "A", from = 1, to = 3, points = {
        { x = 3534.5, z = 9718 }, { x = 3534.5, z = 9721 },
        { x = 3568.5, z = 9721 }, { x = 3568.5, z = 9718 }
    } },
    { id = "B", from = 1, to = 7, points = {
        { x = 3528, z = 9711.5 }, { x = 3525, z = 9711.5 },
        { x = 3525, z = 9677.5 }, { x = 3528, z = 9677.5 }
    } },
    { id = "H", from = 3, to = 5, points = {
        { x = 3575, z = 9711.5 }, { x = 3578, z = 9711.5 },
        { x = 3578, z = 9677.5 }, { x = 3575, z = 9677.5 }
    } },
    { id = "P", from = 7, to = 5, points = {
        { x = 3534.5, z = 9671 }, { x = 3534.5, z = 9668 },
        { x = 3568.5, z = 9668 }, { x = 3568.5, z = 9671 }
    } }
}
local outerPassages = {
    north = passages[9], west = passages[10],
    east = passages[11], south = passages[12]
}
-- These four doors lead from an outer room into the chest room.
local centreDoors = {
    E = { room = 2, x = 3551.5, z = 9703 },
    J = { room = 4, x = 3560, z = 9694.5 },
    L = { room = 6, x = 3551.5, z = 9686 },
    I = { room = 8, x = 3543, z = 9694.5 }
}
local mazeCentre = CoordGrid.new(0, Vector3.new(3551 * 512, 0, 9694 * 512))

local run, states, target, room, nextDoor, pendingDoor
local marker, markerTime = nil, 0
local blinkPeriod = 0.4

-- Limit route work to a Barrows run inside the underground map area.
local function playerInTunnel()
    if not run.selected or not Player.IsAvailable() then return nil end
    local player = Player.GetEntity()
    -- IsAvailable can briefly precede the entity during a game load.
    if not player then return nil end
    local tile = player.coordGrid
    if tile.x < 3500 or tile.x > 3600
        or tile.z < 9600 or tile.z > 9800 then return nil end
    return player
end

-- Place the door marker at the height of the loaded tunnel floor.
local function floorPoint(tile, level)
    local x, z = (tile.x + 0.5) * 512, (tile.z + 0.5) * 512
    local height, available = World.GetGroundHeight(level, x, z)
    if not available then return nil end
    return Vector3.new(x, height + 45, z)
end

-- Match the player's tile to an outer room; exclude the chest room.
local function nearestRoom(tile)
    local closest, distance
    for index, place in ipairs(rooms) do
        local dx, dz = tile.x - place.x, tile.z - place.z
        local squared = dx * dx + dz * dz
        if not distance or squared < distance then
            closest, distance = index, squared
        end
    end

    local dx, dz = tile.x - 3551.5, tile.z - 9694.5
    if dx * dx + dz * dz < distance then return nil end
    return closest
end

-- Measure tile distance in the flat maze for route costs.
local function distance(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

-- Include corridor bends so outer bypasses cost their full walking distance.
local function passageLength(passage)
    local length, previous = 0, rooms[passage.from]
    for _, point in ipairs(passage.points) do
        length = length + distance(previous, point)
        previous = point
    end
    return length + distance(previous, rooms[passage.to])
end
for _, passage in ipairs(passages) do
    passage.length = passageLength(passage)
end

-- Find the first door on the shortest known-open route to the puzzle door's
-- room. A corridor containing the player can be excluded separately.
local function routeFrom(start, excluded)
    local costs, previous, visited = { [start] = 0 }, {}, {}

    -- Eight rooms are small enough to search directly. Corridor distance keeps
    -- a long outer passage from winning over a shorter path through open doors.
    for _ = 1, #rooms do
        local current
        for index = 1, #rooms do
            if not visited[index] and costs[index]
                and (not current or costs[index] < costs[current]) then
                current = index
            end
        end
        if not current or current == target.room then break end
        visited[current] = true

        for _, passage in ipairs(passages) do
            if passage.id ~= excluded and states[passage.id] == true then
                local nextRoom
                if passage.from == current then nextRoom = passage.to end
                if passage.to == current then nextRoom = passage.from end
                if nextRoom then
                    local cost = costs[current] + passage.length
                    if not costs[nextRoom] or cost < costs[nextRoom] then
                        costs[nextRoom] = cost
                        previous[nextRoom] = { room = current, passage = passage }
                    end
                end
            end
        end
    end
    if not costs[target.room] then return nil end

    local first, index = nil, target.room
    while index ~= start do
        local step = previous[index]
        local passage = step.passage
        first = passage.points[step.room == passage.from and 1 or #passage.points]
        index = step.room
    end
    return first or target, costs[target.room]
end

-- Identify the bypass corridors, whose middle tiles are not in any room.
local function outerCorridor(tile)
    if tile.z >= 9718 and tile.x >= 3530 and tile.x <= 3573 then
        return outerPassages.north, { x = tile.x, z = 9721 }
    end
    if tile.x <= 3528 and tile.z >= 9673 and tile.z <= 9716 then
        return outerPassages.west, { x = 3525, z = tile.z }
    end
    if tile.x >= 3575 and tile.z >= 9673 and tile.z <= 9716 then
        return outerPassages.east, { x = 3578, z = tile.z }
    end
    if tile.z <= 9671 and tile.x >= 3530 and tile.x <= 3573 then
        return outerPassages.south, { x = tile.x, z = 9668 }
    end
end

-- From an outer corridor, compare both exits; otherwise mark the first door
-- on the room route. The chest entrance itself is marked from its adjacent room.
local function findDoor(player)
    local tile = player.coordGrid
    local passage, corridorPoint = outerCorridor(tile)

    if passage then
        -- When already in an outer corridor, compare the routes from both ends.
        local bestCost, choice
        for _, endRoom in ipairs({ passage.from, passage.to }) do
            local _, cost = routeFrom(endRoom, passage.id)
            if cost then
                local outer = passage.points[endRoom == passage.from and 2 or 3]
                local door = passage.points[endRoom == passage.from and 1 or 4]
                local total = distance(corridorPoint, outer) + distance(outer, door)
                    + distance(door, rooms[endRoom]) + cost
                if not bestCost or total < bestCost then
                    bestCost, choice = total, door
                end
            end
        end
        return choice
    end
    local start = nearestRoom(tile)
    if start then return routeFrom(start) end
end

-- Group both halves of each door by parent config and read their current lock
-- states. Accept the puzzle entrance only after the same unique open door
-- appears on consecutive scans.
function tunnels.scan()
    local player = playerInTunnel()
    if not player then
        states, target, room, nextDoor, pendingDoor = nil, nil, nil, nil, nil
        return
    end

    local found = {}
    local doors = LocList.Filter({
        coordGrid = mazeCentre, range = 45, sameLevel = true,
        func = function(loc)
            local parent = loc.parentConfig
            return parent and parent.configName:match("^BARROWS_DOOR_([A-P])_[LR]$") ~= nil
        end
    })
    for _, door in ipairs(doors) do
        local letter = door.parentConfig.configName:match("^BARROWS_DOOR_([A-P])_[LR]$")
        local config = door.config and door.config.configName
        local unlocked = config and config:match("^BARROWS_DOOR_UNLOCKED_[LR]$") ~= nil
        local locked = config and config:match("^BARROWS_DOOR_LOCKED_[LR]$") ~= nil
        if unlocked or locked then
            local previous = found[letter]
            if previous == nil then
                found[letter] = unlocked
            elseif previous ~= unlocked then
                found[letter] = "mixed"
            end
        end
    end

    -- Exactly one of the four centre entrances must be open. The client can
    -- briefly show the previous door states while loading a new run.
    local entrance, entranceLetter
    for letter, door in pairs(centreDoors) do
        if found[letter] == nil or found[letter] == "mixed" then
            entrance, entranceLetter = nil, nil
            break
        end
        if found[letter] then
            if entrance then
                entrance, entranceLetter = nil, nil
                break
            end
            entrance, entranceLetter = door, letter
        end
    end
    states, room, nextDoor = found, nil, nil
    target = entranceLetter == pendingDoor and entrance or nil
    pendingDoor = entranceLetter
end

-- Choose another door when the player enters a room or corridor tile.
function tunnels.update()
    if marker and not ui.Interfaces:GetInterface(marker.interfaceID) then marker = nil end
    if not marker then
        local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_BOTTOM)
        if parent then
            marker = ui.Sprite.new(parent, 1)
            marker:SetSize(38, 28)
            marker.spriteID = id.Sprite.WALK_MARKER_DEFAULT
            marker.colour = Vector4.new(0.2, 1, 0.3, 1)
            marker.clickthrough = true
            marker.hidden = true
        end
    end
    local player = playerInTunnel()
    if not player or not target then
        room, nextDoor = nil, nil
        return
    end
    local tile = player.coordGrid
    local passage = outerCorridor(tile)
    local current = passage and (passage.id .. ":" .. tile.x .. "," .. tile.z)
        or nearestRoom(tile)
    if current == room then return end
    room = current
    nextDoor = current and findDoor(player) or nil
end

-- Flash the game's walk chevron above the next door while it is on screen.
local function draw(drawEvent)
    if not marker then return end
    marker.hidden = true
    if not nextDoor then return end
    local player = playerInTunnel()
    if not player then return end
    local mapWorld = ui.Interfaces:GetComponent(id.Component.WORLDMAP_V2__GAME_WORLD)
    if mapWorld and mapWorld.visibleGlobal then return end
    local position = floorPoint(nextDoor, player.coordGrid.level)
    if not position then return end
    local point = ScreenConvert.Vector3ToScreen(
        Vector3.new(position.x, position.y + 240, position.z))
    if not point then return end
    local parent = marker.parent
    if not parent then return end
    local origin = parent.xyGlobal
    local x, y = point.x - origin.x, point.y - origin.y
    if x < 19 or x >= parent.width - 19 or y < 28 or y >= parent.height then
        return
    end
    markerTime = (markerTime + drawEvent.timeDeltaSecs) % blinkPeriod
    marker:SetPos(math.floor(x - 19), math.floor(y - 28))
    marker.hidden = markerTime >= blinkPeriod / 2
end

-- Read the shared tunnel choice and draw its next-door marker each frame.
function tunnels.start(data)
    run = data
    Event.Draw.Subscribe("barrowsTunnelDoor", draw)
end

-- Remove the marker and forget door states when the plugin unloads.
function tunnels.stop()
    Event.Draw.Unsubscribe("barrowsTunnelDoor")
    if marker then marker:Destroy() end
    marker = nil
    states, target, room, nextDoor, pendingDoor = nil, nil, nil, nil, nil
end

return tunnels
