extends SceneTree

var failures := 0
var started := false

func _init() -> void:
	var packed = load("res://scenes/main.tscn")
	root.add_child(packed.instantiate())

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run_tests()
	return false

func run_tests() -> void:
	_test_ebpc()
	_test_food_requirement()
	_test_growth()
	_test_mule_price()
	_test_store_margins()
	_test_price_ratio_and_bounds()
	_test_smithore_noise()
	_test_mule_req()
	_test_spoilage()
	_test_dev_actions()
	_test_scoring()
	_test_colony_rating()
	_test_events()
	_test_event_stats()
	_test_land_events()
	_test_energy_requirement()
	_test_production_eco_bonus()
	_test_mule_seniority()
	_test_crystite_tenure()
	_test_board_generation()
	_test_crystite_constants()
	_test_crystite_price()
	_test_crystite_most_expensive()
	_test_crystite_deposits()
	_test_crystite_production()
	_test_crystite_scoring()
	_test_game_state()

	print(failures == 0 and "ALL TESTS PASSED" or "FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _test_ebpc() -> void:
	var ok := true
	ok = ok and Economy.ebpc(Board.Terrain.PLAINS, 0, Economy.Unit.FOOD) == 2
	ok = ok and Economy.ebpc(Board.Terrain.PLAINS, 0, Economy.Unit.ENERGY) == 3
	ok = ok and Economy.ebpc(Board.Terrain.PLAINS, 0, Economy.Unit.SMITHORE) == 1
	ok = ok and Economy.ebpc(Board.Terrain.RIVER, 0, Economy.Unit.FOOD) == 4
	ok = ok and Economy.ebpc(Board.Terrain.RIVER, 0, Economy.Unit.ENERGY) == 2
	ok = ok and Economy.ebpc(Board.Terrain.RIVER, 0, Economy.Unit.SMITHORE) == 0
	ok = ok and Economy.ebpc(Board.Terrain.MOUNTAIN, 1, Economy.Unit.FOOD) == 1
	ok = ok and Economy.ebpc(Board.Terrain.MOUNTAIN, 1, Economy.Unit.ENERGY) == 1
	ok = ok and Economy.ebpc(Board.Terrain.MOUNTAIN, 1, Economy.Unit.SMITHORE) == 2
	ok = ok and Economy.ebpc(Board.Terrain.MOUNTAIN, 2, Economy.Unit.SMITHORE) == 3
	ok = ok and Economy.ebpc(Board.Terrain.MOUNTAIN, 3, Economy.Unit.SMITHORE) == 4
	_check("EBPC table (plains/river/mountains)", ok, [])

func _test_food_requirement() -> void:
	var ok := true
	ok = ok and Economy.food_requirement(1) == 3 and Economy.food_requirement(4) == 3
	ok = ok and Economy.food_requirement(5) == 4 and Economy.food_requirement(8) == 4
	ok = ok and Economy.food_requirement(9) == 5 and Economy.food_requirement(12) == 5
	ok = ok and Economy.food_requirement_next(12) == 0
	ok = ok and Economy.food_requirement_next(11) == 5
	ok = ok and Economy.food_requirement_next(8) == 5
	_check("food requirement per round (3/4/5, 0 after 12)", ok, [])

func _test_growth() -> void:
	var ok := true
	ok = ok and is_equal_approx(Economy.growth_multiplier(1), 1.0)
	ok = ok and is_equal_approx(Economy.growth_multiplier(2), 1.08)
	ok = ok and is_equal_approx(Economy.growth_multiplier(12), 1.88)
	ok = ok and is_equal_approx(Economy.growth_sum(1), 1.0)
	ok = ok and is_equal_approx(Economy.growth_sum(12), 17.28)
	ok = ok and is_equal_approx(Economy.growth_sum(7), 8.68)
	ok = ok and Economy.player_total([2, 3], 2) == 5
	ok = ok and Economy.player_total([5, 5], 12) == 18
	_check("growth multiplier/sum + player_total", ok, [])

func _test_mule_price() -> void:
	var ok := true
	ok = ok and Economy.mule_price(49) == 90
	ok = ok and Economy.mule_price(50) == 100
	ok = ok and Economy.mule_price(25) == 50
	ok = ok and Economy.mule_price(0) == 0
	_check("mule price = floor_to_10(2x smithore)", ok, [])

func _test_store_margins() -> void:
	var ok := true
	ok = ok and Economy.store_buy_price(Economy.Unit.FOOD, 30) == 15
	ok = ok and Economy.store_sell_price(Economy.Unit.FOOD, 30) == 50
	ok = ok and Economy.store_buy_price(Economy.Unit.ENERGY, 25) == 10
	ok = ok and Economy.store_sell_price(Economy.Unit.ENERGY, 25) == 45
	ok = ok and Economy.store_buy_price(Economy.Unit.SMITHORE, 50) == 50
	ok = ok and Economy.store_sell_price(Economy.Unit.SMITHORE, 50) == 85
	_check("store margins (buy -15/-15/0, sell +35)", ok, [])

func _test_price_ratio_and_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ok := true
	ok = ok and is_equal_approx(Economy.price_ratio(0, 10), 3.0)
	ok = ok and is_equal_approx(Economy.price_ratio(1000, 10), 0.25)
	ok = ok and is_equal_approx(Economy.price_ratio(50, 0), 0.25)
	var scarce := Economy.new_price(Economy.Unit.FOOD, 100, 1, 10, rng)
	var abundant := Economy.new_price(Economy.Unit.FOOD, 100, 100, 10, rng)
	ok = ok and scarce > abundant
	ok = ok and scarce >= 30 and scarce <= 265 and abundant >= 30 and abundant <= 265
	var none := Economy.new_price(Economy.Unit.FOOD, 100, 0, 10, rng)
	ok = ok and none == 250
	for seed_val in range(50):
		rng.seed = seed_val
		for unit in [Economy.Unit.FOOD, Economy.Unit.ENERGY, Economy.Unit.SMITHORE, Economy.Unit.CRYSTITE]:
			var price := Economy.new_price(unit, 100, rng.randi_range(0, 200), rng.randi_range(1, 50), rng)
			ok = ok and price >= Economy.MIN_PRICE[unit] and price <= Economy.MAX_PRICE[unit]
	_check("price ratio clamp + bounds + scarcity drives price up", ok, [scarce, abundant])

func _test_smithore_noise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ok := true
	for i in 200:
		var n := Economy.smithore_noise(rng)
		ok = ok and n % 7 == 0 and n >= -14 and n <= 14
	_check("smithore noise in [-14,+14] step 7", ok, [])

func _test_mule_req() -> void:
	var ok := true
	ok = ok and Economy.mule_req(3, 2) == 5
	ok = ok and Economy.mule_req(6, 2) == 6
	ok = ok and Economy.mule_req(0, 9) == 8
	ok = ok and Economy.mule_req(4, 0) == 4
	_check("mule_req = min(8, min(4,unclaimed) + no_mule)", ok, [])

func _test_spoilage() -> void:
	var ok := true
	ok = ok and Economy.spoilage_food(10) == 5 and Economy.spoilage_food(5) == 2
	ok = ok and Economy.spoilage_food(3) == 1 and Economy.spoilage_food(1) == 0
	ok = ok and Economy.spoilage_energy(10) == 7 and Economy.spoilage_energy(4) == 3
	ok = ok and Economy.spoilage_energy(2) == 1 and Economy.spoilage_energy(1) == 0
	ok = ok and Economy.smithore_after_cap(70) == 50 and Economy.smithore_after_cap(30) == 30
	_check("spoilage (food /2, energy 3/4, smithore cap 50)", ok, [])

func _test_dev_actions() -> void:
	var ok := true
	ok = ok and Economy.dev_actions(3, 3) == 6
	ok = ok and Economy.dev_actions(0, 3) == 2
	ok = ok and Economy.dev_actions(2, 3) == 4
	ok = ok and Economy.dev_actions(9, 5) == 6
	ok = ok and Economy.dev_actions(5, 0) == 6
	_check("dev actions = max(2, 1 + 5*clamp(food/req))", ok, [])

func _test_scoring() -> void:
	var prices := {Economy.Unit.FOOD: 30, Economy.Unit.ENERGY: 25, Economy.Unit.SMITHORE: 50, Economy.Unit.CRYSTITE: 150}
	var river := Plot.new()
	river.terrain = Board.Terrain.RIVER
	river.owner_id = 0
	river.mule = Mule.new(Economy.Unit.FOOD)
	var plain := Plot.new()
	plain.terrain = Board.Terrain.PLAINS
	plain.owner_id = 0
	var plot_value := Economy.plot_score(river) + Economy.plot_score(plain)
	var total := Economy.score(1000, plot_value, 2, 5, 2, 1, 0, prices)
	var expected := 1000 + 1025 + 70 + 150 + 50 + 50
	_check("score example (2345)", total == expected and plot_value == 1025, [total, expected])

func _test_colony_rating() -> void:
	var ok := true
	ok = ok and Economy.colony_rating(0) == 0 and Economy.colony_rating(19999) == 0
	ok = ok and Economy.colony_rating(59999) == 2
	ok = ok and Economy.colony_rating(60000) == 3
	ok = ok and Economy.colony_rating(120000) == 6
	ok = ok and not Economy.colony_success(59999)
	ok = ok and Economy.colony_success(60000)
	_check("colony rating + $60k threshold", ok, [])

func _test_event_stats() -> void:
	var ok := true
	ok = ok and Economy.event_total() == 11778
	var weight_sum := 0.0
	for event in Economy.Event.values():
		weight_sum += Economy.event_weight(event)
	ok = ok and is_equal_approx(weight_sum, 1.0)
	ok = ok and Economy.EVENT_NAMES.size() == 8
	ok = ok and Economy.events_active(1) and Economy.events_active(11)
	ok = ok and not Economy.events_active(0) and not Economy.events_active(12)
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 4000:
		var event := Economy.roll_event(rng)
		counts[event] = counts.get(event, 0) + 1
	ok = ok and counts.size() == Economy.Event.values().size()
	for event in Economy.Event.values():
		ok = ok and counts.get(event, 0) > 0
	ok = ok and counts[Economy.Event.ACID_RAIN] > counts[Economy.Event.PIRATES]
	ok = ok and counts[Economy.Event.SUNSPOTS] > counts[Economy.Event.PIRATES]
	for event in Economy.Event.values():
		ok = ok and FileAccess.file_exists(Economy.EVENT_ICON_PATHS[event])
	_check("event statistics: 11778 total, weights sum 1, rounds 1-11, icons exist", ok, [counts])

func _test_land_events() -> void:
	var ok := true
	ok = ok and Economy.LAND_RECEIVE_FREQUENCIES.size() == 12
	ok = ok and Economy.LAND_LOSE_FREQUENCIES.size() == 12
	var rec_sum := 0.0
	var lose_sum := 0.0
	for i in 12:
		rec_sum += Economy.LAND_RECEIVE_FREQUENCIES[i]
		lose_sum += Economy.LAND_LOSE_FREQUENCIES[i]
	ok = ok and abs(rec_sum - 100.0) < 0.5
	ok = ok and abs(lose_sum - 100.0) < 0.5
	ok = ok and Economy.LAND_RECEIVE_TOTAL == 438 and Economy.LAND_LOSE_TOTAL == 732
	ok = ok and Economy.LAND_TOURNAMENTS == 1093
	var expected_rec := 0.0
	var expected_lose := 0.0
	for r in 12:
		for t in range(Economy.LAND_PLAYERS):
			expected_rec += Economy.land_receive_probability(r + 1)
			expected_lose += Economy.land_lose_probability(r + 1)
	var rec_rate := float(Economy.LAND_RECEIVE_TOTAL) / float(Economy.LAND_TOURNAMENTS)
	var lose_rate := float(Economy.LAND_LOSE_TOTAL) / float(Economy.LAND_TOURNAMENTS)
	ok = ok and is_equal_approx(expected_rec, rec_rate)
	ok = ok and is_equal_approx(expected_lose, lose_rate)
	ok = ok and Economy.land_receive_probability(0) == 0.0 and Economy.land_receive_probability(13) == 0.0
	ok = ok and Economy.land_lose_probability(0) == 0.0 and Economy.land_lose_probability(13) == 0.0
	ok = ok and Economy.land_receive_probability(1) > 0.0 and Economy.land_lose_probability(1) > 0.0
	ok = ok and Economy.land_receive_probability(12) < Economy.land_receive_probability(1)
	ok = ok and Economy.land_lose_probability(1) < Economy.land_lose_probability(2)
	for r in 12:
		ok = ok and Economy.land_receive_probability(r + 1) < 0.02
		ok = ok and Economy.land_lose_probability(r + 1) < 0.02
	_check("land events: 12-month distributions, 438/732 totals, per-turn rates match", ok,
		[rec_sum, lose_sum, expected_rec, expected_lose])

func _test_events() -> void:
	var ok := true
	ok = ok and Economy.event_money_multiplier(1) == 25 and Economy.event_money_multiplier(4) == 50
	ok = ok and Economy.event_money_multiplier(8) == 75 and Economy.event_money_multiplier(12) == 100
	ok = ok and Economy.wampus_reward(3) == 100 and Economy.wampus_reward(7) == 200
	ok = ok and Economy.wampus_reward(8) == 300 and Economy.wampus_reward(12) == 400
	ok = ok and Economy.gambling_grant(1) == 113 and Economy.gambling_grant(2) == 150
	ok = ok and Economy.gambling_grant(3) == 188 and Economy.gambling_grant(4) == 225
	ok = ok and Economy.gambling_grant(12) == 525
	_check("event money multiplier + wampus rewards + gambling grant", ok, [])

func _test_energy_requirement() -> void:
	var mules := [Mule.new(Economy.Unit.FOOD), Mule.new(Economy.Unit.SMITHORE),
		Mule.new(Economy.Unit.SMITHORE), Mule.new(Economy.Unit.ENERGY)]
	_check("energy requirement = non-energy mules", Economy.energy_requirement(mules) == 3, [])

func _test_production_eco_bonus() -> void:
	var p1 := Plot.new()
	p1.col = 3; p1.row = 2
	p1.terrain = Board.Terrain.PLAINS
	p1.owner_id = 0
	p1.mule = Mule.new(Economy.Unit.FOOD)
	var p2 := Plot.new()
	p2.col = 4; p2.row = 2
	p2.terrain = Board.Terrain.PLAINS
	p2.owner_id = 0
	p2.mule = Mule.new(Economy.Unit.FOOD)
	var p3 := Plot.new()
	p3.col = 5; p3.row = 2
	p3.terrain = Board.Terrain.PLAINS
	p3.owner_id = 1
	p3.mule = Mule.new(Economy.Unit.FOOD)
	var out1 := Economy.per_plot_output(p1, Economy.Unit.FOOD, [p2], 0)
	var out2 := Economy.per_plot_output(p2, Economy.Unit.FOOD, [p1, p3], 0)
	var out3 := Economy.per_plot_output(p3, Economy.Unit.FOOD, [p2], 0)
	_check("eco bonus only for same owner adjacent (+1, capped)",
		out1 == 3 and out2 == 3 and out3 == 2, [out1, out2, out3])
	var pa := Plot.new()
	pa.col = 0; pa.row = 1
	pa.terrain = Board.Terrain.PLAINS
	pa.owner_id = 0
	pa.mule = Mule.new(Economy.Unit.FOOD)
	var mkfood := func(c: int, r: int, owner: int) -> Plot:
		var q := Plot.new()
		q.col = c; q.row = r
		q.terrain = Board.Terrain.PLAINS
		q.owner_id = owner
		q.mule = Mule.new(Economy.Unit.FOOD)
		return q
	var out_pair := Economy.per_plot_output(pa, Economy.Unit.FOOD, [mkfood.call(0, 0, 0), mkfood.call(0, 2, 0)], 0)
	var out_trio := Economy.per_plot_output(pa, Economy.Unit.FOOD,
		[mkfood.call(0, 0, 0), mkfood.call(0, 2, 0), mkfood.call(1, 1, 0)], 0)
	var out_mixed := Economy.per_plot_output(pa, Economy.Unit.FOOD,
		[mkfood.call(0, 0, 0), mkfood.call(0, 2, 1)], 0)
	_check("eco bonus +1 per matching neighbor, capped at +2",
		out_pair == 4 and out_trio == 4 and out_mixed == 3, [out_pair, out_trio, out_mixed])
	var river := Plot.new()
	river.terrain = Board.Terrain.RIVER
	river.owner_id = 0
	river.mule = Mule.new(Economy.Unit.SMITHORE)
	_check("river smithore = 0 even with variance",
		Economy.per_plot_output(river, Economy.Unit.SMITHORE, [], 5) == 0, [])

func _test_mule_seniority() -> void:
	var plot := Plot.new()
	plot.terrain = Board.Terrain.PLAINS
	plot.owner_id = 0
	plot.mule = Mule.new(Economy.Unit.FOOD)
	var ok := true
	ok = ok and plot.mule.seniority_bonus() == 0
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.FOOD, [], 0) == 2
	plot.mule.turns_deployed = 3
	ok = ok and plot.mule.seniority_bonus() == 1
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.FOOD, [], 0) == 3
	plot.mule.turns_deployed = 7
	ok = ok and plot.mule.seniority_bonus() == 2
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.FOOD, [], 0) == 4
	plot.mule.turns_deployed = 0
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.FOOD, [], 0) == 2
	var river := Plot.new()
	river.terrain = Board.Terrain.RIVER
	river.owner_id = 0
	river.mule = Mule.new(Economy.Unit.SMITHORE)
	river.mule.turns_deployed = 12
	ok = ok and Economy.per_plot_output(river, Economy.Unit.SMITHORE, [], 0) == 0
	_check("mule seniority +1 per 3 turns, reset to 0, never revives banned mining", ok, [])

func _test_crystite_tenure() -> void:
	var plot := Plot.new()
	plot.terrain = Board.Terrain.PLAINS
	plot.owner_id = 0
	plot.crystite_quality = 0
	plot.mule = Mule.new(Economy.Unit.CRYSTITE)
	var ok := true
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.CRYSTITE, [], 0) == 0
	plot.mule.turns_deployed = 1
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.CRYSTITE, [], 0) == 0
	plot.mule.turns_deployed = 2
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.CRYSTITE, [], 0) == 1
	plot.mule.turns_deployed = 6
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.CRYSTITE, [], 0) == 3
	# Mule changed (refit resets tenure) -> base back to zero.
	plot.mule.turns_deployed = 0
	ok = ok and Economy.per_plot_output(plot, Economy.Unit.CRYSTITE, [], 0) == 0
	# Terrain bans still hold regardless of tenure.
	var river := Plot.new()
	river.terrain = Board.Terrain.RIVER
	river.owner_id = 0
	river.mule = Mule.new(Economy.Unit.CRYSTITE)
	river.mule.turns_deployed = 9
	ok = ok and Economy.per_plot_output(river, Economy.Unit.CRYSTITE, [], 0) == 0
	var peak := Plot.new()
	peak.terrain = Board.Terrain.RIVER
	peak.owner_id = 0
	peak.mule = Mule.new(Economy.Unit.SMITHORE)
	peak.mule.turns_deployed = 9
	ok = ok and Economy.per_plot_output(peak, Economy.Unit.SMITHORE, [], 0) == 0
	_check("crystite tenure: base 1 after 2 rounds, 0 on reset, bans hold", ok, [])

func _test_board_generation() -> void:
	for seed_val in [1, 7, 42, 12345, 99999]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var board := Board.new(rng)
		var counts := board.terrain_counts()
		var mtn := board.mountain_plots().map(func(p): return p.mountains)
		_check("board %d: 45 plots, 44 claimable" % seed_val,
			board.plots.size() == 45 and board.claimable_plots().size() == 44, [])
		_check("board %d: store center, rivers above/below" % seed_val,
			board.get_plot(4, 2).is_store()
			and board.get_plot(4, 0).is_river() and board.get_plot(4, 1).is_river()
			and board.get_plot(4, 3).is_river() and board.get_plot(4, 4).is_river()
			and board.river_plots().size() == 4, [])
		_check("board %d: 10 mountain plots, counts 1-3, has 1 and 3" % seed_val,
			counts[Board.Terrain.MOUNTAIN] == 10 and mtn.all(func(c): return c >= 1 and c <= 3)
			and mtn.has(1) and mtn.has(3), [counts, mtn])
		_check("board %d: no mountains on store/river" % seed_val,
			not board.get_plot(4, 2).is_mountain() and not board.get_plot(4, 1).is_mountain()
			and not board.get_plot(4, 3).is_mountain(), [])

func _test_crystite_constants() -> void:
	var ok := true
	ok = ok and Economy.OUTFIT_COST[Economy.Unit.CRYSTITE] == 100
	ok = ok and Economy.MIN_PRICE[Economy.Unit.CRYSTITE] == 150
	ok = ok and Economy.MAX_PRICE[Economy.Unit.CRYSTITE] == 500
	ok = ok and Economy.START_PRICE[Economy.Unit.CRYSTITE] == 150
	ok = ok and Economy.CRYSTITE_DEMAND == 8
	ok = ok and Economy.CRYSTITE_BASE_PRICE == 200
	ok = ok and Economy.CRYSTITE_STORAGE_CAP == 50
	ok = ok and Economy.crystite_after_cap(70) == 50 and Economy.crystite_after_cap(30) == 30
	ok = ok and Economy.store_buy_price(Economy.Unit.CRYSTITE, 200) == 200
	ok = ok and Economy.store_sell_price(Economy.Unit.CRYSTITE, 200) == 235
	ok = ok and Economy.UNIT_LETTERS[Economy.Unit.CRYSTITE] == "C"
	_check("crystite constants (outfit 100, price 150-500, demand 8, cap 50)", ok, [])

func _test_crystite_price() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ok := true
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 0, 8, rng) == 500
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 4, 8, rng) == 350
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 8, 8, rng) == 200
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 16, 8, rng) == 150
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 24, 8, rng) == 150
	ok = ok and Economy.new_price(Economy.Unit.CRYSTITE, 200, 100, 8, rng) == 150
	_check("crystite price: 150 min / 500 max / supply-driven", ok, [])

func _test_crystite_most_expensive() -> void:
	var ok := true
	for seed_val in range(30):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var supply := rng.randi_range(0, 40)
		var demand := rng.randi_range(1, 12)
		var c_price := Economy.new_price(Economy.Unit.CRYSTITE, Economy.CRYSTITE_BASE_PRICE, supply, demand, rng)
		for unit in [Economy.Unit.FOOD, Economy.Unit.ENERGY, Economy.Unit.SMITHORE]:
			var other := Economy.new_price(unit, Economy.START_PRICE[unit], supply, demand, rng)
			ok = ok and c_price >= other
	_check("crystite is always the most expensive good", ok, [])

func _test_crystite_deposits() -> void:
	for seed_val in [1, 7, 42, 12345, 99999]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var board := Board.new(rng)
		var highs := board.plots.filter(func(p): return p.crystite_quality == Board.CRYSTITE_QUALITY_HIGH)
		_check("crystite %d: exactly 3 HIGH deposits, never store/river" % seed_val,
			highs.size() == Board.HIGH_CRYSTITE_COUNT
			and highs.all(func(p): return not p.is_store() and not p.is_river()), [highs.size()])
		var ok := true
		for plot in board.plots:
			var q := plot.crystite_quality
			ok = ok and q >= 0 and q <= Board.CRYSTITE_QUALITY_HIGH
			if q == 0 or plot.is_store() or q == Board.CRYSTITE_QUALITY_HIGH:
				continue
			if q == Board.CRYSTITE_QUALITY_MEDIUM:
				var near_high := false
				for h in highs:
					if absi(plot.col - h.col) + absi(plot.row - h.row) == 1:
						near_high = true
				ok = ok and near_high
			else:
				var near_low := false
				for h in highs:
					var dc := absi(plot.col - h.col)
					var dr := absi(plot.row - h.row)
					if (dc == 2 and dr == 0) or (dc == 0 and dr == 2) or (dc == 1 and dr == 1):
						near_low = true
				ok = ok and near_low
		_check("crystite %d: star expansion (M ortho-1, L ortho-2/diag-1)" % seed_val, ok, [])

func _test_crystite_production() -> void:
	var ok := true
	var plain := Plot.new()
	plain.terrain = Board.Terrain.PLAINS
	plain.crystite_quality = 0
	ok = ok and Economy.crystite_base(plain) == 0
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [], 0) == 0
	plain.crystite_quality = 1
	ok = ok and Economy.crystite_base(plain) == 1
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [], 0) == 1
	plain.crystite_quality = 2
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [], 0) == 2
	plain.crystite_quality = 3
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [], 0) == 3
	plain.crystite_quality = 4
	ok = ok and Economy.crystite_base(plain) == 4
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [], 1) == 5
	var river := Plot.new()
	river.terrain = Board.Terrain.RIVER
	river.crystite_quality = 3
	ok = ok and Economy.crystite_base(river) == 0
	ok = ok and Economy.per_plot_output(river, Economy.Unit.CRYSTITE, [], 5) == 0
	var neighbor := Plot.new()
	neighbor.terrain = Board.Terrain.PLAINS
	neighbor.owner_id = 0
	neighbor.crystite_quality = 3
	neighbor.mule = Mule.new(Economy.Unit.CRYSTITE)
	plain.owner_id = 0
	plain.crystite_quality = 1
	plain.mule = Mule.new(Economy.Unit.CRYSTITE)
	ok = ok and Economy.per_plot_output(plain, Economy.Unit.CRYSTITE, [neighbor], 0) == 2
	_check("crystite production: quality 0-4, river = 0, eco bonus", ok, [])

func _test_crystite_scoring() -> void:
	var prices := {Economy.Unit.FOOD: 30, Economy.Unit.ENERGY: 25, Economy.Unit.SMITHORE: 50, Economy.Unit.CRYSTITE: 150}
	var plot := Plot.new()
	plot.terrain = Board.Terrain.PLAINS
	plot.owner_id = 0
	plot.mule = Mule.new(Economy.Unit.CRYSTITE)
	_check("crystite plot scores 600 (500 + outfit 100)",
		Economy.plot_score(plot) == 600, [])
	var total := Economy.score(1000, Economy.plot_score(plot), 1, 0, 0, 0, 3, prices)
	_check("score includes crystite goods at p_c (1000+600+35+450 = 2085)",
		total == 2085, [total])

func _test_game_state() -> void:
	var gs = root.get_node("/root/GameState")
	gs.new_game(1234)
	var ok := true
	ok = ok and gs.players.size() == 4
	ok = ok and gs.human().is_human
	ok = ok and gs.cpu_players().size() == 3
	ok = ok and gs.board != null
	ok = ok and gs.prices[Economy.Unit.FOOD] == 30
	ok = ok and gs.prices[Economy.Unit.CRYSTITE] == 150
	ok = ok and gs.store_stock["mules"] == 14
	ok = ok and gs.store_stock[Economy.Unit.CRYSTITE] == 20
	ok = ok and gs.store_stock[Economy.Unit.FOOD] == 20
	ok = ok and gs.store_stock[Economy.Unit.ENERGY] == 20
	ok = ok and gs.store_stock[Economy.Unit.SMITHORE] == 20
	ok = ok and gs.total_supply(Economy.Unit.CRYSTITE) == 20
	ok = ok and gs.mule_price() == 100
	_check("GameState.new_game setup", ok, [])

func _check(name: String, ok: bool, detail: Array) -> void:
	if ok:
		print("PASS: ", name)
	else:
		failures += 1
		print("FAIL: ", name, " got ", detail)
