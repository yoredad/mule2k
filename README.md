# Othello

A single-player Othello (Reversi) game built with Godot 4.6. Play against a
computer opponent on your phone, desktop, or in the browser.

## Overview

- **Engine:** Godot 4.6, typed GDScript, Compatibility renderer
- **Platforms:** Mobile-first portrait (Android/iOS), desktop, and web
- **Gameplay:** Choose to play as Black or White before each game; White always
  moves first
- **Genres of play:** One human vs. a basic computer opponent; no two-player mode

## Features

- Standard 8x8 board with capture rules evaluated in all eight directions
- Color selection every game (White moves first regardless of choice)
- Clickable/draggable board view with translucent hints on legal moves
- Live Black/White score cards that identify `Player` and `Computer`
- Automatic pass for the computer; a `Skip` button when the human cannot move
- Game ends on a full board or when neither color can move, with win/draw result
- AI that randomizes its moves but avoids handing the human a corner move when a
  safer alternative exists
- Responsive portrait layout with mobile safe-area handling

## Project Structure

```text
project.godot                  Engine configuration (portrait 1080x2400 viewport)
scenes/
  main.tscn                    Main scene: title, score cards, board, controls
scripts/
  othello_game.gd              Pure game model: rules, moves, captures, passes
  computer_opponent.gd         Corner-safe random AI
  board_view.gd                Custom-drawn Control rendering board and discs
  main.gd                      Controller: color choice, turn/phase state machine
themes/
  mobile_theme.tres            Shared UI theme
assets/
  icons/                       Original yin/yang launcher icon (SVG + rasters)
tests/
  test_runner.gd               Headless logic tests
```

## Running

Open the project in Godot 4.6 and press F5, or run from the command line:

```powershell
# Parse/startup smoke test
godot --headless --path . --quit-after 2

# Run the logic and AI test suite
godot --headless --path . --script res://tests/test_runner.gd
```

## Controls

- **New Game** - resets the board and asks for your color again
- **Quit** - closes the application where the platform permits it (not iOS)

## Game Rules

- White always opens. If you pick Black, the computer makes the first move.
- Place a disc on an empty square; it must bracket at least one opponent disc to
  flip it, in one or more of the eight directions.
- A player passes (button or automatic) when no legal move exists. The game
  continues if only one player is stuck.
- The game ends when the board is full or neither color can move; the larger disc
  count wins, and equal counts result in a draw.