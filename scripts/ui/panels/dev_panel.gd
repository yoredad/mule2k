extends PanelContainer

signal buy_pressed(unit: int)
signal refit_pressed(unit: int)
signal assay_pressed
signal wampus_pressed
signal gamble_pressed
signal end_turn_pressed

var title_label: Label
var info_label: Label
var message_label: Label
var buy_buttons: Dictionary = {}
var refit_buttons: Dictionary = {}
var assay_button: Button
var wampus_button: Button
var gamble_button: Button

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	title_label = _make_label(vb, "", 18)
	info_label = _make_label(vb, "", 14)
	message_label = _make_label(vb, "", 13)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

	# Buy buttons
	var buy_label := Label.new()
	buy_label.text = "Buy Mule (1 action):"
	buy_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(buy_label)
	var buy_grid := GridContainer.new()
	buy_grid.columns = 2
	buy_grid.add_theme_constant_override("h_separation", 6)
	vb.add_child(buy_grid)
	for unit in Economy.Unit.values():
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 44)
		b.pressed.connect(buy_pressed.emit.bind(unit))
		buy_grid.add_child(b)
		buy_buttons[unit] = b

	# Refit buttons
	var refit_label := Label.new()
	refit_label.text = "Refit Mule (2 actions):"
	refit_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(refit_label)
	var refit_grid := GridContainer.new()
	refit_grid.columns = 2
	refit_grid.add_theme_constant_override("h_separation", 6)
	vb.add_child(refit_grid)
	for unit in Economy.Unit.values():
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 44)
		b.pressed.connect(refit_pressed.emit.bind(unit))
		refit_grid.add_child(b)
		refit_buttons[unit] = b

	assay_button = Button.new()
	assay_button.text = "Assay Office"
	assay_button.custom_minimum_size = Vector2(0, 44)
	assay_button.pressed.connect(func(): assay_pressed.emit())
	vb.add_child(assay_button)
	wampus_button = Button.new()
	wampus_button.text = "Hunt Wampus"
	wampus_button.custom_minimum_size = Vector2(0, 44)
	wampus_button.pressed.connect(func(): wampus_pressed.emit())
	vb.add_child(wampus_button)
	gamble_button = Button.new()
	gamble_button.custom_minimum_size = Vector2(0, 44)
	gamble_button.pressed.connect(func(): gamble_pressed.emit())
	vb.add_child(gamble_button)
	var end := Button.new()
	end.text = "End Turn"
	end.custom_minimum_size = Vector2(0, 44)
	end.pressed.connect(func(): end_turn_pressed.emit())
	vb.add_child(end)

func refresh(player: Player, actions_left: int, mule_price: int, wampus_active: bool, wampus_reward: int, gamble_grant: int, message: String) -> void:
	title_label.text = "%s's Turn — %d action%s left" % [
		player.display_name(), actions_left, "s" if actions_left != 1 else "",
	]
	info_label.text = "Cash $%d  Mules $%d each" % [player.cash, mule_price]
	# Check if player has any empty plots to place mules
	var has_empty_plots := player.empty_plots().size() > 0
	for unit in Economy.Unit.values():
		var b: Button = buy_buttons[unit]
		b.text = "Buy %s ($%d)" % [Economy.UNIT_NAMES[unit], mule_price + Economy.OUTFIT_COST[unit]]
		b.disabled = actions_left <= 0 or not has_empty_plots

		var r: Button = refit_buttons[unit]
		r.text = "Refit to %s ($%d)" % [Economy.UNIT_NAMES[unit], Economy.OUTFIT_COST[unit]]
		r.disabled = actions_left < 2
	assay_button.disabled = actions_left <= 0
	wampus_button.visible = wampus_active
	wampus_button.text = "Hunt Wampus (+$%d)" % wampus_reward
	gamble_button.text = "Gamble (1 action, +$%d, ends turn)" % gamble_grant
	gamble_button.disabled = actions_left <= 0
	message_label.text = message

func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
