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
		var sheet: Texture2D = load("res://assets/mule_sheet.png")
		print("sheet size=", sheet.get_size(), " region=",
			Vector2(sheet.get_width() / 5.0, sheet.get_height() / 4.0))
		var p0: Plot = gs.board.get_plot(0, 0)
		p0.owner_id = 0
		p0.mule = Mule.new(Economy.Unit.FOOD)
		gs.human().plots.append(p0)
		var p1: Plot = gs.board.get_plot(1, 0)
		p1.owner_id = 2
		p1.mule = Mule.new(Economy.Unit.SMITHORE)
		gs.cpu_players()[1].plots.append(p1)
		var p2: Plot = gs.board.get_plot(2, 0)
		p2.owner_id = 0
		gs.human().plots.append(p2)
		bv.queue_redraw()
	if frames == 9:
		var img: Image = root.get_viewport().get_texture().get_image()
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		var sheet: Texture2D = load("res://assets/mule_sheet.png")
		var rw: float = sheet.get_width() / 5.0
		var rh: float = sheet.get_height() / 4.0
		var h: float = cell.y * bv.ICON_HEIGHT_FRAC
		var w: float = h * (rw / rh)
		for tag in ["MULE_F", "MULE_S_ORANGE", "PLACEHOLDER"]:
			var col: int = [0, 1, 2][["MULE_F", "MULE_S_ORANGE", "PLACEHOLDER"].find(tag)]
			var top := Vector2(col * cell.x + (cell.x - w) * 0.5, cell.y - bv.ICON_BOTTOM_OFFSET - h)
			var px: Color = img.get_pixel(int(top.x + w * 0.5), int(top.y + h * 0.5))
			var edge: Color = img.get_pixel(int(top.x + w * 0.5), int(top.y))
			print(tag, " icon center rgb=(", int(px.r * 255), ",", int(px.g * 255), ",", int(px.b * 255),
				") top rgb=(", int(edge.r * 255), ",", int(edge.g * 255), ",", int(edge.b * 255), ")")
		quit(0)
	return false
