extends Control
## Màn hình quán: khung 3D nhìn từ trên xuống + HUD + chọn khu + thẻ thông tin quầy.

var world: TycoonWorld
var sub_vp: SubViewport

var money_label: Label
var rate_label: Label
var rep_label: Label
var rep_bar: ProgressBar
var day_label: Label
var day_bar: ProgressBar
var tag_box: HBoxContainer
var warn_panel: PanelContainer
var warn_label: Label
var collect_btn: Button
var floor_btns: Array = []
var strip_box: BoxContainer
var strip_cards: Dictionary = {}
var strip_floor := -1
var card_layer: Control
var furni_btn: Button
var place_bar: PanelContainer
var place_hint: Label
var place_ok_btn: Button
var toast_label: Label
var toast_timer := 0.0

# Cử chỉ hai ngón trên sân khấu 3D. Phải bắt ở đây (trong `_input`, chạy trước
# lớp giao diện) vì máy chuyển cảm ứng thành chuột trước khi sự kiện kịp chui
# xuống SubViewport — dưới đó chỉ còn thấy chuột, không thấy ngón thứ hai.
var stage_ctrl: Control
var _touches: Dictionary = {}
var _pinch_gap := 0.0
var _pinch_mid := Vector2.ZERO


func _ready() -> void:
	_build()
	GameManager.money_changed.connect(_refresh_hud)
	GameManager.stock_changed.connect(_refresh_tags)
	GameManager.state_changed.connect(_refresh_all)
	GameManager.day_ended.connect(_on_day_ended)
	GameManager.offline_earned.connect(_on_offline_earned)
	_refresh_all()


## Hai ngón trên sân khấu: chụm/xoè để thu phóng, rê để dời khung nhìn ra vỉa hè.
func _input(event: InputEvent) -> void:
	if world == null or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _in_stage(event.position):
				_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_gap = 0.0
		_pinch_mid = Vector2.ZERO
		if _touches.size() >= 2:
			world.gesture_active(true)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() < 2:
			return
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var gap := a.distance_to(b)
		var mid := (a + b) * 0.5
		world.gesture_active(true)
		if _pinch_gap > 4.0 and gap > 4.0:
			world.zoom_by(_pinch_gap / gap)      # xoè hai ngón = kéo lại gần
		if _pinch_mid != Vector2.ZERO:
			world.pan_by(mid - _pinch_mid)       # rê hai ngón = dời khung nhìn
		_pinch_gap = gap
		_pinch_mid = mid
		get_viewport().set_input_as_handled()


func _in_stage(p: Vector2) -> bool:
	if stage_ctrl == null:
		return false
	return stage_ctrl.get_global_rect().has_point(p)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	day_bar.value = GameManager.day_time / GameManager.DAY_DURATION * 100.0
	day_label.text = "NGÀY %d" % GameManager.day
	money_label.text = UIKit.money(GameManager.money) + " ₫"
	var pend := GameManager.total_pending()
	collect_btn.disabled = pend < 1.0
	collect_btn.text = ("THU " + UIKit.money_short(pend) + " ₫") if pend >= 1.0 else "CHƯA CÓ TIỀN CHỜ"
	_sync_strip()
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_label.get_parent().visible = toast_timer > 0.0


# ================= Dựng giao diện =================

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_hud())

	# Máy nằm ngang: sân khấu 3D chiếm phần lớn bên trái, bảng quầy + nút bấm dồn
	# sang cột phải. Xếp chồng dọc như bản cũ thì sân khấu chỉ còn một dải dẹp.
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	# ---- sân khấu 3D ----
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	mid.add_child(stage)
	stage_ctrl = stage

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(vpc)

	sub_vp = SubViewport.new()
	sub_vp.transparent_bg = false
	sub_vp.handle_input_locally = true
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_vp.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(sub_vp)

	world = TycoonWorld.new()
	sub_vp.add_child(world)
	world.station_tapped.connect(_on_station_tapped)
	world.floor_tapped.connect(_on_floor_tapped)
	world.grill_tapped.connect(_show_grill_card)
	world.collected.connect(_on_collected)
	world.focus_changed.connect(_on_focus_changed)
	world.boosted.connect(_on_boosted)
	world.furniture_tapped.connect(_on_furniture_tapped)
	world.placement_changed.connect(_on_placement_changed)

	stage.add_child(_build_overlay())

	# lớp thẻ chi tiết (popup)
	card_layer = Control.new()
	card_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(card_layer)

	mid.add_child(_build_dock())


func _build_hud() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UIKit.flat_pad(UIKit.D_BG, int(UIKit.px(8)), 0, UIKit.D_BG, 0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UIKit.px(5)))
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UIKit.px(10)))
	v.add_child(top)

	# ---- huy hiệu sao: bậc uy tín + thanh tím chạy tới bậc sau ----
	top.add_child(_rep_badge())

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 0)
	top.add_child(left)
	left.add_child(UIKit.label("Cơm Tấm Bà Tấm", 15, UIKit.D_TEXT))
	day_label = UIKit.label("NGÀY 1", 10, UIKit.D_MUTED)
	left.add_child(day_label)

	# ---- ví tiền: tờ tiền xanh + số dư + tốc độ kiếm tiền ----
	top.add_child(_money_chip())

	day_bar = UIKit.bar(0.0, UIKit.NEON_BLUE, 3)
	v.add_child(day_bar)
	return panel


## Huy hiệu ngôi sao bên trái: số trong sao là BẬC uy tín, thanh tím là phần uy
## tín đã tích được trong bậc đó (đúng kiểu thanh kinh nghiệm của game idle).
func _rep_badge() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(UIKit.px(120), UIKit.px(40))
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	rep_bar = UIKit.level_bar(0.0, "", 22, UIKit.NEON_PURPLE, UIKit.D_SLOT)
	rep_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	rep_bar.offset_left = UIKit.px(20)
	rep_bar.offset_top = UIKit.px(9)
	rep_bar.offset_bottom = -UIKit.px(9)
	wrap.add_child(rep_bar)

	var star := UIIcon.make("star", UIKit.px(40), UIKit.NEON_STAR)
	wrap.add_child(star)

	rep_label = UIKit.label("1", 14, Color.WHITE)
	rep_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rep_label.custom_minimum_size = Vector2(UIKit.px(40), UIKit.px(40))
	rep_label.size = Vector2(UIKit.px(40), UIKit.px(40))
	rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrap.add_child(rep_label)
	return wrap


func _money_chip() -> Control:
	var p := UIKit.dark_panel(UIKit.D_SHEET, 8, UIKit.RADIUS_SM)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UIKit.px(9)))
	p.add_child(h)

	var badge := UIKit.dark_panel(UIKit.NEON_GREEN_DARK, 5, UIKit.RADIUS_SM)
	badge.add_child(UIIcon.make("cash", UIKit.px(20), Color("d8ffe8"), UIKit.NEON_GREEN_DARK))
	h.add_child(badge)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)
	money_label = UIKit.label("0 ₫", 17, Color.WHITE)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(money_label)
	rate_label = UIKit.label("0 ₫/s", 10, UIKit.NEON_GREEN)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(rate_label)
	return p


func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# nhãn trạng thái góc trái trên
	tag_box = HBoxContainer.new()
	tag_box.position = Vector2(10, 10)
	tag_box.add_theme_constant_override("separation", 6)
	tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(tag_box)

	# cảnh báo hết nguyên liệu
	warn_panel = PanelContainer.new()
	warn_panel.add_theme_stylebox_override("panel", UIKit.flat_pad(Color(0.71, 0.33, 0.25, 0.94), 8))
	warn_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	warn_panel.offset_top = 52
	warn_panel.offset_bottom = 96
	warn_panel.offset_left = 10
	warn_panel.offset_right = -320
	warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_label = UIKit.label("", 11, Color.WHITE)
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn_panel.add_child(warn_label)
	warn_panel.visible = false
	overlay.add_child(warn_panel)

	# chọn khu (bên phải)
	var floor_col := VBoxContainer.new()
	floor_col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	floor_col.offset_left = -74
	floor_col.offset_right = -8
	floor_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	floor_col.grow_vertical = Control.GROW_DIRECTION_BOTH
	floor_col.add_theme_constant_override("separation", 6)
	overlay.add_child(floor_col)
	floor_btns.clear()
	for i in range(GameManager.FLOORS.size() - 1, -1, -1):
		var f: Dictionary = GameManager.FLOORS[i]
		var b := UIKit.button_secondary("K%d" % (i + 1), 13)
		b.custom_minimum_size = Vector2(99, 68)
		b.pressed.connect(_on_floor_button.bind(i))
		b.set_meta("floor", i)
		floor_col.add_child(b)
		floor_btns.append(b)

	# thu phóng: chụm hai ngón cũng được, nhưng có nút cho chắc tay
	var zoom_col := VBoxContainer.new()
	zoom_col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	zoom_col.offset_left = 8
	zoom_col.offset_right = 74
	zoom_col.grow_vertical = Control.GROW_DIRECTION_BOTH
	zoom_col.add_theme_constant_override("separation", 6)
	overlay.add_child(zoom_col)
	var zin := UIKit.button_secondary("+", 20)
	zin.custom_minimum_size = Vector2(66, 66)
	zin.pressed.connect(func(): world.zoom_by(0.82))
	zoom_col.add_child(zin)
	var zout := UIKit.button_secondary("−", 20)
	zout.custom_minimum_size = Vector2(66, 66)
	zout.pressed.connect(func(): world.zoom_by(1.22))
	zoom_col.add_child(zout)
	var zhome := UIKit.button_ghost("⌂", 16)
	zhome.custom_minimum_size = Vector2(66, 56)
	zhome.pressed.connect(func(): world.reset_view())
	zoom_col.add_child(zhome)

	# thanh điều khiển lúc đang kê bàn
	place_bar = PanelContainer.new()
	place_bar.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 10))
	place_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	place_bar.offset_bottom = -8
	place_bar.offset_top = -122
	place_bar.offset_left = 10
	place_bar.offset_right = -10
	place_bar.visible = false
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 7)
	place_bar.add_child(pv)
	place_hint = UIKit.label("", 12, Color.WHITE)
	place_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(place_hint)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	pv.add_child(prow)
	var rot_btn := UIKit.button_secondary("XOAY", 13)
	rot_btn.custom_minimum_size = Vector2(0, 62)
	rot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_btn.pressed.connect(func(): world.rotate_placement())
	prow.add_child(rot_btn)
	var cancel_btn := UIKit.button_danger("HUỶ", 13)
	cancel_btn.custom_minimum_size = Vector2(0, 62)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): world.cancel_placement())
	prow.add_child(cancel_btn)
	place_ok_btn = UIKit.button_primary("ĐẶT XUỐNG", 14)
	place_ok_btn.custom_minimum_size = Vector2(0, 62)
	place_ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_ok_btn.pressed.connect(_on_place_confirm)
	prow.add_child(place_ok_btn)
	overlay.add_child(place_bar)

	# toast
	var toast_panel := PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 9))
	toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_bottom = -14
	toast_panel.offset_top = -52
	toast_panel.offset_left = 12
	toast_panel.offset_right = -12
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	toast_label = UIKit.label("", 12, UIKit.BG)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	overlay.add_child(toast_panel)
	return overlay


func _build_dock() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.flat_pad(Color.WHITE, 10, 0, Color.WHITE, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	panel.custom_minimum_size = Vector2(372, 0)

	# cột quầy của khu đang xem: xem cấp, tiến độ và nâng cấp bằng một chạm
	var strip_scroll := ScrollContainer.new()
	strip_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(strip_scroll)
	DragScroll.attach(strip_scroll)
	strip_box = VBoxContainer.new()
	strip_box.add_theme_constant_override("separation", 8)
	strip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_scroll.add_child(strip_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)

	collect_btn = UIKit.button_primary("THU TIỀN", 15)
	collect_btn.custom_minimum_size = Vector2(0, 72)
	collect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collect_btn.pressed.connect(_on_collect_all)
	row.add_child(collect_btn)

	furni_btn = UIKit.button_gold("BÀN GHẾ", 13)
	furni_btn.custom_minimum_size = Vector2(150, 72)
	furni_btn.pressed.connect(_show_furniture_card)
	row.add_child(furni_btn)

	var hint := UIKit.label("Chạm quầy · vuốt ngang đổi khu · hai ngón để kéo và thu phóng", 9, UIKit.N600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return panel


# ================= Cập nhật =================

func _refresh_all() -> void:
	_refresh_hud()
	_refresh_tags()
	_refresh_floor_buttons()
	_refresh_furni_btn()
	_rebuild_strip()


func _refresh_furni_btn() -> void:
	if furni_btn == null:
		return
	var waiting := GameManager.furniture_pending()
	furni_btn.text = ("KÊ BÀN (%d)" % waiting) if waiting > 0 else "BÀN GHẾ"


func _refresh_hud() -> void:
	money_label.text = UIKit.money(GameManager.money) + " ₫"
	rate_label.text = UIKit.money_short(GameManager.income_per_second()) + " ₫/s"
	# ngôi sao hiện thẳng ĐIỂM uy tín, thanh tím là phần đã đi trong bậc hiện tại
	rep_label.text = str(int(round(GameManager.reputation)))
	rep_bar.value = maxf(GameManager.rep_progress(), 0.07)


func _refresh_tags() -> void:
	for c in tag_box.get_children():
		c.queue_free()
	tag_box.add_child(UIKit.tag("%d khách/phút" % int(GameManager.arrival_rate()), UIKit.ACCENT_800, UIKit.ACCENT_100))
	tag_box.add_child(UIKit.tag("%d chỗ" % GameManager.seats(), UIKit.ACCENT_800, UIKit.ACCENT_100))
	var grilled := int(GameManager.stock.get("grilled", 0.0))
	var coal := int(GameManager.stock.get("coal", 0.0))
	var grill_col := UIKit.OK if grilled > 0 else UIKit.BAD
	tag_box.add_child(UIKit.tag("%d sườn nướng" % grilled, grill_col,
		Color(0.31, 0.54, 0.36, 0.14) if grilled > 0 else Color(0.71, 0.33, 0.25, 0.12)))
	if coal <= 0:
		tag_box.add_child(UIKit.tag("hết than!", UIKit.BAD, Color(0.71, 0.33, 0.25, 0.12)))
	var amb := GameManager.ambiance()
	if amb > 0:
		tag_box.add_child(UIKit.tag("không khí +%d" % amb, UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))

	var missing := GameManager.missing_ingredients()
	if missing.is_empty():
		warn_panel.visible = false
	else:
		var names: Array = []
		for id in missing:
			names.append(str(GameManager.INGREDIENTS[id]["name"]))
		warn_label.text = "Hết " + ", ".join(names).to_lower() + " — vào Mua sắm để nhập thêm."
		warn_panel.visible = true


func _refresh_floor_buttons() -> void:
	for b in floor_btns:
		var i: int = b.get_meta("floor")
		var fid := str(GameManager.FLOORS[i]["id"])
		var unlocked := GameManager.is_floor_unlocked(fid)
		var active := world != null and world.current_floor() == i
		if not unlocked:
			UIKit._style_button(b, UIKit.BG, UIKit.N600, UIKit.ACCENT if active else UIKit.N400, 2 if active else 1)
			b.text = "K%d 🔒" % (i + 1)
		elif active:
			UIKit._style_button(b, UIKit.ACCENT_900, UIKit.BG, UIKit.ACCENT_900, 0)
			b.text = "K%d" % (i + 1)
		else:
			UIKit._style_button(b, UIKit.BG, UIKit.ACCENT_800, UIKit.ACCENT, 1)
			b.text = "K%d" % (i + 1)


func _on_focus_changed(_index: int) -> void:
	_refresh_floor_buttons()
	_rebuild_strip()


func _on_floor_button(index: int) -> void:
	world.go_to_floor(index)
	_refresh_floor_buttons()
	var f: Dictionary = GameManager.FLOORS[index]
	_toast(str(f["name"]) + " · " + str(f["note"]))


func _on_collect_all() -> void:
	var total := GameManager.collect_all()
	if total > 0.0:
		_toast("Đã thu " + UIKit.money(total) + " ₫")


func _on_collected(amount: float) -> void:
	_toast("+" + UIKit.money(amount) + " ₫")


func _on_day_ended(summary: Dictionary) -> void:
	_toast("Hết ngày %d · lãi %s ₫ · %d lượt khách" % [
		int(summary["day"]), UIKit.money(float(summary["profit"])), int(summary["served"])])


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_timer = 2.6
	toast_label.get_parent().visible = true


# ================= Dải quầy của khu đang xem =================

func _rebuild_strip() -> void:
	if strip_box == null or world == null:
		return
	strip_floor = world.current_floor()
	for c in strip_box.get_children():
		c.queue_free()
	strip_cards.clear()

	var fid := str(GameManager.FLOORS[strip_floor]["id"])
	if not GameManager.is_floor_unlocked(fid):
		var note := UIKit.muted("Khu này chưa mở — chạm vào bảng ngoài lô đất để mở khoá.", 12)
		note.custom_minimum_size = Vector2(0, 0)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strip_box.add_child(note)
		return

	for sid in GameManager.stations_on_floor(fid):
		strip_box.add_child(_strip_card(str(sid)))


func _strip_card(sid: String) -> Control:
	var data: Dictionary = GameManager.STATIONS[sid]
	var card := UIKit.card(8)
	card.custom_minimum_size = Vector2(0, 116)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	v.add_child(top)
	var nm := UIKit.label(str(data["name"]), 12, UIKit.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	top.add_child(nm)
	var lv := UIKit.label("", 12, UIKit.PRIMARY)
	top.add_child(lv)

	var bar := UIKit.bar(0.0, UIKit.OK, 6)
	v.add_child(bar)

	var btn := UIKit.button_primary("", 12)
	btn.custom_minimum_size = Vector2(0, 56)
	btn.pressed.connect(func():
		if GameManager.upgrade_station(sid):
			_toast("%s lên cấp %d" % [str(data["name"]), GameManager.station_level(sid)])
		else:
			_toast("Chưa đủ tiền nâng cấp"))
	v.add_child(btn)

	strip_cards[sid] = {"lv": lv, "bar": bar, "btn": btn}
	return card


## Cập nhật số liệu trên dải quầy (gọi mỗi khung hình, rất nhẹ).
func _sync_strip() -> void:
	if world == null:
		return
	if world.current_floor() != strip_floor:
		_rebuild_strip()
	for sid in strip_cards:
		var r: Dictionary = strip_cards[sid]
		var open := GameManager.is_station_open(str(sid))
		(r["lv"] as Label).text = "C%d" % GameManager.station_level(str(sid)) if open else "—"
		(r["bar"] as ProgressBar).value = float(GameManager.progress.get(sid, 0.0)) * 100.0
		var btn: Button = r["btn"]
		var cost := GameManager.station_upgrade_cost(str(sid))
		btn.text = "▲ " + UIKit.money_short(cost)
		btn.disabled = not GameManager.can_afford(cost)


func _on_boosted(sid: String) -> void:
	_toast("Nấu nhanh " + str(GameManager.STATIONS[sid]["name"]).to_lower() + "!")


## Hộp thoại chào mừng: tiền quán kiếm được lúc người chơi đóng game.
func _on_offline_earned(data: Dictionary) -> void:
	var secs := float(data["seconds"])
	var hours := int(secs / 3600.0)
	var mins := int(fmod(secs, 3600.0) / 60.0)
	var when := ("%d giờ %d phút" % [hours, mins]) if hours > 0 else ("%d phút" % mins)

	var v := _card_shell()
	v.add_child(UIKit.heading("Quán vẫn bán khi bạn vắng mặt", 18, UIKit.TEXT))
	v.add_child(UIKit.muted("Quản lý đã trông quán suốt %s." % when, 13))
	v.add_child(UIKit.separator())

	var amount := UIKit.label(UIKit.money(float(data["amount"])) + " ₫", 30, UIKit.GOLD_DARK)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(amount)
	var sub_l := UIKit.muted("Đã bán %d phần cơm" % int(data["portions"]), 13)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub_l)

	var ok := UIKit.button_gold("NHẬN TIỀN", 16)
	ok.custom_minimum_size = Vector2(0, 85)
	ok.pressed.connect(_clear_card)
	v.add_child(ok)


# ================= Thẻ chi tiết quầy =================

func _on_station_tapped(sid: String) -> void:
	_show_station_card(sid)


func _on_floor_tapped(fid: String) -> void:
	_show_floor_card(fid)


# ================= Bàn ghế: mua rồi tự kê =================

func _on_placement_changed(valid: bool, zone: String) -> void:
	if world == null:
		return
	place_bar.visible = world.place_mode
	if not world.place_mode:
		_refresh_all()
		return
	var where := "ngoài vỉa hè" if zone == "out" else "trong quán"
	place_hint.text = ("Chỗ này kê được (%s) — bấm ĐẶT XUỐNG." % where) if valid \
		else "Chỗ này vướng rồi — kéo sang chỗ khác."
	place_ok_btn.disabled = not valid


func _on_place_confirm() -> void:
	if world.confirm_placement():
		_toast("Đã kê bàn xong. Khách tới là có chỗ ngồi.")
		_refresh_all()


func _begin_place(kind: String, move_index: int = -1) -> void:
	_clear_card()
	world.begin_placement(kind, move_index)
	_toast("Kéo tay để chọn chỗ, rồi bấm ĐẶT XUỐNG.")


## Thẻ mua bàn ghế: mua về kho trước, kê xuống sau.
func _show_furniture_card() -> void:
	if world != null and world.place_mode:
		world.cancel_placement()
	var v := _card_shell()
	v.add_child(UIKit.heading("BÀN GHẾ", 18))
	v.add_child(UIKit.muted("Mua về rồi tự tay kê vào quán hoặc ra vỉa hè. Mỗi bộ thêm chỗ ngồi, khách đông hơn.", 11))
	v.add_child(UIKit.separator())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	DragScroll.attach(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for kind in GameManager.FURNITURE:
		list.add_child(_furniture_row(str(kind)))

	var close := UIKit.button_secondary("ĐÓNG", 14)
	close.custom_minimum_size = Vector2(0, 70)
	close.pressed.connect(_clear_card)
	v.add_child(close)


func _furniture_row(kind: String) -> Control:
	var d: Dictionary = GameManager.FURNITURE[kind]
	var card := UIKit.card(10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var nm := UIKit.label(str(d["name"]), 13, UIKit.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var seats := int(d["seats"])
	if seats > 0:
		top.add_child(UIKit.tag("+%d chỗ" % seats, UIKit.OK, UIKit.N100))
	var zone := str(d.get("zone", "any"))
	var zone_text := "vỉa hè" if zone == "out" else ("trong quán" if zone == "in" else "đâu cũng được")
	top.add_child(UIKit.tag(zone_text))

	v.add_child(UIKit.muted(str(d["desc"]), 11))

	var have := GameManager.furniture_stock(kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var buy := UIKit.button_primary("MUA · " + UIKit.money_short(float(d["cost"])) + " ₫", 13)
	buy.custom_minimum_size = Vector2(0, 64)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.disabled = not GameManager.can_afford(float(d["cost"]))
	buy.pressed.connect(func():
		if GameManager.buy_furniture(kind):
			_toast("Đã mua %s — bấm KÊ để chọn chỗ." % str(d["name"]).to_lower())
			_show_furniture_card())
	row.add_child(buy)
	var place := UIKit.button_gold("KÊ (%d)" % have, 13)
	place.custom_minimum_size = Vector2(150, 64)
	place.disabled = have <= 0
	place.pressed.connect(func(): _begin_place(kind))
	row.add_child(place)
	return card


## Chạm vào một bộ bàn đã kê: dời chỗ, cất vào kho hoặc bán lại.
func _on_furniture_tapped(index: int) -> void:
	if world.place_mode:
		return
	if index < 0 or index >= GameManager.placed.size():
		return
	var it: Dictionary = GameManager.placed[index]
	var kind := str(it.get("kind", ""))
	var d: Dictionary = GameManager.FURNITURE.get(kind, {})
	var v := _card_shell()
	v.add_child(UIKit.heading(str(d.get("name", "Bàn")), 18))
	v.add_child(UIKit.muted("Đang kê %s, khu %d." % [
		"ngoài vỉa hè" if str(it.get("zone", "in")) == "out" else "trong quán",
		int(it.get("floor", 0)) + 1], 11))
	v.add_child(UIKit.separator())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	v.add_child(grid)
	_kv(grid, "Chỗ ngồi", "+%d" % int(d.get("seats", 0)))
	_kv(grid, "Bán lại", UIKit.money(float(d.get("cost", 0)) * 0.5) + " ₫")

	var move := UIKit.button_primary("DI CHUYỂN", 14)
	move.custom_minimum_size = Vector2(0, 70)
	move.pressed.connect(func(): _begin_place(kind, index))
	v.add_child(move)

	var store := UIKit.button_secondary("CẤT VÀO KHO", 13)
	store.custom_minimum_size = Vector2(0, 66)
	store.pressed.connect(func():
		if GameManager.store_furniture(index):
			_toast("Đã cất bàn vào kho, kê lại lúc nào cũng được.")
			_clear_card())
	v.add_child(store)

	var sell := UIKit.button_danger("BÁN LẠI", 13)
	sell.custom_minimum_size = Vector2(0, 66)
	sell.pressed.connect(func():
		var back := GameManager.sell_furniture(index)
		if back > 0.0:
			_toast("Bán lại được " + UIKit.money(back) + " ₫")
			_clear_card())
	v.add_child(sell)

	var close2 := UIKit.button_ghost("ĐÓNG", 13)
	close2.custom_minimum_size = Vector2(0, 60)
	close2.pressed.connect(_clear_card)
	v.add_child(close2)


func _clear_card() -> void:
	for c in card_layer.get_children():
		c.queue_free()
	# Trả lớp thẻ về trong suốt với ngón tay, nếu không nó nuốt hết cú chạm vào
	# sân khấu 3D (không mở được khu, không kê được bàn) dù thẻ đã đóng.
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _card_shell() -> VBoxContainer:
	_clear_card()
	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.12, 0.13, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_clear_card())
	card_layer.add_child(dim)
	card_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.add_child(center)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var card := UIKit.card(14)
	card.custom_minimum_size = Vector2(620, 0)
	margin.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	card.add_child(v)
	return v


## ---------- Bảng nâng cấp nền tối (dựng theo mẫu game idle tycoon) ----------

## Mỗi quầy một biểu tượng vẽ tay, thay cho mấy ký tự ▤▦▩ hồi trước.
const STATION_ICONS := {
	"grill": "flame", "rice": "bowl", "prep": "seat", "drink": "cup",
	"combo": "bowl", "dessert": "plant", "office": "manager",
	"bbq": "flame", "vip": "star", "juice": "cup",
}


func _station_icon(sid: String) -> String:
	return str(STATION_ICONS.get(sid, "bowl"))


## Khung bảng tối: nền mờ (chạm ra ngoài là đóng) + tấm bảng bo góc ở giữa.
func _sheet_shell(width: int = 400) -> VBoxContainer:
	_clear_card()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# chạm vào vùng tối quanh bảng là đóng — không cần bấm đúng nút X
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_clear_card())
	card_layer.add_child(dim)
	card_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.add_child(center)

	var sheet := UIKit.dark_panel(UIKit.D_SHEET, 10, UIKit.RADIUS)
	sheet.custom_minimum_size = Vector2(UIKit.px(width), 0)
	center.add_child(sheet)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UIKit.px(6)))
	sheet.add_child(v)
	return v


## Hàng tiêu đề: biểu tượng + tên viết hoa + nút X đỏ.
func _sheet_header(parent: VBoxContainer, title: String, icon_kind: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UIKit.px(9)))
	parent.add_child(head)

	var ic := UIIcon.make(icon_kind, UIKit.px(21), UIKit.D_TITLE)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)

	var t := UIKit.label(title.to_upper(), 17, UIKit.D_TITLE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)

	var x := UIKit.close_button(34)
	x.pressed.connect(_clear_card)
	head.add_child(x)


## Bảng của một quầy: chỉ số, hai tab, thẻ nâng cấp, thanh cấp và hàng ô chọn quầy.
func _show_station_card(sid: String, tab: String = "upgrade") -> void:
	var data: Dictionary = GameManager.STATIONS[sid]
	var fid := str(data["floor"])
	var v := _sheet_shell()
	_sheet_header(v, str(GameManager.floor_data(fid)["name"]), "seat")

	# ---- hàng chỉ số: tiền mỗi giây + mức hài lòng về giá ----
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", int(UIKit.px(8)))
	v.add_child(stats)
	stats.add_child(UIKit.stat_slot(
		UIKit.money_short(GameManager.income_per_second(sid)) + " ₫/s", "cash"))
	stats.add_child(UIKit.stat_slot(
		"%d%%" % int(round(GameManager.price_appeal(sid) * 100.0)), "chart", UIKit.NEON_BLUE))

	# ---- hai tab ----
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UIKit.px(8)))
	v.add_child(tabs)
	var has_mgr := GameManager.has_manager(sid)
	var t_up := UIKit.tab_button("Nâng cấp", "arrow_up", tab == "upgrade")
	t_up.pressed.connect(func(): _show_station_card(sid, "upgrade"))
	tabs.add_child(t_up)
	var t_mgr := UIKit.tab_button("Quản lý", "manager", tab == "manager", not has_mgr)
	t_mgr.pressed.connect(func(): _show_station_card(sid, "manager"))
	tabs.add_child(t_mgr)

	# ---- thẻ nội dung ----
	if tab == "manager":
		v.add_child(_manager_card(sid))
	else:
		v.add_child(_upgrade_card(sid))

	# ---- hàng ô chọn quầy trong cùng khu ----
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(UIKit.px(8)))
	v.add_child(row)
	for other in GameManager.stations_on_floor(fid):
		var oid := str(other)
		var cost := float(GameManager.station_upgrade_cost(oid))
		var slot := UIKit.item_slot(_station_icon(oid), UIKit.money_short(cost),
			oid == sid, GameManager.can_afford(cost))
		slot.pressed.connect(func(): _show_station_card(oid, tab))
		row.add_child(slot)


## Thẻ nâng cấp: icon vuông, tên + mô tả, giá và nút xanh lá, hàng thưởng thêm
## và thanh cấp độ chạy dưới cùng.
func _upgrade_card(sid: String) -> Control:
	var data: Dictionary = GameManager.STATIONS[sid]
	var lv := GameManager.station_level(sid)
	var cost := float(GameManager.station_upgrade_cost(sid))
	var card := UIKit.dark_panel(UIKit.D_CARD, 10, UIKit.RADIUS)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UIKit.px(7)))
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UIKit.px(10)))
	v.add_child(top)

	var tile := UIKit.dark_panel(UIKit.D_BG, 8, UIKit.RADIUS_SM)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(UIIcon.make(_station_icon(sid), UIKit.px(32), UIKit.D_TEXT))
	top.add_child(tile)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", int(UIKit.px(3)))
	top.add_child(mid)
	mid.add_child(UIKit.label(str(data["name"]).to_upper(), 16, UIKit.D_TITLE))
	var desc := UIKit.label("Nâng cấp để mỗi mẻ ra nhiều phần hơn, nấu nhanh hơn.",
		10, UIKit.D_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(UIKit.px(150), 0)
	mid.add_child(desc)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", int(UIKit.px(4)))
	top.add_child(right)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", int(UIKit.px(5)))
	right.add_child(price)
	var can := GameManager.can_afford(cost)
	price.add_child(UIIcon.make("cash", UIKit.px(15), UIKit.NEON_GREEN if can else UIKit.D_MUTED))
	price.add_child(UIKit.label(UIKit.money_short(cost), 13,
		UIKit.D_TEXT if can else UIKit.D_MUTED))
	var up := UIKit.dark_button("NÂNG CẤP", UIKit.NEON_GREEN, Color("06301a"), 16)
	up.custom_minimum_size = Vector2(UIKit.px(112), UIKit.px(44))
	up.disabled = not can
	up.pressed.connect(func():
		if GameManager.upgrade_station(sid):
			_toast(str(data["name"]) + " lên cấp %d" % GameManager.station_level(sid))
			_show_station_card(sid, "upgrade"))
	right.add_child(up)

	# hàng thưởng: lãi mỗi phần hiện tại và mốc cấp tiếp theo
	var bonus := HBoxContainer.new()
	bonus.add_theme_constant_override("separation", int(UIKit.px(6)))
	v.add_child(bonus)
	bonus.add_child(UIIcon.make("cash", UIKit.px(14), UIKit.NEON_GREEN))
	var lai := GameManager.station_price(sid) - GameManager.station_cost_per_portion(sid)
	bonus.add_child(UIKit.label(UIKit.money_short(lai) + " ₫", 12, UIKit.D_TEXT))
	bonus.add_child(UIKit.label("+%d phần/mẻ" % GameManager.station_batch(sid), 12, UIKit.NEON_GREEN))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus.add_child(pad)
	bonus.add_child(UIKit.label("Mốc sau: cấp %d" % (int(lv / 4) * 4 + 4), 12, UIKit.D_MUTED))

	# thanh cấp: đầy dần qua mỗi mốc 4 cấp rồi cộng thêm một phần mỗi mẻ
	v.add_child(UIKit.level_bar(float(lv % 4) / 4.0, "Cấp %d" % lv))
	return card


## Tab quản lý: thuê người trông quầy để tiền tự chảy về, khỏi chạm bong bóng.
func _manager_card(sid: String) -> Control:
	var data: Dictionary = GameManager.STATIONS[sid]
	var card := UIKit.dark_panel(UIKit.D_CARD, 10, UIKit.RADIUS)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UIKit.px(7)))
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UIKit.px(10)))
	v.add_child(top)
	var tile := UIKit.dark_panel(UIKit.D_BG, 8, UIKit.RADIUS_SM)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(UIIcon.make("person", UIKit.px(32), UIKit.D_TEXT))
	top.add_child(tile)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", int(UIKit.px(3)))
	top.add_child(mid)
	mid.add_child(UIKit.label("QUẢN LÝ QUẦY", 16, UIKit.D_TITLE))
	var desc := UIKit.label("Thuê người trông quầy: tiền tự thu về, khỏi chạm bong bóng.",
		10, UIKit.D_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(UIKit.px(150), 0)
	mid.add_child(desc)

	if GameManager.has_manager(sid):
		var ok := UIKit.dark_button("ĐÃ CÓ QUẢN LÝ", UIKit.D_SLOT, UIKit.NEON_GREEN, 14)
		ok.custom_minimum_size = Vector2(UIKit.px(112), UIKit.px(44))
		ok.disabled = true
		top.add_child(ok)
		v.add_child(UIKit.level_bar(1.0, "Đang trực quầy"))
		return card

	var mc := float(GameManager.manager_cost(sid))
	var can := GameManager.can_afford(mc)
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", int(UIKit.px(4)))
	top.add_child(right)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", int(UIKit.px(5)))
	right.add_child(price)
	price.add_child(UIIcon.make("cash", UIKit.px(15), UIKit.NEON_GREEN if can else UIKit.D_MUTED))
	price.add_child(UIKit.label(UIKit.money_short(mc), 13, UIKit.D_TEXT if can else UIKit.D_MUTED))
	var hire := UIKit.dark_button("THUÊ", UIKit.NEON_BLUE, Color.WHITE, 16)
	hire.custom_minimum_size = Vector2(UIKit.px(112), UIKit.px(44))
	hire.disabled = not can
	hire.pressed.connect(func():
		if GameManager.hire_manager(sid):
			_toast("Quản lý sẽ tự thu tiền ở " + str(data["name"]).to_lower())
			_show_station_card(sid, "manager"))
	right.add_child(hire)

	v.add_child(UIKit.level_bar(0.0, "Chưa có quản lý"))
	return card


## Thẻ lò than vỉa hè: xem mẻ đang nướng, còn bao nhiêu than và nâng cấp lò.
func _show_grill_card() -> void:
	var v := _card_shell()
	v.add_child(UIKit.heading("LÒ THAN VỈA HÈ", 19, UIKit.ACCENT_900))
	v.add_child(UIKit.muted("Nướng sẵn sườn cho quầy trong quán. Mỗi mẻ đốt hết một bao than.", 12))
	v.add_child(UIKit.separator())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	v.add_child(grid)
	_kv(grid, "Cấp lò", "C%d" % GameManager.grill_level)
	_kv(grid, "Mỗi mẻ", "%d miếng" % GameManager.grill_batch())
	_kv(grid, "Một mẻ mất", "%d giây" % int(GameManager.GRILL_CYCLE))
	_kv(grid, "Sườn sống", "%d miếng" % int(GameManager.stock.get("pork", 0.0)))
	_kv(grid, "Than đá", "%d bao" % int(GameManager.stock.get("coal", 0.0)))
	_kv(grid, "Sườn nướng sẵn", "%d miếng" % int(GameManager.stock.get("grilled", 0.0)))

	var bar := UIKit.bar(GameManager.grill_progress * 100.0, UIKit.WARN, 8)
	v.add_child(bar)
	if GameManager.grill_running():
		v.add_child(UIKit.tag("Lò đang đỏ lửa", UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))
	else:
		var why := "Thiếu sườn sống cho cả mẻ" if int(GameManager.stock.get("pork", 0.0)) \
			< GameManager.grill_batch() else "Hết than đá"
		v.add_child(UIKit.tag(why + " — vào Mua sắm nhập thêm", UIKit.BAD,
			Color(0.71, 0.33, 0.25, 0.12)))

	var cost := GameManager.grill_upgrade_cost()
	var up := UIKit.button_primary("NÂNG LÒ · +%d miếng/mẻ · %s ₫" % [
		GameManager.GRILL_BATCH_STEP, UIKit.money(cost)], 13)
	up.custom_minimum_size = Vector2(0, 76)
	up.disabled = not GameManager.can_afford(cost)
	up.pressed.connect(func():
		if GameManager.upgrade_grill():
			_toast("Lò than lên cấp %d — mỗi mẻ %d miếng" % [
				GameManager.grill_level, GameManager.grill_batch()])
			_show_grill_card())
	v.add_child(up)

	var close := UIKit.button_ghost("ĐÓNG", 12)
	close.pressed.connect(_clear_card)
	v.add_child(close)


func _show_floor_card(fid: String) -> void:
	var f := GameManager.floor_data(fid)
	var v := _card_shell()
	v.add_child(UIKit.heading(str(f["name"]), 19, UIKit.ACCENT_900))
	v.add_child(UIKit.muted(str(f["note"]), 12))
	v.add_child(UIKit.separator())
	var names: Array = []
	for sid in GameManager.stations_on_floor(fid):
		names.append(str(GameManager.STATIONS[sid]["name"]))
	v.add_child(UIKit.muted("Mở kèm: " + ", ".join(names).to_lower(), 12))
	v.add_child(UIKit.muted("Thêm 4 chỗ ngồi và +5 uy tín.", 12))

	var cost := float(f["cost"])
	var buy := UIKit.button_primary("MỞ KHU · " + UIKit.money(cost) + " ₫", 14)
	buy.custom_minimum_size = Vector2(0, 78)
	buy.disabled = not GameManager.can_afford(cost)
	buy.pressed.connect(func():
		if GameManager.unlock_floor(fid):
			_toast("Đã mở " + str(f["name"]).to_lower() + "!")
			_clear_card())
	v.add_child(buy)

	var close := UIKit.button_ghost("ĐÓNG", 12)
	close.pressed.connect(_clear_card)
	v.add_child(close)


func _kv(grid: GridContainer, key: String, value: String) -> void:
	grid.add_child(UIKit.muted(key, 11))
	var l := UIKit.label(value, 12, UIKit.ACCENT_900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
