-- Initialize CellTracker early
CellTracker = {}
JailTracker = {}

function SaveFile(data)
    SaveResourceFile(GetCurrentResourceName(), "players.json", json.encode(data, { indent = true }), -1)
end

function LoadFile()
    local al = LoadResourceFile(GetCurrentResourceName(), "players.json")
    if not al then return {} end -- return empty table if file does not exist
    local cfg = json.decode(al)
    return cfg or {}
end

function ExtractIdentifiers(src)
    local identifiers = {
        steam = "",
        ip = "",
        discord = "",
        license = "",
        xbl = "",
        live = ""
    }

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "steam") then
            identifiers.steam = id
        elseif string.find(id, "ip") then
            identifiers.ip = id
        elseif string.find(id, "discord") then
            identifiers.discord = id
        elseif string.find(id, "license") then
            identifiers.license = id
        elseif string.find(id, "xbl") then
            identifiers.xbl = id
        elseif string.find(id, "live") then
            identifiers.live = id
        end
    end

    return identifiers
end

RegisterCommand('jail', function(src, args, raw)
    -- /jail <id> <time>
    if IsPlayerAceAllowed(src, "Dead_Jailing.Jail") then 
        if #args < 2 then
            TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: Invalid usage. ^2Usage: /jail <id> <time>")
            return
        end

        local targetId = tonumber(args[1])
        local jailTime = tonumber(args[2])
        if targetId and GetPlayerIdentifiers(targetId) and GetPlayerIdentifiers(targetId)[1] ~= nil then
            if jailTime then
                if jailTime <= Config.Max_Jail_Time_Allowed then
                    TriggerClientEvent('chatMessage', -1, Config.Prefix .. "Player ^5" .. GetPlayerName(targetId) .. " ^3has been jailed for ^1" .. jailTime .. " ^3seconds...")
                    Citizen.CreateThread(function()
                        local cfg = LoadFile()
                        local ids = ExtractIdentifiers(targetId)
                        cfg[ids.license] = {Cell = nil, Time = jailTime}
                        SaveFile(cfg)

                        while not IsCellFree() do
                            TriggerClientEvent('chatMessage', targetId, Config.Prefix .. "Waiting on a free cell at jail...")
                            Citizen.Wait(10000)
                        end

                        local key = GetFreeCell()
                        local coords = Config.Cells[key]
                        CellTracker[key] = ids.license

                        local cfg = LoadFile()
                        cfg[ids.license] = {Cell = key, Time = jailTime}
                        JailTracker[targetId] = jailTime
                        SaveFile(cfg)

                        TriggerClientEvent('Dead_Jailing:JailPlayer', targetId, coords, jailTime, key)
                    end)
                else
                    TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: You cannot jail for longer than ^3" .. Config.Max_Jail_Time_Allowed .. " ^1seconds...")
                end
            else
                TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: The 2nd argument was not a proper number...")
            end
        else
            TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: Invalid player supplied...")
        end
    end
end)

RegisterCommand('free', function(src, args, raw)
    -- /free <id>
    if IsPlayerAceAllowed(src, "Dead_Jailing.Unjail") then 
        if #args ~= 1 then
            TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: Invalid usage. ^2Usage: /free <id>")
            return
        end

        local targetId = tonumber(args[1])
        if targetId and GetPlayerIdentifiers(targetId) and GetPlayerIdentifiers(targetId)[1] ~= nil then
            TriggerClientEvent('chatMessage', -1, Config.Prefix .. "Player ^5" .. GetPlayerName(targetId) .. " ^3has been released from jail by ^2" .. GetPlayerName(src))
            TriggerClientEvent('Dead_Jailing:UnjailPlayer', targetId)

            local ids = ExtractIdentifiers(targetId)
            local cfg = LoadFile()
            cfg[ids.license] = nil
            JailTracker[targetId] = nil
            SaveFile(cfg)
        else
            TriggerClientEvent('chatMessage', src, Config.Prefix .. "^1ERROR: Invalid player supplied...")
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for k, v in pairs(JailTracker) do
            if v > 0 then
                JailTracker[k] = v - 1
            else
                JailTracker[k] = nil
            end
        end
    end
end)

RegisterNetEvent("Dead_Jailing:Connected")
AddEventHandler("Dead_Jailing:Connected", function()
    local src = source
    local ids = ExtractIdentifiers(src)
    local cfg = LoadFile()

    if cfg[ids.license] ~= nil then
        local time = cfg[ids.license].Time
        local cell = cfg[ids.license].Cell
        if CellTracker[cell] == nil then
            CellTracker[cell] = ids.license
            local coords = Config.Cells[cell]
            TriggerClientEvent('Dead_Jailing:JailPlayer', src, coords, time, cell)
        else
            Citizen.CreateThread(function()
                while not IsCellFree() do
                    TriggerClientEvent('chatMessage', src, Config.Prefix .. "Waiting on a free cell at jail...")
                    Citizen.Wait(10000)
                end
                local key = GetFreeCell()
                local coords = Config.Cells[key]
                CellTracker[key] = ids.license
                local cfg = LoadFile()
                cfg[ids.license] = {Cell = key, Time = tonumber(time)}
                JailTracker[src] = tonumber(time)
                SaveFile(cfg)
                TriggerClientEvent('Dead_Jailing:JailPlayer', src, coords, tonumber(time), key)
            end)
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    local ids = ExtractIdentifiers(src)
    local cfg = LoadFile()

    if cfg[ids.license] ~= nil then
        cfg[ids.license].Time = JailTracker[src]
    end

    JailTracker[src] = nil
    SaveFile(cfg)

    for key, license in pairs(CellTracker) do
        if license == ids.license then
            CellTracker[key] = nil
        end
    end
end)

RegisterNetEvent('Dead_Jailing:FreeCell')
AddEventHandler('Dead_Jailing:FreeCell', function(cell)
    local ids = ExtractIdentifiers(source)
    local cfg = LoadFile()
    cfg[ids.license] = nil
    JailTracker[source] = nil
    SaveFile(cfg)
    CellTracker[cell] = nil
end)

function GetFreeCell()
    for k, _ in pairs(Config.Cells) do
        if CellTracker[k] == nil then
            return k
        end
    end
    return nil
end

function IsCellFree()
    for k, _ in pairs(Config.Cells) do
        if CellTracker[k] == nil then
            return true
        end
    end
    return false
end