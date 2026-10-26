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

local run, states, target, room, route, pendingDoor

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

-- Follow the loaded floor height so the route sits above tunnel tiles.
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

-- Find the shortest known-open passage route from an outer room to the puzzle
-- door's room. A corridor containing the player can be excluded separately.
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
                    local cost = costs[current] + passageLength(passage)
                    if not costs[nextRoom] or cost < costs[nextRoom] then
                        costs[nextRoom] = cost
                        previous[nextRoom] = { room = current, passage = passage }
                    end
                end
            end
        end
    end
    if not costs[target.room] then return nil end

    local steps, index = {}, target.room
    while index ~= start do
        local step = previous[index]
        table.insert(steps, 1, { from = step.room, to = index, passage = step.passage })
        index = step.room
    end

    local points = {}
    for _, step in ipairs(steps) do
        local passage = step.passage
        if step.from == passage.from then
            for _, point in ipairs(passage.points) do points[#points + 1] = point end
        else
            for point = #passage.points, 1, -1 do
                points[#points + 1] = passage.points[point]
            end
        end
        points[#points + 1] = rooms[step.to]
    end
    return points, costs[target.room]
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

-- Start at either end of a bypass corridor or at the nearest outer room,
-- then project the route onto the visible floor.
local function buildRoute(player)
    local tile = player.coordGrid
    local passage, corridorPoint = outerCorridor(tile)
    local points

    if passage then
        -- When already in an outer corridor, route from either end without
        -- crossing back through its wall or sending the line behind the player.
        local bestCost
        for _, endRoom in ipairs({ passage.from, passage.to }) do
            local rest, cost = routeFrom(endRoom, passage.id)
            if rest then
                local outer = passage.points[endRoom == passage.from and 2 or 3]
                local door = passage.points[endRoom == passage.from and 1 or 4]
                local total = distance(corridorPoint, outer) + distance(outer, door)
                    + distance(door, rooms[endRoom]) + cost
                if not bestCost or total < bestCost then
                    bestCost = total
                    points = { corridorPoint, outer, door, rooms[endRoom] }
                    for _, point in ipairs(rest) do points[#points + 1] = point end
                end
            end
        end
    else
        local start = nearestRoom(tile)
        if not start then return nil end
        points = routeFrom(start)
    end
    if not points then return nil end

    local positions = {}
    for _, point in ipairs(points) do
        local position = floorPoint(point, player.coordGrid.level)
        -- Fog can leave later corridor tiles without ground height. Keep the
        -- visible part of the route instead of hiding the whole line.
        if not position then return #positions > 0 and positions or nil end
        positions[#positions + 1] = position
    end
    local door = floorPoint(target, player.coordGrid.level)
    if door then positions[#positions + 1] = door end
    return #positions > 0 and positions or nil
end

-- Group both halves of each door by parent config and read their current lock
-- states. Accept the puzzle entrance only after the same unique open door
-- appears on consecutive scans.
function tunnels.scan()
    local player = playerInTunnel()
    if not player then
        states, target, room, route, pendingDoor = nil, nil, nil, nil, nil
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
    states, room, route = found, nil, nil
    target = entranceLetter == pendingDoor and entrance or nil
    pendingDoor = entranceLetter
end

-- Rebuild the route when the player enters another room or corridor tile.
function tunnels.update()
    local player = playerInTunnel()
    if not player or not target then
        room, route = nil, nil
        return
    end
    local tile = player.coordGrid
    local passage = outerCorridor(tile)
    local current = passage and (passage.id .. ":" .. tile.x .. "," .. tile.z)
        or nearestRoom(tile)
    if current == room then return end
    room = current
    route = current and buildRoute(player) or nil
end

-- Start at the player's feet and draw a floor ribbon; DrawLine's pixel
-- width is capped and can look too thin as the camera pulls back.
local function draw()
    if not route then return end
    local player = playerInTunnel()
    if not player then return end
    local start = floorPoint({ x = player.coordGrid.x, z = player.coordGrid.z },
        player.coordGrid.level)
    if not start then return end

    local positions = { start }
    for _, point in ipairs(route) do positions[#positions + 1] = point end

    local ribbon, tris = {}, {}
    for index = 1, #positions - 1 do
        local from, to = positions[index], positions[index + 1]
        local dx, dz = to.x - from.x, to.z - from.z
        local length = math.sqrt(dx * dx + dz * dz)
        if length > 0 then
            local offsetX, offsetZ = -dz * 16 / length, dx * 16 / length
            local first = #ribbon
            ribbon[first + 1] = Vector3.new(from.x + offsetX, from.y, from.z + offsetZ)
            ribbon[first + 2] = Vector3.new(from.x - offsetX, from.y, from.z - offsetZ)
            ribbon[first + 3] = Vector3.new(to.x + offsetX, to.y, to.z + offsetZ)
            ribbon[first + 4] = Vector3.new(to.x - offsetX, to.y, to.z - offsetZ)
            tris[#tris + 1] = first
            tris[#tris + 1] = first + 1
            tris[#tris + 1] = first + 2
            tris[#tris + 1] = first + 1
            tris[#tris + 1] = first + 3
            tris[#tris + 1] = first + 2
        end
    end
    if #tris > 0 then
        ShapeList.Draw({
            shapePositions = ribbon,
            shapeTris = tris,
            colour = 0xF4C15CCC,
            ignoreDepth = false
        })
    end
    ShapeList.DrawLine({
        positions = positions,
        colour = 0xF4C15CDD,
        lineWidth = 5,
        ignoreDepth = false
    })
end

-- Read the shared tunnel choice and draw the route each frame.
function tunnels.start(data)
    run = data
    Event.Draw.Subscribe("barrowsTunnelRoute", draw)
end

-- Remove the draw hook and forget door states when the plugin unloads.
function tunnels.stop()
    Event.Draw.Unsubscribe("barrowsTunnelRoute")
    states, target, room, route, pendingDoor = nil, nil, nil, nil, nil
end

return tunnels
