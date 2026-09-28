extends PanelContainer

signal sell_pressed(unit: int, qty: int)
signal buy_pressed(unit: int, qty: int)
signal list_pressed(unit: int, qty: int, price: int)
signal accept_pressed(index: int)
signal done_pressed

var title_label: Label
var info_label: Label
var qty_label: Label
var price_label: Label
var status_label: Label
var offers_box: VBoxContainer
var list_qty := 1
var list_price := 30
var last_unit := -1
var last_buy := 30
var last_sell := 65

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	title_label = _make_label(vb, "", 20)
	info_label = _make_label(vb, "", 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var sell1 := Button.new()
	sell1.text = "Sell 1"
	sell1.custom_minimum_size = Vector2(110, 46)
	sell1.pressed.connect(func(): sell_pressed.emit(last_unit, 1))
	row.add_child(sell1)
	var sell_all := Button.new()
	sell_all.text = "Sell All"
	sell_all.custom_minimum_size = Vector2(110, 46)
	sell_all.pressed.connect(func(): sell_pressed.emit(last_unit, 99999))
	row.add_child(sell_all)
	var buy1 := Button.new()
	buy1.text = "Buy 1"
	buy1.custom_minimum_size = Vector2(110, 46)
	buy1.pressed.connect(func(): buy_pressed.emit(last_unit, 1))
	row.add_child(buy1)
	var buy_all := Button.new()
	buy_all.text = "Buy All"
	buy_all.custom_minimum_size = Vector2(110, 46)
	buy_all.pressed.connect(func(): buy_pressed.emit(last_unit, 99999))
	row.add_child(buy_all)
	var list_header := _make_label(vb, "List an offer (up to $999; CPUs counter if too high)", 13)
	list_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	var list_row := HBoxContainer.new()
	list_row.add_theme_constant_override("separation", 8)
	vb.add_child(list_row)
	var qminus := Button.new()
	qminus.text = "-"
	qminus.custom_minimum_size = Vector2(44, 46)
	qminus.pressed.connect(_qty_adj.bind(-1))
	list_row.add_child(qminus)
	qty_label = _make_label(list_row, "Qty 1", 15)
	var qplus := Button.new()
	qplus.text = "+"
	qplus.custom_minimum_size = Vector2(44, 46)
	qplus.pressed.connect(_qty_adj.bind(1))
	list_row.add_child(qplus)
	var pminus := Button.new()
	pminus.text = "-$"
	pminus.custom_minimum_size = Vector2(44, 46)
	pminus.pressed.connect(_price_adj.bind(-5))
	list_row.add_child(pminus)
	price_label = _make_label(list_row, "Price $30", 15)
	var pplus := Button.new()
	pplus.text = "+$"
	pplus.custom_minimum_size = Vector2(44, 46)
	pplus.pressed.connect(_price_adj.bind(5))
	list_row.add_child(pplus)
	var list_button := Button.new()
	list_button.text = "List Offer"
	list_button.custom_minimum_size = Vector2(130, 46)
	list_button.pressed.connect(func(): list_pressed.emit(last_unit, list_qty, list_price))
	list_row.add_child(list_button)
	status_label = _make_label(vb, "", 14)
	offers_box = VBoxContainer.new()
	offers_box.add_theme_constant_override("separation", 4)
	vb.add_child(offers_box)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(0, 46)
	done.pressed.connect(func(): done_pressed.emit())
	vb.add_child(done)

func refresh(unit: int, gs: Node, offers: Array, listing: Dictionary, sales: Array) -> void:
	if unit < 0:
		return
	last_unit = unit
	var p: Player = gs.human()
	var price: int = gs.prices[unit]
	last_buy = Economy.store_buy_price(unit, price)
	last_sell = Economy.store_sell_price(unit, price)
	title_label.text = "Auction: %s" % Economy.UNIT_NAMES[unit]
	info_label.text = "Your stock: %d  cash $%d\nStore: %d units — buys at $%d, sells at $%d" % [
		p.inventory(unit), p.cash, gs.store_stock.get(unit, 0), last_buy, last_sell,
	]
	list_qty = 1
	list_price = last_buy
	qty_label.text = "Qty %d" % list_qty
	price_label.text = "Price $%d" % list_price
	var lines: Array[String] = []
	if listing.get("qty", 0) > 0:
		lines.append("Listed %d @ $%d" % [listing.qty, listing.price])
	for s in sales:
		lines.append("%s bought %d @ $%d" % [s.name, s.qty, s.price])
	status_label.text = "\n".join(lines)
	for child in offers_box.get_children():
		child.queue_free()
	for i in offers.size():
		var offer: Dictionary = offers[i]
		if offer.get("qty", 0) <= 0:
			continue
		var b := Button.new()
		if offer.get("kind", "sell") == "buy":
			b.text = "Sell %d to %s at $%d" % [offer.qty, gs.players[offer.from_id].display_name(), offer.price]
		else:
			b.text = "Buy %d from %s at $%d" % [offer.qty, gs.players[offer.from_id].display_name(), offer.price]
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(accept_pressed.emit.bind(i))
		offers_box.add_child(b)

func _qty_adj(delta: int) -> void:
	list_qty = maxi(1, list_qty + delta)
	qty_label.text = "Qty %d" % list_qty

func _price_adj(delta: int) -> void:
	list_price = clampi(list_price + delta, last_buy, 999)
	price_label.text = "Price $%d" % list_price

func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
