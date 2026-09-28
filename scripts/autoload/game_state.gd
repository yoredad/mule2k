extends Node

signal round_started(round_number: int)
signal game_started

const HUMAN_COLOR := Player.ColorId.GREEN

var rng := RandomNumberGenerator.new()
var board: Board
var players: Array[Player] = []
var round_number: int = 0
var prices: Dictionary = {}
var store_stock: Dictionary = {}
var wampus_plot: Plot = null
var wampus_active: bool = true
var round_event: int = -1
var pest_plot: Plot = null
var meteorite_strikes: int = 0

func _ready() -> void:
	new_game()

func new_game(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	board = Board.new(rng)
	players = []
	for i in range(4):
		var player := Player.new(i, i)
		player.is_human = (i == 0)
		players.append(player)
	round_number = 0
	prices = Economy.START_PRICE.duplicate()
	store_stock = {
		Economy.Unit.FOOD: Economy.START_STORE_STOCK,
		Economy.Unit.ENERGY: Economy.START_STORE_STOCK,
		Economy.Unit.SMITHORE: Economy.START_STORE_STOCK,
		Economy.Unit.CRYSTITE: Economy.START_STORE_STOCK,
		"mules": Economy.START_MULES,
	}
	var mountains := board.mountain_plots()
	wampus_plot = mountains[rng.randi_range(0, mountains.size() - 1)]
	wampus_active = true
	round_event = -1
	pest_plot = null
	meteorite_strikes = 0
	update_ranks()
	game_started.emit()

func update_ranks() -> void:
	var order := shuffled(players)
	order.sort_custom(func(a: Player, b: Player) -> bool: return a.score > b.score)
	for i in order.size():
		order[i].rank = i + 1

func shuffled(array: Array) -> Array:
	var result := array.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

func total_supply(unit: int) -> int:
	var total: int = store_stock.get(unit, 0)
	for player in players:
		total += player.inventory(unit)
	return total

func human() -> Player:
	return players[0]

func cpu_players() -> Array[Player]:
	return players.slice(1)

func mule_price() -> int:
	return Economy.mule_price(prices[Economy.Unit.SMITHORE])

func player_energy_req(player: Player) -> int:
	return Economy.energy_requirement(player.mules())

func player_food_req(player: Player) -> int:
	return Economy.food_requirement(round_number)

func store_price(unit: int) -> int:
	return prices[unit]
