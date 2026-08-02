class_name OthelloGame
extends RefCounted

enum Disc {
	EMPTY = 0,
	BLACK = 1,
	WHITE = 2,
}

const BOARD_SIZE := 8

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

var _board: Array[PackedInt32Array]
var _current_color: int = Disc.WHITE
var _game_over: bool = false
var _last_move: Vector2i = Vector2i(-1, -1)

func _init() -> void:
	reset()

func reset() -> void:
	_board.clear()
	for y in range(BOARD_SIZE):
		var row := PackedInt32Array()
		row.resize(BOARD_SIZE)
		for x in range(BOARD_SIZE):
			row[x] = Disc.EMPTY
		_board.append(row)
	
	# Set standard initial 4 discs
	_board[3][3] = Disc.WHITE
	_board[4][4] = Disc.WHITE
	_board[3][4] = Disc.BLACK
	_board[4][3] = Disc.BLACK
	
	_current_color = Disc.WHITE
	_game_over = false
	_last_move = Vector2i(-1, -1)

func get_board_copy() -> Array[PackedInt32Array]:
	var copy: Array[PackedInt32Array] = []
	for row in _board:
		copy.append(row.duplicate())
	return copy

func set_board_state_for_tests(board_state: Array[PackedInt32Array], current_color: int = Disc.WHITE, game_over: bool = false) -> void:
	_board.clear()
	for row in board_state:
		_board.append(row.duplicate())
	_current_color = current_color
	_game_over = game_over

func get_current_color() -> int:
	return _current_color

func get_last_move() -> Vector2i:
	return _last_move

func is_game_over() -> bool:
	return _game_over

func get_disc_count(color: int) -> int:
	var count := 0
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			if _board[y][x] == color:
				count += 1
	return count

func get_valid_moves(color: int) -> Array[Vector2i]:
	return find_valid_moves(_board, color)

func has_valid_move(color: int) -> bool:
	return not get_valid_moves(color).is_empty()

func is_board_full() -> bool:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			if _board[y][x] == Disc.EMPTY:
				return false
	return true

func try_make_move(position: Vector2i) -> bool:
	if _game_over:
		return false
	
	var flips := find_flips(_board, position, _current_color)
	if flips.is_empty():
		return false
	
	# Apply move
	_board[position.y][position.x] = _current_color
	for pt in flips:
		_board[pt.y][pt.x] = _current_color
	
	_last_move = position
	
	# Check for game over
	if is_board_full() or (not has_valid_move(Disc.WHITE) and not has_valid_move(Disc.BLACK)):
		_game_over = true
	else:
		# Switch turn
		_current_color = opposite_color(_current_color)
	
	return true

func try_pass() -> bool:
	if _game_over:
		return false
	
	# Cannot pass if the current player has any valid moves
	if has_valid_move(_current_color):
		return false
	
	var next_color := opposite_color(_current_color)
	# If the next player also cannot move, game is over
	if not has_valid_move(next_color):
		_game_over = true
	else:
		_current_color = next_color
	
	return true

# Static Helpers

static func opposite_color(color: int) -> int:
	if color == Disc.BLACK:
		return Disc.WHITE
	elif color == Disc.WHITE:
		return Disc.BLACK
	return Disc.EMPTY

static func find_flips(board_state: Array[PackedInt32Array], position: Vector2i, color: int) -> Array[Vector2i]:
	var flips: Array[Vector2i] = []
	
	# Bounds check
	if position.x < 0 or position.x >= BOARD_SIZE or position.y < 0 or position.y >= BOARD_SIZE:
		return flips
	
	# Must be empty
	if board_state[position.y][position.x] != Disc.EMPTY:
		return flips
	
	var opponent := opposite_color(color)
	if opponent == Disc.EMPTY:
		return flips
	
	for dir in DIRECTIONS:
		var cursor := position + dir
		var dir_flips: Array[Vector2i] = []
		
		# Trace opponent pieces in this direction
		while cursor.x >= 0 and cursor.x < BOARD_SIZE and cursor.y >= 0 and cursor.y < BOARD_SIZE and board_state[cursor.y][cursor.x] == opponent:
			dir_flips.append(cursor)
			cursor += dir
		
		# Did we end on our own color?
		if not dir_flips.is_empty() and cursor.x >= 0 and cursor.x < BOARD_SIZE and cursor.y >= 0 and cursor.y < BOARD_SIZE and board_state[cursor.y][cursor.x] == color:
			flips.append_array(dir_flips)
			
	return flips

static func find_valid_moves(board_state: Array[PackedInt32Array], color: int) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, y)
			if not find_flips(board_state, pos, color).is_empty():
				valid.append(pos)
	return valid

static func board_after_move(board_state: Array[PackedInt32Array], position: Vector2i, color: int) -> Array[PackedInt32Array]:
	# Create a deep copy
	var next_board: Array[PackedInt32Array] = []
	for row in board_state:
		next_board.append(row.duplicate())
	
	var flips := find_flips(next_board, position, color)
	if not flips.is_empty():
		next_board[position.y][position.x] = color
		for pt in flips:
			next_board[pt.y][pt.x] = color
			
	return next_board
