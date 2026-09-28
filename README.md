# M.U.L.E. 2K

A Godot 4.6 adaptation of the 1983 Electronic Arts classic M.U.L.E.: an economic
strategy game for 1 human player vs 3 CPU players on a 9x5 planet grid.

See `PLAN.md` for the authoritative game rules, tables, formulas, and AI spec.

## Requirements

- Godot 4.6 at `C:\tools\Godot\Godot_v4.6-stable_win64.exe`
- Windows 10+ (desktop) or Android 7+ (landscape, touch)

## How to Run

1. Open the project in Godot 4.6:
   ```
   & "C:\tools\Godot\Godot_v4.6-stable_win64.exe" -e --path "C:\Users\YoreDad\Projects\godot\mule2k"
   ```
2. Press F5 (or run the project) to play.

## Tests

Run headless from the project folder:

```
& "C:\tools\Godot\Godot_v4.6-stable_win64_console.exe" --headless --path . -s res://tools/unit_test.gd
```

Full-game simulation (3 seeded 12-round games, CPU vs CPU, end-to-end):

```
& "C:\tools\Godot\Godot_v4.6-stable_win64_console.exe" --headless --path . -s res://tools/game_sim_test.gd
```

Both exit 0 when everything passes.

## Export

### Windows
Export preset "Windows Desktop" from the editor (Export -> Windows Desktop -> Export Project)
to `build/mule2k.exe`.

### Android
Export preset "Android" from the editor to `build/mule2k.apk` (gradle build,
arm64-v8a + armeabi-v7a + x86_64, minSdk 24, landscape).

Before the first Android export:
1. Editor -> Manage Export Templates -> Download and Install (requires internet).
2. Editor Settings -> Export -> Android: set Android SDK path and JDK 17 path.
3. The first export auto-generates a debug keystore.

Install with `adb install build/mule2k.apk`.

## Controls

- Mouse or touch: tap plots, buttons, and overlay controls. All touch targets >= 48px.
- The game is played entirely by tapping; there are no real-time minigames.

## Project Structure

```
mule2k/
  PLAN.md               # Full game spec (rules, tables, formulas, AI)
  scenes/main.tscn      # Main scene: board + HUD
  scripts/
    autoload/           # GameState (data + round loop), AudioManager
    data/               # Plot, Player, Mule, Board, Economy (pure math)
    game/               # GameFlow (phase machine), AI controller, Events
    ui/                 # BoardView, HUD, GameUI + overlay panels
  tools/                # Headless unit + simulation tests
  build/                # Exported binaries (mule2k.exe / mule2k.apk)
```
