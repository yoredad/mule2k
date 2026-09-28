extends Control

const MenuPanelScript = preload("res://scripts/ui/panels/menu_panel.gd")
const HowtoPanelScript = preload("res://scripts/ui/panels/howto_panel.gd")
const DevPanelScript = preload("res://scripts/ui/panels/dev_panel.gd")
const AuctionPanelScript = preload("res://scripts/ui/panels/auction_panel.gd")
const StatusPanelScript = preload("res://scripts/ui/panels/status_panel.gd")
const EndPanelScript = preload("res://scripts/ui/panels/end_panel.gd")
const ProductionPanelScript = preload("res://scripts/ui/panels/production_panel.gd")
const PlotAuctionPanelScript = preload("res://scripts/ui/panels/plot_auction_panel.gd")

var gs: Node
var flow: Node
var board_view: Control

var banner_panel: PanelContainer
var banner_label: Label
var banner_icon: AnimatedSprite2D
var banner_timer: Timer
var hint_label: Label

var menu_panel: PanelContainer
var howto_panel: PanelContainer
var dev_panel: PanelContainer
var auction_panel: PanelContainer
var status_panel: PanelContainer
var end_panel: PanelContainer
var production_panel: PanelContainer
var plot_auction_panel: PanelContainer
var assay_popup: PanelContainer
var assay_label: Label

func _ready() -> void:
	gs = get_node("/root/GameState")
	flow = get_node("/root/GameFlow")
	board_view = get_node("BoardView")
	_build_banner()
	_build_hint()
	_build_panels()
	_connect_flow()
	_show_only(menu_panel)

func _build_banner() -> void:
	banner_panel = PanelContainer.new()
	banner_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner_panel.position = Vector2(0, 36)
	banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_panel.z_index = 100  # Ensure banner renders on top
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	banner_icon = AnimatedSprite2D.new()
	banner_icon.scale = Vector2(2.0, 2.0)
	hb.add_child(banner_icon)
	banner_label = Label.new()
	banner_label.add_theme_font_size_override("font_size", 22)
	hb.add_child(banner_label)
	banner_panel.add_child(hb)
	add_child(banner_panel)
	banner_timer = Timer.new()
	banner_timer.wait_time = 4.0
	banner_timer.one_shot = true
	banner_timer.timeout.connect(func(): banner_panel.visible = false)
	add_child(banner_timer)
	banner_panel.visible = false

func _build_hint() -> void:
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(0, -24)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 5)
	add_child(hint_label)

func _build_panels() -> void:
	menu_panel = MenuPanelScript.new()
	_center_overlay(menu_panel)
	add_child(menu_panel)
	howto_panel = HowtoPanelScript.new()
	_center_overlay(howto_panel)
	add_child(howto_panel)
	dev_panel = DevPanelScript.new()
	dev_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dev_panel.position = Vector2(0, -12)
	dev_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dev_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(dev_panel)
	auction_panel = AuctionPanelScript.new()
	_center_overlay(auction_panel)
	add_child(auction_panel)
	status_panel = StatusPanelScript.new()
	_center_overlay(status_panel)
	add_child(status_panel)
	end_panel = EndPanelScript.new()
	_center_overlay(end_panel)
	add_child(end_panel)
	production_panel = ProductionPanelScript.new()
	production_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	production_panel.position = Vector2(0, -12)
	production_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	production_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(production_panel)
	plot_auction_panel = PlotAuctionPanelScript.new()
	_center_overlay(plot_auction_panel)
	add_child(plot_auction_panel)
	assay_popup = PanelContainer.new()
	_center_overlay(assay_popup)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	assay_label = Label.new()
	assay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assay_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(assay_label)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(160, 44)
	ok.pressed.connect(func(): assay_popup.visible = false)
	vb.add_child(ok)
	assay_popup.add_child(vb)
	add_child(assay_popup)
	assay_popup.visible = false
	_show_only(menu_panel)

func _center_overlay(p: Control) -> void:
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH

func _connect_flow() -> void:
	menu_panel.start_pressed.connect(func(): flow.start_game())
	menu_panel.howto_pressed.connect(func(): _show_only(howto_panel))
	menu_panel.quit_pressed.connect(func(): get_tree().quit())
	howto_panel.closed.connect(func(): _show_only(menu_panel))
	dev_panel.buy_pressed.connect(func(unit: int):
		if flow.dev_start_buy(unit):
			dev_panel.visible = false
	)
	dev_panel.refit_pressed.connect(func(unit: int):
		if flow.dev_start_refit(unit):
			dev_panel.visible = false
	)
	dev_panel.assay_pressed.connect(func():
		if flow.dev_start_assay():
			dev_panel.visible = false
	)
	dev_panel.wampus_pressed.connect(func(): flow.dev_wampus())
	dev_panel.gamble_pressed.connect(func(): flow.dev_gamble())
	dev_panel.end_turn_pressed.connect(func(): flow.dev_end_turn())
	auction_panel.sell_pressed.connect(func(unit: int, qty: int): flow.auction_sell(unit, qty))
	auction_panel.buy_pressed.connect(func(unit: int, qty: int): flow.auction_buy(unit, qty))
	auction_panel.list_pressed.connect(func(unit: int, qty: int, price: int): flow.auction_list(unit, qty, price))
	auction_panel.accept_pressed.connect(func(index: int): flow.auction_accept_offer(index))
	auction_panel.done_pressed.connect(func(): flow.auction_done())
	status_panel.next_pressed.connect(func(): flow.summary_next())
	end_panel.again_pressed.connect(func(): flow.start_game())
	production_panel.continue_pressed.connect(func(): flow.production_continue())
	plot_auction_panel.bid_submitted.connect(_on_plot_auction_bid)
	board_view.plot_tapped.connect(_on_plot_tapped)
	flow.phase_changed.connect(_on_phase_changed)
	flow.state_changed.connect(_on_state_changed)
	flow.banner_shown.connect(_on_banner)
	flow.human_turn_started.connect(_on_human_turn)
	flow.highlights_requested.connect(func(cells: Array, color: Color): board_view.set_highlights(cells, color))
	flow.clear_highlights_requested.connect(func(): board_view.clear_highlights())
	flow.outlines_requested.connect(func(cells: Array, color: Color): board_view.set_outlines(cells, color))
	flow.clear_outlines_requested.connect(func(): board_view.clear_outlines())
	flow.summary_ready.connect(_on_summary)
	flow.auction_updated.connect(_on_auction)
	flow.game_finished.connect(_on_game_finished)
	flow.assay_result.connect(_on_assay_result)
	flow.assay_revealed.connect(_on_assay_revealed)
	flow.production_ready.connect(_on_production_ready)
	flow.plot_auction_started.connect(_on_plot_auction_started)
	flow.plot_auction_updated.connect(_on_plot_auction_updated)
	flow.plot_auction_ended.connect(_on_plot_auction_ended)

func _on_plot_tapped(col: int, row: int) -> void:
	if flow.phase == flow.Phase.LAND_GRANT:
		if flow.claim_plot(col, row):
			if flow.plot_auction_plot != null:
				# A plot auction started — keep the white outline on the auction plot.
				board_view.select_plot(flow.plot_auction_plot.col, flow.plot_auction_plot.row, Color.WHITE)
			else:
				_select_tapped(col, row)
	elif flow.phase == flow.Phase.DEVELOPMENT:
		if flow.pending_refit:
			if flow.dev_refit_mule(col, row):
				_select_tapped(col, row)
				# Show dev panel again after refitting mule
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()
			else:
				# Show dev panel again if refit failed (invalid plot)
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()
		elif flow.pending_unit >= 0:
			if flow.dev_place_mule(col, row):
				_select_tapped(col, row)
				# Show dev panel again after placing mule
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()
			else:
				# Show dev panel again if placement failed (invalid plot)
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()
		elif flow.pending_assay:
			if flow.dev_assay(col, row):
				_select_tapped(col, row)
				# Show dev panel again after assaying
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()
			else:
				# Show dev panel again if assay failed
				if flow.dev_player != null and flow.dev_player.is_human:
					dev_panel.visible = true
					_refresh_dev()

func _select_tapped(col: int, row: int) -> void:
	var plot: Plot = gs.board.get_plot(col, row)
	var color: Color = Player.COLORS[plot.owner_id] if plot.is_claimed() else gs.human().color()
	board_view.select_plot(col, row, color)

func _on_phase_changed(p: int) -> void:
	board_view.clear_highlights()
	board_view.clear_selection()
	board_view.clear_outlines()
	match p:
		flow.Phase.MENU:
			_show_only(menu_panel)
			hint_label.visible = false
		flow.Phase.LAND_GRANT:
			_show_only(null)
			hint_label.visible = true
		flow.Phase.DEVELOPMENT:
			_show_only(dev_panel if flow.dev_player != null and flow.dev_player.is_human else null)
			hint_label.visible = false
		flow.Phase.AUCTION:
			_show_only(auction_panel)
			hint_label.visible = false
			_refresh_auction()
		flow.Phase.SUMMARY:
			_show_only(status_panel)
			hint_label.visible = false
		flow.Phase.GAME_OVER:
			_show_only(end_panel)
			hint_label.visible = false
		_:
			_show_only(null)
			hint_label.visible = false

func _on_state_changed() -> void:
	board_view.queue_redraw()
	if flow.phase == flow.Phase.PRODUCTION:
		board_view.set_production_results(flow.production_results)
	# Hide dev panel during CPU turns, show during human turns
	if flow.phase == flow.Phase.DEVELOPMENT:
		if flow.dev_player != null and not flow.dev_player.is_human:
			dev_panel.visible = false
		elif flow.dev_player != null and flow.dev_player.is_human:
			if dev_panel.visible:
				_refresh_dev()
	else:
		if dev_panel.visible:
			_refresh_dev()
	if auction_panel.visible:
		_refresh_auction()
	if plot_auction_panel.visible:
		plot_auction_panel.refresh(flow.plot_auction_plot, flow.plot_auction_bids, gs.human().cash)

func _on_human_turn(player: Player) -> void:
	_show_only(dev_panel)
	_refresh_dev()

func _on_production_ready(results: Dictionary) -> void:
	board_view.set_production_results(results)
	_show_only(production_panel)
	_refresh_production()

func _refresh_production() -> void:
	production_panel.refresh(gs.round_number, flow.production_results, gs)

func _refresh_dev() -> void:
	var player: Player = flow.dev_player
	dev_panel.refresh(player, flow.actions_left, gs.mule_price(),
		gs.wampus_active, Economy.wampus_reward(gs.round_number),
		Economy.gambling_grant(gs.round_number), flow.last_dev_message)

func _refresh_auction() -> void:
	auction_panel.refresh(flow.auction_unit, gs, flow.cpu_offers, flow.human_offer, flow.human_sales)

func _on_summary(rows: Array) -> void:
	status_panel.refresh(rows, gs.round_number >= Economy.MAX_ROUNDS)

func _on_auction(unit: int) -> void:
	_refresh_auction()

func _on_banner(text: String, icon_path: String) -> void:
	banner_label.text = text
	if icon_path != "":
		banner_icon.sprite_frames = load(icon_path)
		banner_icon.visible = true
		banner_icon.play()
	else:
		banner_icon.visible = false
	banner_panel.visible = true
	banner_timer.start()

func _on_assay_result(quality: int) -> void:
	assay_label.text = "Result: %s" % flow.quality_name(quality)
	assay_popup.visible = true

func _on_assay_revealed(player_name: String, col: int, row: int, quality: int) -> void:
	board_view.flash_plot(col, row, Color(1.0, 0.9, 0.3, 0.5))
	assay_label.text = "%s assayed a plot: %s" % [player_name, flow.quality_name(quality)]
	assay_popup.visible = true
	await get_tree().create_timer(2.0).timeout
	assay_popup.visible = false
	board_view.clear_flash()

func _on_game_finished(results: Dictionary) -> void:
	end_panel.refresh(results)

func _show_only(panel: Control) -> void:
	for p in [menu_panel, howto_panel, dev_panel, auction_panel, status_panel, end_panel, production_panel, plot_auction_panel]:
		if p != null:
			p.visible = p == panel
	assay_popup.visible = false

func _on_plot_auction_started(plot: Plot, bids: Dictionary) -> void:
	_show_only(plot_auction_panel)
	plot_auction_panel.refresh(plot, bids, gs.human().cash)
	board_view.select_plot(plot.col, plot.row, Color.WHITE)

func _on_plot_auction_updated(bids: Dictionary) -> void:
	if plot_auction_panel.visible:
		plot_auction_panel.refresh(flow.plot_auction_plot, bids, gs.human().cash)

func _on_plot_auction_bid(amount: int) -> void:
	flow.plot_auction_bid(amount)

func _on_plot_auction_ended(winner: Player, amount: int) -> void:
	# Return to land grant view after auction ends
	board_view.clear_selection()
	_show_only(null)
	hint_label.visible = true
