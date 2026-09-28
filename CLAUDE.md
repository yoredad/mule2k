# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

M.U.L.E. 2K is a Godot 4.6 adaptation of the 1983 Electronic Arts classic M.U.L.E. — an economic strategy game for 1 human player vs 3 CPU players on a 9×5 planet grid. The game runs on Windows desktop and Android (landscape, touch).

**PLAN.md is the authoritative spec.** All game rules, tables, formulas, and AI behavior are defined there. Implement every table and formula exactly as written in PLAN.md.

## Development Commands

### Running the Game

Open in Godot editor:
```powershell
& "C:\tools\Godot\Godot_v4.6-stable_win64.exe" -e --path "C:\Users\YoreDad\Projects\godot\mule2k"
```

Run the game (F5 in editor, or from command line):
```powershell
& "C:\tools\Godot\Godot_v4.6-stable_win64.exe" --path "C:\Users\YoreDad\Projects\godot\mule2k"
```

### Testing

Unit tests (headless, exits 0 on pass):
```powershell
& "C:\tools\Godot\Godot_v4.6-stable_win64_console.exe" --headless --path . -s res://tools/unit_test.gd
```

Full game simulation (3 seeded 12-round games, CPU vs CPU, end-to-end):
```powershell
& "C:\tools\Godot\Godot_v4.6-stable_win64_console.exe" --headless --path . -s res://tools/game_sim_test.gd
```

### Exporting

Windows Desktop: Export from editor to `build/mule2k.exe`

Android: Export from editor to `build/mule2k.apk` (requires export templates, Android SDK, JDK 17 — see README.md for setup)

## Architecture

### Core State Management

The game uses three autoload singletons:

- **GameState** (`scripts/autoload/game_state.gd`) — The central data store. Holds the board, players array, round number, prices, store stock, RNG, and wampus state. Pure data container with minimal logic.

- **GameFlow** (`scripts/game/game_flow.gd`) — The phase state machine. Orchestrates all game phases (Menu → Land Grant → Development → Production → Consumption → Prices → Auction → Replenish → Summary → repeat). Emits signals that the UI responds to. Manages turn order, AI controllers, and phase transitions.

- **AudioManager** (`scripts/autoload/audio_manager.gd`) — Sound effect and music playback.

### Data Layer (Pure Logic)

All classes in `scripts/data/` are pure RefCounted classes with no scene tree dependencies:

- **Board** — 9×5 grid of Plot objects. Generates terrain (plains/river/mountain/store), mountain counts, and hidden crystite deposits at initialization.
  
- **Plot** — Single grid cell. Stores terrain type, mountains count, owner, mule, crystite quality (hidden until assayed).

- **Player** — Player state: cash, food, energy, smithore, crystite, owned plots array, score, rank, color.

- **Mule** — Mule unit type (food/energy/smithore/crystite).

- **Economy** — Static utility functions only. Production formulas (EBPC tables, growth multipliers, variance), pricing logic, consumption requirements, supply/demand calculations, mule pricing. All game balance math lives here.

### Game Logic

- **GameFlow** — Phase machine as described above. The `Phase` enum defines all phases. Each phase has `_begin_*` and `_end_*` methods. Human/AI branching logic lives here.

- **AiController** — Per-CPU-player AI decision maker. Created on-demand by GameFlow. Makes decisions for land grant, development (claim/outfit/wampus/assay), and auction (buy/sell offers). AI difficulty/personality can be adjusted here.

- **Events** — Random event handling (Pirates, Sunspots, Pest, Meteorite, etc). Called during specific phases.

### UI Layer

All UI scripts in `scripts/ui/` respond to GameFlow signals and render GameState:

- **BoardView** — Draws the 9×5 grid with terrain colors, owner colors, mules (sprite sheet), crystite gems, production pips. Emits `plot_tapped` signal. Handles highlights and selection feedback.

- **HUD** — Top status bar showing round, phase, current player, and per-player stats (cash, food, energy, etc).

- **GameUI** — Container for overlay panels. Manages panel visibility.

- **Panels** (`scripts/ui/panels/`) — Modal overlays:
  - `menu_panel.gd` — Start game menu
  - `dev_panel.gd` — Development phase actions (outfit, wampus, assay, pass)
  - `auction_panel.gd` — Auction phase buy/sell interface
  - `production_panel.gd` — Production summary display
  - `status_panel.gd` — End-of-round status
  - `end_panel.gd` — Game over results
  - `howto_panel.gd` — Tutorial/rules

### Important Patterns

1. **Signal-driven UI**: GameFlow emits signals (`phase_changed`, `human_turn_started`, `auction_updated`, etc). UI scripts connect to these and update their display. Never poll GameState directly for changes.

2. **Simulate mode**: GameFlow has a `simulate` flag. When true, human turns are handled by AI (for testing). The game can run headless CPU-vs-CPU.

3. **Deterministic RNG**: GameState.rng is seeded. Pass a seed to `new_game(seed_value)` for reproducible games (used in tests).

4. **Phase-gated logic**: Many methods check `if phase != Phase.X: return` to prevent out-of-phase calls.

5. **CPU decision caching**: AI controllers cache decisions to avoid recomputation. Stored in GameFlow's `_ais` dictionary keyed by player.

## Key Game Systems

### Production (Phase: PRODUCTION)

1. For each player's mule, calculate per-plot output using `Economy` formulas from PLAN.md:
   - Base production (EBPC table by terrain/mountains/unit)
   - Economies of scale bonus (+1 if adjacent same-player same-unit plot)
   - Random variance (-1/0/+1 based on roll)
   - Time scaling (×1.08 per round)
   - Clamp to 0-8

2. Sum per-plot outputs to player inventory.

3. Crystite mining is special: base production comes from hidden plot quality (0-4), not EBPC table. Assay Office reveals true quality.

### Consumption (Phase: CONSUMPTION)

1. Energy: each non-energy mule needs 1 energy. Energy mules are free.
2. Food: player needs 3/4/5 food based on round (see `Economy.food_requirement`).
3. Shortfall: each missing unit costs 1 production in EVERY mule (harsh penalty).
4. Spoilage: excess energy/food decays (see PLAN.md spoilage table).

### Auction (Phase: AUCTION)

Four separate per-unit auctions (Smithore → Food → Energy → Crystite). Players submit buy/sell offers simultaneously. Store acts as market maker with limited stock. Price-priority matching.

AI personalities vary aggressiveness and reserve prices (see `ai_controller.gd`).

### Random Events (Phase: varies)

Events fire at specific times (see PLAN.md section 8). Examples:
- **Pest**: destroys food production on one plot for this round
- **Meteorite**: destroys a random mule, creates EXTRA HIGH crystite deposit (quality 4)
- **Pirates/Sunspots**: affect certain unit shipments
- **Planetquake**: land give/lose (plots change owners)

Events are implemented in `scripts/game/events.gd`.

## Code Style

- Use GDScript static typing (`var x: int`, `func foo() -> void`).
- Constants in UPPER_SNAKE_CASE.
- Private methods prefixed with `_`.
- Document complex formulas with comments referencing PLAN.md section numbers.
- Keep pure math in Economy static functions, not scattered in UI or GameFlow.

## Testing Strategy

- `tools/unit_test.gd` tests Economy formulas, Board generation, Player/Plot/Mule logic in isolation.
- `tools/game_sim_test.gd` runs full games headless with fixed seeds and validates end state (scores, inventories, round count).
- When changing game balance (production, pricing, AI), run both test suites to catch regressions.

## Mobile Considerations

- All touch targets are ≥48px (plot cells scale to fill viewport, buttons are sized accordingly).
- Landscape-only (`window/handheld/orientation=4`).
- Touch and mouse are interchangeable (`emulate_touch_from_mouse=true`).
- No real-time minigames; everything is turn-based tap interactions.

## Common Tasks

**Adjust AI difficulty**: Edit `ai_controller.gd` personality constants (aggressiveness, reserve prices, wampus attempt rates).

**Tweak production balance**: Edit EBPC tables and formulas in `Economy.ebpc()` and related functions. Verify against PLAN.md unless intentionally rebalancing.

**Add new random event**: Add enum to `Economy.Event`, implement handler in `Events.apply_event()`, hook into appropriate phase in `GameFlow`.

**Change board size**: Requires coordinated edits to Board, BoardView, and all hard-coded grid references. Current 9×5 is baked into many places.

**Debug phase transitions**: Add breakpoints in `GameFlow._set_phase()` or log `phase_changed` signal emissions.
