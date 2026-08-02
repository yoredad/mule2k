class_name ComputerOpponent
extends RefCounted

const NO_MOVE := Vector2i(-1, -1)

const CORNERS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(7, 0),
	Vector2i(0, 7),
	Vector2i(7, 7),
]

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func set_seed_for_tests(value: int) -> void:
	_rng.seed = value


func choose_move(
	board_state: Array[PackedInt32Array],
	computer_color: int,
	human_color: int
) -> Vector2i:
	var valid_moves := OthelloGame.find_valid_moves(board_state, computer_color)
	if valid_moves.is_empty():
		return NO_MOVE
	var candidates := valid_moves
	var safe_moves := get_corner_safe_moves(board_state, computer_color, human_color)
	if not safe_moves.is_empty():
		var edge_safe_moves: Array[Vector2i] = []
		for move in safe_moves:
			if is_edge_square(move):
				edge_safe_moves.append(move)
		candidates = edge_safe_moves if not edge_safe_moves.is_empty() else safe_moves
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func get_corner_safe_moves(
	board_state: Array[PackedInt32Array],
	computer_color: int,
	human_color: int
) -> Array[Vector2i]:
	var safe_moves: Array[Vector2i] = []
	for move in OthelloGame.find_valid_moves(board_state, computer_color):
		var after_move := OthelloGame.board_after_move(board_state, move, computer_color)
		var exposes_corner := false
		for human_move in OthelloGame.find_valid_moves(after_move, human_color):
			if CORNERS.has(human_move):
				exposes_corner = true
				break
		if not exposes_corner:
			safe_moves.append(move)
	return safe_moves


static func is_edge_square(position: Vector2i) -> bool:
	return position.x == 0 or position.x == 7 or position.y == 0 or position.y == 7
