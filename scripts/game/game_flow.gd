extends Node

const AiControllerScript = preload("res://scripts/game/ai_controller.gd")
const EventsScript = preload("res://scripts/game/events.gd")

enum Phase { MENU, LAND_GRANT, DEVELOPMENT, PRODUCTION, CONSUMPTION, PRICES, AUCTION, REPLENISH, SUMMARY, GAME_OVER }

const PHASE_NAMES: Array[String] = [
	"Menu", "Land Grant", "Development", "Production", "Consumption",
	"Prices", "Auctions", "Replenish", "Summary", "Game Over",
]
const AUCTION_ORDER: Array[int] = [
	Economy.Unit.SMITHORE, Economy.Unit.FOOD, Economy.Unit.ENERGY, Economy.Unit.CRYSTITE,
]
const MAX_LIST_PRICE := 999
const HIGHLIGHT_CLAIM := Color(1.0, 1.0, 1.0, 0.25)
const HIGHLIGHT_PLACE := Color(0.4, 1.0, 0.4, 0.35)
const HIGHLIGHT_ASSAY := Color(1.0, 0.9, 0.3, 0.35)
const OUTLINE_LATE_GRANT := Color.WHITE
const LATE_GRANT_OUTLINE_ROUND := 9

signal phase_changed(phase: int)
signal state_changed
signal banner_shown(text: String, icon_path: String)
signal human_turn_started(player: Player)
signal highlights_requested(cells: Array, color: Color)
signal clear_highlights_requested
signal outlines_requested(cells: Array, color: Color)
signal clear_outlines_requested
signal summary_ready(rows: Array)
signal auction_updated(unit: int)
signal assay_result(quality: int)
signal assay_revealed(player_name: String, col: int, row: int, quality: int)
signal game_finished(results: Dictionary)
signal production_ready(results: Dictionary)
signal plot_auction_started(plot: Plot, bids: Dictionary)
signal plot_auction_updated(bids: Dictionary)
signal plot_auction_ended(winner: Player, amount: int)

var gs: GameState

var simulate := false
var phase := Phase.MENU
var last_results: Dictionary = {}
var production_results: Dictionary = {}

var grant_order: Array = []
var grant_index := 0
var plot_auction_plot: Plot = null
var plot_auction_bids: Dictionary = {}
var plot_auction_round := 0
var dev_order: Array = []
var turn_index := 0
var dev_player: Player
var actions_left := 0
var wampus_attempts := 0
var wampus_attempted := false
var pending_unit := -1
var pending_assay := false
var pending_refit := false
var auction_index := 0
var auction_unit := -1
var cpu_offers: Array = []
var human_offer: Dictionary = {}
var human_sales: Array = []
var last_dev_message := ""
var _ais: Dictionary = {}
var land_events_processed_this_turn := false

func _ready() -> void:
	gs = get_node("/root/GameState")

# --- Game lifecycle ----------------------------------------------------------

func start_game(seed_value: int = 0) -> void:
	gs.new_game(seed_value)
	_ais.clear()
	last_results = {}
	production_results = {}
	last_dev_message = ""
	_next_round()

func _next_round() -> void:
	gs.round_number += 1
	gs.update_ranks()
	_emit_banner("Round %d" % gs.round_number, "")
	if gs.round_number < Economy.MAX_ROUNDS:
		_begin_land_grant()
	else:
		_begin_development_phase()

# --- Land grant --------------------------------------------------------------

func _begin_land_grant() -> void:
	_set_phase(Phase.LAND_GRANT)
	grant_order = _grant_order()
	grant_index = 0
	_advance_grant()

func _grant_order() -> Array:
	var order := gs.shuffled(gs.players)
	order.sort_custom(func(a: Player, b: Player) -> bool:
		return a.net_worth(gs.prices) < b.net_worth(gs.prices))
	return order

func _advance_grant() -> void:
	if phase != Phase.LAND_GRANT:
		return
	if grant_index >= grant_order.size():
		_end_land_grant()
		return
	var p: Player = grant_order[grant_index]
	_refresh_grant_outlines()
	if p.is_human and not simulate:
		if gs.board.unclaimed_plots().is_empty():
			grant_index += 1
			state_changed.emit()
			_advance_grant()
			return
		highlights_requested.emit(gs.board.unclaimed_plots().map(func(x): return x.key()), HIGHLIGHT_CLAIM)
		_emit_banner("%s: tap a highlighted plot" % p.display_name(), "")
		return
	_cpu_grant(p)

func _cpu_grant(p: Player) -> void:
	var plot: Plot = _ai_for(p).choose_land_grant(gs, gs.rng)
	if plot != null:
		_claim_plot_for(p, plot)
	grant_index += 1
	if simulate:
		_advance_grant()
	else:
		await get_tree().create_timer(0.8).timeout
		_advance_grant()

func claim_plot(col: int, row: int) -> bool:
	if phase != Phase.LAND_GRANT or simulate:
		return false
	if grant_index >= grant_order.size():
		return false
	var p: Player = grant_order[grant_index]
	if not p.is_human:
		return false
	var plot := gs.board.get_plot(col, row)
	if plot == null or plot.is_claimed() or plot.is_store():
		return false
	_claim_plot_for(p, plot)
	grant_index += 1
	clear_highlights_requested.emit()
	_refresh_grant_outlines()
	# 75% chance of plot auction after selection
	if gs.rng.randf() < 0.75:
		_start_plot_auction()
	else:
		_advance_grant()
	return true

func _claim_plot_for(p: Player, plot: Plot) -> void:
	plot.owner_id = p.id
	p.plots.append(plot)
	state_changed.emit()

func _end_land_grant() -> void:
	if phase != Phase.LAND_GRANT:
		return
	clear_outlines_requested.emit()
	_begin_development_phase()

# Late rounds (9+): outline every available plot in white, auction style, so the
# remaining picks are easy to spot. Refreshed after each pick, cleared above.
func _refresh_grant_outlines() -> void:
	if gs.round_number >= LATE_GRANT_OUTLINE_ROUND:
		outlines_requested.emit(
			gs.board.unclaimed_plots().map(func(x): return x.key()), OUTLINE_LATE_GRANT)

# --- Plot Auction ------------------------------------------------------------

func _start_plot_auction() -> void:
	var unclaimed := gs.board.unclaimed_plots()
	if unclaimed.is_empty():
		_advance_grant()
		return
	plot_auction_plot = unclaimed[gs.rng.randi_range(0, unclaimed.size() - 1)]
	plot_auction_bids = {}
	plot_auction_round = 0
	for player in gs.players:
		plot_auction_bids[player.id] = 0
	_emit_banner("Plot Auction for (%d,%d)!" % [plot_auction_plot.col, plot_auction_plot.row], "")
	plot_auction_started.emit(plot_auction_plot, plot_auction_bids)
	_process_plot_auction_round()

func _process_plot_auction_round() -> void:
	plot_auction_round += 1
	# Get CPU bids
	for player in gs.players:
		if not player.is_human:
			var bid := _cpu_plot_bid(player)
			plot_auction_bids[player.id] = bid
	# Emit updated bids (human will bid via UI)
	plot_auction_updated.emit(plot_auction_bids)

func _cpu_plot_bid(player: Player) -> int:
	var current_high := 0
	var current_high_bidder: Player = null
	for p in gs.players:
		var bid: int = plot_auction_bids.get(p.id, 0)
		if bid > current_high:
			current_high = bid
			current_high_bidder = p
	# Don't bid against yourself
	if current_high_bidder == player:
		return current_high
	# Simple AI: bid up to 50% of cash, stop if high bid exceeds 30% of cash
	if current_high > player.cash * 0.3:
		return 0
	var max_bid := int(player.cash * 0.5)
	if current_high >= max_bid:
		return 0
	# Bid 10-20% more than current high
	var increment := maxi(10, int(current_high * 0.15))
	return mini(current_high + increment, max_bid)

func plot_auction_bid(amount: int) -> void:
	if plot_auction_plot == null:
		return
	var human := gs.human()
	# If amount is 0 (pass), don't reduce existing positive bid
	if amount == 0 and plot_auction_bids.get(human.id, 0) > 0:
		# Human is passing - keep their current bid
		_check_plot_auction_winner()
		return
	# Validate bid amount
	if amount < 0:
		amount = 0
	if amount > human.cash:
		amount = human.cash
	plot_auction_bids[human.id] = amount
	# Emit updated bids so human sees their bid immediately
	plot_auction_updated.emit(plot_auction_bids)
	_check_plot_auction_winner()

func _check_plot_auction_winner() -> void:
	var high_bid := 0
	var high_bidder: Player = null
	for player in gs.players:
		var bid: int = plot_auction_bids.get(player.id, 0)
		if bid > high_bid:
			high_bid = bid
			high_bidder = player
	# Check if anyone else wants to bid higher
	var has_new_bid := false
	for player in gs.players:
		if player != high_bidder and not player.is_human:
			var new_bid := _cpu_plot_bid(player)
			if new_bid > high_bid:
				has_new_bid = true
				break
	if has_new_bid:
		# Continue auction
		if not simulate:
			await get_tree().create_timer(1.0).timeout
		_process_plot_auction_round()
	else:
		# Auction complete
		_end_plot_auction(high_bidder, high_bid)

func _end_plot_auction(winner: Player, amount: int) -> void:
	if winner != null and amount > 0 and winner.cash >= amount:
		winner.cash -= amount
		plot_auction_plot.owner_id = winner.id
		winner.plots.append(plot_auction_plot)
		_emit_banner("%s wins auction for $%d!" % [winner.display_name(), amount], "")
	else:
		_emit_banner("No winner - auction cancelled", "")
	plot_auction_ended.emit(winner, amount)
	plot_auction_plot = null
	plot_auction_bids = {}
	state_changed.emit()
	if not simulate:
		await get_tree().create_timer(1.5).timeout
	_advance_grant()

# --- Development -------------------------------------------------------------

func _dev_order() -> Array:
	var order := gs.shuffled(gs.players)
	order.sort_custom(func(a: Player, b: Player) -> bool:
		return a.net_worth(gs.prices) > b.net_worth(gs.prices))
	if gs.store_stock["mules"] <= 7:
		order.reverse()
	return order

func _begin_development_phase() -> void:
	_set_phase(Phase.DEVELOPMENT)
	dev_order = _dev_order()
	turn_index = 0
	_advance_dev()

func _advance_dev() -> void:
	if phase != Phase.DEVELOPMENT:
		return
	if turn_index >= dev_order.size():
		_end_development_phase()
		return
	dev_player = dev_order[turn_index]
	last_dev_message = ""
	land_events_processed_this_turn = false
	_check_charity(dev_player)
	if not gs.wampus_active:
		var mountains: Array = gs.board.mountain_plots()
		gs.wampus_plot = mountains[gs.rng.randi_range(0, mountains.size() - 1)]
		gs.wampus_active = true
	_check_land_events()
	_check_player_event(dev_player)
	actions_left = Economy.dev_actions(dev_player.food, gs.player_food_req(dev_player))
	wampus_attempts = 0
	wampus_attempted = false
	pending_unit = -1
	pending_assay = false
	if dev_player.is_human and not simulate:
		human_turn_started.emit(dev_player)
		return
	_cpu_development()

func _cpu_development() -> void:
	var turn_player: Player = dev_player
	while actions_left > 0:
		if dev_player != turn_player or phase != Phase.DEVELOPMENT:
			return
		var decision: Dictionary = _ai_for(dev_player).development_action(gs, gs.rng, wampus_attempted)
		var was_assay := false
		match decision.get("action", "pass"):
			"wampus":
				wampus_attempted = true
				_attempt_wampus(dev_player)
			"assay":
				was_assay = true
				_do_assay(dev_player, decision.get("plot"), true)
			"buy":
				if not _do_buy(dev_player, decision.get("plot"), decision.get("unit", -1)):
					actions_left = 0
			"refit":
				if not _do_refit(dev_player, decision.get("plot"), decision.get("unit", -1)):
					actions_left = 0
			_:
				actions_left = 0
		if not simulate:
			# Longer pause after assay so player can see the result
			if was_assay:
				await get_tree().create_timer(3.0).timeout
			else:
				await get_tree().create_timer(1.0).timeout
	if phase == Phase.DEVELOPMENT and dev_player == turn_player:
		_end_player_turn()

func _end_player_turn() -> void:
	if phase != Phase.DEVELOPMENT or turn_index >= dev_order.size():
		return
	# Award bonus cash: 100 per remaining action
	var bonus := actions_left * 100
	if bonus > 0:
		dev_player.cash += bonus
		var msg := "%s won $%d gambling!" % [dev_player.display_name(), bonus]
		_emit_banner(msg, "")
	clear_highlights_requested.emit()
	turn_index += 1
	state_changed.emit()
	_advance_dev()

func dev_start_buy(unit: int) -> bool:
	var p := gs.human()
	if phase != Phase.DEVELOPMENT or dev_player != p or actions_left <= 0:
		last_dev_message = "No actions left."
		state_changed.emit()
		return false
	if gs.store_stock["mules"] <= 0:
		last_dev_message = "No mules in store!"
		state_changed.emit()
		return false
	if p.cash < gs.mule_price() + Economy.OUTFIT_COST[unit]:
		last_dev_message = "Not enough cash ($%d needed)." % (gs.mule_price() + Economy.OUTFIT_COST[unit])
		state_changed.emit()
		return false
	if p.empty_plots().size() == 0:
		last_dev_message = "No empty plots available."
		state_changed.emit()
		return false
	pending_unit = unit
	pending_assay = false
	highlights_requested.emit(p.empty_plots().map(func(x): return x.key()), HIGHLIGHT_PLACE)
	last_dev_message = "Tap an empty plot of yours."
	state_changed.emit()
	return true

func dev_place_mule(col: int, row: int) -> bool:
	var p := gs.human()
	if pending_unit < 0 or phase != Phase.DEVELOPMENT or dev_player != p:
		return false
	var plot := gs.board.get_plot(col, row)
	if plot == null or plot.owner_id != p.id or plot.mule != null:
		return false
	return _do_buy(p, plot, pending_unit)

func _do_buy(p: Player, plot: Plot, unit: int) -> bool:
	if plot == null or unit < 0 or plot.owner_id != p.id or plot.mule != null or actions_left <= 0:
		return false
	var cost: int = gs.mule_price() + Economy.OUTFIT_COST[unit]
	if p.cash < cost or gs.store_stock["mules"] <= 0:
		last_dev_message = "Cannot afford."
		return false
	p.cash -= cost
	gs.store_stock["mules"] -= 1
	plot.mule = Mule.new(unit)
	actions_left -= 1
	pending_unit = -1
	clear_highlights_requested.emit()
	AudioManager.play_purchase()
	_emit_banner("%s buys a %s mule" % [p.display_name(), Economy.UNIT_NAMES[unit]], "")
	state_changed.emit()
	return true

func dev_start_assay() -> bool:
	var p := gs.human()
	if phase != Phase.DEVELOPMENT or dev_player != p or actions_left <= 0:
		last_dev_message = "No actions left."
		state_changed.emit()
		return false
	var unassayed: Array = gs.board.plots.filter(func(x): return not x.crystite_assayed and x.terrain != Board.Terrain.STORE)
	if unassayed.size() == 0:
		last_dev_message = "All plots are assayed."
		state_changed.emit()
		return false
	pending_assay = true
	pending_unit = -1
	highlights_requested.emit(unassayed.map(func(x): return x.key()), HIGHLIGHT_ASSAY)
	last_dev_message = "Tap any plot to assay."
	state_changed.emit()
	return true

func dev_assay(col: int, row: int) -> bool:
	var p := gs.human()
	if not pending_assay or phase != Phase.DEVELOPMENT or dev_player != p:
		return false
	var plot := gs.board.get_plot(col, row)
	if plot == null or plot.terrain == Board.Terrain.STORE or plot.crystite_assayed:
		return false
	_do_assay(p, plot, false)
	pending_assay = false
	clear_highlights_requested.emit()
	return true

func _do_assay(p: Player, plot: Plot, silent: bool) -> bool:
	if plot == null or plot.terrain == Board.Terrain.STORE or plot.crystite_assayed or actions_left <= 0:
		return false
	actions_left -= 1
	plot.crystite_assayed = true
	last_dev_message = ""
	_emit_banner("%s assays %s: %s" % [p.display_name(), plot.terrain_name(), quality_name(plot.crystite_quality)], "")
	if silent:
		assay_revealed.emit(p.display_name(), plot.col, plot.row, plot.crystite_quality)
	else:
		assay_result.emit(plot.crystite_quality)
	AudioManager.play_purchase()
	state_changed.emit()
	return true

func dev_wampus() -> bool:
	var p := gs.human()
	if phase != Phase.DEVELOPMENT or dev_player != p:
		return false
	return _attempt_wampus(p)

func dev_gamble() -> bool:
	var p := gs.human()
	if phase != Phase.DEVELOPMENT or dev_player != p or actions_left <= 0:
		last_dev_message = "No actions left."
		state_changed.emit()
		return false
	if pending_unit >= 0 or pending_assay or pending_refit:
		pending_unit = -1
		pending_assay = false
		pending_refit = false
		clear_highlights_requested.emit()
	actions_left -= 1
	var grant := Economy.gambling_grant(gs.round_number)
	p.cash += grant
	_emit_banner("%s gambles +$%d!" % [p.display_name(), grant], "")
	AudioManager.play_purchase()
	_end_player_turn()
	return true

func dev_start_refit(unit: int) -> bool:
	var p := gs.human()
	if phase != Phase.DEVELOPMENT or dev_player != p or actions_left < 2:
		last_dev_message = "Need 2 actions to refit."
		state_changed.emit()
		return false
	var mule_plots := p.plots.filter(func(x): return x.mule != null and x.terrain != Board.Terrain.STORE)
	if mule_plots.is_empty():
		last_dev_message = "No mules to refit!"
		state_changed.emit()
		return false
	if p.cash < Economy.OUTFIT_COST[unit]:
		last_dev_message = "Not enough cash ($%d needed)." % Economy.OUTFIT_COST[unit]
		state_changed.emit()
		return false
	pending_refit = true
	pending_unit = unit
	pending_assay = false
	highlights_requested.emit(mule_plots.map(func(x): return x.key()), HIGHLIGHT_PLACE)
	last_dev_message = "Tap a plot with a mule to refit."
	state_changed.emit()
	return true

func dev_refit_mule(col: int, row: int) -> bool:
	var p := gs.human()
	if not pending_refit or pending_unit < 0 or phase != Phase.DEVELOPMENT or dev_player != p:
		return false
	var plot := gs.board.get_plot(col, row)
	if plot == null or plot.owner_id != p.id or plot.mule == null:
		return false
	return _do_refit(p, plot, pending_unit)

func _do_refit(p: Player, plot: Plot, unit: int) -> bool:
	if plot == null or unit < 0 or plot.owner_id != p.id or plot.mule == null or actions_left < 2:
		return false
	var cost: int = Economy.OUTFIT_COST[unit]
	if p.cash < cost:
		last_dev_message = "Cannot afford."
		return false
	p.cash -= cost
	plot.mule.unit = unit
	plot.mule.turns_deployed = 0
	actions_left -= 2
	pending_refit = false
	pending_unit = -1
	clear_highlights_requested.emit()
	AudioManager.play_purchase()
	_emit_banner("%s refits to %s" % [p.display_name(), Economy.UNIT_NAMES[unit]], "")
	state_changed.emit()
	return true

func _attempt_wampus(p: Player) -> bool:
	if not gs.wampus_active or actions_left <= 0 or wampus_attempts >= 2:
		return false
	actions_left -= 1
	wampus_attempts += 1
	var reward := Economy.wampus_reward(gs.round_number)
	if gs.rng.randf() < 0.6:
		p.cash += reward
		gs.wampus_active = false
		_emit_banner("%s caught the Wampus! +$%d" % [p.display_name(), reward], "")
	else:
		var mountains := gs.board.mountain_plots()
		var others: Array = mountains.filter(func(x): return x != gs.wampus_plot)
		if others.size() > 0:
			gs.wampus_plot = others[gs.rng.randi_range(0, others.size() - 1)]
		_emit_banner("%s missed the Wampus!" % p.display_name(), "")
	AudioManager.play_purchase()
	state_changed.emit()
	return true

func dev_end_turn() -> void:
	if phase != Phase.DEVELOPMENT or dev_player != gs.human():
		return
	if pending_unit >= 0 or pending_assay or pending_refit:
		pending_unit = -1
		pending_assay = false
		pending_refit = false
		clear_highlights_requested.emit()
		last_dev_message = "Placement cancelled."
		state_changed.emit()
	_end_player_turn()

# --- Charity event -------------------------------------------------------------

func _check_charity(p: Player) -> void:
	if p == null or p.cash >= Economy.CHARITY_THRESHOLD:
		return
	p.cash += Economy.CHARITY_AMOUNT
	_emit_banner("%s receives charity +$%d!" % [p.display_name(), Economy.CHARITY_AMOUNT], "")
	state_changed.emit()

# --- Land give/lose events (8.5) ---------------------------------------------

func _check_land_events() -> void:
	if land_events_processed_this_turn:
		return
	land_events_processed_this_turn = true
	var r := gs.round_number
	if gs.rng.randf() < Economy.land_receive_probability(r):
		var target := _ranked_player(gs.players.size())
		var unclaimed := gs.board.unclaimed_plots()
		if target != null and unclaimed.size() > 0:
			var plot: Plot = unclaimed[gs.rng.randi_range(0, unclaimed.size() - 1)]
			plot.owner_id = target.id
			target.plots.append(plot)
			_emit_banner("%s receives an extra plot of land!" % target.display_name(), "")
			state_changed.emit()
	if gs.rng.randf() < Economy.land_lose_probability(r):
		var leader := _ranked_player(1)
		if leader != null and leader.plots.size() > 0:
			var plot: Plot = leader.plots[gs.rng.randi_range(0, leader.plots.size() - 1)]
			if plot.mule != null:
				plot.mule = null
			leader.plots.erase(plot)
			plot.owner_id = -1  # Returns to unclaimed pool for next round's land grant
			_emit_banner("%s loses a plot of land!" % leader.display_name(), "")
			state_changed.emit()

func _ranked_player(rank: int) -> Player:
	for p in gs.players:
		if p.rank == rank:
			return p
	return null

# --- Player event (8.2) ------------------------------------------------------

func _check_player_event(p: Player) -> void:
	if gs.rng.randf() >= 0.25:
		return
	var m := Economy.event_money_multiplier(gs.round_number)
	var options: Array = []
	if p.rank != 1:
		options.append("gift_food")
		options.append("gift_smithore")
	if p.rank <= 2:
		options.append("win")
		options.append("lose")
	if options.is_empty():
		return
	var pick: String = options[gs.rng.randi_range(0, options.size() - 1)]
	match pick:
		"gift_food":
			p.food += 3
			p.energy += 2
			_emit_banner("%s receives a gift: +3 food, +2 energy!" % p.display_name(), "")
		"gift_smithore":
			p.smithore += 2
			_emit_banner("%s receives a gift: +2 smithore!" % p.display_name(), "")
		"win":
			var x := gs.rng.randi_range(2, 8)
			p.cash += x * m
			_emit_banner("%s wins $%d!" % [p.display_name(), x * m], "")
		"lose":
			var y := gs.rng.randi_range(2, 8)
			p.cash = maxi(0, p.cash - y * m)
			_emit_banner("%s loses $%d!" % [p.display_name(), y * m], "")
	state_changed.emit()

# --- Production / consumption / prices ---------------------------------------

func _end_development_phase() -> void:
	if phase != Phase.DEVELOPMENT:
		return
	_produce()

func _produce() -> void:
	_set_phase(Phase.PRODUCTION)
	production_results = {}
	gs.round_event = -1
	gs.pest_plot = null
	if Economy.events_active(gs.round_number):
		gs.round_event = EventsScript.roll_round_event(gs.rng)
		_emit_banner(Economy.EVENT_NAMES[gs.round_event], Economy.EVENT_ICON_PATHS[gs.round_event])
		var result := EventsScript.apply_round_event(gs, gs.round_event, gs.rng)
		if result.message != "":
			_emit_banner(result.message, "")
		# Meteorite strike: highlight the plot and pause 5 seconds
		if gs.round_event == Economy.Event.METEORITE and result.plot != null:
			highlights_requested.emit([Vector2i(result.plot.col, result.plot.row)], Color(1.0, 0.3, 0.3, 0.5))
			if not simulate:
				await get_tree().create_timer(5.0).timeout
			clear_highlights_requested.emit()
	for p in gs.players:
		var outputs := {}
		for unit in Economy.Unit.values():
			outputs[unit] = []
		for plot in p.plots:
			if plot.mule == null:
				continue
			var unit := plot.mule.unit
			var out := Economy.per_plot_output(plot, unit, gs.board.neighbors(plot.col, plot.row), _variance())
			if gs.round_event == Economy.Event.PEST and unit == Economy.Unit.FOOD and plot == gs.pest_plot:
				out = 0
			out = floori(float(out) * EventsScript.event_multiplier(gs.round_event, unit))
			outputs[unit].append([plot, out])
		var missing := Economy.energy_requirement(p.mules()) - p.energy
		if missing > 0:
			var candidates: Array = []
			for plot in p.plots:
				if plot.mule != null and plot.mule.unit != Economy.Unit.ENERGY:
					candidates.append(plot)
			_shuffle(candidates)
			for i in mini(missing, candidates.size()):
				var cplot: Plot = candidates[i]
				for entry in outputs[cplot.mule.unit]:
					if entry[0] == cplot:
						entry[1] = 0
						break
		for unit in Economy.Unit.values():
			var sum := 0
			for entry in outputs[unit]:
				sum += entry[1]
				if entry[1] > 0:
					var plot: Plot = entry[0]
					production_results[Vector2i(plot.col, plot.row)] = {"unit": unit, "count": entry[1]}
			var total := int(floor(float(sum) * Economy.growth_multiplier(gs.round_number)))
			match unit:
				Economy.Unit.FOOD:
					p.food += total
				Economy.Unit.ENERGY:
					p.energy += total
				Economy.Unit.SMITHORE:
					# PLAN.md 3.5/4: spoilage truncates old stock to the cap FIRST,
					# then this round's production banks on top, so fresh output
					# is never lost to the cap.
					p.smithore = Economy.smithore_after_cap(p.smithore) + total
				Economy.Unit.CRYSTITE:
					p.crystite = Economy.crystite_after_cap(p.crystite) + total
		for plot in p.plots:
			# Seniority: every deployed mule ages one turn per round.
			if plot.mule != null:
				plot.mule.turns_deployed += 1
	AudioManager.play_production()
	state_changed.emit()
	if simulate:
		_after_production()
	else:
		production_ready.emit(production_results)

func production_continue() -> void:
	if phase != Phase.PRODUCTION or simulate:
		return
	_after_production()

func _after_production() -> void:
	production_results = {}
	state_changed.emit()
	_consume()

func _variance() -> int:
	var r := gs.rng.randf()
	if r < 0.16:
		return -1
	if r < 0.84:
		return 0
	return 1

func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := gs.rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp

func _consume() -> void:
	_set_phase(Phase.CONSUMPTION)
	var req_f := Economy.food_requirement(gs.round_number)
	for p in gs.players:
		p.food -= mini(p.food, req_f)
		p.energy -= mini(p.energy, Economy.energy_requirement(p.mules()))
		p.food = Economy.spoilage_food(p.food)
		p.energy = Economy.spoilage_energy(p.energy)
	state_changed.emit()
	_update_prices()

func _update_prices() -> void:
	_set_phase(Phase.PRICES)
	var demand_f := Economy.food_requirement_next(gs.round_number) * gs.players.size()
	var demand_e := 4
	for p in gs.players:
		demand_e += Economy.energy_requirement(p.mules())
	var demand_s := Economy.mule_req(gs.board.unclaimed_plots().size(), gs.board.plots_without_mule().size())
	for unit in Economy.Unit.values():
		var demand := demand_f if unit == Economy.Unit.FOOD \
			else demand_e if unit == Economy.Unit.ENERGY \
			else demand_s if unit == Economy.Unit.SMITHORE else Economy.CRYSTITE_DEMAND
		gs.prices[unit] = Economy.new_price(unit, gs.prices[unit], gs.total_supply(unit), demand, gs.rng)
	# Mule shortage (no mules in store): smithore price doubles.
	if gs.store_stock.get("mules", 0) <= 0:
		gs.prices[Economy.Unit.SMITHORE] = mini(gs.prices[Economy.Unit.SMITHORE] * 2,
			Economy.MAX_PRICE[Economy.Unit.SMITHORE])
	state_changed.emit()
	_begin_auctions()

# --- Auctions ----------------------------------------------------------------

func _begin_auctions() -> void:
	_set_phase(Phase.AUCTION)
	auction_index = 0
	cpu_offers = []
	human_offer = {}
	_advance_auction()

func _advance_auction() -> void:
	if phase != Phase.AUCTION:
		return
	if auction_index >= AUCTION_ORDER.size():
		_replenish_mules()
		return
	auction_unit = AUCTION_ORDER[auction_index]
	cpu_offers = []
	human_offer = {}
	human_sales = []
	var cpu_order: Array = gs.cpu_players()
	cpu_order.sort_custom(func(a: Player, b: Player) -> bool:
		return a.rank > b.rank)
	for p in cpu_order:
		var offer := _cpu_auction(p)
		if not offer.is_empty():
			cpu_offers.append(offer)
	if simulate:
		var offer := _cpu_auction(gs.human())
		if not offer.is_empty():
			human_offer = offer
			_resolve_human_offer()
		auction_done()
	else:
		auction_updated.emit(auction_unit)

func _cpu_auction(p: Player) -> Dictionary:
	return _ai_for(p).auction_step(gs, auction_unit)

func auction_sell(unit: int, qty: int) -> bool:
	if phase != Phase.AUCTION or unit != auction_unit or qty <= 0:
		return false
	var p := gs.human()
	qty = mini(qty, p.inventory(unit))
	if qty <= 0:
		return false
	var buy_p := Economy.store_buy_price(unit, gs.prices[unit])
	p.cash += qty * buy_p
	gs.store_stock[unit] += qty
	p.take_units(unit, qty)
	AudioManager.play_auction()
	state_changed.emit()
	return true

func auction_buy(unit: int, qty: int) -> bool:
	if phase != Phase.AUCTION or unit != auction_unit or qty <= 0:
		return false
	var p := gs.human()
	var sell_p := Economy.store_sell_price(unit, gs.prices[unit])
	qty = mini(qty, gs.store_stock.get(unit, 0))
	qty = mini(qty, floori(p.cash / sell_p))
	if qty <= 0:
		return false
	p.cash -= qty * sell_p
	gs.store_stock[unit] -= qty
	p.add_units(unit, qty)
	AudioManager.play_auction()
	state_changed.emit()
	return true

func auction_list(unit: int, qty: int, price: int) -> bool:
	if phase != Phase.AUCTION or unit != auction_unit or qty <= 0 or price <= 0:
		return false
	var p := gs.human()
	var buy_p := Economy.store_buy_price(unit, gs.prices[unit])
	if price < buy_p or price > MAX_LIST_PRICE:
		return false
	# Re-listing refunds the active listing first, so the price can be adjusted.
	if human_offer.get("qty", 0) > 0:
		p.add_units(unit, human_offer.qty)
		human_offer = {}
	qty = mini(qty, p.inventory(unit))
	if qty <= 0:
		return false
	p.take_units(unit, qty)
	human_offer = {"unit": unit, "qty": qty, "price": price}
	_resolve_human_offer()
	AudioManager.play_auction()
	state_changed.emit()
	return true

func _resolve_human_offer() -> void:
	var unit := auction_unit
	if human_offer.get("qty", 0) <= 0:
		return
	var list_price: int = human_offer.price
	var max_bid := Economy.store_sell_price(unit, gs.prices[unit]) - 5
	# 1. Complete against remembered CPU buy bids priced at/above the listing.
	for bid in cpu_offers.duplicate():
		if human_offer.get("qty", 0) <= 0:
			break
		if bid.get("kind", "sell") != "buy" or bid.get("unit", -1) != unit \
				or bid.get("qty", 0) <= 0 or bid.get("price", 0) <= 0:
			continue
		if list_price > bid.price:
			continue
		var buyer: Player = gs.players[bid.from_id]
		var deficit := maxi(0, _auction_req(buyer, unit) - buyer.inventory(unit))
		if deficit <= 0:
			continue
		var n := mini(human_offer.qty, mini(bid.qty, deficit))
		n = mini(n, floori(buyer.cash / list_price))
		if n <= 0:
			continue
		buyer.cash -= n * list_price
		buyer.add_units(unit, n)
		gs.human().cash += n * list_price
		human_offer.qty -= n
		bid.qty -= n
		_record_sale(buyer, n, list_price)
		if bid.qty <= 0:
			cpu_offers.erase(bid)
	# 2. Direct sales to CPUs running a deficit (list at/below their max).
	if list_price <= max_bid:
		for p in gs.cpu_players():
			if human_offer.get("qty", 0) <= 0:
				break
			var deficit := maxi(0, _auction_req(p, unit) - p.inventory(unit))
			if deficit <= 0:
				continue
			var n := mini(human_offer.qty, deficit)
			n = mini(n, floori(p.cash / list_price))
			if n <= 0:
				continue
			p.cash -= n * list_price
			p.add_units(unit, n)
			gs.human().cash += n * list_price
			human_offer.qty -= n
			_record_sale(p, n, list_price)
	# 3. Too high for a CPU running a deficit? Remember a lower counter-offer
	# (a buy bid at their max, sized to fit their budget).
	if list_price > max_bid and max_bid > 0:
		for p in gs.cpu_players():
			var deficit := maxi(0, _auction_req(p, unit) - p.inventory(unit))
			if deficit <= 0:
				continue
			if _find_buy_bid(p.id, unit) >= 0:
				continue
			var q := mini(deficit, floori(p.cash / max_bid))
			q = mini(q, human_offer.qty)
			if q <= 0:
				continue
			cpu_offers.append({"unit": unit, "from_id": p.id, "qty": q,
				"price": max_bid, "kind": "buy"})

func _find_buy_bid(player_id: int, unit: int) -> int:
	for i in cpu_offers.size():
		var o: Dictionary = cpu_offers[i]
		if o.get("kind", "sell") == "buy" and o.get("unit", -1) == unit \
				and o.get("from_id", -1) == player_id and o.get("qty", 0) > 0:
			return i
	return -1

func _record_sale(buyer: Player, qty: int, price: int) -> void:
	human_sales.append({"name": buyer.display_name(), "qty": qty, "price": price})

func auction_accept_offer(index: int) -> bool:
	if phase != Phase.AUCTION or index < 0 or index >= cpu_offers.size():
		return false
	var p := gs.human()
	var offer: Dictionary = cpu_offers[index]
	if offer.get("unit", -2) != auction_unit or offer.get("qty", 0) <= 0 \
			or offer.get("price", 0) <= 0:
		return false
	if offer.get("kind", "sell") == "buy":
		# Accept a CPU's buy bid: sell our units at their bid price.
		var buyer: Player = gs.players[offer.from_id]
		var n := mini(offer.qty, p.inventory(auction_unit))
		n = mini(n, floori(buyer.cash / offer.price))
		if n <= 0:
			return false
		p.take_units(auction_unit, n)
		p.cash += n * offer.price
		buyer.cash -= n * offer.price
		buyer.add_units(auction_unit, n)
		offer.qty -= n
		_record_sale(buyer, n, offer.price)
		if offer.qty <= 0:
			cpu_offers.remove_at(index)
		AudioManager.play_auction()
		state_changed.emit()
		return true
	var max_bid := Economy.store_sell_price(auction_unit, gs.prices[auction_unit]) - 5
	if offer.price > max_bid:
		return false
	var n := mini(offer.qty, floori(p.cash / offer.price))
	if n <= 0:
		return false
	p.cash -= n * offer.price
	p.add_units(auction_unit, n)
	var seller: Player = gs.players[offer.from_id]
	seller.cash += n * offer.price
	offer.qty -= n
	AudioManager.play_auction()
	state_changed.emit()
	return true

func auction_done() -> void:
	if phase != Phase.AUCTION:
		return
	if human_offer.get("qty", 0) > 0:
		gs.human().add_units(human_offer.unit, human_offer.qty)
	human_offer = {}
	human_sales = []
	cpu_offers = []
	auction_index += 1
	_advance_auction()

func _auction_req(p: Player, unit: int) -> int:
	match unit:
		Economy.Unit.FOOD:
			return Economy.food_requirement_next(gs.round_number)
		Economy.Unit.ENERGY:
			return Economy.energy_requirement(p.mules())
	return 0

# --- Replenish / summary / end ----------------------------------------------

func _replenish_mules() -> void:
	_set_phase(Phase.REPLENISH)
	var build := floori(gs.store_stock[Economy.Unit.SMITHORE] / 2)
	gs.store_stock["mules"] = mini(Economy.STORE_MULE_CAP, gs.store_stock["mules"] + build)
	gs.store_stock[Economy.Unit.SMITHORE] -= build * 2
	_summary()

func _summary() -> void:
	_set_phase(Phase.SUMMARY)
	_update_scores()
	gs.update_ranks()
	var rows: Array = []
	for p in gs.players:
		rows.append({
			"name": p.display_name(), "color": p.color(), "rank": p.rank,
			"cash": p.cash, "plots": p.plots.size(), "mules": p.mule_count(),
			"food": p.food, "energy": p.energy, "smithore": p.smithore, "crystite": p.crystite,
			"score": p.score,
		})
	summary_ready.emit(rows)
	state_changed.emit()
	if simulate:
		if gs.round_number < Economy.MAX_ROUNDS:
			_next_round()
		else:
			_end_game()

func summary_next() -> void:
	if phase != Phase.SUMMARY:
		return
	if gs.round_number < Economy.MAX_ROUNDS:
		_next_round()
	else:
		_end_game()

func _update_scores() -> void:
	for p in gs.players:
		var plot_value := 0
		for plot in p.plots:
			plot_value += Economy.plot_score(plot)
		p.score = Economy.score(p.cash, plot_value, p.mule_count(), p.food, p.energy, p.smithore, p.crystite, gs.prices)

func _end_game() -> void:
	_update_scores()
	gs.update_ranks()
	var colony := 0
	for p in gs.players:
		colony += p.score
	var rating := Economy.colony_rating(colony)
	var success := Economy.colony_success(colony)
	var winner_id := -1
	if success:
		winner_id = 0
		for i in gs.players.size():
			if gs.players[i].score > gs.players[winner_id].score:
				winner_id = i
	_set_phase(Phase.GAME_OVER)
	last_results = {
		"colony_total": colony,
		"rating": rating,
		"success": success,
		"winner_id": winner_id,
		"winner_name": gs.players[winner_id].display_name() if winner_id >= 0 else "",
		"round": gs.round_number,
	}
	game_finished.emit(last_results)

# --- Helpers -----------------------------------------------------------------

func _ai_for(p: Player) -> RefCounted:
	if not _ais.has(p.id):
		var personality := AiControllerScript.Personality.NORMAL
		match p.id:
			1:
				personality = AiControllerScript.Personality.HOMESTEADER
			2:
				personality = AiControllerScript.Personality.MINER
			3:
				personality = AiControllerScript.Personality.TRADER
		_ais[p.id] = AiControllerScript.new(p, personality)
	return _ais[p.id]

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)

func _emit_banner(text: String, icon: String) -> void:
	banner_shown.emit(text, icon)

static func quality_name(quality: int) -> String:
	match quality:
		0:
			return "No Crystite"
		1:
			return "Low Crystite"
		2:
			return "Medium Crystite"
		3:
			return "High Crystite"
		_:
			return "EXTRA HIGH Crystite"
