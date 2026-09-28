extends PanelContainer

signal again_pressed

var result_label: Label

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var title := Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	vb.add_child(title)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(result_label)
	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(260, 52)
	again.pressed.connect(func(): again_pressed.emit())
	vb.add_child(again)

func refresh(results: Dictionary) -> void:
	var lines: Array[String] = []
	if results.success:
		lines.append("THE COLONY SUCCEEDS!")
		lines.append("First Founder: %s" % results.winner_name)
	else:
		lines.append("COLONY FAILED")
		lines.append("Everyone is sent home to work in a M.U.L.E. factory.")
	lines.append("Colony total: $%d" % results.colony_total)
	lines.append("Colony rating: %d" % results.rating)
	result_label.text = "\n".join(lines)
	if results.success:
		result_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
