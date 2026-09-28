extends PanelContainer

signal next_pressed

var rows_box: VBoxContainer
var next_button: Button

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var title := Label.new()
	title.text = "Status Summary"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	vb.add_child(rows_box)
	next_button = Button.new()
	next_button.text = "Next Round"
	next_button.custom_minimum_size = Vector2(0, 48)
	next_button.pressed.connect(func(): next_pressed.emit())
	vb.add_child(next_button)

func refresh(rows: Array, last_round: bool) -> void:
	for child in rows_box.get_children():
		child.queue_free()
	for row in rows:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", row.color)
		label.text = "#%d  %s\n   cash $%d  plots %d  mules %d  F%d E%d S%d C%d\n   SCORE %d" % [
			row.rank, row.name, row.cash, row.plots, row.mules,
			row.food, row.energy, row.smithore, row.crystite, row.score,
		]
		rows_box.add_child(label)
	next_button.text = "View Result" if last_round else "Next Round"
