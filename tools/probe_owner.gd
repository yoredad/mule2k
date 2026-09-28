extends SceneTree

var frames := 0
var p_human: Plot
var p_cpu: Plot
var p_none: Plot

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
		p_human = gs.board.get_plot(0, 0)
		p_human.owner_id = 0
		gs.human().plots.append(p_human)
		p_cpu = gs.board.get_plot(1, 0)
		p_cpu.owner_id = 2
		gs.cpu_players()[1].plots.append(p_cpu)
		p_none = gs.board.get_plot(2, 0)
		bv.queue_redraw()
	if frames == 9:
		var img: Image = root.get_viewport().get_texture().get_image()
		var cell := Vector2(bv.size.x / 9.0, bv.size.y / 5.0)
		for tag in ["HUMAN", "CPU", "UNCLAIMED"]:
			var col: int = [0, 1, 2][["HUMAN", "CPU", "UNCLAIMED"].find(tag)]
			var plot: Plot = [p_human, p_cpu, p_none][["HUMAN", "CPU", "UNCLAIMED"].find(tag)]
			print(tag, " terrain=", plot.terrain, " owner=", plot.owner_id)
			for y in range(0, 8):
				var line := ""
				for x in range(0, 10):
					var px: Color = img.get_pixel(int(col * cell.x + x * 2.0), int(y * 2.0))
					var ch := "."
					if px.r > 0.3 and px.g > 0.3 and px.b > 0.3:
						ch = "#"
					elif px.r > 0.6 and px.g < 0.4 and px.b < 0.4:
						ch = "R"
					elif px.g > 0.6 and px.r < 0.5 and px.b < 0.5:
						ch = "G"
					elif px.b > 0.6 and px.r < 0.5:
						ch = "B"
					elif px.r > 0.5 and px.g > 0.3 and px.b < 0.3:
						ch = "O"
					line += ch
				print("  ", line)
		quit(0)
	return false
