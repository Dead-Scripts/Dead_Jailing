local jailTime = nil
local cords = nil
local jailCell = nil

RegisterNetEvent('Dead_Jailing:JailPlayer')
AddEventHandler('Dead_Jailing:JailPlayer', function(jailCoords, time, cell)
    local ped = PlayerPedId()
    jailTime = time
    cords = jailCoords
    jailCell = cell
    SetEntityCoords(ped, jailCoords.x, jailCoords.y, jailCoords.z, 1, 0, 0, 1)
end)

RegisterNetEvent('Dead_Jailing:UnjailPlayer')
AddEventHandler('Dead_Jailing:UnjailPlayer', function()
    jailTime = nil
    local coords = Config.PrisonExit
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, 1, 0, 0, 1)
    TriggerEvent('chatMessage', Config.Prefix .. "You have been released from jail!...") -- Consider updating chat message event
    TriggerServerEvent('Dead_Jailing:FreeCell', jailCell)
    jailCell = nil
    cords = nil
end)

Citizen.CreateThread(function()
    TriggerServerEvent("Dead_Jailing:Connected")
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        if jailTime ~= nil then
            if jailTime > 0 then
                jailTime = jailTime - 1
            end
            if (jailTime % Config.Teleport_And_Notify_Every == 0) and jailTime ~= 0 then
                TriggerEvent('chatMessage', Config.Prefix .. "You have ^1" .. jailTime .. "^3 seconds left in jail...")
                if Config.Teleport_Enabled then
                    SetEntityCoords(ped, cords.x, cords.y, cords.z, 1, 0, 0, 1)
                end
            end
            if jailTime == 0 then
                TriggerEvent('Dead_Jailing:UnjailPlayer')
                jailTime = nil
            end
        end
    end
end)

function Draw2DText(x, y, text, scale, center)
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    if center then
        SetTextJustification(1) -- center
    else
        SetTextJustification(0) -- left
    end
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end