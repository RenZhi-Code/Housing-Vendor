# HousingVendor

A comprehensive database browser for World of Warcraft housing decorations, allowing players to easily find and locate housing items from vendors across all expansions. Features a modern, performance-optimized UI with advanced filtering, statistics tracking, and seamless navigation integration.

## Features

### Complete Housing Database

*   Browse thousands of housing decorations organized by expansion, zone, vendor, type, and category
*   Vendor locations with precise coordinates for easy navigation
*   Comprehensive coverage of items from all WoW expansions (Classic through Midnight)
*   Support for vendor items, quest rewards, achievement rewards, drop rewards, crafted items, and more

### Modern User Interface

*   **Color-Coded Item Bars**: Visual indicators for faction (Horde/Alliance/Neutral) and source type (Achievement/Quest/Drop/Vendor)
*   **Customizable Display**: Adjustable UI scale (0.5x to 1.5x) and font size (10-18px) via Settings
*   **Modern Filter Layout**: Clean, grid-aligned filter panel with multi-column dropdowns for easy browsing
*   **Item List Headers**: Clear column headers (Item Name, Source, Location, Price) for organized viewing

### Advanced Search & Filtering

*   **Multi-Filter System**: Filter by expansion, vendor, zone, type, category, faction, source, and search text
*   **Smart Dropdowns**: Multi-column layout (2-4 columns) for Vendor and Zone filters to handle large lists efficiently
*   **Real-Time Filtering**: Instant results as you type or change filters
*   **Hide Unreleased**: Option to hide items from unreleased expansions
*   **Dynamic Search**: Searches across item names, vendor names, zones, types, and categories simultaneously

### Statistics Dashboard

*   **Collection Progress Overview**: Track your total collection progress with visual progress bar
*   **Items by Source**: Bar graphs showing collected/total for Achievements, Quests, Drops, and Vendors
*   **Items by Faction**: Collection statistics broken down by Horde, Alliance, and Neutral
*   **Items by Category**: Detailed breakdown of collection progress by item category
*   **Items by Expansion**: Top 10 expansions sorted by total items with collection percentages
*   **Color-Coded Graphs**: Visual graphs using faction and source color schemes for easy identification

### Detailed Item Information

*   **Comprehensive Tooltips**: Hover over items to see detailed information, including:
    *   Item name, quality, and type
    *   Source type and specific source name (achievement/quest/drop/vendor name)
    *   Vendor location and zone
    *   Pricing (gold or currency)
    *   Coordinates for waypoint navigation
    *   Faction requirements
    *   Item ID and expansion
    *   Large item icon
    *   Full item description
    *   Vendor information and coordinates
    *   Achievement/Quest/Drop source details
    *   Item level, quality, binding, and sell price
    *   Availability and expansion information
*   **Source Type Display**: Clear indication of item source (Achievement, Quest, Drop, or Vendor) with color coding

### Navigation Integration

*   **Click-to-Set Waypoints**: Click any item bar with coordinates to instantly set a waypoint
*   **Blizzard Waypoint Support**: Native waypoint integration using `C_Map.SetUserWaypoint()`
*   **TomTom Integration**: Optional TomTom addon support for enhanced waypoint features
*   **Visual Waypoint Indicator**: Map icon on item bars indicates waypoint availability

### Collection Tracking

*   **Collection Status**: Track which items you've collected
*   **Visual Indicators**: Color-coded bars and icons show collection status
*   **Statistics Integration**: All statistics respect your collection status
*   **Progress Tracking**: See your overall collection progress at a glance

### Localization Support

*   **Multi-Language Support**: Full localization for 11 languages:
    *   English (US)
    *   German (deDE)
    *   French (frFR)
    *   Spanish (esES, esMX)
    *   Italian (itIT)
    *   Portuguese (ptBR)
    *   Russian (ruRU)
    *   Korean (koKR)
    *   Simplified Chinese (zhCN)
    *   Traditional Chinese (zhTW)

## Usage

### Commands

*   `/hv` or `/housingvendor` - Open/close the main Housing Vendor interface
*   `/hv test` - Test addon functionality and show module status
*   `/hv version` - Display addon version

### Interface Overview

#### Main Window

*   **Draggable**: Click and drag the title bar to move the window
*   **Resizable**: Adjust window size to fit your preferences
*   **Minimap Button**: Click the minimap button to open/close the interface

#### Filter Panel

*   **Search Box**: Type to search across all item fields
*   **Expansion Filter**: Filter by game expansion (Classic, TBC, WotLK, etc.)
*   **Vendor Filter**: Multi-column dropdown showing all vendors
*   **Zone Filter**: Multi-column dropdown showing all zones
*   **Type Filter**: Filter by item type (Decorative, Functional, etc.)
*   **Category Filter**: Filter by item category (Furniture, Lighting, etc.)
*   **Faction Filter**: Filter by Horde, Alliance, or Neutral
*   **Source Filter**: Filter by Achievement, Quest, Drop, or Vendor
*   **Hide Unreleased**: Toggle to hide items from unreleased expansions
*   **Clear Filters**: Button to reset all filters at once

#### Item List

*   **Color-Coded Bars**:
    *   Red border/background = Horde items
    *   Blue border/background = Alliance items
    *   Gold = Achievement items
    *   Bright Blue = Quest items
    *   Orange/Red = Drop items
    *   Green = Vendor items
    *   Gray = Neutral items
*   **Item Information**: Each item bar shows:
    *   Item icon
    *   Item name
    *   Source type and name (e.g., "Achievement: \[Name\]" or "Vendor: \[Name\]")
    *   Housing icon and weight (when available)
    *   Zone name (for vendor items)
    *   Price (gold or currency)
    *   Map icon (if coordinates available)
*   **Hover Effects**: Gold border glow and brightness increase on hover
*   **Click Actions**: Click item bar to set waypoint (if coordinates available)

#### Statistics Dashboard

*   **Access**: Click "Statistics" button in the main window header
*   **Collection Progress**: Overall progress bar and percentage
*   **Bar Graphs**: Visual representation of collection by source, faction, category, and expansion
*   **Back Button**: Return to main item list

#### Settings Panel

*   **Access**: Click "Settings" button in the main window header
*   **UI Scale Slider**: Adjust interface scale from 0.5x to 1.5x
*   **Font Size Slider**: Adjust text size from 10px to 18px
*   **Save Button**: Save settings to database
*   **Reset to Defaults**: Restore default settings

### Key Functionalities

#### Setting Waypoints

1.  **Click Item Bar**: Click any item bar that has a map icon (indicating coordinates are available)
2.  **Automatic Routing**: For cross-continent travel, the addon will:
    *   Find the nearest portal to your destination continent
    *   Set a waypoint to the portal first
    *   Automatically set the final destination waypoint after you reach the portal
3.  **Blizzard Waypoints**: Uses native WoW waypoint system (works without addons)
4.  **TomTom Integration**: If TomTom is installed, waypoints are also added to TomTom

#### Filtering Items

1.  Use the search box for quick text search
2.  Select from dropdown filters to narrow results
3.  Multiple filters work together (AND logic)
4.  Click "Clear Filters" to reset everything

#### Viewing Statistics

1.  Click "Statistics" button in the header
2.  View your collection progress across different categories
3.  Use the "Back" button to return to the item list

#### Customizing Display

1.  Click "Settings" button in the header
2.  Adjust UI Scale slider for larger/smaller interface
3.  Adjust Font Size slider for larger/smaller text
4.  Click "Save" to apply changes
5.  Changes apply immediately to both item list and statistics

## Credits

*   **Author**: RenZhi
*   Housing item data compiled from various in-game sources and community contributions
*   Inspired by the need for better housing decoration discovery in World of Warcraft
