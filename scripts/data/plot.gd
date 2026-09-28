class_name Plot
extends RefCounted

var col: int = 0
var row: int = 0
var terrain: int = Board.Terrain.PLAINS
var mountains: int = 0
var owner_id: int = -1
var mule: Mule = null
var crystite_quality: int = 0
var crystite_assayed: bool = false

func key() -> Vector2i:
	return Vector2i(col, row)

func is_store() -> bool:
	return terrain == Board.Terrain.STORE

func is_river() -> bool:
	return terrain == Board.Terrain.RIVER

func is_mountain() -> bool:
	return terrain == Board.Terrain.MOUNTAIN

func is_claimed() -> bool:
	return owner_id >= 0

func is_empty() -> bool:
	return not is_store() and not is_claimed() and mule == null

func has_mule() -> bool:
	return mule != null

func terrain_name() -> String:
	match terrain:
		Board.Terrain.RIVER:
			return "River"
		Board.Terrain.MOUNTAIN:
			return "Mountain x%d" % mountains
		Board.Terrain.STORE:
			return "Store"
		_:
			return "Plains"
