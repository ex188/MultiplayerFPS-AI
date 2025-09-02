# AI Players for Multiplayer FPS

This implementation adds AI players to the multiplayer FPS game that will play alongside human players when you host a game.

## Features

### AI Behavior
- **Patrol**: AI players patrol around the map when no players are nearby
- **Chase**: When a player is detected, AI will chase them
- **Attack**: AI will engage in combat when close enough to players
- **Retreat**: AI will back away if players get too close
- **Search**: AI will search the last known player location if they lose sight

### AI Settings
- **Difficulty**: Adjustable from 0.5 (Easy) to 2.0 (Hard)
  - Affects reaction time, shooting accuracy, and shooting speed
- **AI Count**: Set how many AI players spawn (0-8)
- **Automatic Spawning**: AI players automatically respawn when killed

### Visual Indicators
- AI players have green colored bodies
- "AI Player X" labels above their heads
- Slightly slower movement speed than human players

## How to Use

1. **Host a Game**: Click "Host" in the main menu
2. **Configure AI**: Use the sliders in the main menu to set:
   - AI Difficulty (0.5 = Easy, 1.0 = Normal, 2.0 = Hard)
   - Number of AI Players (0-8)
3. **Start Playing**: AI players will automatically spawn and start playing

## AI Difficulty Levels

- **Easy (0.5)**: Slower reactions, less accurate shooting, slower shooting rate
- **Normal (1.0)**: Balanced AI behavior
- **Hard (2.0)**: Fast reactions, accurate shooting, rapid fire

## Technical Details

- AI players are server-authoritative (only the host manages them)
- AI uses navigation mesh for pathfinding
- AI has line-of-sight detection for shooting
- AI players can be damaged and killed like human players
- AI respawns automatically at random locations

## Files Added/Modified

- `AIPlayer.gd` - Main AI player script
- `AIPlayer.tscn` - AI player scene
- `world.gd` - Added AI spawning and management
- `world.tscn` - Added AI settings UI

The AI system is fully integrated with the existing multiplayer networking and will work seamlessly with human players joining your hosted game.
