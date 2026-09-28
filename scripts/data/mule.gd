class_name Mule
extends RefCounted

var unit: int = Economy.Unit.FOOD
var turns_deployed: int = 0

func _init(p_unit: int = Economy.Unit.FOOD) -> void:
	unit = p_unit

func seniority_bonus() -> int:
	return turns_deployed / 3

func outfit_cost() -> int:
	return Economy.OUTFIT_COST[unit]

func letter() -> String:
	return Economy.UNIT_LETTERS[unit]

func display_name() -> String:
	return Economy.UNIT_NAMES[unit]
