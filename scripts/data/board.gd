class_name Board
extends RefCounted

enum Terrain { PLAINS, RIVER, MOUNTAIN, STORE }

const COLS: int = 9
const ROWS: int = 5
const STORE_COL: int = 4
const STORE_ROW: int = 2
const RIVER_POSITIONS: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 3), Vector2i(4, 4)]
const MOUNTAIN_PLOT_COUNT: int = 10
const MOUNTAIN_WEIGHTS: Array[int] = [1, 1, 1, 1, 1, 1, 2, 2, 2, 3]
const ORTHO_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG_OFFSETS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const HIGH_CRYSTITE_COUNT: int = 3
const CRYSTITE_QUALITY_HIGH: int = 3
const CRYSTITE_QUALITY_MEDIUM: int = 2
const CRYSTITE_QUALITY_LOW: int = 1
const CRYSTITE_QUALITY_EXTRA_HIGH: int = 4
const TOTAL_CELLS: int = COLS * ROWS

var plots: Array[Plot] = []

func _init(rng: RandomNumberGenerator) -> void:
	generate(rng)

func generate(rng: RandomNumberGenerator) -> void:
	plots.clear()
	for row in ROWS:
		for col in COLS:
			var plot := Plot.new()
			plot.col = col
			plot.row = row
			if col == STORE_COL and row == STORE_ROW:
				plot.terrain = Terrain.STORE
			elif RIVER_POSITIONS.has(Vector2i(col, row)):
				plot.terrain = Terrain.RIVER
			plots.append(plot)
	_place_mountains(rng)
	_place_crystite_deposits(rng)

func _place_mountains(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Plot] = []
	for plot in plots:
		if not plot.is_store() and not plot.is_river():
			candidates.append(plot)
	_shuffle(candidates, rng)
	var mountain_plots: Array[Plot] = candidates.slice(0, MOUNTAIN_PLOT_COUNT)
	for plot in mountain_plots:
		plot.terrain = Terrain.MOUNTAIN
		plot.mountains = MOUNTAIN_WEIGHTS[rng.randi_range(0, MOUNTAIN_WEIGHTS.size() - 1)]
	if not mountain_plots.any(func(p): return p.mountains == 1):
		mountain_plots[0].mountains = 1
	if not mountain_plots.any(func(p): return p.mountains == 3):
		mountain_plots[1].mountains = 3

func _place_crystite_deposits(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Plot] = []
	for plot in plots:
		if not plot.is_store() and not plot.is_river():
			candidates.append(plot)
	_shuffle(candidates, rng)
	var highs := candidates.slice(0, HIGH_CRYSTITE_COUNT)
	for plot in highs:
		plot.crystite_quality = CRYSTITE_QUALITY_HIGH
		for offset in ORTHO_OFFSETS:
			_apply_crystite(plot.col + offset.x, plot.row + offset.y, CRYSTITE_QUALITY_MEDIUM)
			_apply_crystite(plot.col + offset.x * 2, plot.row + offset.y * 2, CRYSTITE_QUALITY_LOW)
		for offset in DIAG_OFFSETS:
			_apply_crystite(plot.col + offset.x, plot.row + offset.y, CRYSTITE_QUALITY_LOW)

func _apply_crystite(col: int, row: int, quality: int) -> void:
	if not in_bounds(col, row):
		return
	var plot := get_plot(col, row)
	plot.crystite_quality = maxi(plot.crystite_quality, quality)

func index(col: int, row: int) -> int:
	return row * COLS + col

func get_plot(col: int, row: int) -> Plot:
	return plots[index(col, row)]

func get_plot_at(pos: Vector2i) -> Plot:
	return get_plot(pos.x, pos.y)

func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS

func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp

func neighbors(col: int, row: int) -> Array[Plot]:
	var result: Array[Plot] = []
	for offset in ORTHO_OFFSETS:
		var nc := col + offset.x
		var nr := row + offset.y
		if in_bounds(nc, nr):
			result.append(get_plot(nc, nr))
	return result

func distance_to_store(col: int, row: int) -> int:
	return absi(col - STORE_COL) + absi(row - STORE_ROW)

func unclaimed_plots() -> Array[Plot]:
	return plots.filter(func(p): return p.is_empty())

func claimable_plots() -> Array[Plot]:
	return plots.filter(func(p): return not p.is_store() and not p.is_claimed())

func plots_without_mule() -> Array[Plot]:
	return plots.filter(func(p): return p.is_claimed() and p.mule == null)

func mountain_plots() -> Array[Plot]:
	return plots.filter(func(p): return p.is_mountain())

func river_plots() -> Array[Plot]:
	return plots.filter(func(p): return p.is_river())

func terrain_counts() -> Dictionary:
	var counts := {}
	for terrain in Terrain.values():
		counts[terrain] = 0
	for plot in plots:
		counts[plot.terrain] += 1
	return counts
