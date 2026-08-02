extends Control

const OthelloGame := preload("res://scripts/othello_game.gd")
const ComputerOpponent := preload("res://scripts/computer_opponent.gd")

const COMPUTER_MOVE_DELAY := 0.4
const COMPUTER_PASS_DELAY := 0.4

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
var _empty_moves: Array[Vector2i] = []

# Style boxes for highlighting active player card
var active_style: StyleBoxFlat
var inactive_style: StyleBoxFlat

func _ready() -> void:
	# Adjust Safe Area on Mobile
	_adjust_safe_area()
	get_viewport().size_changed.connect(_adjust_safe_area)
	
	# Setup card styles
	_setup_card_styles()
	
	# Connect signals
	%Board.cell_pressed.connect(_on_board_cell_pressed)
	%SkipButton.pressed.connect(_on_skip_pressed)
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%WhiteChoiceButton.pressed.connect(_on_white_choice_pressed)
	%BlackChoiceButton.pressed.connect(_on_black_choice_pressed)
	
	# Show initial color prompt
	_show_color_choice()

func _adjust_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	
	var safe_rect := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	if window_size.x == 0 or window_size.y == 0:
		return
		
	var vp_size := get_viewport_rect().size
	var scale_x := vp_size.x / float(window_size.x)
	var scale_y := vp_size.y / float(window_size.y)
	
	var margin_left := int(safe_rect.position.x * scale_x)
	var margin_top := int(safe_rect.position.y * scale_y)
	var margin_right := int((window_size.x - safe_rect.end.x) * scale_x)
	var margin_bottom := int((window_size.y - safe_rect.end.y) * scale_y)
	
	# Maintain minimum 48x64 spacing for layout aesthetics
	margin_left = max(margin_left, 48)
	margin_top = max(margin_top, 64)
	margin_right = max(margin_right, 48)
	margin_bottom = max(margin_bottom, 64)
	
	$SafeArea.add_theme_constant_override("margin_left", margin_left)
	$SafeArea.add_theme_constant_override("margin_top", margin_top)
	$SafeArea.add_theme_constant_override("margin_right", margin_right)
	$SafeArea.add_theme_constant_override("margin_bottom", margin_bottom)

func _setup_card_styles() -> void:
	var base_box: StyleBox = %WhiteCard.get_theme_stylebox("panel")
	if base_box is StyleBoxFlat:
		active_style = base_box.duplicate()
		active_style.border_color = Color("#56D4A5") # Highlight mint border
		active_style.bg_color = Color("#173327") # Slightly brighter container green
		
		inactive_style = base_box.duplicate()
		inactive_style.border_color = Color("#133024", 0.5) # Subdued border
		inactive_style.bg_color = Color("#0C1512") # Subdued background

func _show_color_choice() -> void:
	phase = Phase.CHOOSING_COLOR
	human_color = OthelloGame.Disc.EMPTY
	computer_color = OthelloGame.Disc.EMPTY
	current_valid_moves.clear()
	%WhiteRoleLabel.text = "UNASSIGNED"
	%BlackRoleLabel.text = "UNASSIGNED"
	%ColorChoiceOverlay.visible = true
	%SkipButton.visible = false
	%Board.set_state(game.get_board_copy(), _empty_moves, false)
	%StatusLabel.text = "Choose your color"
	_refresh_ui()

func _start_game(selected_human_color: int) -> void:
	game_generation += 1 # Invalidate any active background/thinking routines
	game.reset()
	
	human_color = selected_human_color
	computer_color = OthelloGame.opposite_color(human_color)
	
	# Set role text
	if human_color == OthelloGame.Disc.WHITE:
		%WhiteRoleLabel.text = "PLAYER"
		%BlackRoleLabel.text = "COMPUTER"
	else:
		%WhiteRoleLabel.text = "COMPUTER"
		%BlackRoleLabel.text = "PLAYER"
		
	%ColorChoiceOverlay.visible = false
	_advance_turn()

func _advance_turn() -> void:
	if game.is_game_over():
		_finish_game()
		return
		
	var active_color := game.get_current_color()
	var valid_moves := game.get_valid_moves(active_color)
	
	if active_color == human_color:
		phase = Phase.HUMAN_TURN
		current_valid_moves = valid_moves
		_refresh_ui()
		
		if current_valid_moves.is_empty():
			%Board.set_state(game.get_board_copy(), _empty_moves, false)
			%StatusLabel.text = "No valid moves. Tap Skip."
			%SkipButton.visible = true
			%SkipButton.disabled = false
		else:
			%Board.set_state(game.get_board_copy(), current_valid_moves, true)
			var col_str := "White" if human_color == OthelloGame.Disc.WHITE else "Black"
			%StatusLabel.text = "Your turn - " + col_str
			%SkipButton.visible = false
	else:
		phase = Phase.COMPUTER_TURN
		current_valid_moves = []
		_refresh_ui()
		%Board.set_state(game.get_board_copy(), _empty_moves, false)
		%SkipButton.visible = false
		
		_run_computer_turn(game_generation)

func _run_computer_turn(generation: int) -> void:
	var active_color := game.get_current_color()
	var valid_moves := game.get_valid_moves(active_color)
	
	if valid_moves.is_empty():
		%StatusLabel.text = "Computer has no valid move and passes."
		await get_tree().create_timer(COMPUTER_PASS_DELAY).timeout
		
		# Validation guard against stale generations or resets
		if not _computer_turn_is_current(generation):
			return
			
		game.try_pass()
		_advance_turn()
	else:
		%StatusLabel.text = "Computer is thinking..."
		await get_tree().create_timer(COMPUTER_MOVE_DELAY).timeout
		
		# Validation guard against stale generations or resets
		if not _computer_turn_is_current(generation):
			return
			
		var move := computer.choose_move(game.get_board_copy(), computer_color, human_color)
		if move != ComputerOpponent.NO_MOVE:
			game.try_make_move(move)
			
		_advance_turn()

func _computer_turn_is_current(generation: int) -> bool:
	return (
		generation == game_generation
		and phase == Phase.COMPUTER_TURN
		and not game.is_game_over()
		and game.get_current_color() == computer_color
	)

func _refresh_ui() -> void:
	var white_cnt := game.get_disc_count(OthelloGame.Disc.WHITE)
	var black_cnt := game.get_disc_count(OthelloGame.Disc.BLACK)
	
	%WhiteCountLabel.text = str(white_cnt)
	%BlackCountLabel.text = str(black_cnt)
	
	# Highlight the active turn card
	if active_style != null and inactive_style != null:
		var current := game.get_current_color()
		if phase == Phase.CHOOSING_COLOR or phase == Phase.GAME_OVER:
			%WhiteCard.add_theme_stylebox_override("panel", inactive_style)
			%BlackCard.add_theme_stylebox_override("panel", inactive_style)
		elif current == OthelloGame.Disc.WHITE:
			%WhiteCard.add_theme_stylebox_override("panel", active_style)
			%BlackCard.add_theme_stylebox_override("panel", inactive_style)
		else:
			%WhiteCard.add_theme_stylebox_override("panel", inactive_style)
			%BlackCard.add_theme_stylebox_override("panel", active_style)

func _finish_game() -> void:
	phase = Phase.GAME_OVER
	%Board.set_state(game.get_board_copy(), _empty_moves, false)
	%SkipButton.visible = false
	_refresh_ui()
	
	var human_score := game.get_disc_count(human_color)
	var computer_score := game.get_disc_count(computer_color)
	
	if human_score > computer_score:
		%StatusLabel.text = "You win! %d - %d" % [human_score, computer_score]
	elif computer_score > human_score:
		%StatusLabel.text = "Computer wins. %d - %d" % [computer_score, human_score]
	else:
		%StatusLabel.text = "Draw. %d - %d" % [human_score, computer_score]

# --- UI Signals ---

func _on_board_cell_pressed(position: Vector2i) -> void:
	if phase != Phase.HUMAN_TURN:
		return
	if not position in current_valid_moves:
		return
		
	# Disable interaction immediately to prevent duplicate rapid clicks
	%Board.set_state(game.get_board_copy(), _empty_moves, false)
	game.try_make_move(position)
	_advance_turn()

func _on_skip_pressed() -> void:
	if phase != Phase.HUMAN_TURN:
		return
	if not current_valid_moves.is_empty():
		return
		
	%SkipButton.disabled = true
	game.try_pass()
	_advance_turn()

func _on_new_game_pressed() -> void:
	game_generation += 1 # Terminate active computer thinking timers
	game.reset()
	_show_color_choice()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_white_choice_pressed() -> void:
	_start_game(OthelloGame.Disc.WHITE)

func _on_black_choice_pressed() -> void:
	_start_game(OthelloGame.Disc.BLACK)
