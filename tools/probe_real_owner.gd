extends SceneTree

var frames := 0
var claimed_human := false
var human_plot: Plot
var revealed_log: Array = []

func _init() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())

func _process(_delta: float) -> bool:
	frames += 1
	var main: Control = root.get_node("Main")
	var gs: Node = root.get_node("GameState")
	var flow: Node = root.get_node("GameFlow")
	var bv: Control = main.board_view
	if frames == 3:
		flow.assay_revealed.connect(func(n: String, c: int, r: int, q: int):
			revealed_log.append([frames, c, r, q, n]))
		flow.human_turn_started.connect(func(p: Player):
			print("HUMAN_TURN frame=", frames, " player=", p.display_name(), " is_human=", p.is_human))
		flow.start_game(1)
		bv.board = gs.board
	if not claimed_human and flow.phase == flow.Phase.LAND_GRANT \
			and flow.grant_index < flow.grant_order.size():
		var p: Player = flow.grant_order[flow.grant_index]
		if p.is_human:
			for plot in gs.board.plots:
				if plot.is_empty():
					human_plot = plot
					break
			var ok: bool = flow.claim_plot(human_plot.col, human_plot.row)
			print("human claimed=", ok, " plot=", human_plot.col, ",", human_plot.row,
				" owner=", human_plot.owner_id)
			claimed_human = true
	if frames > 500 and flow.phase != flow.Phase.LAND_GRANT:
		var img: Image = root.get_viewport().get_texture().get_image()
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		var checked := 0
		var matched := 0
		for plot in gs.board.plots:
			if plot.is_claimed():
				var px: Color = img.get_pixel(int((plot.col + 0.5) * cell.x), int(plot.row * cell.y + 2.0))
				var expected: Color = Player.COLORS[plot.owner_id]
				if absf(px.r - expected.r) < 0.25 and absf(px.g - expected.g) < 0.25 \
						and absf(px.b - expected.b) < 0.25:
					matched += 1
				else:
					print("MISMATCH plot ", plot.col, ",", plot.row, " owner=", plot.owner_id,
						" px=(", int(px.r * 255), ",", int(px.g * 255), ",", int(px.b * 255), ")",
						" exp=(", int(expected.r * 255), ",", int(expected.g * 255), ",", int(expected.b * 255), ")")
				checked += 1
		print("checked=", checked, " matched=", matched, " phase=", flow.phase,
			" flash=", bv.flash_cell, " highlights=", bv.highlight_cells.size())
		for r in revealed_log:
			print("REVEALED frame=", r[0], " plot=", r[1], ",", r[2], " q=", r[3], " who=", r[4])
		quit(0)
	return false
