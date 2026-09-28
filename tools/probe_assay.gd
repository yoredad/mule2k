extends SceneTree

var frames := 0
var cpu_plot: Plot
var revealed := 0

func _init() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())

func _process(_delta: float) -> bool:
	frames += 1
	var main: Control = root.get_node("Main")
	var gs: Node = root.get_node("GameState")
	var flow: Node = root.get_node("GameFlow")
	var ui: Control = main
	if frames == 3:
		gs.new_game(1)
		main.board_view.board = gs.board
		for p in gs.board.plots:
			if p.is_empty():
				cpu_plot = p
				break
		gs.cpu_players()[1].plots.append(cpu_plot)
		cpu_plot.owner_id = 2
		flow._set_phase(flow.Phase.DEVELOPMENT)
		flow.dev_player = gs.human()
		flow.actions_left = 5
		flow.assay_revealed.connect(func(_n: String, _c: int, _r: int, _q: int): revealed += 1)
		var ok: bool = flow.dev_start_assay()
		print("start_assay=", ok, " highlights=", main.board_view.highlight_cells.size())
		var done: bool = flow.dev_assay(cpu_plot.col, cpu_plot.row)
		print("assay_cpu_plot=", done, " assayed=", cpu_plot.crystite_assayed,
			" quality=", cpu_plot.crystite_quality, " pending=", flow.pending_assay)
		var silent: bool = flow._do_assay(gs.cpu_players()[0], gs.board.get_plot(1, 1), true)
		print("cpu_silent_assay=", silent, " revealed_signal=", revealed,
			" flash=", main.board_view.flash_cell, " popup=", ui.assay_popup.visible)
		quit(0)
	return false
