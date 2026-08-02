extends SceneTree

const OthelloGameScript := preload("res://scripts/othello_game.gd")
const ComputerOpponentScript := preload("res://scripts/computer_opponent.gd")

const WHITE := OthelloGameScript.Disc.WHITE
const BLACK := OthelloGameScript.Disc.BLACK
const EMPTY := OthelloGameScript.Disc.EMPTY

var failures: Array[String] = []
var check_count := 0


func _initialize() -> void:
	_run_model_tests()
	_run_ai_tests()
	if failures.is_empty():
		print("ALL TESTS PASSED (%d checks)" % check_count)
		quit(0)
	else:
		print("FAILED TESTS: %d of %d checks" % [failures.size(), check_count])
		for failure in failures:
			print("  FAIL: " + failure)
		quit(1)


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func check_board_equal(actual: Array[PackedInt32Array], expected: Array[PackedInt32Array], message: String) -> void:
	if actual.size() != expected.size():
		check(false, message)
		return
	for y in range(actual.size()):
		if actual[y] != expected[y]:
			check(false, message)
			return
	check(true, message)


func check_set_equal(actual: Array[Vector2i], expected: Array[Vector2i], message: String) -> void:
	if actual.size() != expected.size():
		check(false, message)
		return
	for move in expected:
		if not actual.has(move):
			check(false, message)
			return
	check(true, message)


func empty_board() -> Array[PackedInt32Array]:
	var board: Array[PackedInt32Array] = []
	for y in range(8):
		var row := PackedInt32Array()
		row.resize(8)
		board.append(row)
	return board


func filled_board(color: int) -> Array[PackedInt32Array]:
	var board: Array[PackedInt32Array] = []
	for y in range(8):
		var row := PackedInt32Array()
		for x in range(8):
			row.append(color)
		board.append(row)
	return board


func place(board: Array[PackedInt32Array], x: int, y: int, color: int) -> void:
	board[y][x] = color


func set_instance_board(game: OthelloGameScript, board: Array[PackedInt32Array], current_color: int) -> void:
	game._board = board
	game._current_color = current_color
	game._game_over = false
	game._last_move = Vector2i(-1, -1)


# ---------------------------------------------------------------------------
# Model tests
# ---------------------------------------------------------------------------

func _run_model_tests() -> void:
	var game: OthelloGameScript = OthelloGameScript.new()

	var initial := game.get_board_copy()
	check(initial.size() == 8, "initial board has 8 rows")
	for row in initial:
		check(row.size() == 8, "initial board has 8 columns per row")
	check(game.get_disc_count(WHITE) == 2, "initial board has two White discs")
	check(game.get_disc_count(BLACK) == 2, "initial board has two Black discs")
	check(game.get_current_color() == WHITE, "White moves first after reset")
	check(not game.is_game_over(), "game not over after reset")
	check(initial[3][3] == WHITE and initial[4][3] == BLACK and initial[3][4] == BLACK and initial[4][4] == WHITE,
		"initial four center discs are placed correctly")
	check(game.get_last_move() == Vector2i(-1, -1), "last move is unset after reset")

	var initial_moves := game.get_valid_moves(WHITE)
	check_set_equal(initial_moves, [Vector2i(4, 2), Vector2i(5, 3), Vector2i(2, 4), Vector2i(3, 5)],
		"initial White moves are exactly (4,2),(5,3),(2,4),(3,5)")

	var before_occupied := game.get_board_copy()
	check(not game.try_make_move(Vector2i(3, 3)), "move onto occupied square is rejected")
	check_board_equal(game.get_board_copy(), before_occupied, "rejected move does not mutate board")
	check(game.get_current_color() == WHITE, "rejected move does not switch turn")

	var before_empty := game.get_board_copy()
	check(not game.try_make_move(Vector2i(0, 0)), "empty non-capturing move is rejected")
	check_board_equal(game.get_board_copy(), before_empty, "rejected empty move does not mutate board")

	check(game.try_make_move(Vector2i(4, 2)), "White move at (4,2) is accepted")
	var after_move := game.get_board_copy()
	check(after_move[3][4] == WHITE, "disc at (4,3) flips to White")
	check(game.get_disc_count(WHITE) == 4 and game.get_disc_count(BLACK) == 1, "counts are 4 White, 1 Black after move")
	check(game.get_current_color() == BLACK, "turn switches to Black after White move")
	check(game.get_last_move() == Vector2i(4, 2), "last move is stored")
	check(game.get_disc_count(WHITE) + game.get_disc_count(BLACK) + game.get_disc_count(EMPTY) == 64,
		"disc counts plus empties equal 64")

	# Horizontal line capture.
	var horizontal := empty_board()
	for x in range(1, 5):
		place(horizontal, x, 3, BLACK)
	place(horizontal, 5, 3, WHITE)
	check_set_equal(OthelloGameScript.find_flips(horizontal, Vector2i(0, 3), WHITE),
		[Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)], "horizontal line flips every enclosed disc")
	var horizontal_after := OthelloGameScript.board_after_move(horizontal, Vector2i(0, 3), WHITE)
	check(horizontal_after[3][0] == WHITE and horizontal_after[3][4] == WHITE, "horizontal move places disc and flips line")
	check(horizontal[3][0] == EMPTY, "board_after_move does not mutate the input board")

	# Vertical line capture.
	var vertical := empty_board()
	for y in range(1, 5):
		place(vertical, 3, y, BLACK)
	place(vertical, 3, 5, WHITE)
	check_set_equal(OthelloGameScript.find_flips(vertical, Vector2i(3, 0), WHITE),
		[Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)], "vertical line flips every enclosed disc")

	# Diagonal captures, both axes.
	var diagonal_a := empty_board()
	place(diagonal_a, 1, 1, BLACK)
	place(diagonal_a, 2, 2, BLACK)
	place(diagonal_a, 3, 3, BLACK)
	place(diagonal_a, 4, 4, WHITE)
	check_set_equal(OthelloGameScript.find_flips(diagonal_a, Vector2i(0, 0), WHITE),
		[Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)], "descending diagonal flips enclosed discs")
	var diagonal_b := empty_board()
	place(diagonal_b, 1, 6, BLACK)
	place(diagonal_b, 2, 5, BLACK)
	place(diagonal_b, 3, 4, BLACK)
	place(diagonal_b, 4, 3, WHITE)
	check_set_equal(OthelloGameScript.find_flips(diagonal_b, Vector2i(0, 7), WHITE),
		[Vector2i(1, 6), Vector2i(2, 5), Vector2i(3, 4)], "ascending diagonal flips enclosed discs")

	# Multi-direction move.
	var multi := empty_board()
	place(multi, 4, 4, WHITE)
	place(multi, 6, 4, WHITE)
	place(multi, 4, 3, BLACK)
	place(multi, 5, 3, BLACK)
	check_set_equal(OthelloGameScript.find_flips(multi, Vector2i(4, 2), WHITE),
		[Vector2i(4, 3), Vector2i(5, 3)], "one move flips discs in two directions")
	var multi_after := OthelloGameScript.board_after_move(multi, Vector2i(4, 2), WHITE)
	check(multi_after[3][4] == WHITE and multi_after[3][5] == WHITE, "multi-direction move applies all flips")

	# Edge scanning: no out-of-bounds access or false captures.
	var edge_a := empty_board()
	place(edge_a, 2, 0, WHITE)
	place(edge_a, 1, 0, BLACK)
	check_set_equal(OthelloGameScript.find_flips(edge_a, Vector2i(0, 0), WHITE),
		[Vector2i(1, 0)], "top-left corner capture works")
	var edge_b := empty_board()
	place(edge_b, 5, 0, WHITE)
	place(edge_b, 6, 0, BLACK)
	check_set_equal(OthelloGameScript.find_flips(edge_b, Vector2i(7, 0), WHITE),
		[Vector2i(6, 0)], "top-right edge capture works")
	var edge_c := empty_board()
	place(edge_c, 5, 0, WHITE)
	place(edge_c, 6, 0, BLACK)
	place(edge_c, 7, 0, BLACK)
	check(OthelloGameScript.find_flips(edge_c, Vector2i(4, 0), WHITE).is_empty(),
		"sequence ending at the board edge does not capture")
	var edge_d := empty_board()
	place(edge_d, 1, 0, BLACK)
	check(OthelloGameScript.find_flips(edge_d, Vector2i(0, 0), WHITE).is_empty(),
		"opponent run without a friendly end does not capture")
	check(OthelloGameScript.find_flips(edge_d, Vector2i(-1, 3), WHITE).is_empty(), "out-of-bounds position is rejected")
	check(OthelloGameScript.find_flips(edge_d, Vector2i(8, 8), WHITE).is_empty(), "far out-of-bounds position is rejected")
	check(OthelloGameScript.find_flips(edge_d, Vector2i(0, 8), WHITE).is_empty(), "edge out-of-bounds position is rejected")

	# Corner capture with multiple directions.
	var corner := empty_board()
	place(corner, 3, 3, WHITE)
	place(corner, 1, 1, BLACK)
	place(corner, 2, 2, BLACK)
	place(corner, 2, 0, WHITE)
	place(corner, 1, 0, BLACK)
	check_set_equal(OthelloGameScript.find_flips(corner, Vector2i(0, 0), WHITE),
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 2)], "corner move captures on both axes")

	# Illegal pass.
	var before_pass := game.get_board_copy()
	check(not game.try_pass(), "pass is rejected when the current color can move")
	check_board_equal(game.get_board_copy(), before_pass, "rejected pass does not mutate state")
	check(game.get_current_color() == BLACK, "rejected pass does not switch turn")

	# Legal pass: White has no move, Black has one move at (3,3).
	var pass_board := filled_board(BLACK)
	place(pass_board, 4, 4, WHITE)
	place(pass_board, 3, 3, EMPTY)
	place(pass_board, 2, 7, EMPTY)
	check(OthelloGameScript.find_valid_moves(pass_board, WHITE).is_empty(), "fixture has no White moves")
	check_set_equal(OthelloGameScript.find_valid_moves(pass_board, BLACK), [Vector2i(3, 3)], "fixture has one Black move")
	var pass_game: OthelloGameScript = OthelloGameScript.new()
	set_instance_board(pass_game, pass_board, WHITE)
	check(pass_game.try_pass(), "pass is accepted when only the current color cannot move")
	check(pass_game.get_current_color() == BLACK, "pass switches to the opposite color")
	check(not pass_game.is_game_over(), "single-color pass does not end the game")

	# Neither color can move: game over even with empty squares.
	var dead_board := filled_board(BLACK)
	place(dead_board, 4, 4, WHITE)
	place(dead_board, 2, 7, EMPTY)
	check(OthelloGameScript.find_valid_moves(dead_board, WHITE).is_empty(), "dead fixture has no White moves")
	check(OthelloGameScript.find_valid_moves(dead_board, BLACK).is_empty(), "dead fixture has no Black moves")
	var dead_game: OthelloGameScript = OthelloGameScript.new()
	set_instance_board(dead_game, dead_board, WHITE)
	check(dead_game.try_pass(), "pass accepted when neither color can move")
	check(dead_game.is_game_over(), "game ends when neither color can move")
	check(not dead_game.try_make_move(Vector2i(2, 7)), "moves are rejected after game over")

	# Full board ends the game immediately.
	var full_board := filled_board(WHITE)
	place(full_board, 6, 7, BLACK)
	place(full_board, 7, 7, EMPTY)
	var full_game: OthelloGameScript = OthelloGameScript.new()
	set_instance_board(full_game, full_board, WHITE)
	check(full_game.try_make_move(Vector2i(7, 7)), "final move onto the last empty square is accepted")
	check(full_game.is_board_full(), "board is full after final move")
	check(full_game.is_game_over(), "game ends immediately when the board is full")

	# Board copies never expose mutable references.
	var copy_game: OthelloGameScript = OthelloGameScript.new()
	var board_copy := copy_game.get_board_copy()
	board_copy[0] = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	board_copy[1][1] = WHITE
	var fresh := copy_game.get_board_copy()
	check(fresh[0][0] == EMPTY and fresh[1][1] == EMPTY, "mutating a returned board copy does not mutate the model")

	# Full random games always terminate with correct disc totals.
	for round_index in range(6):
		var play_game: OthelloGameScript = OthelloGameScript.new()
		play_game.reset()
		var turn_count := 0
		while not play_game.is_game_over() and turn_count < 128:
			var moves := play_game.get_valid_moves(play_game.get_current_color())
			if moves.is_empty():
				check(play_game.try_pass(), "automatic pass is accepted mid-game (round %d)" % round_index)
			else:
				var move := moves[randi() % moves.size()]
				check(play_game.try_make_move(move), "random move is accepted (round %d)" % round_index)
			turn_count += 1
		check(play_game.is_game_over(), "random game terminates (round %d)" % round_index)
		check(play_game.get_disc_count(BLACK) + play_game.get_disc_count(WHITE) == 64 - play_game.get_disc_count(EMPTY),
			"final counts agree (round %d)" % round_index)


# ---------------------------------------------------------------------------
# AI tests
# ---------------------------------------------------------------------------

func _run_ai_tests() -> void:
	# Fixture N: no valid moves at all.
	var no_move_board := filled_board(BLACK)
	place(no_move_board, 4, 4, WHITE)
	place(no_move_board, 2, 7, EMPTY)
	var ai: ComputerOpponentScript = ComputerOpponentScript.new()
	for seed in range(8):
		ai.set_seed_for_tests(seed)
		check(ai.choose_move(no_move_board, BLACK, WHITE) == ComputerOpponentScript.NO_MOVE,
			"AI returns NO_MOVE when it has no valid moves (seed %d)" % seed)

	# Fixture O: exactly one valid move at (3,3).
	var one_move_board := filled_board(BLACK)
	place(one_move_board, 4, 4, WHITE)
	place(one_move_board, 3, 3, EMPTY)
	place(one_move_board, 2, 7, EMPTY)
	for seed in range(8):
		ai.set_seed_for_tests(seed)
		check(ai.choose_move(one_move_board, BLACK, WHITE) == Vector2i(3, 3),
			"AI returns the only legal move (seed %d)" % seed)

	# Fixture X: one unsafe move (0,1) exposes (0,0); safe moves are (0,5),(4,2),(5,3).
	var mixed_board := empty_board()
	place(mixed_board, 0, 2, BLACK)
	place(mixed_board, 0, 3, WHITE)
	place(mixed_board, 0, 4, BLACK)
	place(mixed_board, 3, 3, WHITE)
	place(mixed_board, 4, 3, BLACK)
	place(mixed_board, 4, 4, WHITE)
	var mixed_valid: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 5), Vector2i(4, 2), Vector2i(5, 3)]
	var mixed_safe: Array[Vector2i] = [Vector2i(0, 5), Vector2i(4, 2), Vector2i(5, 3)]
	check_set_equal(OthelloGameScript.find_valid_moves(mixed_board, WHITE), mixed_valid, "mixed fixture valid moves")
	check_set_equal(ai.get_corner_safe_moves(mixed_board, WHITE, BLACK), mixed_safe, "mixed fixture corner-safe set")
	for seed in range(16):
		ai.set_seed_for_tests(seed)
		var move := ai.choose_move(mixed_board, WHITE, BLACK)
		check(mixed_safe.has(move), "AI never exposes a corner when a safe move exists (seed %d: %s)" % [seed, move])

	# Fixture E: safe edge moves (0,5) and corner take (0,7) exist; (0,1) is unsafe.
	var edge_board := empty_board()
	place(edge_board, 0, 2, BLACK)
	place(edge_board, 0, 3, WHITE)
	place(edge_board, 0, 4, BLACK)
	place(edge_board, 3, 3, WHITE)
	place(edge_board, 4, 3, BLACK)
	place(edge_board, 4, 4, WHITE)
	place(edge_board, 1, 7, BLACK)
	place(edge_board, 2, 7, WHITE)
	var edge_safe: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 7), Vector2i(4, 2), Vector2i(5, 3)]
	var edge_safe_edges: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 7)]
	check_set_equal(ai.get_corner_safe_moves(edge_board, WHITE, BLACK), edge_safe, "edge fixture corner-safe set")
	check(ai.get_corner_safe_moves(edge_board, WHITE, BLACK).has(Vector2i(0, 7)),
		"computer corner take is corner-safe and eligible")
	for seed in range(16):
		ai.set_seed_for_tests(seed)
		var move := ai.choose_move(edge_board, WHITE, BLACK)
		check(edge_safe_edges.has(move),
			"AI prefers edge plays among corner-safe moves (seed %d: %s)" % [seed, move])

	# Fixture I: safe moves exist but none on the edge; both moves are interior.
	var interior_board := empty_board()
	place(interior_board, 3, 3, WHITE)
	place(interior_board, 4, 3, BLACK)
	place(interior_board, 4, 4, WHITE)
	var interior_safe: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 3)]
	for seed in range(16):
		ai.set_seed_for_tests(seed)
		var move := ai.choose_move(interior_board, WHITE, BLACK)
		check(interior_safe.has(move), "AI falls back to the corner-safe set when no edge move is safe (seed %d)" % seed)
		check(not ComputerOpponentScript.is_edge_square(move), "edge preference cannot invent an edge move (seed %d)" % seed)

	# Fixture F: every move exposes a corner; the AI falls back to all valid moves.
	var fallback_board := empty_board()
	place(fallback_board, 0, 2, BLACK)
	place(fallback_board, 0, 3, WHITE)
	place(fallback_board, 0, 4, BLACK)
	place(fallback_board, 0, 5, WHITE)
	place(fallback_board, 7, 2, BLACK)
	place(fallback_board, 7, 3, WHITE)
	place(fallback_board, 7, 4, BLACK)
	place(fallback_board, 7, 5, WHITE)
	var fallback_valid: Array[Vector2i] = [Vector2i(0, 1), Vector2i(7, 1)]
	check_set_equal(OthelloGameScript.find_valid_moves(fallback_board, WHITE), fallback_valid, "fallback fixture valid moves")
	check(ai.get_corner_safe_moves(fallback_board, WHITE, BLACK).is_empty(), "fallback fixture has no safe moves")
	for seed in range(16):
		ai.set_seed_for_tests(seed)
		var move := ai.choose_move(fallback_board, WHITE, BLACK)
		check(fallback_valid.has(move),
			"AI returns a legal move when every move exposes a corner (seed %d: %s)" % [seed, move])

	# Simulation isolation: evaluation never changes the live board snapshot.
	var isolation_board := empty_board()
	place(isolation_board, 3, 3, WHITE)
	place(isolation_board, 4, 3, BLACK)
	place(isolation_board, 4, 4, WHITE)
	var isolation_snapshot: Array[PackedInt32Array] = []
	for row in isolation_board:
		isolation_snapshot.append(row.duplicate())
	ai.set_seed_for_tests(7)
	ai.choose_move(isolation_board, WHITE, BLACK)
	check_board_equal(isolation_board, isolation_snapshot, "AI evaluation does not mutate the live board snapshot")
	OthelloGameScript.board_after_move(isolation_board, Vector2i(4, 2), WHITE)
	check_board_equal(isolation_board, isolation_snapshot, "board_after_move does not mutate its input")
