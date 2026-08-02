extends SceneTree

## Integration smoke test: instantiates scenes/main.tscn and drives the
## controller through color choice, human moves, computer turns, passes,
## and the New-Game generation guard.

var failures: Array[String] = []
var check_count := 0

var main: Control
var game: RefCounted


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func _initialize() -> void:
	_run()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	game = main.game

	check(main.phase == 0, "initial phase is CHOOSING_COLOR")
	check(main.color_choice_overlay.visible, "color overlay is visible at startup")
	check(main.status_label.text == "Choose your color", "status shows the color prompt")
	check(main.white_count_label.text == "2" and main.black_count_label.text == "2", "counts start at 2 and 2")
	check(main.human_color == 0 and main.computer_color == 0, "no role assignment before choice")

	var before: Array[PackedInt32Array] = main.game.get_board_copy()
	main._on_board_cell_pressed(Vector2i(4, 2))
	check(main.game.get_board_copy() == before, "board tap while overlay is up changes nothing")

	main._on_white_choice_pressed()
	await process_frame
	check(not main.color_choice_overlay.visible, "overlay hides after color choice")
	check(main.human_color == 2 and main.computer_color == 1, "human White, computer Black")
	check(main.phase == 1, "human White moves first")
	check(main.current_valid_moves.size() == 4, "human sees four legal moves")
	check(main.white_role_label.text == "PLAYER" and main.black_role_label.text == "COMPUTER", "role labels identify player and computer")
	check(main.board._interactive, "board is interactive on the human turn")
	check(not main.skip_button.visible, "skip hidden when the human can move")

	main._on_board_cell_pressed(Vector2i(0, 0))
	check(main.phase == 1 and main.game.get_current_color() == 2, "invalid tap is ignored")

	main._on_board_cell_pressed(Vector2i(4, 2))
	await process_frame
	check(main.phase == 2, "computer turn after human move")
	check(not main.board._interactive, "board disabled during computer turn")
	check(main.status_label.text == "Computer is thinking...", "thinking status shown")

	await create_timer(0.7).timeout
	check(main.phase == 1, "computer move returns to human turn")
	check(main.game.get_disc_count(2) + main.game.get_disc_count(1) == 6, "computer placed one Black disc")
	check(main.game.get_disc_count(2) >= 3, "human White kept its discs through the computer move")

	# Rapid duplicate tap applies at most one move.
	main._on_board_cell_pressed(main.current_valid_moves[0])
	var board_after_first_tap: Array[PackedInt32Array] = main.game.get_board_copy()
	main._on_board_cell_pressed(main.current_valid_moves[0])
	check(main.game.get_board_copy() == board_after_first_tap,
		"duplicate tap during the computer turn changes nothing")
	check(main.phase == 2, "phase is unchanged by the duplicate tap")
	await create_timer(0.7).timeout
	check(main.phase == 1, "computer turn completes normally after duplicate tap")

	# Human pass: White has no moves; computer Black moves; game must not end.
	main._on_new_game_pressed()
	await process_frame
	check(main.phase == 0 and main.color_choice_overlay.visible, "new game shows the color prompt")
	check(main.game.get_disc_count(2) == 2 and main.game.get_disc_count(1) == 2, "new game resets the board")
	main._on_white_choice_pressed()
	await process_frame
	var pass_board: Array[PackedInt32Array] = main.game.get_board_copy()
	for y in range(8):
		for x in range(8):
			pass_board[y][x] = 1
	pass_board[4][4] = 2
	pass_board[4][0] = 2
	pass_board[3][3] = 0
	pass_board[2][7] = 0
	pass_board[3][0] = 0
	main.game._board = pass_board
	main.game._current_color = 2
	main.game._game_over = false
	main.game._last_move = Vector2i(-1, -1)
	main._advance_turn()
	await process_frame
	check(main.phase == 1 and main.skip_button.visible, "skip appears when the human has no moves")
	check(not main.board._interactive, "board disabled when the human has no moves")
	check(main.status_label.text == "No valid moves. Tap Skip.", "no-move status shown")
	main._on_skip_pressed()
	await create_timer(0.7).timeout
	check(main.phase == 1, "single-player pass does not end the game")
	check(main.skip_button.visible, "skip returns when the human still has no moves after the computer move")

	# New Game during the computer delay invalidates the pending move.
	main._on_new_game_pressed()
	await process_frame
	main._on_black_choice_pressed()
	await process_frame
	check(main.phase == 2, "computer starts as White when the human picks Black")
	main._on_new_game_pressed()
	await process_frame
	await create_timer(0.7).timeout
	check(main.phase == 0, "stale computer action does not change the phase")
	check(main.color_choice_overlay.visible, "overlay stays up after stale action")
	check(main.game.get_disc_count(2) == 2 and main.game.get_disc_count(1) == 2, "stale action never moves the board")

	# Quit handler exists and is wired.
	check(main.quit_button.pressed.get_connections().size() >= 1, "quit button is connected")

	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("ALL SCENE TESTS PASSED (%d checks)" % check_count)
		quit(0)
	else:
		print("FAILED SCENE TESTS: %d of %d checks" % [failures.size(), check_count])
		for failure in failures:
			print("  FAIL: " + failure)
		quit(1)
