extends Control

var hamburger_button: Button
var info_panel: VBoxContainer
var round_label: Label
var prices_label: Label
var store_label: Label
var player_labels: Array[Label] = []
var is_expanded: bool = false

@onready var gs: Node = get_node("/root/GameState")
@onready var flow: Node = get_node("/root/GameFlow")

func _ready() -> void:
	# Set mouse filter to pass through - only children will intercept
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create hamburger button
	hamburger_button = Button.new()
	hamburger_button.text = "☰"
	hamburger_button.custom_minimum_size = Vector2(48, 48)
	hamburger_button.add_theme_font_size_override("font_size", 28)
	hamburger_button.pressed.connect(_toggle_panel)
	add_child(hamburger_button)

	# Create info panel (initially hidden)
	info_panel = VBoxContainer.new()
	info_panel.add_theme_constant_override("separation", 4)
	info_panel.visible = false
	info_panel.position = Vector2(0, 48)
	add_child(info_panel)

	# Add background to info panel
	var panel_bg := PanelContainer.new()
	info_panel.add_child(panel_bg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel_bg.add_child(vb)

	_make_label(vb, "M.U.L.E. 2K", 26)
	round_label = _make_label(vb, "", 16)
	prices_label = _make_label(vb, "", 16)
	store_label = _make_label(vb, "", 16)
	for i in 4:
		player_labels.append(_make_label(vb, "", 14))

func _make_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _toggle_panel() -> void:
	is_expanded = !is_expanded
	info_panel.visible = is_expanded

func _process(_delta: float) -> void:
	if gs.board == null:
		return
	round_label.text = "Round %d / %d — %s" % [gs.round_number, Economy.MAX_ROUNDS, flow.PHASE_NAMES[flow.phase]]
	prices_label.text = "Prices  Food $%d  Energy $%d  Smithore $%d  Crystite $%d" % [
		gs.prices[Economy.Unit.FOOD],
		gs.prices[Economy.Unit.ENERGY],
		gs.prices[Economy.Unit.SMITHORE],
		gs.prices[Economy.Unit.CRYSTITE],
	]
	store_label.text = "Store  F%d E%d S%d C%d  Mules %d ($%d each)" % [
		gs.store_stock[Economy.Unit.FOOD],
		gs.store_stock[Economy.Unit.ENERGY],
		gs.store_stock[Economy.Unit.SMITHORE],
		gs.store_stock[Economy.Unit.CRYSTITE],
		gs.store_stock["mules"],
		gs.mule_price(),
	]
	for i in gs.players.size():
		var p: Player = gs.players[i]
		player_labels[i].text = "%s: $%d  F%d E%d S%d  mules %d  score %d" % [
			p.display_name(), p.cash, p.food, p.energy, p.smithore, p.mule_count(), p.score,
		]
