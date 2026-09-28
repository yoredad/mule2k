extends SceneTree

var frames := 0

func _init() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())

func _process(_delta: float) -> bool:
	frames += 1
	var main: Control = root.get_node("Main")
	var gs: Node = root.get_node("GameState")
	var flow: Node = root.get_node("GameFlow")
	if frames == 3:
		gs.new_game(1)
		main.board_view.board = gs.board
		var target = null
		for p in gs.board.plots:
			if p.is_empty():
				target = p
				break
		gs.human().plots.append(target)
		target.owner_id = 0
		flow._set_phase(flow.Phase.DEVELOPMENT)
		flow.dev_player = gs.human()
		flow.actions_left = 5
		gs.human().cash = 10000
		flow.dev_start_buy(0)
		var placed: bool = flow.dev_place_mule(target.col, target.row)
		print("buy+place returned=", placed, " plot.mule=", target.mule != null)
		main.board_view.queue_redraw()
	if frames == 9:
		var bv: Control = main.board_view
		var img: Image = root.get_viewport().get_texture().get_image()
		var target = null
		for p in gs.board.plots:
			if p.mule != null:
				target = p
				break
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		var center := Vector2((target.col + 0.5) * cell.x, (target.row + 0.5) * cell.y)
		print("NO HIGHLIGHT: center rgb=(", int(img.get_pixel(int(center.x), int(center.y)).r * 255), ",",
			int(img.get_pixel(int(center.x), int(center.y)).g * 255), ",",
			int(img.get_pixel(int(center.x), int(center.y)).b * 255), ")")
		bv.set_highlights([Vector2i(target.col, target.row)], Color(0.4, 1.0, 0.4, 0.35))
		main.board_view.queue_redraw()
	if frames == 14:
		var bv: Control = main.board_view
		var img: Image = root.get_viewport().get_texture().get_image()
		var target = null
		for p in gs.board.plots:
			if p.mule != null:
				target = p
				break
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		var center := Vector2((target.col + 0.5) * cell.x, (target.row + 0.5) * cell.y)
		print("WITH HIGHLIGHT: center rgb=(", int(img.get_pixel(int(center.x), int(center.y)).r * 255), ",",
			int(img.get_pixel(int(center.x), int(center.y)).g * 255), ",",
			int(img.get_pixel(int(center.x), int(center.y)).b * 255), ")")
		quit(0)
	return false
