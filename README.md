# PathCrosser - Advanced Player Tracker

**Version 2.0** - A comprehensive World of Warcraft addon for tracking player encounters with detailed history, coordinates, and analytics.

## Features

### 📝 Detailed Encounter Tracking
- **Complete History**: Every encounter is logged with full details
- **Timestamps**: Exact date and time of each meeting
- **Coordinates**: Map coordinates (X, Y) for every encounter
- **Location Data**: Zone and subzone information
- **Activity Detection**: Tracks what players were doing:
  - ⚔ Combat
  - ☠ Dead/Ghost
  - 💤 AFK
  - 🎣 Fishing
  - ✨ Casting
  - 🔍 Exploring
- **Status Flags**: PvP flagged, in combat, mounted, etc.

### 👥 Player Information
- **Class, Race, and Faction**: Comprehensive player details
- **Level Tracking**: Updated automatically
- **Guild Information**: Guild names are saved
- **Relation System**: Mark players as Friend, Rival, or Neutral
- **Tags**: Organize players with custom tags
- **Notes**: Add personal notes to any player

### 📊 Statistics & Analytics
- **Database Overview**: Total players and encounters
- **Top Players**: Most frequently encountered players
- **Active Zones**: Heat map of where you meet most players
- **Class Distribution**: Breakdown by class
- **Faction Analysis**: Alliance vs Horde statistics
- **Time-based Analysis**: When you encounter players most

### 🎨 Enhanced User Interface
- **Tab-based Navigation**: 
  - Player List: Searchable, sortable, filterable
  - Player Details: In-depth view with full encounter history
  - Statistics: Visual analytics and insights
- **Advanced Filtering**:
  - Search by name/realm
  - Filter by relation (friends, rivals, neutral, tagged)
  - Sort by: Recently seen, Most encounters, Alphabetical, Level
- **Interactive**: Click any player to view detailed information
- **Color-coded**: Class colors for easy identification
- **Relation Icons**: ★ for Friends, ⚔ for Rivals

### 🔔 Smart Notifications
- First-time encounter alerts
- Friend spotted notifications
- Customizable notification settings

### ⚙️ Tracking Options
- **Auto-tracking**:
  - Mouseover units
  - Targeted players
  - Nearby players (via nameplates, every 5 seconds)
  - Party/raid members
- **City Tracking**: Optional tracking in sanctuaries/major cities
- **Configurable**: Enable/disable each tracking method

## Commands

| Command | Description |
|---------|-------------|
| `/pc` or `/pathcrosser` | Open main window |
| `/pc stats` | Show quick statistics in chat |
| `/pc prune` | Manually prune old encounters |
| `/pc help` | Display all available commands |

## Installation

1. Extract the PathCrosser folder to your WoW AddOns directory:
   - `World of Warcraft\_retail_\Interface\AddOns\`
2. Restart WoW or reload UI (`/reload`)
3. The addon will automatically start tracking players

### Optional Dependencies
For the full UI experience, install these libraries (usually included in other addons):
- **Ace3**: Required for the GUI
- **LibDataBroker-1.1**: For minimap button
- **LibDBIcon-1.0**: For minimap button

## Usage

### Basic Usage
Just play the game! PathCrosser automatically tracks:
- Players you mouseover
- Players you target
- Nearby players (if enabled)
- Party/raid members (if enabled)

### Viewing Tracked Players
1. Type `/pc` or click the minimap button
2. Browse the player list
3. Use search and filters to find specific players
4. Click any player to view detailed encounter history

### Organizing Players
1. Click a player name to open their details
2. Change their relation (Friend/Rival/Neutral)
3. Add tags (comma-separated)
4. Write notes about the player
5. View their complete encounter history with coordinates

### Encounter History
Each encounter shows:
- 📅 Date and time
- 🗺️ Zone and subzone
- 📍 Coordinates
- 🎯 What they were doing
- ⚔️ Status flags (PvP, Combat, AFK)

### Statistics
View the Statistics tab to see:
- Total players and encounters
- Most encountered players (Top 10)
- Most active zones (Top 10)
- Class distribution
- Friend/Rival counts
- Tagged players

## Configuration

Access settings via:
- Game Menu → Options → AddOns → PathCrosser
- Or type `/pc` and customize from the main window

### Settings Include
- ✅ Track in cities
- ✅ Track nearby players
- ✅ Track party members
- ✅ Notify on first encounters
- ✅ Notify when friends are spotted
- 🧹 Prune old encounters
- 🗑️ Clear all data

## Database Management

### Auto-Pruning
- Encounters older than 90 days are automatically removed on login
- Player records with notes/tags are preserved even if old

### Manual Pruning
- Use `/pc prune` or the options panel button
- Cleans up old data to keep the database efficient

### Data Limits
- Up to 100 encounters per player are stored
- Older encounters are removed automatically to prevent bloat

### Migration
- Old database format (v1.0) automatically migrates to v2.0
- Your existing data is preserved and enhanced

## Features Coming Soon
- Import/Export functionality
- Data sharing between characters
- Enhanced map integration
- Encounter heat maps
- More detailed statistics

## Tips & Tricks

### Best Practices
1. **Mark Important Players**: Use the Friend/Rival system for players you want to track
2. **Use Tags**: Organize players by event, guild, or any custom category
3. **Add Notes**: Remember context about encounters
4. **Review Statistics**: Learn where you encounter most players

### Performance
- Nearby scanning runs every 5 seconds (disable if causing lag)
- Each player stores max 100 encounters
- Database auto-prunes every 90 days
- Lightweight and efficient design

### Privacy
- PathCrosser stores data **locally only**
- No data is sent anywhere
- Only you can see your tracked players
- Players are not notified that you're tracking them

## Tooltip Integration

When hovering over any player, PathCrosser adds:
- ★ Friend or ⚔ Rival indicator
- Total encounter count
- Last seen time
- Last known location with coordinates
- Guild name
- Tags
- Note preview (first 50 characters)

## Technical Details

### Database Structure
```lua
PathCrosser_DB = {
    version = 2,
    players = {
        ["PlayerName-RealmName"] = {
            class = "CLASS",
            level = 80,
            faction = "Alliance/Horde",
            race = "RACE",
            guild = "Guild Name",
            encounters = {
                {
                    timestamp = 1234567890,
                    zone = "Zone Name",
                    subzone = "Subzone",
                    x = 45.2,
                    y = 78.9,
                    activity = "combat",
                    inCombat = true,
                    isDead = false,
                    isMounted = false,
                    isAFK = false,
                    isPvP = true
                }
            },
            notes = "Personal notes",
            tags = {"tag1", "tag2"},
            relation = "friend/rival/neutral"
        }
    },
    options = { ... },
    minimap = { ... }
}
```

## Support

For issues, suggestions, or feedback:
- Use the `/reportbug` command in-game
- Check for updates regularly

## Version History

### Version 2.0 (Current)
- ✨ Complete rewrite with enhanced features
- 📍 Coordinate tracking for all encounters
- 🏷️ Tags and notes system
- 👥 Friend/Rival marking
- 📊 Advanced statistics
- 🎨 New tabbed UI
- 🎯 Activity detection
- 🔔 Smart notifications
- 🗺️ Subzone tracking
- 📈 Much more detailed analytics

### Version 1.0
- Basic player tracking
- Simple encounter counting
- Basic GUI with search
- Tooltip integration

---

**Enjoy tracking your adventures across Azeroth!** 🌍
