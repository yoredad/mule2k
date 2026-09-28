class_name Player
extends RefCounted

enum ColorId { GREEN, BLUE, ORANGE, PURPLE }

const COLOR_NAMES: Array[String] = ["Green", "Blue", "Orange", "Purple"]
const COLORS: Array[Color] = [
	Color("3fae49"),
	Color("3f7fae"),
	Color("e08a1e"),
	Color("a94fae"),
]

const START_CASH: int = 1000
const START_FOOD: int = 4
const START_ENERGY: int = 2

var id: int = 0
var color_id: int = ColorId.GREEN
var is_human: bool = false
var cash: int = START_CASH
var food: int = START_FOOD
var energy: int = START_ENERGY
var smithore: int = 0
var crystite: int = 0
var plots: Array[Plot] = []
var score: int = 0
var rank: int = 0

func _init(p_id: int, p_color_id: int = ColorId.GREEN, p_human: bool = false) -> void:
	id = p_id
	color_id = p_color_id
	is_human = p_human

func color() -> Color:
	return COLORS[color_id]

func display_name() -> String:
	return COLOR_NAMES[color_id]

func mules() -> Array[Mule]:
	var result: Array[Mule] = []
	for plot in plots:
		if plot.mule != null:
			result.append(plot.mule)
	return result

func mule_count() -> int:
	return plots.filter(func(p): return p.mule != null).size()

func non_energy_mules() -> int:
	return plots.filter(func(p): return p.mule != null and p.mule.unit != Economy.Unit.ENERGY).size()

func total_units(unit: int) -> int:
	return plots.filter(func(p): return p.mule != null and p.mule.unit == unit).size()

func inventory(unit: int) -> int:
	match unit:
		Economy.Unit.FOOD:
			return food
		Economy.Unit.ENERGY:
			return energy
		Economy.Unit.SMITHORE:
			return smithore
		Economy.Unit.CRYSTITE:
			return crystite
	return 0

func add_units(unit: int, qty: int) -> void:
	match unit:
		Economy.Unit.FOOD:
			food += qty
		Economy.Unit.ENERGY:
			energy += qty
		Economy.Unit.SMITHORE:
			smithore += qty
		Economy.Unit.CRYSTITE:
			crystite += qty

func take_units(unit: int, qty: int) -> void:
	match unit:
		Economy.Unit.FOOD:
			food -= qty
		Economy.Unit.ENERGY:
			energy -= qty
		Economy.Unit.SMITHORE:
			smithore -= qty
		Economy.Unit.CRYSTITE:
			crystite -= qty

func empty_plots() -> Array[Plot]:
	return plots.filter(func(p): return p.mule == null)

func net_worth(prices: Dictionary) -> int:
	var plot_value := 0
	for plot in plots:
		plot_value += 500 + (plot.mule.outfit_cost() if plot.mule != null else 0)
	return Economy.score(cash, plot_value, mule_count(), food, energy, smithore, crystite, prices)
