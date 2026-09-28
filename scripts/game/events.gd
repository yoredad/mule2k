class_name Events
extends RefCounted

static func roll_round_event(rng: RandomNumberGenerator) -> int:
	return Economy.roll_event(rng)

static func event_multiplier(event: int, unit: int) -> float:
	match event:
		Economy.Event.SUNSPOTS:
			if unit == Economy.Unit.ENERGY:
				return 2.0
		Economy.Event.ACID_RAIN:
			if unit == Economy.Unit.FOOD:
				return 2.0
			if unit == Economy.Unit.ENERGY:
				return 0.5
		Economy.Event.PLANETQUAKE:
			if unit == Economy.Unit.SMITHORE or unit == Economy.Unit.CRYSTITE:
				return 0.5
	return 1.0

static func apply_round_event(gs: GameState, event: int, rng: RandomNumberGenerator) -> Dictionary:
	var result = {"message": "", "plot": null}
	match event:
		Economy.Event.PIRATES:
			for p in gs.players:
				p.crystite = 0
			result.message = "Pirates take ALL crystite!"
		Economy.Event.FIRE_IN_STORE:
			for unit in Economy.Unit.values():
				gs.store_stock[unit] = 0
			result.message = "Fire in Store! All stock lost!"
		Economy.Event.RADIATION:
			var mule_plots: Array = []
			for p in gs.players:
				for plot in p.plots:
					if plot.mule != null:
						mule_plots.append(plot)
			if mule_plots.size() > 0:
				var target: Plot = mule_plots[rng.randi_range(0, mule_plots.size() - 1)]
				var owner: Player = gs.players[target.owner_id]
				target.mule = null
				result.message = "%s's mule goes crazy and runs away!" % owner.display_name()
			else:
				result.message = "Radiation sweeps the colony (no mules harmed)."
		Economy.Event.METEORITE:
			if gs.meteorite_strikes >= 3:
				result.message = "Meteorite passes harmlessly overhead."
			else:
				var candidates: Array = gs.board.plots.filter(func(p): return not p.is_store())
				var plot: Plot = candidates[rng.randi_range(0, candidates.size() - 1)]
				if plot.mule != null:
					plot.mule = null
				plot.crystite_quality = Board.CRYSTITE_QUALITY_EXTRA_HIGH
				plot.crystite_assayed = false
				gs.meteorite_strikes += 1
				result.message = "Meteorite Strike! %s gains EXTRA HIGH crystite." % plot.terrain_name()
				result.plot = plot
		Economy.Event.PEST:
			var food_plots: Array = []
			for p in gs.players:
				for plot in p.plots:
					if plot.mule != null and plot.mule.unit == Economy.Unit.FOOD:
						food_plots.append(plot)
			if food_plots.size() > 0:
				gs.pest_plot = food_plots[rng.randi_range(0, food_plots.size() - 1)]
				result.message = "Pest Attack! A food plot yields nothing this round."
			else:
				result.message = "Pest Attack! (no food plots to hit)"
	return result
