extends PanelContainer

signal bid_submitted(amount: int)

var plot_label: Label
var bids_label: Label
var bid_input: LineEdit
var bid_button: Button
var pass_button: Button

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var title := Label.new()
	title.text = "Plot Auction"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	plot_label = Label.new()
	plot_label.add_theme_font_size_override("font_size", 16)
	plot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(plot_label)

	bids_label = Label.new()
	bids_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(bids_label)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)

	var input_label := Label.new()
	input_label.text = "Your Bid: $"
	input_label.add_theme_font_size_override("font_size", 16)
	hb.add_child(input_label)

	bid_input = LineEdit.new()
	bid_input.custom_minimum_size = Vector2(120, 44)
	bid_input.text = "0"
	bid_input.add_theme_font_size_override("font_size", 16)
	hb.add_child(bid_input)

	var button_hb := HBoxContainer.new()
	button_hb.add_theme_constant_override("separation", 8)
	vb.add_child(button_hb)

	bid_button = Button.new()
	bid_button.text = "Submit Bid"
	bid_button.custom_minimum_size = Vector2(160, 44)
	bid_button.pressed.connect(_on_bid_pressed)
	button_hb.add_child(bid_button)

	pass_button = Button.new()
	pass_button.text = "Pass (Bid $0)"
	pass_button.custom_minimum_size = Vector2(160, 44)
	pass_button.pressed.connect(_on_pass_pressed)
	button_hb.add_child(pass_button)

func refresh(plot: Plot, bids: Dictionary, player_cash: int) -> void:
	plot_label.text = "Auctioning Plot (%d,%d) - %s" % [plot.col, plot.row, plot.terrain_name()]

	var bid_text := "Current Bids:\n"
	var high_bid := 0
	for player_id in bids.keys():
		var bid: int = bids[player_id]
		if bid > high_bid:
			high_bid = bid

	for player_id in bids.keys():
		var bid: int = bids[player_id]
		var player_name := Player.COLOR_NAMES[player_id]
		if bid == high_bid and bid > 0:
			bid_text += "%s: $%d (HIGH BID)\n" % [player_name, bid]
		elif bid > 0:
			bid_text += "%s: $%d\n" % [player_name, bid]
		else:
			bid_text += "%s: Passed\n" % player_name

	bid_text += "\nYour Cash: $%d" % player_cash
	bids_label.text = bid_text

	# Set suggested bid to beat high bid
	if high_bid > 0:
		bid_input.text = str(high_bid + 10)
	else:
		bid_input.text = "50"

	# Show minimum bid required
	bid_input.placeholder_text = "Min bid: $%d" % (high_bid + 1 if high_bid > 0 else 1)

func _on_bid_pressed() -> void:
	var amount := bid_input.text.to_int()
	# Validate bid is higher than current high bid
	if amount <= 0:
		# Treat 0 or negative as pass
		bid_submitted.emit(0)
	else:
		bid_submitted.emit(amount)

func _on_pass_pressed() -> void:
	bid_submitted.emit(0)
