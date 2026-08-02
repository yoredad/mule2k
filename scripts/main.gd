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
@onready var new_game_button: Button = %NewGameButton
@onready var quit_button: Button = %QuitButton
@onready var color_choice_overlay: ColorRect = %ColorChoiceOverlay
@onready var white_choice_button: Button = %WhiteChoiceButton
@onready var black_choice_button: Button = %BlackChoiceButton


func _ready() -> void:
	board.cell_pressed.connect(_on_board_cell_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	white_choice_button.pressed.connect(_on_white_choice_pressed)
	black_choice_button.pressed.connect(_on_black_choice_pressed)
	game.reset()
	_refresh_ui()
	_show_color_choice()


func _show_color_choice() -> void:
	phase = Phase.CHOOSING_COLOR
	color_choice_overlay.visible = true
	status_label.text = "Choose your color"


func _start_game(selected_human_color: int) -> void:
	game_generation += 1
	game.reset()
	human_color = selected_human_color
	computer_color = OthelloGame.opposite_color(human_color)
	color_choice_overlay.visible = false
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
		return
	phase = Phase.COMPUTER_TURN
	skip_button.visible = false
	_update_board()
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
	_advance_turn()


func _is_computer_action_still_valid(generation: int) -> bool:
	return generation == game_generation \
		and phase == Phase.COMPUTER_TURN \
		and not game.is_game_over() \
		and game.get_current_color() == computer_color


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
		_advance_turn()
	else:
		_refresh_ui()


func _on_skip_pressed() -> void:
	if phase != Phase.HUMAN_TURN or not current_valid_moves.is_empty():
		return
	skip_button.visible = false
	skip_button.disabled = true
	if game.try_pass():
		_advance_turn()
	else:
		skip_button.disabled = false
		_refresh_ui()


func _on_new_game_pressed() -> void:
	game_generation += 1
	phase = Phase.CHOOSING_COLOR
	current_valid_moves = []
	human_color = OthelloGame.Disc.EMPTY
	computer_color = OthelloGame.Disc.EMPTY
	skip_button.visible = false
	skip_button.disabled = false
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
