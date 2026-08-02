class_name OthelloBoardView
extends Control

signal cell_pressed(position: Vector2i)

const CELL_COUNT := 8

const COLOR_BORDER := Color("#09261E")
const COLOR_BOARD := Color("#1F5C40")
const COLOR_GRID := Color(1.0, 1.0, 1.0, 0.14)
const COLOR_BLACK_DISC := Color("#111513")
const COLOR_BLACK_DISC_EDGE := Color("#3A413C")
const COLOR_WHITE_DISC := Color("#F5F1E8")
const COLOR_WHITE_DISC_OUTLINE := Color("#111513")
const COLOR_MARKER := Color(1.0, 0.835, 0.31, 0.7)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

const GRID_WIDTH := 3.0
const DISC_RADIUS_FACTOR := 0.38
const MARKER_RADIUS_FACTOR := 0.11

var _board: Array[PackedInt32Array]
var _valid_moves: Array[Vector2i] = []
var _interactive: bool = false


func set_state(
	board_state: Array[PackedInt32Array],
	valid_moves: Array[Vector2i],
	interactive: bool
) -> void:
	_board.clear()
	for row in board_state:
		_board.append(row.duplicate())
	_valid_moves = valid_moves.duplicate()
	_interactive = interactive
	queue_redraw()


func _draw() -> void:
	if _board.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var side := minf(size.x, size.y)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var cell_size := side / CELL_COUNT

	draw_rect(Rect2(origin - Vector2(GRID_WIDTH, GRID_WIDTH), Vector2(side, side) + Vector2(GRID_WIDTH * 2.0, GRID_WIDTH * 2.0)), COLOR_BORDER)
	draw_rect(Rect2(origin, Vector2(side, side)), COLOR_BOARD)
	for i in range(1, CELL_COUNT):
		var offset := i * cell_size
		draw_line(origin + Vector2(offset, 0.0), origin + Vector2(offset, side), COLOR_GRID, GRID_WIDTH)
		draw_line(origin + Vector2(0.0, offset), origin + Vector2(side, offset), COLOR_GRID, GRID_WIDTH)

	for y in range(CELL_COUNT):
		for x in range(CELL_COUNT):
			var value := _board[y][x]
			if value == OthelloGame.Disc.EMPTY:
				continue
			var center := origin + Vector2(x + 0.5, y + 0.5) * cell_size
			_draw_disc(center, cell_size * DISC_RADIUS_FACTOR, value)

	if _interactive:
		for move in _valid_moves:
			var center := origin + Vector2(move.x + 0.5, move.y + 0.5) * cell_size
			draw_circle(center, cell_size * MARKER_RADIUS_FACTOR, COLOR_MARKER)


func _draw_disc(center: Vector2, radius: float, color: int) -> void:
	var shadow_offset := radius * 0.09
	draw_circle(center + Vector2(shadow_offset, shadow_offset), radius, COLOR_SHADOW)
	if color == OthelloGame.Disc.BLACK:
		draw_circle(center, radius, COLOR_BLACK_DISC)
		draw_arc(center, radius - 1.5, 0.0, TAU, 48, COLOR_BLACK_DISC_EDGE, 2.0)
	else:
		draw_circle(center, radius, COLOR_WHITE_DISC)
		draw_arc(center, radius - 1.5, 0.0, TAU, 48, COLOR_WHITE_DISC_OUTLINE, 3.0)


func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var side := minf(size.x, size.y)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var local := mouse_event.position
	if local.x < origin.x or local.y < origin.y or local.x >= origin.x + side or local.y >= origin.y + side:
		return
	var cell_size := side / CELL_COUNT
	var column := int(floor((local.x - origin.x) / cell_size))
	var row := int(floor((local.y - origin.y) / cell_size))
	cell_pressed.emit(Vector2i(column, row))
