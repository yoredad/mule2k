class_name AiController
extends RefCounted

enum Personality { NORMAL, HOMESTEADER, MINER, TRADER }

var player: Player
var personality := Personality.NORMAL

func _init(p_player: Player, p_personality: Personality = Personality.NORMAL) -> void:
	player = p_player
	personality = p_personality

# --- 10.1 Land grant ---------------------------------------------------------

func choose_land_grant(gs: GameState, rng: RandomNumberGenerator) -> Plot:
	var best: Plot = null
	var best_val := -1e18
	for plot in gs.board.unclaimed_plots():
		var v := _land_value(gs, plot, rng)
		if v > best_val:
			best_val = v
			best = plot
	return best

func _land_value(gs: GameState, plot: Plot, rng: RandomNumberGenerator) -> float:
	var val := -1e9
	for unit in [Economy.Unit.FOOD, Economy.Unit.ENERGY, Economy.Unit.SMITHORE]:
		var ebpc := Economy.ebpc(plot.terrain, plot.mountains, unit)
		if ebpc <= 0:
			continue
		var profit := float(gs.prices[unit]) * float(ebpc + _eco(gs, plot, unit)) \
			* Economy.growth_sum(13 - gs.round_number) \
			- float(gs.mule_price() + Economy.OUTFIT_COST[unit])
		profit += _shortage_bonus(gs, unit)
		val = maxf(val, profit)
	var dist := gs.board.distance_to_store(plot.col, plot.row)
	var noise := (rng.randf() * 2.0 - 1.0) * 0.15 * val
	return val - float(dist - 1) + noise

func _shortage_bonus(gs: GameState, unit: int) -> float:
	if unit == Economy.Unit.FOOD:
		var proj := projections(gs)
		return float(gs.prices[Economy.Unit.FOOD]) * 2.0 * maxf(0.0, -proj.food)
	if unit == Economy.Unit.ENERGY:
		var proj := projections(gs)
		return float(gs.prices[Economy.Unit.ENERGY]) * 2.0 * maxf(0.0, -proj.energy)
	if unit == Economy.Unit.SMITHORE and personality == Personality.MINER:
		return float(gs.prices[Economy.Unit.SMITHORE]) * 1.5
	return 0.0

# --- 10.2 Projections --------------------------------------------------------

func projections(gs: GameState, extra_unit: int = -1) -> Dictionary:
	var r := gs.round_number
	var e_req_extra := Economy.energy_requirement(player.mules())
	if extra_unit >= 0 and extra_unit != Economy.Unit.ENERGY:
		e_req_extra += 1
	var food_prod := _prod(gs, Economy.Unit.FOOD)
	var energy_prod := _prod(gs, Economy.Unit.ENERGY)
	var req_f_now := Economy.food_requirement(r)
	var req_f_next := Economy.food_requirement_next(r)
	var e_req_now := Economy.energy_requirement(player.mules())
	var proj_food := float(player.food - mini(player.food, req_f_now) + food_prod)
	proj_food = proj_food - floorf(proj_food / 2.0) - float(req_f_next)
	var proj_energy := float(player.energy - mini(player.energy, e_req_now) + energy_prod)
	proj_energy = proj_energy - floorf(proj_energy / 4.0) - float(e_req_extra)
	return {"food": proj_food, "energy": proj_energy, "energy_req": e_req_extra}

func _prod(gs: GameState, unit: int) -> int:
	var sum := 0
	for plot in player.plots:
		if plot.mule != null and plot.mule.unit == unit:
			var base := Economy.crystite_base(plot) if unit == Economy.Unit.CRYSTITE \
				else Economy.ebpc(plot.terrain, plot.mountains, unit)
			if base <= 0:
				base = Economy.tenure_base_bonus(plot, unit)
			if base <= 0:
				continue
			sum += base + Economy.eco_bonus(plot, unit, gs.board.neighbors(plot.col, plot.row)) \
				+ plot.mule.seniority_bonus()
	return int(floor(float(sum) * Economy.growth_multiplier(gs.round_number)))

# --- 10.3 / 10.7 Development -------------------------------------------------

func development_action(gs: GameState, rng: RandomNumberGenerator, wampus_tried: bool) -> Dictionary:
	if gs.wampus_active and not wampus_tried and rng.randf() < 0.4:
		return {"action": "wampus"}
	if _unassayed_plots().size() > 0 and rng.randf() < 0.35:
		return {"action": "assay", "plot": _assay_target(gs, rng)}
	# Energy shortage always wins; otherwise prioritize crystite on owned
	# high/medium plots, then smithore production.
	var proj_energy := projections(gs, Economy.Unit.ENERGY)
	if proj_energy.energy < proj_energy.energy_req:
		if gs.store_stock["mules"] > 0:
			var result := _buy_best(gs, Economy.Unit.ENERGY, rng)
			if result.get("action", "pass") == "buy":
				return result
		# No mules available to buy (store empty, no free plot, or short on
		# cash): swap an existing non-energy mule to energy instead.
		return _refit_to_energy()
	var crys := _buy_crystite(gs, rng)
	if crys.get("action", "pass") == "buy":
		return crys
	return _buy_best(gs, Economy.Unit.SMITHORE, rng)

func _buy_crystite(gs: GameState, rng: RandomNumberGenerator) -> Dictionary:
	# Only assayed medium-or-better plots (quality >= 2); hidden deposits stay
	# hidden so CPUs never cheat. River plots are excluded via crystite_base.
	var best: Plot = null
	var best_score := -1e18
	for plot in player.empty_plots():
		if not plot.crystite_assayed:
			continue
		var base := Economy.crystite_base(plot)
		if base < 2:
			continue
		var score := float(base + _eco_future(gs, plot, Economy.Unit.CRYSTITE)) \
			+ (rng.randf() * 2.0 - 1.0) * 0.1 \
			- float(gs.board.distance_to_store(plot.col, plot.row)) * 0.01
		if score > best_score:
			best_score = score
			best = plot
	if best == null:
		return {"action": "pass"}
	var cost: int = gs.mule_price() + Economy.OUTFIT_COST[Economy.Unit.CRYSTITE]
	if player.cash < cost:
		return {"action": "pass"}
	return {"action": "buy", "plot": best, "unit": Economy.Unit.CRYSTITE}

func _refit_to_energy() -> Dictionary:
	# Convert the least productive non-energy mule to energy. Energy mules
	# can work any terrain, so every non-energy mule is a candidate.
	var best: Plot = null
	var best_base := 1e18
	for plot in player.plots:
		if plot.mule == null or plot.mule.unit == Economy.Unit.ENERGY:
			continue
		var base := float(Economy.crystite_base(plot)) if plot.mule.unit == Economy.Unit.CRYSTITE \
			else float(Economy.ebpc(plot.terrain, plot.mountains, plot.mule.unit))
		if base < best_base:
			best_base = base
			best = plot
	if best == null:
		return {"action": "pass"}
	if player.cash < Economy.OUTFIT_COST[Economy.Unit.ENERGY]:
		return {"action": "pass"}
	return {"action": "refit", "plot": best, "unit": Economy.Unit.ENERGY}

func _buy_best(gs: GameState, unit: int, rng: RandomNumberGenerator) -> Dictionary:
	var best: Plot = null
	var best_score := -1e18
	for plot in player.empty_plots():
		var ebpc := Economy.crystite_base(plot) if unit == Economy.Unit.CRYSTITE \
			else Economy.ebpc(plot.terrain, plot.mountains, unit)
		if ebpc <= 0:
			continue
		var score := float(ebpc + _eco_future(gs, plot, unit)) + (rng.randf() * 2.0 - 1.0) * 0.1 \
			- float(gs.board.distance_to_store(plot.col, plot.row)) * 0.01
		if score > best_score:
			best_score = score
			best = plot
	if best == null:
		return {"action": "pass"}
	var cost: int = gs.mule_price() + Economy.OUTFIT_COST[unit]
	if player.cash < cost:
		return {"action": "pass"}
	return {"action": "buy", "plot": best, "unit": unit}

func _eco(gs: GameState, plot: Plot, unit: int) -> int:
	var count := 0
	for n in gs.board.neighbors(plot.col, plot.row):
		if n.owner_id == player.id and n.mule != null and n.mule.unit == unit:
			count += 1
	return mini(count, 2)

func _eco_future(gs: GameState, plot: Plot, unit: int) -> int:
	return _eco(gs, plot, unit)

func _unassayed_plots() -> Array:
	return player.plots.filter(func(p): return not p.crystite_assayed)

func _assay_target(gs: GameState, rng: RandomNumberGenerator) -> Plot:
	var unassayed := _unassayed_plots()
	for u in unassayed:
		for n in gs.board.neighbors(u.col, u.row):
			if n.owner_id == player.id and n.crystite_assayed and n.crystite_quality >= 2:
				return u
	return unassayed[rng.randi_range(0, unassayed.size() - 1)]

# --- 10.4 / 10.6 Auctions ----------------------------------------------------

func auction_step(gs: GameState, unit: int) -> Dictionary:
	var price: int = gs.prices[unit]
	var buy_p := Economy.store_buy_price(unit, price)
	var sell_p := Economy.store_sell_price(unit, price)
	var owned := player.inventory(unit)
	if unit == Economy.Unit.SMITHORE and gs.store_stock.get("mules", 0) <= 0 and owned > 0:
		# Mule shortage: dump the whole stock to the store so it can build mules.
		player.cash += owned * buy_p
		gs.store_stock[unit] += owned
		player.take_units(unit, owned)
		return {}
	var req := _auction_req(gs, unit)
	var keep := _auction_keep(gs, unit)
	var deficit := maxi(0, req - owned)
	var surplus := maxi(0, owned - keep)
	if deficit > 0:
		var n := mini(deficit, gs.store_stock.get(unit, 0))
		n = mini(n, floori(player.cash / sell_p))
		if n > 0:
			player.cash -= n * sell_p
			gs.store_stock[unit] -= n
			player.add_units(unit, n)
		return {}
	if surplus > 0:
		var min_sell := _auction_min_sell(unit)
		if buy_p >= min_sell or (personality == Personality.TRADER and buy_p >= min_sell - 5):
			player.cash += surplus * buy_p
			gs.store_stock[unit] += surplus
			player.take_units(unit, surplus)
			return {}
		if gs.store_stock.get(unit, 0) == 0:
			var markup := _auction_list_markup(unit)
			if personality == Personality.TRADER:
				markup += 4
			var qty := mini(surplus, 2)
			return {"unit": unit, "from_id": player.id, "qty": qty, "price": buy_p + markup, "kind": "sell"}
	return {}

func _auction_req(gs: GameState, unit: int) -> int:
	match unit:
		Economy.Unit.FOOD:
			return Economy.food_requirement_next(gs.round_number)
		Economy.Unit.ENERGY:
			return Economy.energy_requirement(player.mules())
	return 0

func _auction_keep(gs: GameState, unit: int) -> int:
	var req := _auction_req(gs, unit)
	match unit:
		Economy.Unit.FOOD:
			return req + 2
		Economy.Unit.ENERGY:
			return req + 1
	return 8

func _auction_min_sell(unit: int) -> int:
	match unit:
		Economy.Unit.FOOD:
			return 35
		Economy.Unit.ENERGY:
			return 30
		Economy.Unit.SMITHORE:
			return 55
	return 150

func _auction_list_markup(unit: int) -> int:
	if unit == Economy.Unit.SMITHORE or unit == Economy.Unit.CRYSTITE:
		return 20
	return 10
