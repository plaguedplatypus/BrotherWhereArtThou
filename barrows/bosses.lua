-- BARROWS_KILLS packs the six original brothers into separate low bits.
-- Akrisae and Linza use their own VarPlayers.
local displayOrder = {
    { id = "ahrim", name = "Ahrim", mask = 0x1 },
    { id = "torag", name = "Torag", mask = 0x10 },
    { id = "dharok", name = "Dharok", mask = 0x2 },
    { id = "verac", name = "Verac", mask = 0x20 },
    { id = "guthan", name = "Guthan", mask = 0x4 },
    { id = "karil", name = "Karil", mask = 0x8 },
    { id = "akrisae", name = "Akrisae" },
    { id = "linza", name = "Linza" }
}
local byId = {}
for _, boss in ipairs(displayOrder) do
    byId[boss.id] = boss
end

-- Linza's sarcophagus cannot lead to the tunnels.
local tunnelOrder = {
    byId.verac, byId.akrisae, byId.dharok, byId.ahrim,
    byId.torag, byId.guthan, byId.karil
}

return { byId = byId, displayOrder = displayOrder, tunnelOrder = tunnelOrder }
