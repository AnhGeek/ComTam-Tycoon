extends Control
## Màn hình cài đặt: đặt giá bán từng món, xem lãi/phần, lưu và chơi lại.

var money_label: Label
var list_box: VBoxContainer
var price_rows: Dictionary = {}   # sid -> Dictionary(spin, profit, appeal)
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0
var confirm: ConfirmationDialog


func _ready() -> void:
	_build()
	GameManager.money_changed.connect(_refresh_money)
	GameManager.state_changed.connect(_sync_rows)
	_refresh_money()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_panel.visible = toast_timer > 0.0


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 12, 0, UIKit.ACCENT_900, 0))
	var hrow := HBoxContainer.new()
	head.add_child(hrow)
	var title := UIKit.heading("Cài đặt", 19, UIKit.BG)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(title)
	money_label = UIKit.label("0 ₫", 17, UIKit.BG)
	hrow.add_child(money_label)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	# cuon bang cach keo ngon tay (xem drag_scroll.gd)
	DragScroll.attach(scroll)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(list_box)

	_build_prices()
	_build_options()

	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 9))
	toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_left = 12
	toast_panel.offset_right = -12
	toast_panel.offset_top = -56
	toast_panel.offset_bottom = -16
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	toast_label = UIKit.label("", 12, UIKit.BG)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	add_child(toast_panel)

	confirm = ConfirmationDialog.new()
	confirm.title = "Chơi lại từ đầu"
	confirm.dialog_text = "Xoá toàn bộ tiến trình và bắt đầu lại?"
	confirm.ok_button_text = "Xoá"
	confirm.cancel_button_text = "Huỷ"
	confirm.confirmed.connect(func():
		GameManager.reset_game()
		_sync_rows()
		_toast("Đã bắt đầu lại từ đầu"))
	add_child(confirm)


# ---------- Giá bán ----------

func _build_prices() -> void:
	list_box.add_child(UIKit.section("Giá bán — giá cao thì lãi nhiều nhưng ít khách"))

	var suggest := UIKit.button_primary("ĐẶT LẠI GIÁ ĐỀ XUẤT CHO MỌI MÓN", 13)
	suggest.custom_minimum_size = Vector2(0, 71)
	suggest.pressed.connect(func():
		GameManager.suggest_all_prices()
		_sync_rows()
		_toast("Đã áp dụng giá đề xuất"))
	list_box.add_child(suggest)

	# Liệt kê MENU chứ không phải quầy: quầy chỉ làm ra phần cơm, phần bì chả...
	# còn cái có giá bán là mấy món bưng ra cho khách.
	for sid in GameManager.MENU:
		list_box.add_child(_price_row(sid))


func _price_row(sid: String) -> Control:
	var data: Dictionary = GameManager.MENU[sid]
	var card := UIKit.card(11)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 2)
	top.add_child(names)
	names.add_child(UIKit.label(str(data["name"]), 15, UIKit.ACCENT_900))
	names.add_child(UIKit.muted(str(data["desc"]) + " · vốn "
		+ UIKit.money(GameManager.dish_cost(sid)) + " ₫", 11))

	var spin := SpinBox.new()
	spin.min_value = ceil(GameManager.dish_cost(sid) * 1.05 / 1000.0) * 1000.0
	spin.max_value = float(data["price"]) * 4.0
	spin.step = 1000.0
	spin.value = float(GameManager.dish_price(sid))
	spin.custom_minimum_size = Vector2(190, 68)
	spin.select_all_on_focus = true
	UIKit.style_spinbox(spin)
	spin.value_changed.connect(func(val: float):
		GameManager.set_price(sid, val)
		_update_row_labels(sid))
	top.add_child(spin)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	v.add_child(stats)
	var profit := UIKit.label("", 11, UIKit.OK)
	profit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(profit)
	var appeal := UIKit.label("", 11, UIKit.N700)
	appeal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(appeal)

	if not GameManager.dish_open(sid):
		card.modulate = Color(1, 1, 1, 0.55)
		spin.editable = false

	price_rows[sid] = {"spin": spin, "profit": profit, "appeal": appeal, "card": card}
	_update_row_labels(sid)
	return card


func _update_row_labels(sid: String) -> void:
	if not price_rows.has(sid):
		return
	var r: Dictionary = price_rows[sid]
	var margin := float(GameManager.dish_price(sid)) - GameManager.dish_cost(sid)
	var profit: Label = r["profit"]
	profit.text = "Lãi %s ₫ mỗi phần" % UIKit.money(margin)
	profit.add_theme_color_override("font_color", UIKit.OK if margin > 0.0 else UIKit.BAD)
	var ap := GameManager.dish_appeal(sid)
	var word := "rất đông khách"
	if ap < 0.5:
		word = "ít khách"
	elif ap < 0.8:
		word = "khách vừa"
	elif ap < 1.1:
		word = "đông khách"
	(r["appeal"] as Label).text = "Mức hút khách: %s (%d%%)" % [word, int(ap * 100.0)]


func _sync_rows() -> void:
	for sid in price_rows:
		var r: Dictionary = price_rows[sid]
		var spin: SpinBox = r["spin"]
		spin.set_block_signals(true)
		spin.value = float(GameManager.dish_price(sid))
		spin.set_block_signals(false)
		spin.editable = GameManager.dish_open(sid)
		(r["card"] as Control).modulate = Color(1, 1, 1, 1.0 if GameManager.dish_open(sid) else 0.55)
		_update_row_labels(sid)


# ---------- Tuỳ chọn khác ----------

func _build_options() -> void:
	list_box.add_child(UIKit.spacer(6))
	list_box.add_child(UIKit.section("Quán"))

	var info := UIKit.card(11)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info.add_child(iv)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	iv.add_child(g)
	_kv(g, "Một ngày trong game", "%d giây" % int(GameManager.DAY_DURATION))
	_kv(g, "Lương phải trả mỗi ngày", UIKit.money(GameManager.daily_salary()) + " ₫")
	_kv(g, "Chỗ ngồi", str(GameManager.seats()))
	_kv(g, "Không khí quán", "+" + str(GameManager.ambiance()))
	list_box.add_child(info)

	var save_btn := UIKit.button_secondary("LƯU TIẾN TRÌNH NGAY", 13)
	save_btn.custom_minimum_size = Vector2(0, 71)
	save_btn.pressed.connect(func():
		GameManager.save_game()
		_toast("Đã lưu tiến trình"))
	list_box.add_child(save_btn)

	var reset_btn := UIKit.button_danger("CHƠI LẠI TỪ ĐẦU", 13)
	reset_btn.custom_minimum_size = Vector2(0, 71)
	reset_btn.pressed.connect(func(): confirm.popup_centered(Vector2i(300, 140)))
	list_box.add_child(reset_btn)

	list_box.add_child(UIKit.spacer(4))
	list_box.add_child(UIKit.muted("Tiến trình tự lưu vào cuối mỗi ngày trong game.", 11))

	_build_debug()


# ---------- Gỡ lỗi ----------

func _build_debug() -> void:
	# Mấy nút này chỉ để test cho nhanh, tắt bằng "debug_tools": false trong
	# chung của data/balance.json là cả khúc này biến mất.
	if not GameManager.DEBUG_TOOLS:
		return

	list_box.add_child(UIKit.spacer(6))
	list_box.add_child(UIKit.section("Gỡ lỗi — chỉ dùng lúc test"))

	for amount in [1000000.0, 10000000.0, 100000000.0]:
		var money_amount: float = amount
		var btn := UIKit.button_secondary("+ " + UIKit.money(money_amount) + " ₫", 13)
		btn.custom_minimum_size = Vector2(0, 71)
		btn.pressed.connect(func():
			GameManager.debug_add_money(money_amount)
			_toast("Đã cộng " + UIKit.money(money_amount) + " ₫"))
		list_box.add_child(btn)

	var clear_btn := UIKit.button_danger("XOÁ SẠCH TIỀN (VỀ 0 ₫)", 13)
	clear_btn.custom_minimum_size = Vector2(0, 71)
	clear_btn.pressed.connect(func():
		GameManager.debug_add_money(-GameManager.money)
		_toast("Ví trống trơn rồi"))
	list_box.add_child(clear_btn)


func _kv(grid: GridContainer, key: String, value: String) -> void:
	grid.add_child(UIKit.muted(key, 11))
	var l := UIKit.label(value, 12, UIKit.ACCENT_900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)


func _refresh_money() -> void:
	money_label.text = UIKit.money(GameManager.money) + " ₫"


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_timer = 2.2
	toast_panel.visible = true
