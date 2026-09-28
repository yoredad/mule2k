extends SceneTree

var started := false
var failures := 0
var pips_seen := false

func _init() -> void:
	var packed = load("res://scenes/main.tscn")
	root.add_child(packed.instantiate())

func _process(_delta: float) -> bool:
	if not started:
		started = true
		_run()
	return false

func _run() -> void:
	var flow: Node = root.get_node("GameFlow")
	var gs: Node = root.get_node("GameState")
	flow.simulate = true
	for seed_value in [1, 424242, 987654321]:
		pips_seen = false
		var hook := func() -> void:
			if flow.phase == flow.Phase.PRODUCTION and not flow.production_results.is_empty():
				pips_seen = true
		flow.state_changed.connect(hook)
		flow.start_game(seed_value)
		flow.state_changed.disconnect(hook)
		_run_checks(flow, gs, seed_value)
		_check("sim seed %d showed production pips" % seed_value, pips_seen, [])
		_check("sim seed %d production results cleared" % seed_value,
			flow.production_results.is_empty(), [flow.production_results])
	print(failures == 0 and "SIM PASSED" or "SIM FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _run_checks(flow: Node, gs: Node, seed_value: int) -> void:
	var results: Dictionary = flow.last_results
	_check("sim seed %d reached round 12" % seed_value, gs.round_number == Economy.MAX_ROUNDS, [gs.round_number])
	_check("sim seed %d game over phase" % seed_value, flow.phase == flow.Phase.GAME_OVER, [flow.phase])
	var ok_prices := true
	for unit in Economy.Unit.values():
		var price: int = gs.prices[unit]
		if price < Economy.MIN_PRICE[unit] or price > Economy.MAX_PRICE[unit]:
			ok_prices = false
	_check("all prices within bounds", ok_prices, [gs.prices])
	var claimed := 0
	for p in gs.players:
		claimed += p.plots.size()
	_check("claimed + unclaimed == 44", claimed + gs.board.unclaimed_plots().size() == 44,
		[claimed, gs.board.unclaimed_plots().size()])
	var ok_stock := true
	for unit in Economy.Unit.values():
		if gs.store_stock.get(unit, 0) < 0:
			ok_stock = false
	_check("store stock never negative", ok_stock, [gs.store_stock])
	var ranks: Array = gs.players.map(func(p): return p.rank)
	ranks.sort()
	_check("ranks are 1..4", ranks == [1, 2, 3, 4], [ranks])
	_check("colony total computed", results.has("colony_total") and results.colony_total > 0, [results])
	var cash_total := 0
	for p in gs.players:
		cash_total += p.cash
	_check("player cash preserved (sum > 0)", cash_total > 0, [cash_total])
	_check("meteorite strikes capped at 3", gs.meteorite_strikes <= 3, [gs.meteorite_strikes])
	_check("wampus always on a mountain", gs.wampus_plot != null and gs.wampus_plot.is_mountain(),
		[gs.wampus_plot])

func _check(name: String, ok: bool, detail: Array) -> void:
	if ok:
		print("PASS: ", name)
	else:
		failures += 1
		print("FAIL: ", name, " got ", detail)
