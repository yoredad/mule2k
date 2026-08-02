class_name OthelloGame
extends RefCounted

## Pure Othello rules model with no UI dependencies.
##
## Coordinates use Vector2i(x, y) everywhere outside the board array:
## x is the column (0-7) and y is the row (0-7).
## Array access is ALWAYS board[y][x].

enum Disc {
	EMPTY,
	BLACK,
	WHITE,
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
	_board = create_initial_board()
	_current_color = Disc.WHITE
	_game_over = false
	_last_move = Vector2i(-1, -1)


func get_board_copy() -> Array[PackedInt32Array]:
	var copy: Array[PackedInt32Array] = []
	for row in _board:
		copy.append(row.duplicate())
	return copy


func get_current_color() -> int:
	return _current_color


func get_last_move() -> Vector2i:
	return _last_move


func is_game_over() -> bool:
	return _game_over


func get_disc_count(color: int) -> int:
	var count := 0
	for row in _board:
		for value in row:
			if value == color:
				count += 1
	return count


func get_valid_moves(color: int) -> Array[Vector2i]:
	return find_valid_moves(_board, color)


func has_valid_move(color: int) -> bool:
	return not find_valid_moves(_board, color).is_empty()


func try_make_move(position: Vector2i) -> bool:
	if _game_over:
		return false
	var flips := find_flips(_board, position, _current_color)
	if flips.is_empty():
		return false
	_board[position.y][position.x] = _current_color
	for flip in flips:
		_board[flip.y][flip.x] = _current_color
	_last_move = position
	var board_is_full := is_board_full()
	var neither_color_can_move := not has_valid_move(Disc.BLACK) and not has_valid_move(Disc.WHITE)
	if board_is_full or neither_color_can_move:
		_game_over = true
	else:
		_current_color = opposite_color(_current_color)
	return true


func try_pass() -> bool:
	if _game_over:
		return false
	if has_valid_move(_current_color):
		return false
	var next_color := opposite_color(_current_color)
	if has_valid_move(next_color):
		_current_color = next_color
	else:
		_game_over = true
	return true


func is_board_full() -> bool:
	for row in _board:
		for value in row:
			if value == Disc.EMPTY:
				return false
	return true


static func opposite_color(color: int) -> int:
	match color:
		Disc.BLACK:
			return Disc.WHITE
		Disc.WHITE:
			return Disc.BLACK
	return Disc.EMPTY


static func create_initial_board() -> Array[PackedInt32Array]:
	var board: Array[PackedInt32Array] = []
	for y in range(BOARD_SIZE):
		var row := PackedInt32Array()
		row.resize(BOARD_SIZE)
		board.append(row)
	board[3][3] = Disc.WHITE
	board[4][3] = Disc.BLACK
	board[3][4] = Disc.BLACK
	board[4][4] = Disc.WHITE
	return board


static func find_flips(
	board_state: Array[PackedInt32Array],
	position: Vector2i,
	color: int
) -> Array[Vector2i]:
	var flips: Array[Vector2i] = []
	if color == Disc.EMPTY:
		return flips
	if not is_in_bounds(position):
		return flips
	if board_state[position.y][position.x] != Disc.EMPTY:
		return flips
	var opponent := opposite_color(color)
	for direction in DIRECTIONS:
		var cursor := position + direction
		var directional: Array[Vector2i] = []
		while is_in_bounds(cursor) and board_state[cursor.y][cursor.x] == opponent:
			directional.append(cursor)
			cursor += direction
		if not directional.is_empty() and is_in_bounds(cursor) and board_state[cursor.y][cursor.x] == color:
			flips.append_array(directional)
	return flips


static func find_valid_moves(board_state: Array[PackedInt32Array], color: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var position := Vector2i(x, y)
			if board_state[y][x] == Disc.EMPTY and not find_flips(board_state, position, color).is_empty():
				moves.append(position)
	return moves


static func board_after_move(
	board_state: Array[PackedInt32Array],
	position: Vector2i,
	color: int
) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for row in board_state:
		result.append(row.duplicate())
	var flips := find_flips(board_state, position, color)
	if flips.is_empty():
		return result
	result[position.y][position.x] = color
	for flip in flips:
		result[flip.y][flip.x] = color
	return result


static func is_in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < BOARD_SIZE and position.y >= 0 and position.y < BOARD_SIZE
