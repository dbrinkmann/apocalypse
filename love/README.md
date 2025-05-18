# Apocalypse MUD Client

A modern, graphical client for MUD (Multi-User Dungeon) games built with LÖVE (Love2D) framework. This client provides a rich visual interface while maintaining the classic MUD gameplay experience.

## Features

### Core Systems
- **MUD Connection Management**
  - Multiple connection support
  - ANSI color code parsing
  - UTF-8 text handling
  - Input buffering and command history

### User Interface
- **Modern Window System**
  - Draggable and resizable windows
  - Window z-ordering
  - Title bars with window management
  - Custom window styling with rounded corners

- **Terminal Window**
  - ANSI color support
  - Scrollable message history
  - Blinking cursor
  - Custom font support
  - Message buffering and display

### Game World Visualization
- **2D Game World**
  - Background image support
  - Entity system for NPCs and players
  - Item system for objects
  - Camera system with scaling and positioning

### Technical Features
- **Logging System**
  - Debug logging
  - Raw data logging
  - Output logging
  - Configurable log levels

- **Configuration**
  - Window size and position settings
  - Font configuration
  - Color scheme customization
  - Game world settings

## Requirements
- LÖVE 11.4 or higher
- Lua 5.1 or higher
- LuaSocket library

## Installation
1. Install LÖVE framework from [love2d.org](https://love2d.org)
2. Clone this repository
3. Run the game using LÖVE:
   ```
   love .
   ```

## Configuration
The game can be configured through `config.txt`:
- Window dimensions
- Font settings
- Color schemes
- Connection settings

## Directory Structure
- `main.lua` - Main game loop and initialization
- `game_world.lua` - Game world and entity management
- `parser.lua` - Text and command parsing
- `logger.lua` - Logging system
- `conf.lua` - LÖVE configuration
- `fonts/` - Custom fonts
- `images/` - Game assets and sprites

## Development
The project is built using:
- LÖVE framework for graphics and input handling
- LuaSocket for network communication
- Custom UI framework for window management
- Entity-Component system for game objects

## License
[Add your license information here]

## Contributing
[Add contribution guidelines here] 