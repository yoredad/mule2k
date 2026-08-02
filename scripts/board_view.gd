class_name OthelloBoardView
extends Control

signal cell_pressed(position: Vector2i)

const Disc = {
	EMPTY = 0,
	BLACK = 1,
	WHITE = 2,
}

var _board: Array[PackedInt32Array] = []
var _valid_moves: Array[Vector2i] = []
var _interactive: bool = false

# Layout cache calculated during drawing
var _board_side: float = 0.0
var _offset_x: float = 0.0
var _offset_y: float = 0.0
var _cell_size: float = 0.0

func _init() -> void:
	# Initialize an empty board state for safety before the first state update
	_board.clear()
	for y in range(8):
		var row := PackedInt32Array()
		row.resize(8)
		row.fill(Disc.EMPTY)
		_board.append(row)

func set_state(
	board_state: Array[PackedInt32Array],
	valid_moves: Array[Vector2i],
	interactive: bool
) -> void:
	# Deep copy board state to avoid sharing references
	_board.clear()
	for row in board_state:
		_board.append(row.duplicate())
	_valid_moves = valid_moves.duplicate()
	_interactive = interactive
	queue_redraw()

func _draw() -> void:
	# Calculate largest centered square
	_board_side = min(size.x, size.y)
	_offset_x = (size.x - _board_side) / 2.0
	_offset_y = (size.y - _board_side) / 2.0
	_cell_size = _board_side / 8.0
	
	var board_rect := Rect2(_offset_x, _offset_y, _board_side, _board_side)
	
	# 1. Draw outer background border/shadow
	draw_rect(board_rect, Color("#09261E"), true)
	
	# 2. Draw active green board surface (inset slightly to show border)
	var surface_rect := board_rect.grow(-4.0)
	draw_rect(surface_rect, Color("#1B6344"), true) # Rich board green
	
	# 3. Draw grid lines
	var line_color := Color("#0B2C1F") # Deep forest shadow line
	var line_width := 4.0
	for i in range(1, 8):
		var pos_offset: float = i * _cell_size
		# Vertical grid line
		draw_line(
			Vector2(_offset_x + pos_offset, _offset_y),
			Vector2(_offset_x + pos_offset, _offset_y + _board_side),
			line_color,
			line_width
		)
		# Horizontal grid line
		draw_line(
			Vector2(_offset_x, _offset_y + pos_offset),
			Vector2(_offset_x + _board_side, _offset_y + pos_offset),
			line_color,
			line_width
		)
		
	# 4. Draw discs and legal moves
	var disc_radius := _cell_size * 0.38
	var shadow_offset := Vector2(_cell_size * 0.04, _cell_size * 0.04)
	var shadow_color := Color(0, 0, 0, 0.35)
	
	# Draw all shadows first to layer properly
	for y in range(8):
		for x in range(8):
			var disc := _board[y][x]
			if disc != Disc.EMPTY:
				var cell_center := Vector2(
					_offset_x + (x + 0.5) * _cell_size,
					_offset_y + (y + 0.5) * _cell_size
				)
				draw_circle(cell_center + shadow_offset, disc_radius, shadow_color)
				
	# Draw actual discs
	for y in range(8):
		for x in range(8):
			var disc := _board[y][x]
			if disc == Disc.EMPTY:
				continue
				
			var cell_center := Vector2(
				_offset_x + (x + 0.5) * _cell_size,
				_offset_y + (y + 0.5) * _cell_size
			)
			
			if disc == Disc.WHITE:
				# Warm ivory disc
				draw_circle(cell_center, disc_radius, Color("#F5F1E8"))
				# Subdued dark outline
				draw_circle(cell_center, disc_radius, Color("#2C2E2B"), false, 3.0)
			elif disc == Disc.BLACK:
				# Charcoal disc
				draw_circle(cell_center, disc_radius, Color("#161A18"))
				# Subtle lighter edge highlight
				draw_circle(cell_center, disc_radius, Color("#3A3E3B"), false, 2.5)
				
	# 5. Draw valid move indicators (only if active/interactive human turn)
	if _interactive:
		var marker_radius := _cell_size * 0.11
		# Translucent gold/mint green highlight
		var marker_color := Color("#56D4A5", 0.45) # Soft high-contrast mint green
		var border_color := Color("#56D4A5", 0.75)
		
		for move in _valid_moves:
			var cell_center := Vector2(
				_offset_x + (move.x + 0.5) * _cell_size,
				_offset_y + (move.y + 0.5) * _cell_size
			)
			draw_circle(cell_center, marker_radius, marker_color)
			draw_circle(cell_center, marker_radius, border_color, false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
		
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Verify coordinates fall inside square board area
			var local_pos: Vector2 = mouse_event.position - Vector2(_offset_x, _offset_y)
			if local_pos.x >= 0 and local_pos.x < _board_side and local_pos.y >= 0 and local_pos.y < _board_side:
				var cell_x := int(floor(local_pos.x / _cell_size))
				var cell_y := int(floor(local_pos.y / _cell_size))
				
				# Bound clamp for complete safety
				cell_x = clampi(cell_x, 0, 7)
				cell_y = clampi(cell_y, 0, 7)
				
				cell_pressed.emit(Vector2i(cell_x, cell_y))
				get_viewport().set_input_as_handled()
