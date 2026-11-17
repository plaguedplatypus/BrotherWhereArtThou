local bosses = require("barrows/bosses").byId

local accountStore = {}
local storageName = "barrowsTunnelV1"

-- The self player's display name separates local saves.
-- A name change starts a new save because no stable ID is available here.
function accountStore.currentKey()
    if not Player.IsAvailable() then return nil end
    local player = Player.GetEntity()
    if not player or not player.isValid then return nil end
    local displayName = player.displayName
    if type(displayName) ~= "string" or displayName == "" then return nil end
    return storageName .. ":name:" .. displayName:lower()
end

-- Reset the shared table in place because every world overlay holds it.
-- A nil key loads only the default values.
function accountStore.load(data, key)
    data.selected, data.slain = nil, {}
    data.showAkrisae, data.showLinza = false, false
    data.chestOpen, data.linzaKills, data.linzaCounted = false, 0, false
    data.showLinzaKC, data.showCombatStyles = true, true
    data.lootRuns, data.lootCaptured = {}, false
    if not key then return end

    local saved = PersistentDB:GetStructuredData(key)
    if type(saved) ~= "table" then return end
    if bosses[saved.selected] and saved.selected ~= "linza" then
        data.selected = saved.selected
    end
    -- Keep quest-derived visibility while the game reloads quest status so
    -- active marks survive.
    data.showAkrisae = saved.showAkrisae == true
    data.showLinza = saved.showLinza == true
    data.chestOpen = saved.chestOpen == true
    if type(saved.linzaKills) == "number" and saved.linzaKills >= 0
        and saved.linzaKills < math.huge then
        data.linzaKills = math.floor(saved.linzaKills)
    end
    data.linzaCounted = saved.linzaCounted == true
    -- Keep saved items and kill details as plain data, never game proxies.
    if type(saved.lootRuns) == "table" then
        for _, run in ipairs(saved.lootRuns) do
            if type(run) == "table" and type(run.items) == "table"
                and type(run.slain) == "table" then
                local items = {}
                for _, item in ipairs(run.items) do
                    if type(item) == "table" and type(item.id) == "number"
                        and item.id > 0 and item.id % 1 == 0
                        and type(item.count) == "number" and item.count > 0
                        and item.count % 1 == 0 then
                        items[#items + 1] = { id = item.id, count = item.count }
                    end
                end
                if #items > 0 then
                    local entry = {
                        items = items, slain = {},
                        showAkrisae = run.showAkrisae == true,
                        showLinza = run.showLinza == true
                    }
                    for id in pairs(bosses) do
                        if run.slain[id] == true then entry.slain[id] = true end
                    end
                    data.lootRuns[#data.lootRuns + 1] = entry
                end
            end
        end
    end
    data.lootCaptured = saved.lootCaptured == true
    data.showLinzaKC = saved.showLinzaKC ~= false
    data.showCombatStyles = saved.showCombatStyles ~= false
    if type(saved.slain) == "table" then
        for id in pairs(bosses) do
            if saved.slain[id] == true then data.slain[id] = true end
        end
    end
    if not data.showAkrisae then
        if data.selected == "akrisae" then data.selected = nil end
        data.slain.akrisae = nil
    end
end

function accountStore.save(key, data)
    if key then PersistentDB:SetStructuredData(key, data) end
end

return accountStore
