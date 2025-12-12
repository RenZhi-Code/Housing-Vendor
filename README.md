# HousingVendor

A comprehensive database browser for World of Warcraft housing decorations, allowing players to easily find and locate housing items from vendors across all expansions. Features a modern, performance-optimized UI with advanced filtering, statistics tracking, collection management, and seamless navigation integration.

## Features

### Complete Housing Database

- Browse thousands of housing decorations organized by expansion, zone, vendor, type, and category
- Vendor locations with precise coordinates for easy navigation
- Comprehensive coverage of items from all WoW expansions (Classic through Midnight)
- Support for vendor items, quest rewards, achievement rewards, drop rewards, crafted items, and more

### Modern User Interface

- **Multiple UI Themes**: Four distinct visual themes available
  - **Midnight Theme** (Default): Deep purples, moonlit blues, and silver accents
  - **Alliance Theme**: Royal blues and gold - For the Alliance!
  - **Horde Theme**: Crimson reds and dark iron - Lok'tar Ogar!
  - **Sleek Black Theme**: Modern minimalist with pure blacks and cyan accents
  - Seamless theme switching via Settings panel
  - Theme preference saved and persists across sessions
  - Real-time theme updates without reload

- **Color-Coded Item Bars**: Visual indicators for faction (Horde/Alliance/Neutral) and source type (Achievement/Quest/Drop/Vendor)
- **Customizable Display**: Adjustable UI scale (0.5x to 1.5x) and font size (10-18px) via Settings
- **Modern Filter Layout**: Clean, grid-aligned filter panel with multi-column dropdowns for easy browsing
- **Item List Headers**: Clear column headers (Item Name, Source, Location, Price) for organized viewing
- **Enhanced Visual Design**: Professional stat cards, gradient progress bars, improved tooltip styling

### Advanced Search & Filtering

- **Multi-Filter System**: Filter by expansion, vendor, zone, type, category, faction, source, and search text
- **Collection Filter**: Filter items by collection status (Collected/Uncollected/All)
  - Automatic batch scanning of uncached items when filter is applied
  - Real-time filter cache invalidation when collection status changes
- **Smart Dropdowns**: Multi-column layout (2-4 columns) for Vendor and Zone filters to handle large lists efficiently
- **Real-Time Filtering**: Instant results as you type or change filters
- **Hide Unreleased**: Option to hide items from unreleased expansions
- **Dynamic Search**: Searches across item names, vendor names, zones, types, and categories simultaneously

### Collection Tracking System

- **Real-Time Collection Detection**: Automatic collection status tracking using multiple WoW API methods
  - Primary: `C_Housing.IsDecorCollected(decorID)` - Direct decor collection check
  - Secondary: `C_HousingCatalog.GetCatalogEntryInfoByRecordID(recordID)` - Catalog entry info
  - Tertiary: `C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)` - Item-based lookup
  - Fallback: `C_PlayerInfo.IsItemCollected(itemID)` - General item collection check
  - Quantity-based: Uses `numStored + numPlaced > 0` from API data for owned items

- **Event-Driven Updates**: Automatic collection status updates via WoW events
  - Updates when items are added to housing chest
  - Updates when collection changes
  - Updates when items are purchased
  - Updates when viewing vendors
  - Updates when items are obtained or looted
  - Updates on zone transitions and login

- **Passive Collection Updates**: Tooltip callback integration
  - Automatic collection status detection when hovering over items in housing catalog
  - Silent background updates without user interaction
  - Efficient API usage with intelligent caching

- **Dual-Layer Caching**: 
  - Session cache (fast, cleared on reload)
  - Persistent cache (survives reloads and sessions)
  - Automatic cache migration from legacy systems

- **Visual Collection Indicators**: 
  - Green checkmark overlay for collected items
  - Owned quantity display on item icons
  - Color-coded collection status throughout the interface

### Statistics Dashboard

- **Collection Progress Overview**: Overall completion percentage with visual progress bar
- **Items by Source**: Detailed breakdown by Achievement, Quest, Drop, Vendor, and Profession
  - Shows collected/total for each source type
  - Visual progress bars with color-coded source types
  - Cost breakdown (free, gold cost, currency cost) for each source
- **Items by Faction**: Collection statistics for Horde, Alliance, and Neutral items
  - Color-coded bar graphs matching faction colors
  - Collected/total counts for each faction
- **Items by Expansion**: Top 10 expansions sorted by total items
  - Collection percentages for each expansion
  - Collected/total counts
  - Breakdown by source type within each expansion
- **Items by Category**: Detailed category breakdown with collection progress
  - Shows collected/total for each category
  - Top categories sorted by total items
  - Source type breakdown within categories
- **Items by Profession**: Crafted items organized by profession
  - Collection progress for each profession
  - Visual progress bars for profession-specific items
- **Items by Quality/Rarity**: Breakdown by item quality (Poor, Common, Uncommon, Rare, Epic, Legendary)
  - Quality color coding matching WoW item quality colors
  - Collection progress for each quality tier
- **Items by Price Range**: Price-based categorization
  - Free items, Cheap (1-100g), Moderate (101-1,000g), Expensive (1k-10kg), Luxury (10kg+)
  - Collection progress for each price range
- **Items by Currency**: Breakdown of items requiring specific currencies
  - Shows collected/total for each currency type
  - Top currencies sorted by total items
- **Housing Inventory Stats**: Real-time inventory tracking from API
  - Total items in storage
  - Total items placed in housing
  - Items with API data vs total items
- **Travel Statistics**: Vendor location and travel information
  - Unique vendor locations count
  - Zones to visit with uncollected items
  - Total vendors across all expansions
  - Top zones by uncollected items (with vendor counts)
  - Zone-by-zone breakdown with collection progress
- **Easy Wins Section**: Quick reference for easy-to-obtain items
  - Lists free or cheap (≤50g) uncollected items
  - Shows item name, price, source type, and zone
  - Sorted by price (cheapest first)
  - Limited to top 15 items for quick reference

### Detailed Item Information

- **Comprehensive Tooltips**: Hover over items to see detailed information, including:
  - Item name, quality, and type
  - Source type and specific source name (achievement/quest/drop/vendor name)
  - Vendor location and zone
  - Pricing (gold or currency)
  - Coordinates for waypoint navigation
  - Faction requirements
  - Item ID and expansion
  - Large item icon
  - Full item description
  - Vendor information and coordinates
  - Achievement/Quest/Drop source details
  - Item level, quality, binding, and sell price
  - Availability and expansion information

- **Enhanced Preview Panel**:
  - **Improved Readability**: Increased font sizes throughout the panel
    - Larger headers and labels for better visibility
    - Adjusted vertical spacing to accommodate larger fonts
    - Repositioned elements to prevent overflow

  - **Profession Information Display**:
    - **Reagent Requirements**: Complete reagent list for crafted items
      - Shows all required reagents with item names and quantities (e.g., "5x Iron Ore")
      - Dynamically loads reagent item names from WoW API
      - Displays reagents in dedicated right-side panel for easy viewing
      - Auto-refreshes item names if initially unavailable
    - **Profession Details**: Comprehensive profession information
      - Profession name (e.g., "Blacksmithing", "Engineering")
      - Skill level requirement with current skill comparison
      - Color-coded status: Green if skill requirement met, Red if not met
      - Recipe/pattern name from spell ID or recipe ID
      - Real-time skill level checking against player's current profession skill

  - **Enhanced Reputation Information**:
    - **Detailed Reputation Display**: Comprehensive reputation requirement information
      - Faction name with color coding (green if requirement met, red if not met)
      - Required standing clearly displayed (e.g., "Revered", "Exalted")
      - Current player standing with progress tracking
      - Progress bar showing current reputation value (e.g., "Friendly (1250/3000)")
      - Automatic faction ID mapping for accurate reputation detection
      - Case-insensitive reputation standing comparison
      - Support for both standard factions and major faction renown
    - **Reputation Status Indicators**:
      - Green text for met requirements
      - Red text for unmet requirements with current standing shown
      - Progress values displayed in parentheses
      - Tooltip support for additional reputation information

  - **Quest Information Display**:
    - **Interactive Quest Tooltips**: Clickable quest requirements
      - Quest name displayed in Requirements section
      - Hover over quest name to see full quest tooltip
      - Quest ID integration for accurate quest lookup
      - Support for quest requirements from both static data and API unlock requirements
      - Automatic quest name resolution from quest ID

  - **Collection Status**: 
    - Visual collection status indicators (green checkmark for collected items)
    - Real-time collection status updates
    - Accurate collection detection using CollectionAPI

- **Source Type Display**: Clear indication of item source (Achievement, Quest, Drop, or Vendor) with color coding

### Navigation Integration

- **Click-to-Set Waypoints**: Click any item bar with coordinates to instantly set a waypoint
- **Blizzard Waypoint Support**: Native waypoint integration using `C_Map.SetUserWaypoint()`
- **TomTom Integration**: Optional TomTom addon support for enhanced waypoint features
- **Visual Waypoint Indicator**: Map icon on item bars indicates waypoint availability
- **Automatic Routing**: For cross-continent travel, the addon will:
  - Find the nearest portal to your destination continent
  - Set a waypoint to the portal first
  - Automatically set the final destination waypoint after you reach the portal

### Localization Support

- **Multi-Language Support**: Full localization for 11 languages:
  - English (US)
  - German (deDE)
  - French (frFR)
  - Spanish (esES, esMX)
  - Italian (itIT)
  - Portuguese (ptBR)
  - Russian (ruRU)
  - Korean (koKR)
  - Simplified Chinese (zhCN)
  - Traditional Chinese (zhTW)

## Usage

### Commands

- `/hv` or `/housingvendor` or `/decor` - Open/close the main Housing Vendor interface
- `/hv scan` or `/hv refresh` or `/hv rescan` - Force comprehensive collection scan
  - Scans all housing decor items via API
  - Batch processing to avoid performance issues
  - Displays scan progress and results
  - Automatically refreshes UI after completion
- `/hv version` or `/hv versioncheck` - Display version filter information
  - Shows current game version, build, and TOC version
  - Indicates if running on beta/PTR client
  - Lists available expansions
  - Shows Midnight content visibility status
- `/hv stats` or `/hv statistics` - Show completion statistics in chat
- `/hv test` - Test addon functionality and show module status

### Interface Overview

#### Main Window

- **Draggable**: Click and drag the title bar to move the window
- **Resizable**: Adjust window size to fit your preferences
- **Minimap Button**: Click the minimap button to open/close the interface

#### Filter Panel

- **Search Box**: Type to search across all item fields
- **Expansion Filter**: Filter by game expansion (Classic, TBC, WotLK, etc.)
- **Vendor Filter**: Multi-column dropdown showing all vendors
- **Zone Filter**: Multi-column dropdown showing all zones
- **Type Filter**: Filter by item type (Decorative, Functional, etc.)
- **Category Filter**: Filter by item category (Furniture, Lighting, etc.)
- **Faction Filter**: Filter by Horde, Alliance, or Neutral
- **Source Filter**: Filter by Achievement, Quest, Drop, or Vendor
- **Collection Filter**: Filter by Collected, Uncollected, or All items
- **Hide Unreleased**: Toggle to hide items from unreleased expansions
- **Clear Filters**: Button to reset all filters at once

#### Item List

- **Color-Coded Bars**:
  - Red border/background = Horde items
  - Blue border/background = Alliance items
  - Gold = Achievement items
  - Bright Blue = Quest items
  - Orange/Red = Drop items
  - Green = Vendor items
  - Gray = Neutral items

- **Item Information**: Each item bar shows:
  - Item icon
  - Item name
  - Source type and name (e.g., "Achievement: [Name]" or "Vendor: [Name]")
  - Housing icon and weight (when available)
  - Zone name (for vendor items)
  - Price (gold or currency)
  - Map icon (if coordinates available)
  - Collection status indicator (green checkmark if collected)
  - Owned quantity (if applicable)

- **Hover Effects**: Gold border glow and brightness increase on hover
- **Click Actions**: Click item bar to set waypoint (if coordinates available)

#### Statistics Dashboard

- **Access**: Click "Statistics" button in the main window header
- **Collection Progress**: Overall progress bar and percentage
- **Bar Graphs**: Visual representation of collection by source, faction, category, and expansion
- **Travel Statistics**: Vendor locations and zones to visit
- **Easy Wins**: Quick reference for free or cheap uncollected items
- **Back Button**: Return to main item list

#### Settings Panel

- **Access**: Click "Settings" button in the main window header
- **UI Scale Slider**: Adjust interface scale from 0.5x to 1.5x
- **Font Size Slider**: Adjust text size from 10px to 18px
- **Theme Selector**: Choose from four available themes (Midnight, Alliance, Horde, Sleek Black)
- **Save Button**: Save settings to database
- **Reset to Defaults**: Restore default settings

### Key Functionalities

#### Setting Waypoints

- **Click Item Bar**: Click any item bar that has a map icon (indicating coordinates are available)
- **Automatic Routing**: For cross-continent travel, the addon will:
  - Find the nearest portal to your destination continent
  - Set a waypoint to the portal first
  - Automatically set the final destination waypoint after you reach the portal
- **Blizzard Waypoints**: Uses native WoW waypoint system (works without addons)
- **TomTom Integration**: If TomTom is installed, waypoints are also added to TomTom

#### Filtering Items

- Use the search box for quick text search
- Select from dropdown filters to narrow results
- Multiple filters work together (AND logic)
- Collection filter automatically scans uncached items when applied
- Click "Clear Filters" to reset everything

#### Viewing Statistics

- Click "Statistics" button in the header
- View your collection progress across different categories
- Scroll through comprehensive statistics breakdowns
- Use the "Back" button to return to the item list

#### Customizing Display

- Click "Settings" button in the header
- Adjust UI Scale slider for larger/smaller interface
- Adjust Font Size slider for larger/smaller text
- Select a theme to change the visual appearance
- Click "Save" to apply changes
- Changes apply immediately to both item list and statistics

#### Collection Management

- Collection status is automatically tracked via WoW events
- Hover over items in the housing catalog for passive collection updates
- Use `/hv scan` to force a comprehensive collection scan
- Collection status is cached persistently and survives reloads
- Filter by collection status to see what you have or need

## Technical Details

### Version Compatibility

- **Interface Compatibility**: Supports both Interface 110207 (The War Within) and 120000 (Midnight)
- **Midnight API Support**: Conditional event registration for Midnight expansion features
  - Safe registration of `HOUSING_CATALOG_UPDATED` event using pcall
  - Automatic detection of client version (11.2.7 vs 12.x)
  - No errors on live clients when Midnight events are unavailable
  - Full compatibility with both The War Within (11.2.7) and Midnight (12.x) clients

### Performance

- **Batch Processing**: Large operations split into batches with delays
  - Prevents UI freezing during large scans
  - Configurable batch sizes and delays
  - Progress feedback for long operations
- **Intelligent Caching**:
  - Persistent cache survives reloads and sessions
  - Session cache for faster lookups during current session
  - Automatic cache invalidation when needed
  - Efficient API usage with minimal redundant calls
- **Smart Filter Caching**: Filter results cached for faster re-filtering
  - Automatic cache invalidation when collection status updates
  - Batch processing for large item lists

### Data Management

- **HousingDecorData Integration**: 
  - Helper functions for itemID ↔ decorID conversion
  - Seamless mapping between item and decor identifiers
  - Support for all housing decor items across expansions
- **Version Filtering**: Automatically hides items not available in the current game version
  - Shows beta content (e.g., Midnight expansion) only when logged into beta client

## Credits

- **Author**: RenZhi
- **Housing item data** compiled from various in-game sources and community contributions
- **Inspired by** the need for better housing decoration discovery in World of Warcraft

## Version

Current Version: **12.12.25.80**

For detailed changelog, see [CHANGELOG.md](CHANGELOG.md)

