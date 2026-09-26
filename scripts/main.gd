extends Control

enum Phase {
	CHOOSING_COLOR,
	HUMAN_TURN,
	COMPUTER_TURN,
	GAME_OVER,
}

const COMPUTER_DELAY_SECONDS := 0.4

var game := OthelloGame.new()
var computer := ComputerOpponent.new()
var phase: Phase = Phase.CHOOSING_COLOR
var human_color: int = OthelloGame.Disc.EMPTY
var computer_color: int = OthelloGame.Disc.EMPTY
var current_valid_moves: Array[Vector2i] = []
var game_generation: int = 0

## Round history: list of 2D board snapshots taken after both players have gone.
## Each entry of board_state_list is an 8x8 Array of square-state ints
## (0 = empty, 1 = white, 2 = black). turn_counter is the index into the list
## pointing at the currently active round.
var board_state_list: Array = []
var round_meta_list: Array = []
var turn_counter: int = 0
var _human_acted_this_round: bool = false

@onready var white_role_label: Label = %WhiteRoleLabel
@onready var white_color_label: Label = %WhiteColorLabel
@onready var white_count_label: Label = %WhiteCountLabel
@onready var black_role_label: Label = %BlackRoleLabel
@onready var black_color_label: Label = %BlackColorLabel
@onready var black_count_label: Label = %BlackCountLabel
@onready var white_card: PanelContainer = %WhiteCard
@onready var black_card: PanelContainer = %BlackCard
@onready var board: OthelloBoardView = %Board
@onready var status_label: Label = %StatusLabel
@onready var skip_button: Button = %SkipButton
@onready var undo_button: Button = %UndoButton
@onready var new_game_button: Button = %NewGameButton
@onready var quit_button: Button = %QuitButton
@onready var color_choice_overlay: ColorRect = %ColorChoiceOverlay
@onready var white_choice_button: Button = %WhiteChoiceButton
@onready var black_choice_button: Button = %BlackChoiceButton


func _ready() -> void:
	board.cell_pressed.connect(_on_board_cell_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	white_choice_button.pressed.connect(_on_white_choice_pressed)
	black_choice_button.pressed.connect(_on_black_choice_pressed)
	game.reset()
	board_state_list.clear()
	round_meta_list.clear()
	turn_counter = 0
	_human_acted_this_round = false
	_refresh_ui()
	_show_color_choice()


func _show_color_choice() -> void:
	phase = Phase.CHOOSING_COLOR
	color_choice_overlay.visible = true
	status_label.text = "Choose your color"
	_update_undo_button()


func _start_game(selected_human_color: int) -> void:
	game_generation += 1
	game.reset()
	human_color = selected_human_color
	computer_color = OthelloGame.opposite_color(human_color)
	color_choice_overlay.visible = false
	_reset_round_history()
	_refresh_ui()
	_advance_turn()


func _advance_turn() -> void:
	_refresh_ui()
	if game.is_game_over():
		_finish_game()
		return
	var current_color := game.get_current_color()
	current_valid_moves = game.get_valid_moves(current_color)
	if current_color == human_color:
		phase = Phase.HUMAN_TURN
		if current_valid_moves.is_empty():
			skip_button.visible = true
			skip_button.disabled = false
			status_label.text = "No valid moves. Tap Skip."
		else:
			skip_button.visible = false
			status_label.text = "Your turn - %s" % _color_name(current_color)
		_update_board()
		_update_undo_button()
		return
	phase = Phase.COMPUTER_TURN
	skip_button.visible = false
	_update_board()
	_update_undo_button()
	if current_valid_moves.is_empty():
		status_label.text = "Computer has no valid move and passes."
		_run_computer_action(game_generation, true)
	else:
		status_label.text = "Computer is thinking..."
		_run_computer_action(game_generation, false)


func _run_computer_action(generation: int, is_pass: bool) -> void:
	await get_tree().create_timer(COMPUTER_DELAY_SECONDS).timeout
	if not _is_computer_action_still_valid(generation):
		return
	if is_pass:
		game.try_pass()
	else:
		var move := computer.choose_move(game.get_board_copy(), computer_color, human_color)
		if move != ComputerOpponent.NO_MOVE:
			game.try_make_move(move)
	# A full round completed (human already went, computer just went): inspect
	# the board state, increment the list by one and store a 2D representation.
	if _human_acted_this_round:
		_push_round_state()
		_human_acted_this_round = false
	_advance_turn()


func _is_computer_action_still_valid(generation: int) -> bool:
	return generation == game_generation \
		and phase == Phase.COMPUTER_TURN \
		and not game.is_game_over() \
		and game.get_current_color() == computer_color


## Captures the current turn metadata that accompanies a 2D board snapshot.
func _capture_round_meta() -> Dictionary:
	return {
		"current_color": game.get_current_color(),
		"game_over": game.is_game_over(),
		"last_move": game.get_last_move(),
	}


## Starts a fresh round history with the initial board at index 0.
## Index 0 is always the initial configuration: 2 white and 2 black discs.
func _reset_round_history() -> void:
	board_state_list.clear()
	round_meta_list.clear()
	_human_acted_this_round = false
	board_state_list.append(game.get_square_state_2d())
	round_meta_list.append(_capture_round_meta())
	turn_counter = 0
	_update_undo_button()


## Inspects the board after both players have gone, increments the list by
## one and stores a 2D representation (0 = empty, 1 = white, 2 = black).
func _push_round_state() -> void:
	while board_state_list.size() > turn_counter + 1:
		board_state_list.pop_back()
		round_meta_list.pop_back()
	board_state_list.append(game.get_square_state_2d())
	round_meta_list.append(_capture_round_meta())
	turn_counter = board_state_list.size() - 1
	_update_undo_button()


func can_undo() -> bool:
	return turn_counter > 0 \
		and not board_state_list.is_empty() \
		and (phase == Phase.HUMAN_TURN or phase == Phase.GAME_OVER)


func _update_undo_button() -> void:
	if undo_button == null:
		return
	# Disabled whenever the turn counter is at the first entry (0).
	if turn_counter <= 0:
		undo_button.disabled = true
		return
	undo_button.disabled = not can_undo()


func _refresh_ui() -> void:
	white_count_label.text = str(game.get_disc_count(OthelloGame.Disc.WHITE))
	black_count_label.text = str(game.get_disc_count(OthelloGame.Disc.BLACK))
	if human_color == OthelloGame.Disc.WHITE:
		white_role_label.text = "PLAYER"
		black_role_label.text = "COMPUTER"
	elif human_color == OthelloGame.Disc.BLACK:
		white_role_label.text = "COMPUTER"
		black_role_label.text = "PLAYER"
	else:
		white_role_label.text = "PLAYER"
		black_role_label.text = "COMPUTER"
	_update_board()
	_update_active_card()
	_update_undo_button()


func _update_board() -> void:
	var interactive := phase == Phase.HUMAN_TURN and not current_valid_moves.is_empty()
	board.set_state(game.get_board_copy(), current_valid_moves, interactive)


func _update_active_card() -> void:
	var white_active := false
	var black_active := false
	if phase != Phase.CHOOSING_COLOR and not game.is_game_over():
		if game.get_current_color() == OthelloGame.Disc.WHITE:
			white_active = true
		else:
			black_active = true
	white_card.add_theme_stylebox_override("panel",
		get_theme_stylebox("panel", "ScoreCardActive" if white_active else "ScoreCard"))
	black_card.add_theme_stylebox_override("panel",
		get_theme_stylebox("panel", "ScoreCardActive" if black_active else "ScoreCard"))


func _finish_game() -> void:
	phase = Phase.GAME_OVER
	skip_button.visible = false
	_update_board()
	_update_undo_button()
	var human_count := game.get_disc_count(human_color)
	var computer_count := game.get_disc_count(computer_color)
	if human_count > computer_count:
		status_label.text = "You win! %d - %d" % [human_count, computer_count]
	elif computer_count > human_count:
		status_label.text = "Computer wins. %d - %d" % [computer_count, human_count]
	else:
		status_label.text = "Draw. %d - %d" % [human_count, computer_count]


func _on_board_cell_pressed(position: Vector2i) -> void:
	if phase != Phase.HUMAN_TURN:
		return
	if game.get_current_color() != human_color:
		return
	if not current_valid_moves.has(position):
		return
	board.set_state(game.get_board_copy(), current_valid_moves, false)
	if game.try_make_move(position):
		if game.is_game_over():
			_push_round_state()
			_human_acted_this_round = false
		else:
			_human_acted_this_round = true
		_advance_turn()
	else:
		_refresh_ui()


func _on_skip_pressed() -> void:
	if phase != Phase.HUMAN_TURN or not current_valid_moves.is_empty():
		return
	skip_button.visible = false
	skip_button.disabled = true
	if game.try_pass():
		if game.is_game_over():
			_push_round_state()
			_human_acted_this_round = false
		else:
			_human_acted_this_round = true
		_advance_turn()
	else:
		skip_button.disabled = false
		_refresh_ui()


func _on_undo_pressed() -> void:
	# Never decrement below the first entry (index 0 = initial 2W/2B board).
	if turn_counter <= 0:
		turn_counter = 0
		_update_undo_button()
		return
	if not can_undo():
		return
	# Cancel any pending computer timer so it cannot move after the restore.
	game_generation += 1
	# Decrement the turn counter and use it as the index into the history list.
	turn_counter = maxi(0, turn_counter - 1)
	var board_2d: Array = []
	for row in board_state_list[turn_counter]:
		board_2d.append((row as Array).duplicate())
	var meta: Dictionary = round_meta_list[turn_counter]
	game.restore_square_state_2d(
		board_2d,
		int(meta["current_color"]),
		bool(meta["game_over"]),
		meta["last_move"]
	)
	_human_acted_this_round = false
	current_valid_moves = []
	_advance_turn()


func _on_new_game_pressed() -> void:
	game_generation += 1
	phase = Phase.CHOOSING_COLOR
	current_valid_moves = []
	human_color = OthelloGame.Disc.EMPTY
	computer_color = OthelloGame.Disc.EMPTY
	skip_button.visible = false
	skip_button.disabled = false
	# Reset the history list and the turn counter for the new game.
	board_state_list.clear()
	round_meta_list.clear()
	turn_counter = 0
	_human_acted_this_round = false
	game.reset()
	_refresh_ui()
	_show_color_choice()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_white_choice_pressed() -> void:
	_start_game(OthelloGame.Disc.WHITE)


func _on_black_choice_pressed() -> void:
	_start_game(OthelloGame.Disc.BLACK)


func _color_name(color: int) -> String:
	return "White" if color == OthelloGame.Disc.WHITE else "Black"
