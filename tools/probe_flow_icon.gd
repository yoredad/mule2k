extends SceneTree

var frames := 0
var target: Plot

func _init() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())

func _sample(tag: String, bv: Control) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
	var region: Rect2 = bv.mule_regions[4]
	var h: float = cell.y * bv.ICON_HEIGHT_FRAC
	var w: float = h * (region.size.x / region.size.y)
	var top := Vector2((target.col + 0.5) * cell.x - w * 0.5, (target.row + 1) * cell.y - bv.ICON_BOTTOM_OFFSET - h)
	var lit := 0
	for dy in range(4, int(h) - 4, 4):
		for dx in range(4, int(w) - 4, 4):
			var px: Color = img.get_pixel(int(top.x + dx), int(top.y + dy))
			if px.r + px.g + px.b > 1.8:
				lit += 1
	print(tag, " light-pixel count in icon area=", lit)

func _process(_delta: float) -> bool:
	frames += 1
	var main: Control = root.get_node("Main")
	var gs: Node = root.get_node("GameState")
	var flow: Node = root.get_node("GameFlow")
	var bv: Control = main.board_view
	if frames == 3:
		gs.new_game(1)
		bv.board = gs.board
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
		bv.queue_redraw()
	if frames == 9:
		_sample("CLAIMED_NO_MULE", bv)
		flow.dev_start_buy(Economy.Unit.FOOD)
		var ok: bool = flow.dev_place_mule(target.col, target.row)
		print("place returned=", ok, " mule=", target.mule != null)
		bv.queue_redraw()
	if frames == 15:
		_sample("AFTER_MULE_PLACED", bv)
		var unclaimed: Plot = null
		for p in gs.board.plots:
			if p.is_empty():
				unclaimed = p
				break
		var img: Image = root.get_viewport().get_texture().get_image()
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		var center := Vector2((unclaimed.col + 0.5) * cell.x, (unclaimed.row + 0.5) * cell.y)
		var px: Color = img.get_pixel(int(center.x), int(center.y))
		print("UNCLAIMED center rgb=(", int(px.r * 255), ",", int(px.g * 255), ",", int(px.b * 255), ")")
		quit(0)
	return false
