extends Control

signal plot_tapped(col: int, row: int)

const TERRAIN_COLORS := {
	Board.Terrain.PLAINS: Color("c8b48a"),
	Board.Terrain.RIVER: Color("3a6ea5"),
	Board.Terrain.MOUNTAIN: Color("8a8a8a"),
	Board.Terrain.STORE: Color("b03a3a"),
}
const GRID_COLOR := Color("2b2b2b")
const MOUNTAIN_PEAK_COLOR := Color("565656")
const RIVER_DEPTH_COLOR := Color("2c4f7c")
const UNIT_COLORS := {
	Economy.Unit.FOOD: Color("3fae49"),
	Economy.Unit.ENERGY: Color("e0c41e"),
	Economy.Unit.SMITHORE: Color("4a7fb5"),
	Economy.Unit.CRYSTITE: Color("d24a9e"),
}
const GEM_COLORS := {
	0: Color("7a7a7a"),
	1: Color("3fae49"),
	2: Color("e0c41e"),
	3: Color("e08a1e"),
	4: Color("c22a2a"),
}
const SHEET_PATH := "res://assets/mule_sheet.png"
const PIP_SHEET_PATH := "res://assets/pip_sheet.png"
const SHEET_PLACEHOLDER_COL := 4
const SHEET_COL_BY_UNIT := {
	Economy.Unit.FOOD: 0,
	Economy.Unit.ENERGY: 1,
	Economy.Unit.CRYSTITE: 2,
	Economy.Unit.SMITHORE: 3,
}
const SHEET_ROW_BY_COLOR := {0: 0, 1: 2, 2: 1, 3: 3}
const ICON_BOTTOM_OFFSET := 10.0
const ICON_HEIGHT_FRAC := 0.42

var board: Board
var highlight_cells: Array[Vector2i] = []
var highlight_color := Color(1.0, 1.0, 1.0, 0.25)
var outline_cells: Array[Vector2i] = []
var outline_color := Color.WHITE
var selected_cell := Vector2i(-1, -1)
var selected_color := Color.WHITE
var flash_cell := Vector2i(-1, -1)
var flash_color := Color.WHITE
var mule_sheet: Texture2D
var mule_regions: Array[Rect2] = []
var pip_sheet: Texture2D
var pip_regions: Array[Rect2] = []
var production_results: Dictionary = {}

@onready var gs: Node = get_node("/root/GameState")

func _ready() -> void:
	board = gs.board
	mule_sheet = load(SHEET_PATH)
	if mule_sheet != null:
		_build_atlas(mule_sheet)
	pip_sheet = load(PIP_SHEET_PATH)
	if pip_sheet != null:
		_build_pip_atlas(pip_sheet)
	resized.connect(queue_redraw)
	# Update board reference when a new game starts
	gs.game_started.connect(_on_game_started)
	queue_redraw()

func _on_game_started() -> void:
	board = gs.board
	queue_redraw()

func _build_atlas(tex: Texture2D) -> void:
	var img: Image = tex.get_image()
	var col_bands := _content_bands(img, true)
	var row_bands := _content_bands(img, false)
	if col_bands.size() < 5 or row_bands.size() < 4:
		return
	col_bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y - a.x < b.y - b.x)
	row_bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y - a.x < b.y - b.x)
	col_bands = col_bands.slice(0, 5)
	row_bands = row_bands.slice(row_bands.size() - 4, row_bands.size())
	col_bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	row_bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	mule_regions.clear()
	for r in 4:
		for c in 5:
			mule_regions.append(Rect2(col_bands[c].x, row_bands[r].x,
				col_bands[c].y - col_bands[c].x, row_bands[r].y - row_bands[r].x))

func _content_bands(img: Image, vertical: bool) -> Array:
	var bands: Array = []
	var in_band := false
	var start := 0
	var outer := img.get_width() if vertical else img.get_height()
	var inner := img.get_height() if vertical else img.get_width()
	for i in outer:
		var any := false
		for j in range(0, inner, 2):
			var px := img.get_pixel(i, j) if vertical else img.get_pixel(j, i)
			if px.a > 0.05:
				any = true
				break
		if any and not in_band:
			in_band = true
			start = i
		elif not any and in_band:
			in_band = false
			bands.append(Vector2i(start, i))
	if in_band:
		bands.append(Vector2i(start, outer))
	return bands

func _build_pip_atlas(tex: Texture2D) -> void:
	var img: Image = tex.get_image()
	var row_bands := _content_bands(img, false)
	if row_bands.is_empty():
		return
	row_bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y - a.x > b.y - b.x)
	var band: Vector2i = row_bands[0]
	var scan_y := (band.x + band.y) / 2
	var runs: Array = []
	var start := -1
	var last_idx := -1
	for x in img.get_width():
		var c := img.get_pixel(x, scan_y)
		if c.a > 0.05:
			var idx := _nearest_player_color(c)
			if start < 0 or idx != last_idx:
				if start >= 0:
					runs.append([start, x, last_idx])
				start = x
				last_idx = idx
		elif start >= 0:
			runs.append([start, x, last_idx])
			start = -1
	if start >= 0:
		runs.append([start, img.get_width(), last_idx])
	pip_regions = []
	for color_id in Player.ColorId.values():
		pip_regions.append(Rect2())
	for run in runs:
		if run[1] - run[0] <= 10:
			continue
		pip_regions[run[2]] = Rect2(run[0], band.x, run[1] - run[0], band.y - band.x)

func _nearest_player_color(c: Color) -> int:
	var best := 0
	var best_dist := 1e9
	for color_id in Player.ColorId.values():
		var pc: Color = Player.COLORS[color_id]
		var d := absf(c.r - pc.r) + absf(c.g - pc.g) + absf(c.b - pc.b)
		if d < best_dist:
			best_dist = d
			best = color_id
	return best

func set_production_results(results: Dictionary) -> void:
	production_results = results
	queue_redraw()

func set_highlights(cells: Array, color: Color) -> void:
	highlight_cells.assign(cells)
	highlight_color = color
	queue_redraw()

func clear_highlights() -> void:
	highlight_cells = []
	queue_redraw()

func set_outlines(cells: Array, color: Color) -> void:
	outline_cells.assign(cells)
	outline_color = color
	queue_redraw()

func clear_outlines() -> void:
	outline_cells = []
	queue_redraw()

func select_plot(col: int, row: int, color: Color) -> void:
	selected_cell = Vector2i(col, row)
	selected_color = color
	queue_redraw()

func clear_selection() -> void:
	selected_cell = Vector2i(-1, -1)
	queue_redraw()

func flash_plot(col: int, row: int, color: Color) -> void:
	flash_cell = Vector2i(col, row)
	flash_color = color
	queue_redraw()

func clear_flash() -> void:
	flash_cell = Vector2i(-1, -1)
	queue_redraw()

func _draw() -> void:
	if board == null:
		return
	var cell := cell_size()
	# Draw everything in a single pass per plot
	for plot in board.plots:
		var rect := cell_rect(plot.col, plot.row, cell)
		# Base terrain
		draw_rect(rect, TERRAIN_COLORS[plot.terrain], true)
		draw_rect(rect, GRID_COLOR, false, 1.0)
		# Terrain features
		match plot.terrain:
			Board.Terrain.MOUNTAIN:
				_draw_mountains(rect, plot.mountains)
			Board.Terrain.STORE:
				_draw_store(rect)
			Board.Terrain.RIVER:
				_draw_river(rect)
		# Ownership border (if claimed)
		if plot.is_claimed():
			_draw_owner(rect, plot)
		# Mule icon (if has mule)
		if plot.mule != null and plot.terrain != Board.Terrain.STORE:
			_draw_plot_icon(rect, plot)
		# Crystite gem (if assayed)
		if plot.crystite_assayed:
			_draw_gem(rect, plot.crystite_quality)
	# Production pips
	_draw_production_pips(cell)
	# Highlight overlays
	for hcell in highlight_cells:
		draw_rect(cell_rect(hcell.x, hcell.y, cell), highlight_color, true)
	# Flash overlay
	if board.in_bounds(flash_cell.x, flash_cell.y):
		draw_rect(cell_rect(flash_cell.x, flash_cell.y, cell), flash_color, true)
	# Outline overlays (e.g. late-round land grant picks, auction style)
	for ocell in outline_cells:
		if board.in_bounds(ocell.x, ocell.y):
			draw_rect(cell_rect(ocell.x, ocell.y, cell).grow(-2.0),
				outline_color, false, 3.0)
	# Selection border
	if board.in_bounds(selected_cell.x, selected_cell.y):
		draw_rect(cell_rect(selected_cell.x, selected_cell.y, cell).grow(-2.0),
			selected_color, false, 3.0)

func cell_size() -> Vector2:
	return Vector2(size.x / Board.COLS, size.y / Board.ROWS)

func cell_rect(col: int, row: int, cell: Vector2) -> Rect2:
	return Rect2(Vector2(col * cell.x, row * cell.y), cell)

func _draw_mountains(rect: Rect2, count: int) -> void:
	var base_y := rect.position.y + rect.size.y * 0.55
	var step := rect.size.x / float(count + 1)
	var half_w := rect.size.x * 0.16
	for i in count:
		var cx := rect.position.x + step * (i + 1)
		var pts := PackedVector2Array([
			Vector2(cx - half_w, base_y),
			Vector2(cx, base_y - rect.size.y * 0.32),
			Vector2(cx + half_w, base_y),
		])
		draw_colored_polygon(pts, MOUNTAIN_PEAK_COLOR)

func _draw_store(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.66), "$",
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.5, 28, Color.WHITE)

func _draw_river(rect: Rect2) -> void:
	var pts := PackedVector2Array([
		rect.position + Vector2(0, rect.size.y * 0.7),
		rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.35),
		rect.position + Vector2(rect.size.x, rect.size.y * 0.6),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(0, rect.size.y),
	])
	draw_colored_polygon(pts, RIVER_DEPTH_COLOR)

func _draw_owner(rect: Rect2, plot: Plot) -> void:
	if plot.owner_id < 0 or plot.owner_id >= Player.COLORS.size():
		return
	var color: Color = Player.COLORS[plot.owner_id]
	# Draw a thicker, more visible border
	draw_rect(rect.grow(-1.0), color, false, 4.0)
	# Draw colored bar at bottom
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 8), Vector2(rect.size.x, 8)),
		color, true)

func _draw_plot_icon(rect: Rect2, plot: Plot) -> void:
	if mule_sheet != null and mule_regions.size() == 20:
		var row: int = SHEET_ROW_BY_COLOR.get(plot.owner_id, 0) if plot.is_claimed() else 0
		var col: int = SHEET_COL_BY_UNIT.get(plot.mule.unit, SHEET_PLACEHOLDER_COL) \
			if plot.mule != null else SHEET_PLACEHOLDER_COL
		var region: Rect2 = mule_regions[row * 5 + col]
		var h := rect.size.y * ICON_HEIGHT_FRAC
		var w := h * (region.size.x / region.size.y)
		var pos := Vector2(rect.position.x + (rect.size.x - w) * 0.5,
			rect.position.y + rect.size.y - ICON_BOTTOM_OFFSET - h)
		draw_texture_rect_region(mule_sheet, Rect2(pos, Vector2(w, h)), region)
	else:
		_draw_mule_fallback(rect, plot)

func _draw_mule_fallback(rect: Rect2, plot: Plot) -> void:
	if plot.mule == null:
		return
	var color: Color = Player.COLORS[plot.owner_id]
	var center := rect.position + rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.22
	draw_circle(center, radius, color)
	draw_arc(center, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 2.0)
	var font := ThemeDB.fallback_font
	var letter := plot.mule.letter()
	var size := int(radius * 1.4)
	draw_string_outline(font, center + Vector2(-radius * 0.5, radius * 0.4), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, center + Vector2(-radius * 0.5, radius * 0.4), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_gem(rect: Rect2, quality: int) -> void:
	var center := rect.position + Vector2(rect.size.x * 0.85, rect.size.y * 0.15)
	var radius := minf(rect.size.x, rect.size.y) * 0.09
	draw_circle(center, radius, GEM_COLORS.get(quality, GEM_COLORS[0]))
	draw_arc(center, radius, 0.0, TAU, 12, Color.WHITE, 1.0)

func _draw_production_pips(cell: Vector2) -> void:
	if pip_sheet == null or pip_regions.size() != 4:
		return
	for key in production_results:
		var entry: Dictionary = production_results[key]
		var count: int = entry.get("count", 0)
		if count <= 0:
			continue
		var cell_pos: Vector2i = key
		var plot: Plot = board.get_plot(cell_pos.x, cell_pos.y)
		if plot == null or plot.owner_id < 0 or plot.owner_id >= pip_regions.size():
			continue
		var region: Rect2 = pip_regions[plot.owner_id]
		if region.size.x <= 0 or region.size.y <= 0:
			continue
		_draw_pips(cell_rect(cell_pos.x, cell_pos.y, cell), count, region)

func _draw_pips(rect: Rect2, count: int, region: Rect2) -> void:
	var ps := rect.size.x * 0.16
	var gap := 2.0
	for i in mini(count, 8):
		var pos := rect.position + Vector2(3.0 + float(i % 4) * (ps + gap),
			3.0 + float(i / 4) * (ps + gap))
		draw_texture_rect_region(pip_sheet, Rect2(pos, Vector2(ps, ps)), region)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_size()
		var col := int(event.position.x / cell.x)
		var row := int(event.position.y / cell.y)
		if board.in_bounds(col, row):
			plot_tapped.emit(col, row)
		accept_event()
