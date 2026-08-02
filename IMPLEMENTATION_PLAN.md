# Othello for Godot 4.6 - Implementation Plan

## 1. Purpose

Build a one-player Othello game in Godot 4.6 using typed GDScript. The human
plays against a basic computer opponent. The primary target is a portrait mobile
screen with a 1080x2400 reference resolution.

This repository is currently empty. The implementation session should create the
entire project from this specification.

## 2. Fixed Product Decisions

These decisions are requirements and should not be changed during implementation
without user approval:

1. The board is 8x8.
2. The player chooses Black or White before each game.
3. White always moves first. Do not change this to traditional Black-first play.
4. A valid move must place a disc on an empty square and flip at least one
   opponent disc.
5. Captures are evaluated in all eight directions.
6. If the computer has no valid move, it passes automatically.
7. If the human has no valid move, show a `Skip` button and wait for the human to
   press it.
8. The game ends when the board is full or neither color has a valid move.
9. If only one color has no move, the game continues by passing that color's
   turn. This interpretation is necessary because the requested pass behavior
   conflicts with ending as soon as only one player cannot move.
10. The computer avoids a move that gives the human a valid corner move on the
    immediately following turn whenever a corner-safe alternative exists. Among
    corner-safe moves, it uniformly prefers plays on the board edge (all 28
    perimeter squares, including the corners). Only when no corner-safe move
    exists does it fall back to a uniformly random choice from all valid moves,
    without any edge preference.
11. The Black and White counts remain visible and update after every move.
12. The score area identifies which color belongs to `Player` and which belongs
    to `Computer`.
13. `New Game` resets the board and asks for the human's color again.
14. `Quit` closes the application where the platform permits it.
15. The phone launcher icon is an original yin/yang design representing the
    Black and White game discs.

## 3. Explicit Non-Goals

Do not add these features unless requested later:

- Online or local two-player play
- Multiple AI difficulty levels
- Minimax, alpha-beta search, or positional scoring
- Saved games or persistent statistics
- Accounts, achievements, advertisements, or analytics
- External art packs, fonts, plugins, or test frameworks
- Complex disc-flip animation
- Sound or music

The fixed board-edge preference described in decision 10 and section 9.3 is the
only strategic heuristic allowed. It is not a license for additional positional
scoring or search.

## 4. Proposed Project Structure

```text
project.godot
export_presets.cfg                       # Add when configuring mobile exports
IMPLEMENTATION_PLAN.md
assets/
  icons/
    yin_yang_icon.svg                    # 1024x1024 vector master/project icon
    yin_yang_icon_1024.png               # Opaque iOS master icon
    yin_yang_store_512.png               # Optional Google Play listing icon
    android/
      yin_yang_main_192.png              # Legacy Android launcher icon
      yin_yang_foreground_432.png        # Adaptive icon foreground
      yin_yang_background_432.png        # Adaptive icon background
      yin_yang_monochrome_432.png        # Android 13+ themed icon
scenes/
  main.tscn
scripts/
  othello_game.gd
  computer_opponent.gd
  board_view.gd
  main.gd
themes/
  mobile_theme.tres
tests/
  test_runner.gd
```

Use one main scene. Do not introduce autoloads; the project does not need global
state.

## 5. Project Configuration

Create `project.godot` for Godot 4.6 with these settings:

| Project setting | Intended value |
| --- | --- |
| Application name | `Othello` |
| Main scene | `res://scenes/main.tscn` |
| Project icon | `res://assets/icons/yin_yang_icon.svg` |
| Viewport width | `1080` |
| Viewport height | `2400` |
| Desktop width override | Approximately `450` |
| Desktop height override | Approximately `1000` |
| Handheld orientation | `portrait` |
| Stretch mode | `canvas_items` |
| Stretch aspect | `expand` |
| Renderer | `gl_compatibility` |
| Emulate mouse from touch | Enabled |

Use the Compatibility renderer because the project is simple 2D and should run
on a broad range of phones.

The desktop override is only for convenient editor testing. All layout values
are authored against the 1080x2400 logical reference size.

## 6. Yin/Yang Launcher Icon

### 6.1 Art direction

Create a traditional vertical yin/yang symbol that visually connects the Black
and White Othello discs.

Use this palette:

| Element | Color |
| --- | --- |
| Full-bleed background | Deep board green, approximately `#123B2D` |
| Black region | Charcoal, approximately `#111513` |
| White region | Warm ivory, approximately `#F5F1E8` |
| Optional outer outline | Dark green-black, approximately `#09261E` |

Design constraints:

- Use no text.
- Use no gradients, filters, raster effects, or small decorative details.
- Do not bake rounded corners into standard icons. The operating system applies
  its own icon mask.
- Keep strong contrast at 48x48 pixels.
- Build the art from original geometric primitives rather than downloading an
  icon from a third party.
- Use an outer symbol radius `R`, lobe radius `R / 2`, and dot radius `R / 6`.
- The normal icon has a full-bleed, opaque green background.
- The yin/yang symbol occupies approximately 70 percent of the 1024x1024 master
  canvas.

### 6.2 Vector master

Create `assets/icons/yin_yang_icon.svg` with:

- `width="1024"`, `height="1024"`, and `viewBox="0 0 1024 1024"`.
- Only simple SVG `rect`, `circle`, and `path` elements.
- Solid fills and, if needed, one simple outer stroke.
- No Inkscape-only metadata or SVG features unsupported by Godot's SVG importer.
- An opaque background covering the entire canvas.

Keep the SVG as the editable source of truth. Generate PNG files from the SVG or
from purpose-built adaptive SVG variants; do not manually redraw each size.

### 6.3 Android icon assets

Godot needs high-resolution launcher files and generates lower-density versions.

| File | Size | Alpha requirement | Purpose |
| --- | ---: | --- | --- |
| `yin_yang_main_192.png` | 192x192 | Opaque | Android versions before adaptive icons |
| `yin_yang_foreground_432.png` | 432x432 | Transparent outside artwork | Android 8+ foreground |
| `yin_yang_background_432.png` | 432x432 | Opaque | Android 8+ background |
| `yin_yang_monochrome_432.png` | 432x432 | Transparent outside artwork | Android 13+ themed icon |

Adaptive foreground requirements:

- Center the symbol at `(216, 216)`.
- Keep all critical art inside a centered 264-pixel-diameter safe circle.
- Use a symbol diameter near 252 pixels, leaving a small safety margin.
- Leave the area outside the symbol transparent.
- Put the full-bleed green color only in the separate background image.

The monochrome icon cannot be a solid filled circle because Android replaces all
non-transparent colors with one themed color. Draw a recognizable single-color
line version consisting of an outer ring, an S-shaped divider, and two dots.
Keep the same 264-pixel safe zone.

Configure these Android export properties when an Android preset is created:

```text
launcher_icons/main_192x192
launcher_icons/adaptive_foreground_432x432
launcher_icons/adaptive_background_432x432
launcher_icons/adaptive_monochrome_432x432
```

Use the adaptive foreground as the Android system splash icon if no separate
splash treatment is added.

### 6.4 iOS and store assets

Create an opaque 1024x1024 PNG for the iOS base/App Store icon. Do not include an
alpha channel because the App Store icon must be opaque. Let Godot's iOS exporter
derive smaller required sizes.

Create an opaque 512x512 PNG for a future Google Play store listing. This file is
not the same as the Android adaptive foreground.

### 6.5 Icon verification

Verify all of the following:

- Godot imports the master SVG without warnings.
- The project icon appears in Godot's Project Manager.
- The legacy Android, iOS, and store PNGs are fully opaque.
- Adaptive foreground and monochrome files retain transparent backgrounds.
- The icon is recognizable at 48x48, 72x72, and 96x96.
- The adaptive icon remains intact under circle, square, rounded-square, and
  squircle masks.
- No critical art crosses the adaptive 264-pixel safe zone.
- A debug Android installation shows the icon correctly on the home screen.
- Android themed-icon mode still produces a recognizable yin/yang symbol.

## 7. Game Rules and Board Representation

### 7.1 Coordinates

Use `Vector2i(x, y)` everywhere outside the board array:

- `x` is the column from 0 through 7.
- `y` is the row from 0 through 7.
- Array access is always `board[y][x]`.

Document this once in the game model and apply it consistently. Mixing row and
column order is a likely source of capture bugs.

### 7.2 Initial board

Use the standard four center discs:

```text
........
........
........
...WB...
...BW...
........
........
........
```

Coordinates:

| Coordinate | Disc |
| --- | --- |
| `(3, 3)` | White |
| `(4, 3)` | Black |
| `(3, 4)` | Black |
| `(4, 4)` | White |

Set the current color to White after every reset.

### 7.3 Disc values

Use an enum rather than strings:

```gdscript
enum Disc {
    EMPTY,
    BLACK,
    WHITE,
}
```

Store the board as `Array[PackedInt32Array]`, with eight rows of eight values.
When copying a board, duplicate every row explicitly.

### 7.4 Directions

Use these exact directions:

```gdscript
const DIRECTIONS: Array[Vector2i] = [
    Vector2i(-1, -1),
    Vector2i(0, -1),
    Vector2i(1, -1),
    Vector2i(-1, 0),
    Vector2i(1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
    Vector2i(1, 1),
]
```

## 8. Game Model

Implement `scripts/othello_game.gd` as a pure, UI-independent model:

```gdscript
class_name OthelloGame
extends RefCounted
```

### 8.1 Owned state

```gdscript
var _board: Array[PackedInt32Array]
var _current_color: int = Disc.WHITE
var _game_over: bool = false
var _last_move: Vector2i = Vector2i(-1, -1)
```

No Control or scene nodes should be referenced by this class.

### 8.2 Public API

Implement this API or a semantically equivalent typed API:

```gdscript
func reset() -> void
func get_board_copy() -> Array[PackedInt32Array]
func get_current_color() -> int
func get_last_move() -> Vector2i
func is_game_over() -> bool
func get_disc_count(color: int) -> int
func get_valid_moves(color: int) -> Array[Vector2i]
func has_valid_move(color: int) -> bool
func try_make_move(position: Vector2i) -> bool
func try_pass() -> bool
func is_board_full() -> bool

static func opposite_color(color: int) -> int
static func find_flips(
    board_state: Array[PackedInt32Array],
    position: Vector2i,
    color: int
) -> Array[Vector2i]
static func find_valid_moves(
    board_state: Array[PackedInt32Array],
    color: int
) -> Array[Vector2i]
static func board_after_move(
    board_state: Array[PackedInt32Array],
    position: Vector2i,
    color: int
) -> Array[PackedInt32Array]
```

`get_board_copy()` must never return mutable references to the live rows. The
view and AI may inspect snapshots but must not mutate model state.

### 8.3 Capture algorithm

Use one capture function for validation, move generation, move application, and
AI simulation.

```text
find_flips(board, position, color):
    reject an out-of-bounds position
    reject an occupied position
    opponent = opposite_color(color)
    all_flips = []

    for each direction:
        cursor = position + direction
        directional_flips = []

        while cursor is in bounds and board[cursor] is opponent:
            append cursor to directional_flips
            advance cursor by direction

        if directional_flips is not empty
        and cursor is still in bounds
        and board[cursor] is color:
            append directional_flips to all_flips

    return all_flips
```

Important behavior:

- At least one adjacent opponent disc is required in a direction.
- The opponent sequence must terminate at a friendly disc.
- Encountering an empty square invalidates that direction.
- Reaching the board edge before a friendly disc invalidates that direction.
- A move is valid if the combined flip list is non-empty.
- One move may flip discs in several directions at once.

### 8.4 Applying a move

`try_make_move(position)` should:

1. Reject calls after game over.
2. Call `find_flips()` using `_current_color`.
3. Return `false` without changing state if no discs would flip.
4. Place the current color at the requested position.
5. Change every captured coordinate to the current color.
6. Store the position as `_last_move`.
7. Check whether the board is full.
8. Check whether both Black and White have no valid moves.
9. Set `_game_over` if either ending condition is true.
10. Otherwise switch `_current_color` to the opposite color.
11. Return `true`.

Do not end merely because the next color has no valid move. The controller will
handle that pass.

### 8.5 Passing

`try_pass()` should:

1. Reject calls after game over.
2. Reject a pass if `_current_color` has any valid move.
3. If the opposite color also has no valid move, set `_game_over`.
4. Otherwise switch `_current_color` to the opposite color.
5. Return whether the pass was accepted.

## 9. Computer Opponent

Implement `scripts/computer_opponent.gd` as:

```gdscript
class_name ComputerOpponent
extends RefCounted
```

### 9.1 Constants and random source

```gdscript
const NO_MOVE := Vector2i(-1, -1)
const CORNERS: Array[Vector2i] = [
    Vector2i(0, 0),
    Vector2i(7, 0),
    Vector2i(0, 7),
    Vector2i(7, 7),
]

var _rng := RandomNumberGenerator.new()
```

Randomize the RNG for normal play. Expose a test-only seed setter so strategy
tests can be deterministic.

### 9.2 Public API

```gdscript
func choose_move(
    board_state: Array[PackedInt32Array],
    computer_color: int,
    human_color: int
) -> Vector2i

func get_corner_safe_moves(
    board_state: Array[PackedInt32Array],
    computer_color: int,
    human_color: int
) -> Array[Vector2i]

func set_seed_for_tests(value: int) -> void

static func is_edge_square(position: Vector2i) -> bool
```

### 9.3 Selection algorithm

An edge square is any square on the board perimeter: `x == 0 || x == 7 ||
y == 0 || y == 7`. The edge set includes the four corners.

```text
valid_moves = all legal computer moves

if valid_moves is empty:
    return NO_MOVE

safe_moves = []

for each computer move:
    simulate the move on a deep board copy
    calculate the human's valid moves on that result

    if none of the human moves is a corner:
        append the computer move to safe_moves

if safe_moves is not empty:
    edge_safe_moves = [moves in safe_moves that lie on the board edge]
    candidates = edge_safe_moves if edge_safe_moves is not empty else safe_moves
else:
    candidates = valid_moves

return a uniformly random element from candidates
```

This is a direct look-ahead for actual corner availability. Do not substitute a
heuristic that merely avoids squares adjacent to corners.

Edge priority applies only inside the corner-safe pool. If every legal move
exposes a corner, the computer falls back to a uniformly random choice from all
valid moves without any edge preference, so the human-corner rule is never
violated by the preference.

A computer move at a corner is itself corner-safe by construction: the corner
is occupied afterward, so the human cannot take it. Such moves therefore remain
eligible for the edge pool.

Do not prioritize moves with the most captures or any other positional scoring.
Within either candidate pool, every move remains equally eligible apart from
the edge-vs-interior distinction described above.

## 10. Board View

Implement `scripts/board_view.gd` as a custom-drawn Control:

```gdscript
class_name OthelloBoardView
extends Control

signal cell_pressed(position: Vector2i)
```

Custom drawing avoids creating 64 button nodes and makes the square board easy to
scale.

### 10.1 State and API

```gdscript
var _board: Array[PackedInt32Array]
var _valid_moves: Array[Vector2i]
var _interactive: bool = false

func set_state(
    board_state: Array[PackedInt32Array],
    valid_moves: Array[Vector2i],
    interactive: bool
) -> void
```

`set_state()` should copy its inputs and call `queue_redraw()`.

### 10.2 Drawing

In `_draw()`:

1. Determine the largest square that fits inside the Control.
2. Center the square if the Control is not exactly square.
3. Divide the side length by eight to get `cell_size`.
4. Draw a dark outer border.
5. Draw the green board and grid lines.
6. Draw every occupied disc centered in its cell.
7. Draw valid-move markers only when `_interactive` is true.

Suggested proportions:

| Element | Value |
| --- | --- |
| Disc radius | `cell_size * 0.38` |
| Valid marker radius | `cell_size * 0.10` to `0.12` |
| Grid width | Approximately 3 to 4 logical pixels |
| Disc shadow offset | Small, optional, and consistent |

Black discs should be charcoal with a subtle lighter edge. White discs should be
warm ivory with a dark outline. Legal move markers should be translucent gold or
mint and remain clearly visible over the board.

### 10.3 Input

In `_gui_input(event)`:

1. Ignore all input while `_interactive` is false.
2. Process pressed left-mouse events only.
3. Rely on the project setting that emulates mouse input from touch.
4. Reject coordinates outside the rendered board rectangle.
5. Convert the local point into a board column and row with `floor()`.
6. Emit `cell_pressed(Vector2i(column, row))`.
7. Let `main.gd` perform the final legal-move check.

Handling only emulated mouse events prevents a mobile tap from producing both a
touch event and a mouse event.

## 11. Main Scene

Create `scenes/main.tscn` with this approximate tree:

```text
Main (Control, main.gd)
|- Background (ColorRect)
|- SafeArea (MarginContainer)
|  `- Page (VBoxContainer)
|     |- TitleLabel
|     |- ScoreRow (HBoxContainer)
|     |  |- WhiteCard (PanelContainer)
|     |  |  `- WhiteCardContent (VBoxContainer)
|     |  |     |- WhiteRoleLabel
|     |  |     |- WhiteColorLabel
|     |  |     `- WhiteCountLabel
|     |  `- BlackCard (PanelContainer)
|     |     `- BlackCardContent (VBoxContainer)
|     |        |- BlackRoleLabel
|     |        |- BlackColorLabel
|     |        `- BlackCountLabel
|     |- BoardRegion (AspectRatioContainer)
|     |  `- Board (Control, board_view.gd)
|     |- StatusPanel (PanelContainer)
|     |  `- StatusLabel
|     |- SkipSlot (CenterContainer)
|     |  `- SkipButton
|     `- ActionRow (HBoxContainer)
|        |- NewGameButton
|        `- QuitButton
`- ColorChoiceOverlay (ColorRect)
   `- ChoiceCenter (CenterContainer)
      `- ChoicePanel (PanelContainer)
         `- ChoiceContent (VBoxContainer)
            |- ChoiceTitle
            |- ChoiceInstructions
            |- WhiteChoiceButton
            `- BlackChoiceButton
```

Set the root, background, safe-area layer, and choice overlay to Full Rect.

Mark script-facing nodes as unique names and access them with `%Board`,
`%StatusLabel`, `%SkipButton`, and similar references.

The color overlay must block pointer input to the scene behind it and must not be
dismissible without selecting a color.

## 12. Portrait Layout

Use containers rather than fixed positions. At the 1080x2400 reference size,
target these approximate measurements:

| Region | Guideline |
| --- | ---: |
| Outer margin | 48 minimum |
| Title height | 80 to 100 |
| Score row height | 220 to 260 |
| Board maximum | 984x984 |
| Status panel height | 140 to 170 |
| Skip slot height | 130 to 150 |
| Action button height | 130 to 150 |
| Standard spacing | 24 to 36 |
| Color modal width | Approximately 880 |
| Color modal padding | 56 to 64 |

Use `AspectRatioContainer` with ratio `1.0`, centered alignment, and fit behavior
for the board.

Keep `SkipSlot` in the layout even when `SkipButton` is hidden. This prevents the
board and footer from shifting when a pass becomes necessary.

### 12.1 Safe areas

Give the main `SafeArea` container fixed margins of at least 48 logical pixels.
On mobile, optionally increase these values using
`DisplayServer.get_display_safe_area()`.

If native safe-area support is implemented:

- Convert physical display coordinates to logical viewport coordinates.
- Never apply raw physical pixel values directly to a stretched Control layout.
- Recalculate after a root-window size change.
- Use the fixed 48-pixel minimum on desktop because desktop display safe areas do
  not necessarily describe the application window.

## 13. Theme and Visual Design

Create `themes/mobile_theme.tres` and use it for the complete scene.

Visual direction:

- Dark forest or charcoal page background
- Rich green board
- Warm ivory primary text
- Muted green-gray secondary text
- Rounded score and status panels
- Clear pressed, hover, focus, and disabled button states
- Highlighted border on the score card whose color currently moves
- No dependency on color alone; always show role and color text

Suggested font sizes at the reference resolution:

| Element | Size |
| --- | ---: |
| Game title | 68 to 76 |
| Score role/color labels | 36 to 44 |
| Score count | 72 to 88 |
| Status text | 40 to 48 |
| Buttons | 42 to 50 |
| Modal title | 58 to 66 |
| Modal instructions | 38 to 44 |

Use Godot's built-in font unless a suitable local font is already available. Do
not download a font solely for this project.

## 14. Main Controller

Implement `scripts/main.gd` as the only owner of UI and turn sequencing.

### 14.1 State

```gdscript
enum Phase {
    CHOOSING_COLOR,
    HUMAN_TURN,
    COMPUTER_TURN,
    GAME_OVER,
}

var game := OthelloGame.new()
var computer := ComputerOpponent.new()
var phase: Phase = Phase.CHOOSING_COLOR
var human_color: int = OthelloGame.Disc.EMPTY
var computer_color: int = OthelloGame.Disc.EMPTY
var current_valid_moves: Array[Vector2i] = []
var game_generation: int = 0
```

`game_generation` invalidates delayed computer work when a new game starts.

### 14.2 Recommended methods

```gdscript
func _ready() -> void
func _show_color_choice() -> void
func _start_game(selected_human_color: int) -> void
func _advance_turn() -> void
func _run_computer_turn(generation: int) -> void
func _refresh_ui() -> void
func _finish_game() -> void
func _on_board_cell_pressed(position: Vector2i) -> void
func _on_skip_pressed() -> void
func _on_new_game_pressed() -> void
func _on_quit_pressed() -> void
func _on_white_choice_pressed() -> void
func _on_black_choice_pressed() -> void
```

Connect signals explicitly in `_ready()` instead of splitting connections
between scene metadata and code.

### 14.3 Color selection

The startup overlay should read approximately:

```text
CHOOSE YOUR COLOR

White always moves first.

[ PLAY AS WHITE ]
[ PLAY AS BLACK ]
```

`_start_game(selected_human_color)` should:

1. Increment `game_generation`.
2. Reset the model.
3. Set `human_color` to the selected color.
4. Set `computer_color` to the opposite color.
5. Hide the overlay.
6. Refresh role labels and scores.
7. Call `_advance_turn()`.

If the human selected White, the first phase is a human turn. If the human
selected Black, the computer owns White and immediately begins the first move.

### 14.4 Central turn transition

All successful moves and passes should return to one `_advance_turn()` function:

```text
refresh board and scores

if the model says game over:
    finish the game
    return

current_valid_moves = valid moves for the model's current color

if current color belongs to human:
    phase = HUMAN_TURN

    if valid moves exist:
        enable board
        hide Skip
        show human-turn status
    else:
        disable board
        show Skip
        show "No valid moves. Tap Skip."

    return

phase = COMPUTER_TURN
disable board
hide Skip

if no computer move exists:
    show computer-pass status
    wait briefly
    pass computer turn
    advance turn again
    return

show thinking status
wait briefly
choose and apply computer move
advance turn again
```

Use a delay around 0.4 seconds for a computer move or automatic pass. This is
long enough to make the turn change understandable without making play slow.

### 14.5 Delayed-turn safety

Before beginning an asynchronous computer action, copy `game_generation` into a
local variable. After every `await`, verify:

- The copied generation still equals `game_generation`.
- `phase` is still `COMPUTER_TURN`.
- The model is not game over.
- The model's current color still equals `computer_color`.

If any check fails, return without changing the board. This prevents a stale
timer from moving after the human presses `New Game`.

### 14.6 Human move input

When `Board.cell_pressed` fires:

1. Require `phase == HUMAN_TURN`.
2. Require the model's current color to equal `human_color`.
3. Require the coordinate to be present in `current_valid_moves`.
4. Immediately make the board noninteractive to prevent rapid duplicate taps.
5. Call `game.try_make_move(position)`.
6. Call `_advance_turn()` if successful.
7. Refresh without changing turns if the model unexpectedly rejects the move.

### 14.7 Human pass input

When `Skip` is pressed:

1. Require `phase == HUMAN_TURN`.
2. Require `current_valid_moves` to be empty.
3. Hide and disable the button immediately.
4. Call `game.try_pass()`.
5. Call `_advance_turn()`.

The button should never be shown when the human has a legal move.

## 15. Score and Status UI

Keep White and Black cards in fixed positions. Change their role labels after
the human chooses a color instead of moving the cards.

Example when the human selected White:

```text
PLAYER                 COMPUTER
WHITE                  BLACK
12                     9
```

Example when the human selected Black:

```text
COMPUTER               PLAYER
WHITE                  BLACK
12                     9
```

Update counts after reset, every move, every pass, and at game end.

Use these status messages or concise equivalents:

| State | Message |
| --- | --- |
| Waiting for choice | `Choose your color` |
| Human White turn | `Your turn - White` |
| Human Black turn | `Your turn - Black` |
| Computer turn | `Computer is thinking...` |
| Human cannot move | `No valid moves. Tap Skip.` |
| Computer cannot move | `Computer has no valid move and passes.` |
| Human wins | `You win! 35 - 29` |
| Computer wins | `Computer wins. 40 - 24` |
| Draw | `Draw. 32 - 32` |

At game end, compare the count for `human_color` with the count for
`computer_color`. Disable board input, hide Skip, leave `New Game` and `Quit`
visible, and show the final result in the status panel.

## 16. New Game and Quit

### 16.1 New Game

Keep `New Game` visible during play and after game over.

Its handler should:

1. Increment `game_generation` before any other action.
2. Set the phase to `CHOOSING_COLOR`.
3. Disable board interaction.
4. Reset the model so the board visibly returns to the initial four discs.
5. Clear human and computer role assignments.
6. Update both counts to 2.
7. Hide Skip.
8. Set status to `Choose your color`.
9. Show the color-selection overlay.

### 16.2 Quit

The handler should call:

```gdscript
get_tree().quit()
```

This closes desktop and Android builds. iOS does not permit applications to
close themselves, so the platform may ignore the request. Keep the requested
button unless iOS-specific product requirements later override it.

## 17. Automated Tests

Use a lightweight test runner without third-party addons. Implement
`tests/test_runner.gd` as a headless script that records failures, prints useful
messages, and exits with status 1 when any test fails.

Run with the available Godot 4.6 executable, for example:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

### 17.1 Required model tests

| Test | Expected result |
| --- | --- |
| Initial board | Two White, two Black, current color White |
| Initial White moves | Exactly `(4,2)`, `(5,3)`, `(2,4)`, `(3,5)` |
| Occupied target | Move rejected with no mutation |
| Empty non-capturing target | Move rejected with no mutation |
| White move at `(4,2)` | Black disc at `(4,3)` flips to White |
| Horizontal line | Every enclosed opponent disc flips |
| Vertical line | Every enclosed opponent disc flips |
| Diagonal lines | Captures work in both diagonal axes |
| Multi-direction move | All valid directions flip during one move |
| Edge scanning | No out-of-bounds access or false capture |
| Corner capture | Legal corner move captures correctly |
| Disc counts | Black plus White equals occupied squares |
| Illegal pass | Pass rejected when current color has a move |
| Legal pass | Turn changes when only current color has no move |
| Neither color can move | Game ends even with empty squares remaining |
| Full board | Game ends immediately |
| Board copy | Mutating a returned copy does not mutate the model |

### 17.2 Required AI tests

| Test | Expected result |
| --- | --- |
| No valid moves | Returns `NO_MOVE` |
| One valid move | Returns that move |
| Safe moves exist | Returned move is always in the corner-safe set |
| All moves expose a corner | Returned move remains in the full valid set |
| Edge-safe moves exist | Returned move is always an edge square and corner-safe |
| Safe but no edge moves | Returned move is in the corner-safe set, with no edge preference possible |
| Computer corner take | A computer corner capture is corner-safe and eligible for the edge pool |
| General selection | Returned coordinate is always a legal computer move |
| Simulation isolation | AI evaluation never changes the live board snapshot |

Construct at least one explicit fixture with both a safe and unsafe computer move,
and one fixture whose safe moves contain both edge and interior squares, so
corner avoidance and edge preference are tested deterministically rather than
statistically.

### 17.3 Parse smoke test

After the full project exists, run a short headless startup to catch scene and
script parse errors:

```powershell
godot --headless --path . --quit-after 2
```

Use the actual local executable name or full path if `godot` is not on `PATH`.

## 18. Manual Verification

Verify these scenarios in the editor and, when available, on a physical Android
device or emulator:

| Scenario | Expected behavior |
| --- | --- |
| 1080x2400 | Entire interface fits with no clipping |
| 1080x1920 | Board remains square and controls remain visible |
| Taller phone ratio | Containers distribute extra vertical space cleanly |
| Desktop mouse | Board and all buttons work |
| Mobile touch | One tap creates at most one move |
| Human chooses White | Human moves first |
| Human chooses Black | Computer moves first as White |
| Invalid board tap | No board or turn change |
| Human cannot move | Skip appears and board is disabled |
| Human has a move | Skip is hidden |
| Computer cannot move | Computer automatically passes |
| Computer edge play | Computer prefers edge squares when corner-safe edge moves exist, and never exposes a corner |
| Neither can move | Result appears without requiring two manual passes |
| Full board | Result appears immediately |
| Rapid repeated tap | Only one legal move is applied |
| New Game during AI delay | No stale computer move occurs |
| New Game after result | Board resets and color prompt appears |
| Score display | Counts and role labels remain accurate |
| App icon | Correct yin/yang icon appears on phone home screen |

## 19. Implementation Order

Follow this order so logic is validated before UI complexity is introduced:

1. Create `project.godot` and a minimal startup scene that opens in Godot 4.6.
2. Create the yin/yang SVG and required raster launcher assets.
3. Wire the project icon and verify the SVG imports correctly.
4. Implement `othello_game.gd`.
5. Implement model tests and make all rule tests pass.
6. Implement `computer_opponent.gd`.
7. Add AI corner-safety, edge-preference, and fallback tests.
8. Implement the custom `board_view.gd`.
9. Create `mobile_theme.tres`.
10. Build the responsive `main.tscn` scene tree.
11. Implement color selection and the controller state machine in `main.gd`.
12. Add asynchronous generation guards around computer delays.
13. Implement dynamic safe-area margins if needed after testing the fixed layout.
14. Run automated tests and the headless parse smoke test.
15. Test all gameplay branches manually at several portrait resolutions.
16. Add/configure an Android export preset and map all launcher icon files.
17. Install a debug build on a phone or emulator and verify touch, layout, and
    launcher masks.

## 20. Definition of Done

The project is complete only when all of these statements are true:

- The project opens and runs in Godot 4.6 without parser errors.
- The interface is designed for a 1080x2400 portrait viewport.
- The human can select Black or White before every game.
- White always owns the first turn.
- Selecting Black causes the computer to make the first move.
- Legal move generation works in all eight directions.
- A move flips every enclosed opponent line.
- Illegal moves never mutate state.
- The computer returns only legal moves.
- The computer randomly chooses from corner-safe moves when any exist.
- The computer uniformly prefers edge plays, including corners, whenever the
  corner-safe pool contains at least one edge square.
- The computer falls back to all valid moves when every move exposes a corner,
  without any edge preference.
- The computer automatically passes when it cannot move.
- The human sees Skip only when no human move exists.
- The game continues after a single-player pass.
- The game ends on a full board or when neither color can move.
- Black and White counts are always accurate and visible.
- Score cards always identify `Player` and `Computer` correctly.
- Final status identifies a player win, computer win, or draw.
- New Game invalidates pending AI work, resets the board, and asks for color.
- Quit closes the application on supported platforms.
- Mouse and touch controls both work without duplicate moves.
- The board remains square and the controls remain usable on common portrait
  aspect ratios.
- The original yin/yang icon imports correctly and appears as the project icon.
- Android legacy, adaptive, and themed launcher variants are correctly mapped.
- The launcher symbol remains recognizable and unclipped under common masks.
- All automated tests pass.
