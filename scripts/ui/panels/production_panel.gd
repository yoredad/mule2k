extends PanelContainer

signal continue_pressed

var title_label: Label
var summary_label: Label

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	title_label = _make_label(vb, "", 18)
	summary_label = _make_label(vb, "", 14)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(460, 0)
	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func(): continue_pressed.emit())
	vb.add_child(button)

func refresh(round_number: int, results: Dictionary, gs: Node) -> void:
	title_label.text = "Round %d Production" % round_number
	var per_player := {}
	for key in results:
		var cell_pos: Vector2i = key
		var plot: Plot = gs.board.get_plot(cell_pos.x, cell_pos.y)
		if plot == null or plot.owner_id < 0:
			continue
		var entry: Dictionary = results[key]
		var unit: int = entry.get("unit", 0)
		if not per_player.has(plot.owner_id):
			per_player[plot.owner_id] = {}
		per_player[plot.owner_id][unit] = per_player[plot.owner_id].get(unit, 0) + entry.get("count", 0)
	var lines: Array[String] = []
	for pid in per_player:
		var parts: Array[String] = []
		for unit in Economy.Unit.values():
			if per_player[pid].has(unit):
				parts.append("%d %s" % [per_player[pid][unit], Economy.UNIT_NAMES[unit]])
		lines.append("%s: %s" % [gs.players[pid].display_name(), ", ".join(parts)])
	if lines.is_empty():
		lines.append("No production this round.")
	summary_label.text = "\n".join(lines)

func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
