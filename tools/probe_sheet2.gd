extends SceneTree

var frames := 0

func _init() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())

func _process(_delta: float) -> bool:
	frames += 1
	var main: Control = root.get_node("Main")
	var gs: Node = root.get_node("GameState")
	var bv: Control = main.board_view
	if frames == 3:
		gs.new_game(1)
		bv.board = gs.board
		print("regions=", bv.mule_regions.size())
		for r in 4:
			for c in 5:
				print("region r", r, "c", c, "=", bv.mule_regions[r * 5 + c])
		var p0: Plot = gs.board.get_plot(0, 0)
		p0.owner_id = 0
		p0.mule = Mule.new(Economy.Unit.FOOD)
		gs.human().plots.append(p0)
		var p1: Plot = gs.board.get_plot(1, 0)
		p1.owner_id = 2
		p1.mule = Mule.new(Economy.Unit.SMITHORE)
		gs.cpu_players()[1].plots.append(p1)
		var p2: Plot = gs.board.get_plot(2, 0)
		p2.owner_id = 3
		gs.cpu_players()[2].plots.append(p2)
		bv.queue_redraw()
	if frames == 9:
		var img: Image = root.get_viewport().get_texture().get_image()
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		for tag in ["MULE_F_GREEN", "MULE_S_RED", "PLACEHOLDER_PURPLE"]:
			var col: int = [0, 1, 2][["MULE_F_GREEN", "MULE_S_RED", "PLACEHOLDER_PURPLE"].find(tag)]
			var h: float = cell.y * bv.ICON_HEIGHT_FRAC
			var region: Rect2 = bv.mule_regions[[0, 5, 19][["MULE_F_GREEN", "MULE_S_RED", "PLACEHOLDER_PURPLE"].find(tag)]]
			var w: float = h * (region.size.x / region.size.y)
			var top := Vector2(col * cell.x + (cell.x - w) * 0.5, cell.y - bv.ICON_BOTTOM_OFFSET - h)
			var px: Color = img.get_pixel(int(top.x + w * 0.5), int(top.y + h * 0.5))
			print(tag, " icon center rgb=(", int(px.r * 255), ",", int(px.g * 255), ",", int(px.b * 255), ")")
		quit(0)
	return false
