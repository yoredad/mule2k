extends SceneTree

var flow: Node
var gs: Node
var started := false
var placed_mule := false
var checks := {}

func _init() -> void:
	var packed = load("res://scenes/main.tscn")
	root.add_child(packed.instantiate())

func _process(_delta: float) -> bool:
	if not started:
		started = true
		flow = root.get_node("GameFlow")
		gs = root.get_node("GameState")
		var bv: Node = root.get_node("Main/BoardView")
		print("PIP_REGIONS: ", bv.pip_regions)
		print("SIMULATE: ", flow.simulate)
		flow.phase_changed.connect(func(p: int):
			print("PHASE -> ", flow.PHASE_NAMES[p], " round ", gs.round_number,
				" results ", flow.production_results.size()))
		flow.start_game(7)
		return false
	_drive()
	return false

func _drive() -> void:
	match flow.phase:
		flow.Phase.LAND_GRANT:
			if flow.grant_index < flow.grant_order.size() and flow.grant_order[flow.grant_index].is_human:
				var unclaimed: Array = gs.board.unclaimed_plots()
				if not unclaimed.is_empty():
					flow.claim_plot(unclaimed[0].col, unclaimed[0].row)
		flow.Phase.DEVELOPMENT:
			if flow.dev_player != null and flow.dev_player.is_human:
				if not placed_mule:
					placed_mule = true
					if flow.dev_start_buy(Economy.Unit.FOOD):
						var plot: Plot = gs.human().empty_plots()[0]
						flow.dev_place_mule(plot.col, plot.row)
				flow.dev_end_turn()
		flow.Phase.PRODUCTION:
			if not flow.production_results.is_empty() and not checks.has("pips"):
				checks["pips"] = true
				print("PIPS: %d plots produced" % flow.production_results.size())
				print("SAMPLE: ", flow.production_results.values()[0])
			if not checks.has("paused"):
				checks["paused"] = true
				print("PAUSED: phase stays ", flow.phase, " until continue")
			flow.production_continue()
			if not checks.has("continued"):
				checks["continued"] = true
				print("CONTINUE: phase after -> ", flow.phase)
		flow.Phase.AUCTION:
			flow.auction_done()
		flow.Phase.SUMMARY:
			flow.summary_next()
		flow.Phase.GAME_OVER:
			if not checks.has("done"):
				checks["done"] = true
				print("PROBE DONE: round ", gs.round_number,
					", results cleared: ", flow.production_results.is_empty())
			quit(0)
