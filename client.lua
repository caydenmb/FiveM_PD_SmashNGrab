local QBCore = exports['qb-core']:GetCoreObject()

-- ///////////////////////////////////////////////////////////////////////////
-- IsAuthorized(): true if your job is allowed
-- ///////////////////////////////////////////////////////////////////////////
local function IsAuthorized()
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.job then return false end
    for _, job in ipairs(Config.AuthorizedJobs) do
        if pd.job.name == job then return true end
    end
    return false
end

-- ///////////////////////////////////////////////////////////////////////////
-- GetNearbyPlayers(): returns list of { serverId, ped, dist, name }
-- ///////////////////////////////////////////////////////////////////////////
local function GetNearbyPlayers()
    local mePed = PlayerPedId()
    local mePos = GetEntityCoords(mePed)
    local out  = {}

    for _, serverId in ipairs(QBCore.Functions.GetPlayers()) do
        local ped = GetPlayerPed(serverId)
        if ped ~= mePed then
            local dist = #(mePos - GetEntityCoords(ped))
            if dist <= Config.MaxTargetDistance then
                out[#out+1] = {
                    serverId = serverId,
                    ped      = ped,
                    dist     = dist,
                    name     = GetPlayerName(serverId) -- native to fetch their display name
                }
            end
        end
    end

    return out
end

-- ///////////////////////////////////////////////////////////////////////////
-- Smash & drag logic.
-- ///////////////////////////////////////////////////////////////////////////
local function DoBreakWindowAndDrag(targetPed, seatIdx)
    local veh       = GetVehiclePedIsIn(targetPed, false)
    local windowIdx = Config.WindowIndex[seatIdx]
    local seatName  = Config.SeatNames[seatIdx] or "unknown"

    -- Smash
    SmashVehicleWindow(veh, windowIdx)
    QBCore.Functions.Notify(("🔨 Smashed %s window."):format(seatName), "success")
    Wait(250)

    -- Force exit
    TaskLeaveVehicle(targetPed, veh, 0)
    Wait(500)

    -- Reposition
    local offset   = Config.ExitOffsets[seatIdx]
    local worldPos = GetOffsetFromEntityInWorldCoords(veh, offset)
    SetEntityCoords(targetPed, worldPos.x, worldPos.y, worldPos.z)
    ClearPedTasksImmediately(targetPed)

    QBCore.Functions.Notify("✅ Suspect dragged out successfully.", "success")
end

-- ///////////////////////////////////////////////////////////////////////////
-- Handler once a specific player is chosen
-- ///////////////////////////////////////////////////////////////////////////
RegisterNetEvent('police:client:ConfirmBreak', function(data)
    local targetPed = GetPlayerPed(data.serverId)
    if targetPed == PlayerPedId() then return end

    -- make sure they’re still in a vehicle
    local veh = GetVehiclePedIsIn(targetPed, false)
    if veh == 0 then
        QBCore.Functions.Notify("❗ Suspect is no longer in a vehicle.", "error")
        return
    end

    -- find their seat
    local seatIdx = nil
    for s = -1, GetVehicleMaxNumberOfPassengers(veh)-1 do
        if GetPedInVehicleSeat(veh, s) == targetPed then
            seatIdx = s
            break
        end
    end
    if not seatIdx or not Config.WindowIndex[seatIdx] then
        QBCore.Functions.Notify("❗ Unable to determine window.", "error")
        return
    end

    DoBreakWindowAndDrag(targetPed, seatIdx)
end)

-- ///////////////////////////////////////////////////////////////////////////
-- Main command: either auto‑target or show selection menu
-- ///////////////////////////////////////////////////////////////////////////
local function BreakWindowHandler()
    -- Auth check
    if not IsAuthorized() then
        QBCore.Functions.Notify("❌ You are not authorized to use this.", "error")
        return
    end

    -- Gather players
    local nearby = GetNearbyPlayers()
    if #nearby == 0 then
        QBCore.Functions.Notify(("⚠️ No suspects within %.1fm."):format(Config.MaxTargetDistance), "error")
        return

    elseif #nearby == 1 then
        -- Single target: do it immediately
        local entry = nearby[1]
        BreakWindowHandler = nil
        -- Find seat quickly:
        local veh = GetVehiclePedIsIn(entry.ped, false)
        local seatIdx
        for s = -1, GetVehicleMaxNumberOfPassengers(veh)-1 do
            if GetPedInVehicleSeat(veh, s) == entry.ped then seatIdx = s; break end
        end
        DoBreakWindowAndDrag(entry.ped, seatIdx)

    else
        -- Multiple: build a menu
        local menu = {{ header = "Select Suspect", txt = "" }}
        for _, ply in ipairs(nearby) do
            menu[#menu+1] = {
                header = ply.name,
                txt    = ("~y~%.1fm~s~"):format(ply.dist),
                params = {
                    event = "police:client:ConfirmBreak",
                    args  = { serverId = ply.serverId }
                }
            }
        end
        menu[#menu+1] = {
            header = "Cancel",
            txt    = "",
            params = { event = "qb-menu:closeMenu" }
        }

        exports['qb-menu']:openMenu(menu)
    end
end

-- ///////////////////////////////////////////////////////////////////////////
-- Register chat command.
-- ///////////////////////////////////////////////////////////////////////////
RegisterCommand('breakwindow', BreakWindowHandler, false)
--[[ 
-- Optional key bind:
RegisterKeyMapping('breakwindow', 'Smash window & drag suspect', 'keyboard', 'G')
--]]
