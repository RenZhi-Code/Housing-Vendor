-- Event handling
local addonName, addon = ...

_G["HousingEvents"] = {}
local HousingEvents = _G["HousingEvents"]

function HousingEvents:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == "HousingVendor" then
      -- Make Housing globally available
      _G.Housing = Housing or {}
      Housing.Initialize = Housing.Initialize or function(self)
        self:InitializeSavedVariables()
        
        -- Initialize other modules with error handling
        local initErrors = {}
        
        if HousingAPI then
          if HousingAPI.Initialize then
            local success, err = pcall(function() HousingAPI:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingAPI: " .. tostring(err))
            end
          end
        end
        
        if HousingCatalogAPI then
          if HousingCatalogAPI.Initialize then
            local success, err = pcall(function() HousingCatalogAPI:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingCatalogAPI: " .. tostring(err))
            end
          end
        end
        
        if HousingDecorAPI then
          if HousingDecorAPI.Initialize then
            local success, err = pcall(function() HousingDecorAPI:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingDecorAPI: " .. tostring(err))
            end
          end
        end
        
        if HousingEditorAPI then
          if HousingEditorAPI.Initialize then
            local success, err = pcall(function() HousingEditorAPI:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingEditorAPI: " .. tostring(err))
            end
          end
        end
        
        if HousingDataEnhancer then
          if HousingDataEnhancer.Initialize then
            local success, err = pcall(function() HousingDataEnhancer:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingDataEnhancer: " .. tostring(err))
            end
          end
        end
        
        if HousingWaypointManager then
          if HousingWaypointManager.Initialize then
            local success, err = pcall(function() HousingWaypointManager:Initialize() end)
            if not success then
              table.insert(initErrors, "HousingWaypointManager: " .. tostring(err))
            end
          end
        end

        if #initErrors > 0 then
          print("|cFFFF0000Housing|r|cFF0066FFVendor|r version" .. (Housing.version or " unknown") .. " loaded (some modules failed)")
        else
          print("|cFFFF0000Housing|r|cFF0066FFVendor|r version" .. (Housing.version or " unknown") .. " loaded")
        end
      end
      
      Housing.InitializeSavedVariables = Housing.InitializeSavedVariables or function(self)
        -- Schema version for SavedVariables migrations
        local CURRENT_SCHEMA_VERSION = 2

        -- Set defaults if DB doesn't exist
        if not HousingDB then
          HousingDB = {}
        end

        -- Initialize schema version
        if not HousingDB.schemaVersion then
          HousingDB.schemaVersion = 1
        end
        
        -- Initialize saved variables
        if not HousingDB.minimapButton then
          HousingDB.minimapButton = {
            hide = false,
            position = {
              minimapPos = 225,
            },
          }
        end
        
        if not HousingDB.settings then
          HousingDB.settings = {
            showCollected = true,
            usePortalNavigation = true,
            displayMode = "items",
            autoTrackCompletion = false,
            enableMarketData = false,
            preloadApiData = false,
            preloadDataOnLogin = false,
            disableApiCalls = false,
          }
        end

        -- Ensure new settings are initialized for existing users
        if HousingDB.settings.usePortalNavigation == nil then
          HousingDB.settings.usePortalNavigation = true
        end

        if HousingDB.settings.disableApiCalls == nil then
          HousingDB.settings.disableApiCalls = false
        end

        if HousingDB.settings.showCollected == nil then
          HousingDB.settings.showCollected = true
        end

        if HousingDB.settings.autoTrackCompletion == nil then
          HousingDB.settings.autoTrackCompletion = false
        end

        if HousingDB.settings.enableMarketData == nil then
          HousingDB.settings.enableMarketData = false
        end

        if HousingDB.settings.preloadApiData == nil then
          HousingDB.settings.preloadApiData = false
        end
        
        if HousingDB.settings.showOutstandingPopup == nil then
          HousingDB.settings.showOutstandingPopup = true
        end
        
        if HousingDB.settings.autoFilterByZone == nil then
          HousingDB.settings.autoFilterByZone = false
        end

        if HousingDB.settings.preloadDataOnLogin == nil then
          HousingDB.settings.preloadDataOnLogin = false
        end

        -- Migration: preloading the datapack at login defeats low-memory goals.
        -- Disable it once for existing users; they can re-enable via settings if desired.
        if HousingDB.settings.preloadDataOnLogin == true and HousingDB.settings._preloadDataOnLoginDisabledOnce ~= true then
          HousingDB.settings.preloadDataOnLogin = false
          HousingDB.settings._preloadDataOnLoginDisabledOnce = true
          print("|cFF8A7FD4HousingVendor:|r Disabled 'preload data on login' to reduce login memory (re-enable in settings if you really want it).")
        end

        if not HousingDB.uiScale then
          HousingDB.uiScale = 1.0
        end
        
        if not HousingDB.fontSize then
          HousingDB.fontSize = 12
        end

        -- Icon cache is session-only (never persisted to SavedVariables)
        if HousingDB.iconCache ~= nil then
          HousingDB.iconCache = nil
        end
        if HousingDB.settings.persistIconCache ~= nil then
          HousingDB.settings.persistIconCache = nil
        end

        -- Initialize wishlist (account-wide)
        if not HousingDB.wishlist then
          HousingDB.wishlist = {}
        end

        -- Session-only caches: Remove old persistent caches to prevent SavedVariables bloat.
        -- Collection status is queried fresh from API each session (no persistent cache needed)
        if HousingDB.collectedDecor ~= nil then
          HousingDB.collectedDecor = nil
        end
        if HousingDB.apiDataCache ~= nil or HousingDB.apiDataCacheAccess ~= nil then
          HousingDB.apiDataCache = nil
          HousingDB.apiDataCacheAccess = nil
        end
        if HousingDB.apiDump ~= nil or HousingDB.apiDumpByFaction ~= nil then
          HousingDB.apiDump = nil
          HousingDB.apiDumpByFaction = nil
        end
        if collectgarbage then
          collectgarbage("step", 1000)
        end

        -- Migration: Remove deprecated collectedItems field (replaced by collectedDecor)
        if HousingDB.collectedItems ~= nil then
          HousingDB.collectedItems = nil
        end

        -- Run schema migrations
        self:MigrateSchema()
      end

      Housing.MigrateSchema = Housing.MigrateSchema or function(self)
        local CURRENT_SCHEMA_VERSION = 2
        local version = HousingDB.schemaVersion or 1

        -- Migration from v1 to v2
        if version < 2 then
          -- v2: Removed deprecated collectedItems field
          -- (Already handled above, but formalized here)
          if HousingDB.collectedItems ~= nil then
            HousingDB.collectedItems = nil
          end

          HousingDB.schemaVersion = 2
        end

        -- Future migrations go here
        -- if version < 3 then
        --   -- Migration from v2 to v3
        --   HousingDB.schemaVersion = 3
        -- end
      end
      
      Housing:Initialize()

      -- Initialize VersionFilter (should be done early to filter expansion data)
      if HousingVersionFilter then
        local success, err = pcall(HousingVersionFilter.Initialize, HousingVersionFilter)
        if not success then
          print("HousingVendor: VersionFilter initialization error: " .. tostring(err))
        end
      end

      -- Initialize Performance Auditor
      if HousingPerformanceAuditor then
        local success, err = pcall(HousingPerformanceAuditor.Initialize, HousingPerformanceAuditor)
        if not success then
          print("HousingVendor: PerformanceAuditor initialization error: " .. tostring(err))
        end
      end

      -- Initialize DataManager and Icons first (required by UI)
      if HousingDataManager then
        local success, err = pcall(HousingDataManager.Initialize, HousingDataManager)
        if not success then
          print("HousingVendor: DataManager initialization error: " .. tostring(err))
        end
      end
      
      if HousingIcons and HousingIcons.Initialize then
        local success, err = pcall(HousingIcons.Initialize, HousingIcons)
        if not success then
          print("HousingVendor: Icons initialization error: " .. tostring(err))
        end
      end

      -- Initialize config UI
      if HousingConfigUI then
        local success, err = pcall(HousingConfigUI.Initialize, HousingConfigUI)
        if not success then
          print("HousingVendor: ConfigUI initialization error: " .. tostring(err))
        end
      end
      
      -- Initialize statistics UI
      if HousingStatisticsUI then
        local success, err = pcall(HousingStatisticsUI.Initialize, HousingStatisticsUI)
        if not success then
          print("HousingVendor: StatisticsUI initialization error: " .. tostring(err))
        end
      end
      
      -- Initialize outstanding items UI
      if HousingOutstandingItemsUI then
        local success, err = pcall(HousingOutstandingItemsUI.Initialize, HousingOutstandingItemsUI)
        if not success then
          print("HousingVendor: OutstandingItemsUI initialization error: " .. tostring(err))
        end
      end

      -- Initialize new UI after all modules and data are loaded
      if HousingUINew then
        local success, err = pcall(HousingUINew.Initialize, HousingUINew)
        if success then
          -- Silently initialized
        else
          print("HousingVendor UI initialization error: " .. tostring(err))
        end
      else
        print("HousingVendor UI module not found - check file loading order")
      end
      
      -- Debug: Check if modules are loaded
      if HousingDebugPrint then
        HousingDebugPrint("Module check:")
        HousingDebugPrint("  HousingDataManager: " .. tostring(HousingDataManager ~= nil))
        HousingDebugPrint("  HousingIcons: " .. tostring(HousingIcons ~= nil))
        HousingDebugPrint("  HousingUINew: " .. tostring(HousingUINew ~= nil))
        HousingDebugPrint("  HousingItemList: " .. tostring(HousingItemList ~= nil))
        HousingDebugPrint("  HousingFilters: " .. tostring(HousingFilters ~= nil))
        HousingDebugPrint("  HousingPreviewPanel: " .. tostring(HousingPreviewPanel ~= nil))
      end
    end
  end

  if event == "PLAYER_LOGIN" then
    -- Preload data addon if setting is enabled
    if HousingDB and HousingDB.settings and HousingDB.settings.preloadDataOnLogin then
        if HousingDataLoader and HousingDataLoader.LoadData then
          HousingDataLoader:LoadData(function(success)
            if success then
             local mem = (GetAddOnMemoryUsage and string.format("%.1f MB", GetAddOnMemoryUsage("HousingVendor") / 1024)) or "ready"
             print("|cFF8A7FD4HousingVendor:|r Data preloaded (" .. mem .. ")")
            end
          end)
        end
      end

    -- Some C_* APIs (and the catalog searcher) can be unavailable on ADDON_LOADED.
    -- Retry once at login to ensure vendor/zone naming data is available for filters.
    if HousingAPI and HousingAPI.CreateCatalogSearcher then
      pcall(function() HousingAPI:CreateCatalogSearcher() end)
    end

    -- Start zone popup event handlers if popup setting is enabled.
    -- Note: this feature needs datapack data to compute zone/vendor matches.
    if HousingDB and HousingDB.settings and HousingDB.settings.showOutstandingPopup then
      if HousingDataLoader and HousingDataLoader.LoadData then
        HousingDataLoader:LoadData(function(success)
          if success then
            -- Build index cache early since data is now loaded at startup
            if HousingDataManager and HousingDataManager.GetAllItemIDs then
              pcall(function() HousingDataManager:GetAllItemIDs() end)
            end

            if HousingReputation and HousingReputation.StartTracking then
              HousingReputation:StartTracking()
            end
            if HousingOutstandingItemsUI and HousingOutstandingItemsUI.StartEventHandlers then
              HousingOutstandingItemsUI:StartEventHandlers()
            end
          end
        end)
      end
    end
  end

  if event == "PLAYER_LOGOUT" then
    if HousingEvents.Shutdown then
      HousingEvents:Shutdown()
    end
  end
end

function HousingEvents:Shutdown()
  print("|cFF8A7FD4HousingVendor:|r Shutting down...")

  if HousingAPICache and HousingAPICache.StopCleanupTimer then
    HousingAPICache:StopCleanupTimer()
  end
  if HousingDataEnhancer and HousingDataEnhancer.StopMarketRefresh then
    HousingDataEnhancer:StopMarketRefresh()
  end
  if HousingCollectionAPI and HousingCollectionAPI.StopEventHandlers then
    HousingCollectionAPI:StopEventHandlers()
  end
  if HousingWaypointManager and HousingWaypointManager.ClearWaypoint then
    HousingWaypointManager:ClearWaypoint()
  end
  if HousingOutstandingItemsUI and HousingOutstandingItemsUI.StopEventHandlers then
    HousingOutstandingItemsUI:StopEventHandlers()
  end
  if HousingItemList and HousingItemList.Cleanup then
    HousingItemList:Cleanup()
  end
  if HousingReputation and HousingReputation.StopTracking then
    HousingReputation:StopTracking()
  end

  collectgarbage("collect")
end

-- Register events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, ...)
  HousingEvents:OnEvent(event, ...)
end)
