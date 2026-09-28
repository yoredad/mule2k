extends PanelContainer

signal closed

var scroll: ScrollContainer
var text_label: RichTextLabel

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var title := Label.new()
	title.text = "How to Play"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.text = """
[b]Goal:[/b] Build the best colony. 12 rounds, 4 players (1 human + 3 CPU). Colony total >= $60,000 wins — otherwise everyone is sent home to work in a M.U.L.E. factory.

[b]Land Grant (rounds 1-11):[/b] Worst-off players pick first. Tap a highlighted plot to claim it.

[b]Development:[/b] Each turn you get 2-6 actions (more food = more actions, minimum 2). Each action: buy + mount a mule (Food $25, Energy $50, Smithore $75, Crystite $100 outfit + mule price), use the Assay Office (1 action, reveals hidden crystite on any plot for all to see), hunt the Wampus (60% catch, big cash reward), or Gamble (1 action, ends your turn, cash scales with round).

[b]Production:[/b] Plains: food 2 / energy 3 / smithore 1. River: food 4 / energy 2 (no mining). Mountains: smithore 1-3. Adjacent same-owner plots producing the same good get +1. Growth x1.08 per round. Energy mules need no energy; every other mule needs 1 energy or a random mule produces 0.

[b]Consumption:[/b] Food needed per round: 3 (R1-4), 4 (R5-8), 5 (R9-12). Energy needed = # non-energy mules. After eating: food spoils by half, energy by a quarter, smithore/crystite cap at 50.

[b]Store & Prices:[/b] Supply/demand each round. Store buys at price - $15 (smithore/crystite at price) and sells at + $35. Crystite is the most expensive good ($150-$500); store starts with 20 of every good. Mule price = 2x smithore price rounded to $10; the store builds 1 new mule per 2 smithore it holds.

[b]Auctions:[/b] Smithore, Food, Energy, Crystite. Sell surplus, buy what you lack, or list player-to-player offers. Crystal quality gems: gray = none, green = low, yellow = medium, orange = high, red = extra high.

[b]Events:[/b] One event every round 1-11 (sunspots, acid rain, pests, planetquake, meteorite, fire, pirates, radiation — check the animated icon). The leader may lose a plot of land and the last-place player may receive one — checked at the start of each player's turn.

[b]Scoring:[/b] Cash + plots (500 + outfit) + mules x35 + goods at current prices.
"""
	scroll.add_child(text_label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	vb.add_child(close)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var w: int = clampi(int(vs.x) - 160, 420, 760)
	var h: int = clampi(int(vs.y) - 160, 320, 480)
	scroll.custom_minimum_size = Vector2(w, h)
	text_label.custom_minimum_size = Vector2(w, 0)
