class_name Economy
extends RefCounted

enum Unit { FOOD, ENERGY, SMITHORE, CRYSTITE }
enum Event { PIRATES, SUNSPOTS, ACID_RAIN, PEST, METEORITE, FIRE_IN_STORE, PLANETQUAKE, RADIATION }

const UNIT_NAMES: Array[String] = ["Food", "Energy", "Smithore", "Crystite"]
const UNIT_LETTERS: Array[String] = ["F", "E", "S", "C"]
const OUTFIT_COST: Dictionary = {Unit.FOOD: 25, Unit.ENERGY: 50, Unit.SMITHORE: 75, Unit.CRYSTITE: 100}
const MIN_PRICE: Dictionary = {Unit.FOOD: 30, Unit.ENERGY: 25, Unit.SMITHORE: 50, Unit.CRYSTITE: 150}
const MAX_PRICE: Dictionary = {Unit.FOOD: 265, Unit.ENERGY: 265, Unit.SMITHORE: 265, Unit.CRYSTITE: 500}
const STORE_BUY_OFFSET: Dictionary = {Unit.FOOD: -15, Unit.ENERGY: -15, Unit.SMITHORE: 0, Unit.CRYSTITE: 0}
const STORE_SELL_SPREAD: int = 35
const GROWTH_PER_ROUND: float = 0.08
const MAX_ROUNDS: int = 12
const SMITHORE_STORAGE_CAP: int = 50
const CRYSTITE_STORAGE_CAP: int = 50
const CRYSTITE_DEMAND: int = 8
const CRYSTITE_BASE_PRICE: int = 200
const COLONY_TARGET: int = 60000
const COLONY_RATING_DENOM: int = 20000
const COLONY_RATING_OFFSET: int = 10000
const MAX_PER_PLOT: int = 8
const STORE_MULE_CAP: int = 14
const START_MULES: int = 14
const START_STORE_STOCK: int = 20
const START_PRICE: Dictionary = {Unit.FOOD: 30, Unit.ENERGY: 25, Unit.SMITHORE: 50, Unit.CRYSTITE: 150}
const START_MULE_PRICE: int = 100
const CHARITY_THRESHOLD: int = 100
const CHARITY_AMOUNT: int = 200

# --- Base production (EBPC) -------------------------------------------------

static func ebpc(terrain: int, mountains: int, unit: int) -> int:
	match terrain:
		Board.Terrain.PLAINS:
			match unit:
				Unit.FOOD:
					return 2
				Unit.ENERGY:
					return 3
				Unit.SMITHORE:
					return 1
		Board.Terrain.RIVER:
			match unit:
				Unit.FOOD:
					return 4
				Unit.ENERGY:
					return 2
				Unit.SMITHORE:
					return 0
		Board.Terrain.MOUNTAIN:
			match unit:
				Unit.FOOD:
					return 1
				Unit.ENERGY:
					return 1
				Unit.SMITHORE:
					return 1 + mountains
	return 0

# --- Time scaling ------------------------------------------------------------

static func growth_multiplier(round_number: int) -> float:
	return 1.0 + GROWTH_PER_ROUND * float(maxi(round_number, 1) - 1)

static func growth_sum(n: int) -> float:
	var nn := maxi(n, 0)
	return float(nn) + 0.04 * float(nn) * float(nn - 1)

# --- Requirements ------------------------------------------------------------

static func food_requirement(round_number: int) -> int:
	if round_number <= 0:
		return 3
	if round_number <= 4:
		return 3
	if round_number <= 8:
		return 4
	return 5

static func food_requirement_next(round_number: int) -> int:
	if round_number >= MAX_ROUNDS:
		return 0
	return food_requirement(round_number + 1)

static func energy_requirement(mules: Array) -> int:
	var count := 0
	for mule in mules:
		if mule.unit != Unit.ENERGY:
			count += 1
	return count

static func dev_actions(food: int, food_req: int) -> int:
	if food_req <= 0:
		return 6
	return maxi(2, 1 + int(5.0 * clampf(float(food) / float(food_req), 0.0, 1.0)))

# --- Production --------------------------------------------------------------

static func crystite_base(plot: Plot) -> int:
	if plot.is_river():
		return 0
	return clampi(plot.crystite_quality, 0, 4)

static func tenure_base_bonus(plot: Plot, unit: int) -> int:
	# A mule deployed 2+ rounds coaxes base 1 out of quality-0 plots.
	# Terrain bans (river mining) still yield 0. Refit/new mules reset
	# tenure to 0, dropping the base back to 0.
	if unit != Unit.CRYSTITE or plot.is_river():
		return 0
	if plot.mule == null or plot.mule.unit != unit:
		return 0
	return 1 if plot.mule.turns_deployed >= 2 else 0

static func eco_bonus(plot: Plot, unit: int, neighbors: Array) -> int:
	var count := 0
	for n in neighbors:
		if n.is_claimed() and n.owner_id == plot.owner_id and n.mule != null and n.mule.unit == unit:
			count += 1
	return mini(count, 2)

static func per_plot_output(plot: Plot, unit: int, neighbors: Array, variance: int = 0) -> int:
	var base := crystite_base(plot) if unit == Unit.CRYSTITE else ebpc(plot.terrain, plot.mountains, unit)
	if base <= 0:
		base = tenure_base_bonus(plot, unit)
		if base <= 0:
			return 0
	var seniority := 0
	if plot.mule != null and plot.mule.unit == unit:
		seniority = plot.mule.seniority_bonus()
	return clampi(base + eco_bonus(plot, unit, neighbors) + variance + seniority, 0, MAX_PER_PLOT)

static func player_total(per_plot_outputs: Array, round_number: int) -> int:
	var sum := 0
	for output in per_plot_outputs:
		sum += output
	return int(floor(float(sum) * growth_multiplier(round_number)))

# --- Spoilage ----------------------------------------------------------------

static func spoilage_food(units: int) -> int:
	return floori(float(units) / 2.0)

static func spoilage_energy(units: int) -> int:
	return floori(float(units) * 3.0 / 4.0)

static func smithore_after_cap(units: int) -> int:
	return mini(units, SMITHORE_STORAGE_CAP)

static func crystite_after_cap(units: int) -> int:
	return mini(units, CRYSTITE_STORAGE_CAP)

# --- Store prices ------------------------------------------------------------

static func store_buy_price(unit: int, price: int) -> int:
	return maxi(price + STORE_BUY_OFFSET[unit], 0)

static func store_sell_price(unit: int, price: int) -> int:
	return store_buy_price(unit, price) + STORE_SELL_SPREAD

static func mule_price(smithore_price: int) -> int:
	return floori(float(2 * smithore_price) / 10.0) * 10

static func price_ratio(supply: int, demand: int) -> float:
	if demand <= 0:
		return 0.25
	if supply <= 0:
		return 3.0
	return clampf(float(demand) / float(supply), 0.25, 3.0)

static func smithore_noise(rng: RandomNumberGenerator) -> int:
	return (rng.randi_range(-1, 1) + rng.randi_range(-1, 1)) * 7

static func new_price(unit: int, price: int, supply: int, demand: int, rng: RandomNumberGenerator) -> int:
	var ratio := price_ratio(supply, demand)
	var result := roundi(float(price) * (0.25 + 0.75 * ratio))
	if unit == Unit.SMITHORE:
		result += smithore_noise(rng)
	return clampi(result, MIN_PRICE[unit], MAX_PRICE[unit])

static func mule_req(unclaimed_plots_left: int, plots_without_mule: int) -> int:
	return mini(8, mini(4, unclaimed_plots_left) + plots_without_mule)

# --- Scoring -----------------------------------------------------------------

static func plot_score(plot: Plot) -> int:
	return 500 + (plot.mule.outfit_cost() if plot.mule != null else 0)

static func score(cash: int, plot_value: int, mules: int, food: int, energy: int, smithore: int, crystite: int, prices: Dictionary) -> int:
	return cash + plot_value + mules * 35 \
		+ food * prices[Unit.FOOD] \
		+ energy * prices[Unit.ENERGY] \
		+ smithore * prices[Unit.SMITHORE] \
		+ crystite * prices[Unit.CRYSTITE]

static func colony_rating(colony_total: int) -> int:
	return clampi(roundi(float(colony_total - COLONY_RATING_OFFSET) / float(COLONY_RATING_DENOM)), 0, 6)

static func colony_success(colony_total: int) -> bool:
	return colony_total >= COLONY_TARGET

# --- Events ------------------------------------------------------------------

# Empirical frequencies recorded by SMITHORE.COM across 1,093 real M.U.L.E. tournaments
# (11,778 events, rounds 1-11 only). Source: http://www.smithore.com/eventstats.php
const EVENT_NAMES: Array[String] = [
	"Pirate Attack", "Sunspot Activity", "Acid Rain Storm", "Pest Attack",
	"Meteorite Strike", "Fire in Store", "Planetquake", "Radiation",
]
const EVENT_FREQUENCIES: Dictionary = {
	Event.PIRATES: 1149, Event.SUNSPOTS: 1754, Event.ACID_RAIN: 1828, Event.PEST: 1672,
	Event.METEORITE: 1208, Event.FIRE_IN_STORE: 1243, Event.PLANETQUAKE: 1745, Event.RADIATION: 1179,
}
const EVENT_ICON_PATHS: Dictionary = {
	Event.PIRATES: "res://assets/events/pirates/sprite_frames.tres",
	Event.SUNSPOTS: "res://assets/events/sunspots/sprite_frames.tres",
	Event.ACID_RAIN: "res://assets/events/acidrain/sprite_frames.tres",
	Event.PEST: "res://assets/events/pest/sprite_frames.tres",
	Event.METEORITE: "res://assets/events/meteorite/sprite_frames.tres",
	Event.FIRE_IN_STORE: "res://assets/events/fireinstore/sprite_frames.tres",
	Event.PLANETQUAKE: "res://assets/events/quake/sprite_frames.tres",
	Event.RADIATION: "res://assets/events/radiation/sprite_frames.tres",
}

static func event_total() -> int:
	var total := 0
	for event in Event.values():
		total += EVENT_FREQUENCIES[event]
	return total

static func event_weight(event: int) -> float:
	return float(EVENT_FREQUENCIES[event]) / float(event_total())

static func roll_event(rng: RandomNumberGenerator) -> int:
	var roll := rng.randi_range(1, event_total())
	var acc := 0
	for event in Event.values():
		acc += EVENT_FREQUENCIES[event]
		if roll <= acc:
			return event
	return Event.RADIATION

static func events_active(round_number: int) -> bool:
	return round_number >= 1 and round_number < MAX_ROUNDS

# --- Land give/lose events ---------------------------------------------------
# smithore.com "When does a Player receive or lose a Plot of Land" (Atari & C64):
# per-month (round 1-12) DISTRIBUTION of occurrences, as % of that event's total.
# Receive: 438 total, Lose: 732 total (over 1,093 tournaments). Land events CAN occur in round 12.
const LAND_RECEIVE_FREQUENCIES: Array[float] = [
	7.5, 10.5, 8.4, 9.6, 10.5, 13.0, 13.2, 15.1, 8.2, 1.4, 1.4, 1.1,
]
const LAND_LOSE_FREQUENCIES: Array[float] = [
	0.1, 9.0, 9.7, 11.1, 8.3, 9.6, 7.5, 9.0, 10.1, 8.9, 10.4, 6.3,
]
const LAND_RECEIVE_FREQUENCY_SUM := 99.9
const LAND_LOSE_FREQUENCY_SUM := 100.0
const LAND_RECEIVE_TOTAL := 438
const LAND_LOSE_TOTAL := 732
const LAND_TOURNAMENTS := 1093
const LAND_PLAYERS := 4

# Land events are checked at the START OF EACH PLAYER'S TURN (not at the end of the round).
# Per-turn chance = normalized month distribution / LAND_PLAYERS turns * (event total / tournaments),
# so a full 12-round game expects exactly RECEIVE_TOTAL/LAND_TOURNAMENTS receives and
# LOSE_TOTAL/LAND_TOURNAMENTS loses, matching the observed smithore.com rates.
static func land_receive_probability(round_number: int) -> float:
	return _land_probability(round_number, LAND_RECEIVE_FREQUENCIES, LAND_RECEIVE_FREQUENCY_SUM, LAND_RECEIVE_TOTAL)

static func land_lose_probability(round_number: int) -> float:
	return _land_probability(round_number, LAND_LOSE_FREQUENCIES, LAND_LOSE_FREQUENCY_SUM, LAND_LOSE_TOTAL)

static func _land_probability(round_number: int, frequencies: Array[float], sum: float, total: int) -> float:
	if round_number < 1 or round_number > frequencies.size():
		return 0.0
	return frequencies[round_number - 1] / sum / float(LAND_PLAYERS) \
		* float(total) / float(LAND_TOURNAMENTS)

static func event_money_multiplier(round_number: int) -> int:
	return 25 * (round_number / 4 + 1)

static func wampus_reward(round_number: int) -> int:
	if round_number <= 3:
		return 100
	if round_number <= 7:
		return 200
	if round_number <= 11:
		return 300
	return 400

static func gambling_grant(round_number: int) -> int:
	return ceili(75.0 * (float(round_number) / 2.0 + 1.0))
