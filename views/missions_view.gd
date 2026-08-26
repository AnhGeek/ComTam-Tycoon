extends Control
## Màn hình nhiệm vụ: mục tiêu dài hạn + phần thưởng tiền để bấm nhận.

var money_label: Label
var summary_label: Label
var list_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0


func _ready() -> void:
    _build()
    GameManager.money_changed.connect(_refresh_money)
    GameManager.missions_changed.connect(_rebuild)
    GameManager.state_changed.connect(_rebuild)
    _rebuild()


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
    var hv := VBoxContainer.new()
    hv.add_theme_constant_override("separation", 4)
    head.add_child(hv)
    var row := HBoxContainer.new()
    hv.add_child(row)
    var title := UIKit.heading("Nhiệm vụ", 20, Color.WHITE)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    money_label = UIKit.label("0 ₫", 17, Color.WHITE)
    row.add_child(money_label)
    summary_label = UIKit.label("", 12, UIKit.ACCENT_400)
    hv.add_child(summary_label)
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
    list_box.add_theme_constant_override("separation", 9)
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(list_box)

    toast_panel = PanelContainer.new()
    toast_panel.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 11))
    toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    toast_panel.offset_left = 12
    toast_panel.offset_right = -12
    toast_panel.offset_top = -60
    toast_panel.offset_bottom = -16
    toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_panel.visible = false
    toast_label = UIKit.label("", 13, Color.WHITE)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_panel.add_child(toast_label)
    add_child(toast_panel)


func _refresh_money() -> void:
    money_label.text = UIKit.money(GameManager.money) + " ₫"


func _rebuild() -> void:
    if list_box == null:
        return
    _refresh_money()
    var ready_n := GameManager.missions_ready()
    var done_n := 0
    for m in GameManager.MISSIONS:
        if GameManager.mission_claimed(str(m["id"])):
            done_n += 1
    summary_label.text = "Đã xong %d/%d · %d phần thưởng đang chờ nhận" % [
        done_n, GameManager.MISSIONS.size(), ready_n]

    for c in list_box.get_children():
        c.queue_free()

    # nhiệm vụ nhận được xếp lên trên, đã nhận xuống cuối
    var pending_list: Array = []
    var active_list: Array = []
    var done_list: Array = []
    for m in GameManager.MISSIONS:
        if GameManager.mission_claimed(str(m["id"])):
            done_list.append(m)
        elif GameManager.mission_done(m):
            pending_list.append(m)
        else:
            active_list.append(m)

    if not pending_list.is_empty():
        list_box.add_child(UIKit.section("Sẵn sàng nhận thưởng"))
        for m in pending_list:
            list_box.add_child(_row(m))
    if not active_list.is_empty():
        list_box.add_child(UIKit.section("Đang làm"))
        for m in active_list:
            list_box.add_child(_row(m))
    if not done_list.is_empty():
        list_box.add_child(UIKit.section("Đã hoàn thành"))
        for m in done_list:
            list_box.add_child(_row(m))


func _row(m: Dictionary) -> Control:
    var id := str(m["id"])
    var target := float(m["target"])
    var progress := GameManager.mission_progress(m)
    var done := GameManager.mission_done(m)
    var taken := GameManager.mission_claimed(id)

    var card := UIKit.card(12)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 7)
    card.add_child(v)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 8)
    v.add_child(top)
    var name_l := UIKit.label(str(m["name"]), 15, UIKit.TEXT)
    name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top.add_child(name_l)
    top.add_child(UIKit.tag("+" + UIKit.money_short(float(m["reward"])) + " ₫",
        Color("40300a"), UIKit.GOLD))

    var pct := clampf(progress / maxf(target, 1.0) * 100.0, 0.0, 100.0)
    v.add_child(UIKit.bar(pct, UIKit.OK if done else UIKit.PRIMARY, 8))

    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation", 8)
    v.add_child(bottom)
    var prog_l := UIKit.muted(_fmt_progress(m, progress, target), 12)
    prog_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom.add_child(prog_l)

    if taken:
        card.modulate = Color(1, 1, 1, 0.6)
        bottom.add_child(UIKit.tag("Đã nhận", UIKit.OK, Color(0.13, 0.76, 0.55, 0.16)))
    elif done:
        var claim := UIKit.button_gold("NHẬN", 14)
        claim.custom_minimum_size = Vector2(163, 68)
        claim.pressed.connect(func():
            var r := GameManager.claim_mission(id)
            if r > 0.0:
                _toast("Nhận thưởng " + UIKit.money(r) + " ₫"))
        bottom.add_child(claim)
    return card


func _fmt_progress(m: Dictionary, progress: float, target: float) -> String:
    var kind := str(m["kind"])
    if kind == "earned":
        return "%s / %s ₫" % [UIKit.money_short(progress), UIKit.money_short(target)]
    return "%d / %d" % [int(progress), int(target)]


func _toast(msg: String) -> void:
    toast_label.text = msg
    toast_timer = 2.4
    toast_panel.visible = true
