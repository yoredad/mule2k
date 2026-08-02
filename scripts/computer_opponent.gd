class_name ComputerOpponent
extends RefCounted

const OthelloGame := preload("res://scripts/othello_game.gd")

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
	
	var safe_moves := get_corner_safe_moves(board_state, computer_color, human_color)
	
	var candidates := safe_moves if not safe_moves.is_empty() else valid_moves
	var idx := _rng.randi_range(0, candidates.size() - 1)
	return candidates[idx]

func get_corner_safe_moves(
	board_state: Array[PackedInt32Array],
	computer_color: int,
	human_color: int
) -> Array[Vector2i]:
	var valid_moves := OthelloGame.find_valid_moves(board_state, computer_color)
	var safe_moves: Array[Vector2i] = []
	
	for move in valid_moves:
		# Simulate move
		var next_board := OthelloGame.board_after_move(board_state, move, computer_color)
		
		# Find human's legal moves on this simulated board
		var human_moves := OthelloGame.find_valid_moves(next_board, human_color)
		
		# Check if any human move is a corner
		var exposes_corner := false
		for h_move in human_moves:
			if h_move in CORNERS:
				exposes_corner = true
				break
		
		if not exposes_corner:
			safe_moves.append(move)
			
	return safe_moves
