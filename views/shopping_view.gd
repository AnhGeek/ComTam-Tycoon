extends Control
## Màn hình mua sắm: nguyên liệu · nhân viên · trang trí.

const TABS := [
    {"id": "ingredients", "label": "Nguyên liệu"},
    {"id": "staff", "label": "Nhân viên"},
    {"id": "decor", "label": "Trang trí"},
]

var current := "ingredients"
var money_label: Label
var tab_buttons: Dictionary = {}
var list_box: VBoxContainer
var toast_label: Label
var toast_panel: PanelContainer
var toast_timer := 0.0


func _ready() -> void:
    _build()
    GameManager.money_changed.connect(_refresh_money)
    GameManager.stock_changed.connect(_rebuild_list)
    GameManager.state_changed.connect(_rebuild_list)
    _rebuild_list()
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

    # ---- thanh trên ----
    var head := PanelContainer.new()
    head.add_theme_stylebox_override("panel", UIKit.flat_pad(UIKit.ACCENT_900, 12, 0, UIKit.ACCENT_900, 0))
    var hv := VBoxContainer.new()
    hv.add_theme_constant_override("separation", 8)
    head.add_child(hv)

    var row := HBoxContainer.new()
    hv.add_child(row)
    var title := UIKit.heading("Mua sắm", 19, UIKit.BG)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    money_label = UIKit.label("0 ₫", 17, UIKit.BG)
    row.add_child(money_label)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    hv.add_child(tabs)
    for t in TABS:
        var b := UIKit.button_secondary(str(t["label"]), 13)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size = Vector2(0, 61)
        b.pressed.connect(_on_tab.bind(str(t["id"])))
        tabs.add_child(b)
        tab_buttons[str(t["id"])] = b
    root.add_child(head)

    # ---- danh sách ----
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

    # ---- toast ----
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


func _on_tab(id: String) -> void:
    current = id
    _rebuild_list()


func _refresh_money() -> void:
    money_label.text = UIKit.money(GameManager.money) + " ₫"
    _refresh_buttons_enabled()


func _refresh_tabs() -> void:
    for id in tab_buttons:
        var b: Button = tab_buttons[id]
        if id == current:
            UIKit._style_button(b, UIKit.ACCENT, UIKit.BG, UIKit.ACCENT, 0)
        else:
            UIKit._style_button(b, Color(1, 1, 1, 0.06), UIKit.BG, Color(1, 1, 1, 0.35), 1)


# ================= Danh sách =================

func _rebuild_list() -> void:
    if list_box == null:
        return
    _refresh_tabs()
    for c in list_box.get_children():
        c.queue_free()
    match current:
        "ingredients":
            _build_ingredients()
        "staff":
            _build_staff()
        "decor":
            _build_decor()
    _refresh_money()


func _build_ingredients() -> void:
    list_box.add_child(UIKit.section("Kho nguyên liệu — mua theo lố"))

    var quick := UIKit.button_primary("NHẬP NHANH MỌI THỨ ĐANG THIẾU", 13)
    quick.custom_minimum_size = Vector2(0, 71)
    quick.pressed.connect(func():
        var n := GameManager.buy_all_low(60.0)
        _toast(("Đã nhập %d loại nguyên liệu" % n) if n > 0 else "Kho vẫn còn đủ hàng"))
    list_box.add_child(quick)

    for id in GameManager.shop_ingredients():
        var d: Dictionary = GameManager.INGREDIENTS[id]
        var qty := float(GameManager.stock.get(id, 0.0))
        var pack := int(d["pack"])
        var cost := float(d["price"]) * pack

        var card := UIKit.card(11)
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 10)
        card.add_child(h)

        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.add_theme_constant_override("separation", 3)
        h.add_child(info)
        info.add_child(UIKit.label(str(d["name"]), 15, UIKit.ACCENT_900))
        var low := qty <= 5.0
        var stock_col := UIKit.BAD if low else UIKit.N700
        info.add_child(UIKit.label("Còn %d %s · lố %d · %s ₫/%s" % [
            int(qty), str(d["unit"]), pack, UIKit.money(float(d["price"])), str(d["unit"])], 11, stock_col))
        var bar := UIKit.bar(clampf(qty / 60.0 * 100.0, 0.0, 100.0), UIKit.BAD if low else UIKit.ACCENT, 5)
        info.add_child(bar)

        var buy := UIKit.button_secondary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(150, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_ingredient(id):
                _toast("Đã nhập %d %s %s" % [pack, str(d["unit"]), str(d["name"]).to_lower()])
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
        list_box.add_child(card)


func _build_staff() -> void:
    list_box.add_child(UIKit.section("Nhân viên — trả lương mỗi cuối ngày"))
    list_box.add_child(UIKit.muted("Tổng lương hiện tại: %s ₫/ngày" % UIKit.money(GameManager.daily_salary()), 12))

    for id in GameManager.STAFF:
        var d: Dictionary = GameManager.STAFF[id]
        var have := int(GameManager.staff.get(id, 0))
        var maxn := int(d["max"])
        var cost := float(d["cost"]) * (have + 1)

        var card := UIKit.card(11)
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 10)
        card.add_child(h)

        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.add_theme_constant_override("separation", 3)
        h.add_child(info)
        var name_row := HBoxContainer.new()
        name_row.add_theme_constant_override("separation", 6)
        info.add_child(name_row)
        name_row.add_child(UIKit.label(str(d["name"]), 15, UIKit.ACCENT_900))
        name_row.add_child(UIKit.tag("%d/%d" % [have, maxn]))
        info.add_child(UIKit.muted(str(d["desc"]), 11))
        info.add_child(UIKit.muted("Lương %s ₫/ngày" % UIKit.money(float(d["salary"])), 11))

        if have >= maxn:
            var full := UIKit.button_ghost("ĐỦ NGƯỜI", 12)
            full.disabled = true
            full.custom_minimum_size = Vector2(156, 75)
            h.add_child(full)
        else:
            var hire := UIKit.button_secondary(UIKit.money_short(cost) + " ₫", 13)
            hire.custom_minimum_size = Vector2(156, 75)
            hire.set_meta("cost", cost)
            hire.pressed.connect(func():
                if GameManager.hire_staff(id):
                    _toast("Đã thuê thêm " + str(d["name"]).to_lower())
                else:
                    _toast("Không đủ tiền"))
            h.add_child(hire)
        list_box.add_child(card)


func _build_decor() -> void:
    list_box.add_child(UIKit.section("Trang trí — tăng không khí quán, khách tới nhiều hơn"))
    list_box.add_child(UIKit.muted("Không khí hiện tại: +%d · chỗ ngồi: %d" % [
        GameManager.ambiance(), GameManager.seats()], 12))

    for id in GameManager.DECOR:
        var d: Dictionary = GameManager.DECOR[id]
        var have := int(GameManager.decor.get(id, 0))
        var cost := float(d["cost"])

        var card := UIKit.card(11)
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 10)
        card.add_child(h)

        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.add_theme_constant_override("separation", 3)
        h.add_child(info)
        var nr := HBoxContainer.new()
        nr.add_theme_constant_override("separation", 6)
        info.add_child(nr)
        nr.add_child(UIKit.label(str(d["name"]), 15, UIKit.ACCENT_900))
        if have > 0:
            nr.add_child(UIKit.tag("đã có %d" % have, UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))
        info.add_child(UIKit.muted(str(d["desc"]), 11))

        var buy := UIKit.button_secondary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(156, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_decor(id):
                _toast("Đã đặt " + str(d["name"]).to_lower() + " vào quán")
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
        list_box.add_child(card)

    list_box.add_child(UIKit.spacer(6))
    list_box.add_child(UIKit.section("Mở rộng quán"))
    for f in GameManager.FLOORS:
        var fid := str(f["id"])
        if GameManager.is_floor_unlocked(fid):
            continue
        var card2 := UIKit.card(11)
        var h2 := HBoxContainer.new()
        h2.add_theme_constant_override("separation", 10)
        card2.add_child(h2)
        var info2 := VBoxContainer.new()
        info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info2.add_theme_constant_override("separation", 3)
        h2.add_child(info2)
        info2.add_child(UIKit.label(str(f["name"]), 15, UIKit.ACCENT_900))
        info2.add_child(UIKit.muted(str(f["note"]), 11))
        var open := UIKit.button_primary(UIKit.money_short(float(f["cost"])) + " ₫", 13)
        open.custom_minimum_size = Vector2(156, 75)
        open.set_meta("cost", float(f["cost"]))
        open.pressed.connect(func():
            if GameManager.unlock_floor(fid):
                _toast("Đã mở " + str(f["name"]).to_lower() + "!")
            else:
                _toast("Không đủ tiền"))
        h2.add_child(open)
        list_box.add_child(card2)


func _refresh_buttons_enabled() -> void:
    if list_box == null:
        return
    for card in list_box.get_children():
        _walk_buttons(card)


func _walk_buttons(node: Node) -> void:
    if node is Button and node.has_meta("cost"):
        node.disabled = not GameManager.can_afford(float(node.get_meta("cost")))
    for c in node.get_children():
        _walk_buttons(c)


func _toast(msg: String) -> void:
    toast_label.text = msg
    toast_timer = 2.2
    toast_panel.visible = true
