extends PanelContainer

signal start_pressed
signal howto_pressed
signal quit_pressed

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var title := Label.new()
	title.text = "M.U.L.E. 2K"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vb.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Colonize a planet. Don't get sent home."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vb.add_child(subtitle)
	var start := Button.new()
	start.text = "Start Game"
	start.custom_minimum_size = Vector2(300, 52)
	start.pressed.connect(func(): start_pressed.emit())
	vb.add_child(start)
	var howto := Button.new()
	howto.text = "How to Play"
	howto.custom_minimum_size = Vector2(300, 52)
	howto.pressed.connect(func(): howto_pressed.emit())
	vb.add_child(howto)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(300, 52)
	quit.pressed.connect(func(): quit_pressed.emit())
	vb.add_child(quit)
