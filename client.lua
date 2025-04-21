local QBCore = exports['qb-core']:GetCoreObject()

-- ///////////////////////////////////////////////////////////////////////////
-- CONFIG REFERENCE
--   Config.MaxTargetDistance, Config.AuthorizedJobs, Config.WindowIndex, etc.
-- ///////////////////////////////////////////////////////////////////////////

-- ///////////////////////////////////////////////////////////////////////////
-- Authorization check
-- ///////////////////////////////////////////////////////////////////////////
local function IsAuthorized()
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.job then return false end
    for _, job in ipairs(Config.AuthorizedJobs) do
        if pd.job.name == job then
            return true
        end
    end
    return false
end

-- ///////////////////////////////////////////////////////////////////////////
-- Gather all players within Config.MaxTargetDistance
-- ///////////////////////////////////////////////////////////////////////////
local function GetNearbyPlayers()
    local mePed = PlayerPedId()
    local mePos = GetEntityCoords(mePed)
    local out = {}

    for _, serverId in ipairs(QBCore.Functions.GetPlayers()) do
        local ped = GetPlayerPed(serverId)
        if ped ~= mePed then
            local dist = #(mePos - GetEntityCoords(ped))
            if dist <= Config.MaxTargetDistance then
                out[#out+1] = {
                    serverId = serverId,
                    ped      = ped,
                    dist     = dist,
                    name     = GetPlayerName(serverId)
                }
            end
        end
    end

    return out
end

-- ///////////////////////////////////////////////////////////////////////////
-- Smash window & drag logic.
-- ///////////////////////////////////////////////////////////////////////////
local function DoBreakWindowAndDrag(targetPed, seatIdx)
    local veh       = GetVehiclePedIsIn(targetPed, false)
    local windowIdx = Config.WindowIndex[seatIdx]
    local seatName  = Config.SeatNames[seatIdx] or "unknown"

    -- Smash window
    SmashVehicleWindow(veh, windowIdx)
    QBCore.Functions.Notify(("🔨 Smashed %s window."):format(seatName), "success")
    Wait(250)

    -- Force exit
    TaskLeaveVehicle(targetPed, veh, 0)
    Wait(500)

    -- Reposition on exit
    local offset   = Config.ExitOffsets[seatIdx]
    local worldPos = GetOffsetFromEntityInWorldCoords(veh, offset)
    SetEntityCoords(targetPed, worldPos.x, worldPos.y, worldPos.z)
    ClearPedTasksImmediately(targetPed)

    QBCore.Functions.Notify("✅ Suspect dragged out successfully.", "success")
end

-- ///////////////////////////////////////////////////////////////////////////
-- Called when the player selects someone from the menu
-- ///////////////////////////////////////////////////////////////////////////
RegisterNetEvent('police:client:ConfirmBreak', function(data)
    local ped = GetPlayerPed(data.serverId)
    if ped == PlayerPedId() then return end

    -- Ensure they’re still in a vehicle
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return QBCore.Functions.Notify("❗ Suspect left the vehicle.", "error")
    end

    -- Find their seat
    local seatIdx
    for s = -1, GetVehicleMaxNumberOfPassengers(veh)-1 do
        if GetPedInVehicleSeat(veh, s) == ped then
            seatIdx = s
            break
        end
    end

    if not seatIdx or not Config.WindowIndex[seatIdx] then
        return QBCore.Functions.Notify("❗ Unable to determine window.", "error")
    end

    DoBreakWindowAndDrag(ped, seatIdx)
end)

-- ///////////////////////////////////////////////////////////////////////////
-- Main handler: either auto‑target or show a menu if there’s more than one
-- ///////////////////////////////////////////////////////////////////////////
local function BreakWindowHandler()
    if not IsAuthorized() then
        return QBCore.Functions.Notify("❌ You are not authorized.", "error")
    end

    local nearby = GetNearbyPlayers()
    if #nearby == 0 then
        return QBCore.Functions.Notify(("⚠️ No suspects within %.1fm."):format(Config.MaxTargetDistance), "error")
    elseif #nearby == 1 then
        -- Only one choice: do it immediately
        local entry = nearby[1]
        local veh   = GetVehiclePedIsIn(entry.ped, false)
        local seatIdx
        for s = -1, GetVehicleMaxNumberOfPassengers(veh)-1 do
            if GetPedInVehicleSeat(veh, s) == entry.ped then seatIdx = s; break end
        end
        DoBreakWindowAndDrag(entry.ped, seatIdx)
    else
        -- Multiple choices: build and open a qb-menu
        local menu = {{ header = "🔍 Select a suspect", txt = "" }}
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
            header = "❌ Cancel",
            txt    = "",
            params = { event = "qb-menu:closeMenu" }
        }
        exports['qb-menu']:openMenu(menu)
    end
end

-- ///////////////////////////////////////////////////////////////////////////
-- THIRD EYE MAPPING
-- Binds Left Alt (LMENU) so that HOLDING it runs BreakWindowHandler()
-- ///////////////////////////////////////////////////////////////////////////
-- Note: RegisterKeyMapping will fire once per press.
RegisterKeyMapping('breakwindow', 'Third Eye: Smash & Drag', 'keyboard', 'LMENU')
RegisterCommand('breakwindow', BreakWindowHandler, false)

-- You can still type /breakwindow if you prefer chat commands.
