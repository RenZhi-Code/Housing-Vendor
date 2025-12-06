-- Waypoint Manager Module for HousingVendor addon
-- Handles both Blizzard native waypoints and TomTom integration

local WaypointManager = {}
WaypointManager.__index = WaypointManager

local pendingDestination = nil
local eventFrame = CreateFrame("Frame")
local lastMapID = nil
local function GetExpansionFromMapID(mapID)
    if not mapID or mapID == 0 then return nil end
    if HousingMapIDToExpansion and HousingMapIDToExpansion[mapID] then
        return HousingMapIDToExpansion[mapID]
    end
    return nil
end

local function GetPortalRoom()
    local faction = UnitFactionGroup("player")

    if faction == "Alliance" then
        return {
            name = "Stormwind Portal Room",
            x = 49.0,
            y = 87.0,
            mapID = 84,
            zoneName = "Stormwind City"
        }
    elseif faction == "Horde" then
        return {
            name = "Orgrimmar Portal Room",
            x = 49.0,
            y = 38.0,
            mapID = 85,
            zoneName = "Orgrimmar"
        }
    end

    return nil
end
local function RequiresPortalTravel(currentMapID, destinationMapID)
    if not currentMapID or not destinationMapID then return false end
    if currentMapID == destinationMapID then return false end

    local currentExpansion = GetExpansionFromMapID(currentMapID)
    local destExpansion = GetExpansionFromMapID(destinationMapID)

    if not currentExpansion or not destExpansion then
        return true
    end

    return currentExpansion ~= destExpansion
end
local function FindNearestPortal(currentMapID, destinationMapID, currentX, currentY)
    if not HousingPortalData then return nil end

    local currentExpansion = GetExpansionFromMapID(currentMapID)
    local destinationExpansion = GetExpansionFromMapID(destinationMapID)

    if currentExpansion == destinationExpansion then
        return nil
    end

    local currentZonePortals = nil

    for zoneName, portals in pairs(HousingPortalData) do
        if portals and #portals > 0 then
            for _, portal in ipairs(portals) do
                if portal.mapID == currentMapID then
                    currentZonePortals = portals
                    break
                end
            end
            if currentZonePortals then break end
        end
    end

    if not currentZonePortals then return nil end

    local nearestPortal = nil
    local minDistance = math.huge

    for _, portal in ipairs(currentZonePortals) do
        if portal.mapID == currentMapID then
            local dx = (portal.x - currentX) * (portal.x - currentX)
            local dy = (portal.y - currentY) * (portal.y - currentY)
            local distance = math.sqrt(dx + dy)

            if distance < minDistance then
                minDistance = distance
                nearestPortal = portal
            end
        end
    end

    return nearestPortal
end
-- Invalidate player position cache
local function InvalidatePlayerPosition()
    playerPositionValid = false
end

local function GetPlayerPosition()
    -- Return cached position if valid
    if playerPositionValid and cachedPlayerMapID then
        return cachedPlayerMapID, cachedPlayerX, cachedPlayerY
    end
    
    -- Fetch fresh position
    local currentMapID = nil
    local currentX = nil
    local currentY = nil

    if C_Map and C_Map.GetBestMapForUnit then
        local success, mapID = pcall(function()
            return C_Map.GetBestMapForUnit("player")
        end)
        if success and mapID then
            currentMapID = mapID
        end
    end

    if C_Map and C_Map.GetPlayerMapPosition and currentMapID then
        local success, position = pcall(function()
            return C_Map.GetPlayerMapPosition(currentMapID, "player")
        end)
        if success and position then
            currentX, currentY = position:GetXY()
        end
    end

    -- Cache the result
    cachedPlayerMapID = currentMapID
    cachedPlayerX = currentX
    cachedPlayerY = currentY
    playerPositionValid = true

    return currentMapID, currentX, currentY
end
local function GetNearestFlightPoint(destinationMapID, destX, destY)
    if not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap then
        return nil
    end

    local success, taxiNodes = pcall(function()
        return C_TaxiMap.GetTaxiNodesForMap(destinationMapID)
    end)

    if not success or not taxiNodes or #taxiNodes == 0 then
        return nil
    end

    local nearestNode = nil
    local minDistance = math.huge

    for _, node in ipairs(taxiNodes) do
        if node.position then
            local nodeX, nodeY = node.position:GetXY()
            local dx = (nodeX - destX) * (nodeX - destX)
            local dy = (nodeY - destY) * (nodeY - destY)
            local distance = math.sqrt(dx + dy)

            if distance < minDistance then
                minDistance = distance
                nearestNode = {
                    name = node.name,
                    x = nodeX * 100,
                    y = nodeY * 100,
                    mapID = destinationMapID,
                    nodeID = node.nodeID
                }
            end
        end
    end

    return nearestNode
end
local function SetBlizzardWaypoint(mapID, x, y)
    if not C_Map or not C_Map.SetUserWaypoint then
        return false, "Blizzard map API not available"
    end

    local success, err = pcall(function()
        C_Map.ClearUserWaypoint()
        local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(point)

        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)

    if not success then
        return false, tostring(err)
    end

    return true, nil
end
local function SetTomTomWaypoint(mapID, x, y, title)
    if not TomTom then
        return false, "TomTom addon not installed"
    end

    if not TomTom.AddWaypoint then
        return false, "TomTom.AddWaypoint not available"
    end

    local success, err = pcall(function()
        local waypointUID = TomTom:AddWaypoint(mapID, x, y, {
            title = title,
            persistent = false,
            minimap = true,
            world = true
        })

        if not waypointUID then
            error("TomTom:AddWaypoint returned nil")
        end
    end)

    if not success then
        return false, tostring(err)
    end

    return true, nil
end
function WaypointManager:SetWaypoint(item)
    if not item then
        print("|cFFFF4040HousingVendor:|r No item data provided")
        return false
    end

    if not item.vendorCoords or not item.vendorCoords.x or not item.vendorCoords.y then
        print("|cFFFF4040HousingVendor:|r No valid coordinates for waypoint")
        return false
    end

    if not item.mapID or item.mapID == 0 then
        print("|cFFFF4040HousingVendor:|r No valid map ID for waypoint")
        return false
    end

    local x = item.vendorCoords.x / 100
    local y = item.vendorCoords.y / 100

    if x < 0 or x > 1 or y < 0 or y > 1 then
        print("|cFFFF4040HousingVendor:|r Invalid coordinates: " .. tostring(x) .. ", " .. tostring(y))
        return false
    end

    local currentMapID = GetPlayerPosition()
    local locationName = item.vendorName or item.name or item.zoneName or "location"
    local destinationExpansion = GetExpansionFromMapID(item.mapID)
    local coords = string.format("%.1f, %.1f", item.vendorCoords.x, item.vendorCoords.y)

    if currentMapID and RequiresPortalTravel(currentMapID, item.mapID) then
        local portalRoom = GetPortalRoom()

        if portalRoom then
            print("|cFFFFAA00=== HousingVendor: Portal Routing Required ===|r")
            print("|cFFFFD100Step 1:|r Navigate to " .. portalRoom.name)
            print("|cFFFFD100Step 2:|r Use portal to |cFF00FF00" .. (destinationExpansion or item.zoneName or "destination") .. "|r")
            print("|cFFFFD100Step 3:|r Waypoint will automatically update when you arrive!")
            print("|cFFFFAA00==========================================|r")

            pendingDestination = {
                item = item,
                locationName = locationName
            }

            local portalX = portalRoom.x / 100
            local portalY = portalRoom.y / 100

            SetBlizzardWaypoint(portalRoom.mapID, portalX, portalY)
            SetTomTomWaypoint(portalRoom.mapID, portalX, portalY, portalRoom.name)

            return true
        end
    end

    if pendingDestination and pendingDestination.item then
        local pendingItem = pendingDestination.item
        pendingDestination = nil
        return self:SetWaypoint(pendingItem)
    end

    SetBlizzardWaypoint(item.mapID, x, y)
    SetTomTomWaypoint(item.mapID, x, y, locationName)

    print("|cFF00FF00HousingVendor:|r Waypoint set to " .. locationName .. " at |cFFFFD100" .. coords .. "|r")

    return true
end
function WaypointManager:ClearPendingDestination()
    if pendingDestination then
        print("|cFF00FF00HousingVendor:|r Cleared pending destination")
        pendingDestination = nil
        return true
    end
    return false
end

function WaypointManager:HasPendingDestination()
    return pendingDestination ~= nil
end

local function OnZoneChanged()
    if not pendingDestination or not pendingDestination.item then
        return
    end

    local currentMapID = nil
    if C_Map and C_Map.GetBestMapForUnit then
        local success, mapID = pcall(function()
            return C_Map.GetBestMapForUnit("player")
        end)
        if success and mapID then
            currentMapID = mapID
        end
    end

    if not currentMapID then
        return
    end

    if lastMapID == currentMapID then
        return
    end

    lastMapID = currentMapID

    local currentExpansion = GetExpansionFromMapID(currentMapID)
    local destinationExpansion = GetExpansionFromMapID(pendingDestination.item.mapID)

    if currentExpansion and destinationExpansion and currentExpansion == destinationExpansion then
        C_Timer.After(1.5, function()
            if pendingDestination and pendingDestination.item then
                local item = pendingDestination.item
                pendingDestination = nil
                WaypointManager:SetWaypoint(item)
            end
        end)
    end
end
-- Single event handler function (avoids creating closures)
local function OnEventHandler(self, event, ...)
    InvalidatePlayerPosition()  -- Invalidate cached position on any zone change
    OnZoneChanged()
end

eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")  -- Most reliable single event for zone changes
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", OnEventHandler)

function WaypointManager:Initialize()
    if C_Map and C_Map.GetBestMapForUnit then
        local success, mapID = pcall(function()
            return C_Map.GetBestMapForUnit("player")
        end)
        if success and mapID then
            lastMapID = mapID
        end
    end

    print("|cFF00FF00HousingVendor:|r Waypoint Manager initialized with automatic portal routing")
end

_G["HousingWaypointManager"] = WaypointManager

return WaypointManager
