extends Control
## Màn hình mua sắm: nguyên liệu · nhân viên · trang trí · kho lạnh.

const TABS := [
    {"id": "ingredients", "label": "Nguyên liệu"},
    {"id": "staff", "label": "Nhân viên"},
    {"id": "decor", "label": "Trang trí"},
    {"id": "cold", "label": "Kho lạnh"},
]

var current := "ingredients"
## Đang mua sắm cho khu nào — nhân viên với trang trí đều tính riêng từng khu,
## chỉ có kho nguyên liệu là chung cả quán.
var shop_floor := ""
var money_label: Label
var tab_buttons: Dictionary = {}
var floor_row: HBoxContainer
var floor_note: Label
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

    # Hàng nút chọn khu: mua cho khu nào thì bấm khu đó trước.
    floor_row = HBoxContainer.new()
    floor_row.add_theme_constant_override("separation", 6)
    hv.add_child(floor_row)
    floor_note = UIKit.label("", 11, UIKit.BG)
    hv.add_child(floor_note)
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


## Danh sách khu trên đầu trang. Tab nguyên liệu không cần chọn khu vì kho dùng
## chung, nên chỗ đó chỉ ghi một dòng nhắc.
func _refresh_floor_row() -> void:
    if floor_row == null:
        return
    for c in floor_row.get_children():
        c.queue_free()
    if shop_floor.is_empty() or not GameManager.is_floor_unlocked(shop_floor):
        shop_floor = str(GameManager.FLOORS[0]["id"])
    if current == "ingredients":
        floor_row.visible = false
        floor_note.text = "Kho nguyên liệu dùng chung cho cả 3 khu · đồ tươi trữ tối đa %d mỗi món" \
            % GameManager.cold_capacity()
        return
    floor_row.visible = true
    for f in GameManager.FLOORS:
        var fid := str(f["id"])
        if not GameManager.is_floor_unlocked(fid):
            continue
        var on := fid == shop_floor
        var tb: Button = UIKit.button_primary(str(f["name"]), 12) if on else UIKit.button_secondary(str(f["name"]), 12)
        tb.custom_minimum_size = Vector2(0, 52)
        tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tb.pressed.connect(func():
            shop_floor = fid
            _rebuild_list())
        floor_row.add_child(tb)
    var fname := str(GameManager.floor_data(shop_floor)["name"])
    if current == "staff":
        floor_note.text = "Đang thuê người cho: %s · lương khu này %s ₫/ngày" % [
            fname, UIKit.money(GameManager.floor_salary(shop_floor))]
    elif current == "cold":
        floor_note.text = "Tủ lạnh của: %s · %d cái, cấp %d" % [
            fname, GameManager.fridge_count(shop_floor), GameManager.fridge_level(shop_floor)]
    else:
        floor_note.text = "Đang bày biện cho: " + fname


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
    _refresh_floor_row()
    for c in list_box.get_children():
        c.queue_free()
    match current:
        "ingredients":
            _build_ingredients()
        "staff":
            _build_staff()
        "decor":
            _build_decor()
        "cold":
            _build_cold()
    _refresh_money()


func _build_ingredients() -> void:
    list_box.add_child(UIKit.section("Kho nguyên liệu — mua theo lố"))

    var quick := UIKit.button_primary("NHẬP NHANH CHO ĐẦY KHO", 13)
    quick.custom_minimum_size = Vector2(0, 71)
    quick.pressed.connect(func():
        # món nào đã đầy thì thôi, món nào thiếu vẫn nhập — hết tiền mới chịu
        var thieu := _has_low_stock()
        var n := GameManager.buy_all_low()
        if n > 0:
            _toast("Đã nhập %d loại nguyên liệu" % n)
        elif thieu:
            _toast("Không đủ tiền nhập hàng")
        else:
            _toast("Kho đang đầy, khỏi nhập"))
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
        var cold := GameManager.is_cold(id)
        var cap := float(GameManager.cold_capacity())
        var full := cold and qty >= cap
        var stock_col := UIKit.BAD if low else UIKit.N700
        # Đồ tươi đo theo trần kho lạnh, đồ khô thì chất bao nhiêu cũng được nên
        # cứ lấy mốc 60 cho dễ nhìn.
        var line := "Còn %d %s · lố %d · %s ₫/%s" % [
            int(qty), str(d["unit"]), pack, UIKit.money(float(d["price"])), str(d["unit"])]
        if cold:
            line = "Còn %d/%d %s · lố %d · %s ₫/%s" % [
                int(qty), int(cap), str(d["unit"]), pack,
                UIKit.money(float(d["price"])), str(d["unit"])]
        info.add_child(UIKit.label(line, 11, stock_col))
        var pct := qty / cap * 100.0 if cold else qty / 60.0 * 100.0
        var bar_col: Color = UIKit.BAD if low else (UIKit.WARN if full else UIKit.ACCENT)
        var bar := UIKit.bar(clampf(pct, 0.0, 100.0), bar_col, 5)
        info.add_child(bar)
        if full:
            info.add_child(UIKit.muted("Kho lạnh đầy — kê thêm tủ lạnh mới nhập được nữa", 11))

        # kho lạnh đầy thì cái nút cũng thôi mời gọi, khỏi bấm cho mất công
        if full:
            var stop := UIKit.button_secondary("KHO ĐẦY", 13)
            stop.custom_minimum_size = Vector2(150, 75)
            stop.disabled = true
            h.add_child(stop)
            list_box.add_child(card)
            continue
        var buy := UIKit.button_secondary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(150, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_ingredient(id):
                _toast("Đã nhập %s vào kho" % str(d["name"]).to_lower())
            elif GameManager.is_cold(id) and GameManager.stock_room(id) <= 0.0:
                _toast("Kho lạnh đầy rồi — kê thêm tủ đi")
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
        list_box.add_child(card)


## Kho lạnh: tủ lạnh mua riêng cho từng khu, nâng cấp cũng riêng từng khu —
## nhưng chỗ trữ thì góp chung vào một cái kho của quán, vì kho nguyên liệu xưa
## giờ vẫn dùng chung.
func _build_cold() -> void:
    var fname := str(GameManager.floor_data(shop_floor)["name"])
    list_box.add_child(UIKit.section("Tủ lạnh " + fname.to_lower() + " — chỗ trữ đồ tươi"))

    var names: Array = []
    for cid in GameManager.COLD_ITEMS:
        names.append(str(GameManager.INGREDIENTS[cid]["name"]).to_lower())
    list_box.add_child(UIKit.muted("Trữ lạnh: " + ", ".join(names)
        + " · cả quán %d mỗi món" % GameManager.cold_capacity(), 12))

    var have := GameManager.fridge_count(shop_floor)
    var lv := GameManager.fridge_level(shop_floor)

    # ---- thẻ 1: kê thêm một cái tủ nữa cho khu này
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
    nr.add_child(UIKit.label("Tủ lạnh", 15, UIKit.ACCENT_900))
    if have > 0:
        nr.add_child(UIKit.tag("khu này %d/%d" % [have, GameManager.FRIDGE_MAX],
            UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))
    info.add_child(UIKit.muted("Mỗi cái trữ thêm %d mỗi món tươi (cấp %d)" % [
        GameManager.FRIDGE_SLOT + (lv - 1) * GameManager.FRIDGE_SLOT_STEP, lv], 11))
    if GameManager.fridge_at_max(shop_floor):
        var full := UIKit.button_secondary("HẾT CHỖ KÊ", 13)
        full.custom_minimum_size = Vector2(156, 75)
        full.disabled = true
        h.add_child(full)
    else:
        var cost := GameManager.fridge_cost(shop_floor)
        var buy := UIKit.button_primary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(156, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_fridge(shop_floor):
                _toast("Đã kê thêm tủ lạnh cho " + fname.to_lower())
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
    list_box.add_child(card)

    # ---- thẻ 2: nâng cấp tủ của khu này, mọi cái tủ cùng rộng ra một nấc
    var card2 := UIKit.card(11)
    var h2 := HBoxContainer.new()
    h2.add_theme_constant_override("separation", 10)
    card2.add_child(h2)
    var info2 := VBoxContainer.new()
    info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info2.add_theme_constant_override("separation", 3)
    h2.add_child(info2)
    var nr2 := HBoxContainer.new()
    nr2.add_theme_constant_override("separation", 6)
    info2.add_child(nr2)
    nr2.add_child(UIKit.label("Nâng cấp tủ lạnh", 15, UIKit.ACCENT_900))
    nr2.add_child(UIKit.tag("C%d" % lv, UIKit.ACCENT_900, Color(0.31, 0.36, 0.54, 0.12)))
    info2.add_child(UIKit.muted("Khu này góp %d chỗ mỗi món · lên cấp thì mỗi tủ rộng thêm %d" % [
        GameManager.fridge_floor_capacity(shop_floor), GameManager.FRIDGE_SLOT_STEP], 11))
    if have <= 0:
        var none := UIKit.button_secondary("CHƯA CÓ TỦ", 13)
        none.custom_minimum_size = Vector2(156, 75)
        none.disabled = true
        h2.add_child(none)
    elif GameManager.fridge_level_at_max(shop_floor):
        var maxed := UIKit.button_secondary("ĐÃ TỐI ĐA", 13)
        maxed.custom_minimum_size = Vector2(156, 75)
        maxed.disabled = true
        h2.add_child(maxed)
    else:
        var ucost := GameManager.fridge_upgrade_cost(shop_floor)
        var up := UIKit.button_secondary(UIKit.money_short(ucost) + " ₫", 13)
        up.custom_minimum_size = Vector2(156, 75)
        up.set_meta("cost", ucost)
        up.pressed.connect(func():
            if GameManager.upgrade_fridge(shop_floor):
                _toast("Tủ lạnh %s lên cấp %d" % [fname.to_lower(),
                    GameManager.fridge_level(shop_floor)])
            else:
                _toast("Không đủ tiền"))
        h2.add_child(up)
    list_box.add_child(card2)

    # ---- kho lạnh đang chứa gì
    list_box.add_child(UIKit.spacer(6))
    list_box.add_child(UIKit.section("Đồ tươi đang trữ"))
    for cid in GameManager.COLD_ITEMS:
        var ing: Dictionary = GameManager.INGREDIENTS[cid]
        var qty := float(GameManager.stock.get(cid, 0.0))
        var cap := float(GameManager.cold_capacity())
        var row := UIKit.card(9)
        var rv := VBoxContainer.new()
        rv.add_theme_constant_override("separation", 3)
        row.add_child(rv)
        rv.add_child(UIKit.label("%s — %d/%d %s" % [
            str(ing["name"]), int(qty), int(cap), str(ing["unit"])], 13, UIKit.ACCENT_900))
        rv.add_child(UIKit.bar(clampf(qty / cap * 100.0, 0.0, 100.0),
            UIKit.WARN if qty >= cap else UIKit.ACCENT, 5))
        list_box.add_child(row)


## Còn món nào chưa đầy kho không — để cái toast nói cho đúng chuyện.
func _has_low_stock() -> bool:
    for id in GameManager.shop_ingredients():
        if float(GameManager.stock.get(id, 0.0)) < GameManager.stock_target(str(id)):
            return true
    return false


## Khu đang chọn có sẵn mấy người (gộp mọi loại) nhờ đã mở khu.
func _free_here() -> int:
    var n := 0
    for id in GameManager.STAFF:
        n += GameManager.staff_free(shop_floor, str(id))
    return n


func _build_staff() -> void:
    var fname := str(GameManager.floor_data(shop_floor)["name"])
    list_box.add_child(UIKit.section("Nhân viên " + fname.to_lower() + " — trả lương mỗi cuối ngày"))
    # người đi kèm khi mở khu không ăn lương, nên số người và tiền lương lệch nhau
    list_box.add_child(UIKit.muted("Khu này %d người (%d có sẵn khi mở khu) · lương %s ₫/ngày · cả quán %s ₫/ngày" % [
        GameManager.floor_crew(shop_floor), _free_here(),
        UIKit.money(GameManager.floor_salary(shop_floor)),
        UIKit.money(GameManager.daily_salary())], 12))

    for id in GameManager.STAFF:
        var d: Dictionary = GameManager.STAFF[id]
        var have := GameManager.staff_count(shop_floor, id)
        var maxn := GameManager.staff_max(id)
        var cost := GameManager.hire_cost(id, shop_floor)

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
        name_row.add_child(UIKit.tag("khu này %d/%d" % [have, maxn]))
        var free := GameManager.staff_free(shop_floor, str(id))
        if free > 0:
            name_row.add_child(UIKit.tag("%d có sẵn" % free, UIKit.ACCENT_900,
                Color(0.31, 0.36, 0.54, 0.12)))
        var everyone := GameManager.staff_total(str(id))
        if everyone > have:
            name_row.add_child(UIKit.tag("cả quán %d" % everyone, UIKit.ACCENT_900, Color(0.31, 0.36, 0.54, 0.12)))
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
                if GameManager.hire_staff(id, shop_floor):
                    _toast("Đã thuê thêm " + str(d["name"]).to_lower() + " cho " + fname.to_lower())
                else:
                    _toast("Không đủ tiền"))
            h.add_child(hire)
        list_box.add_child(card)


func _build_decor() -> void:
    list_box.add_child(UIKit.section("Trang trí — tăng không khí quán, khách tới nhiều hơn"))
    # trang trí mua cho khu nào thì chỉ khu đó hưởng, nên nói rõ số của khu trước
    list_box.add_child(UIKit.muted("Khu này: không khí +%d · %d chỗ · %d khách/phút — cả quán +%d, %d chỗ" % [
        GameManager.floor_ambiance(shop_floor), GameManager.floor_seats(shop_floor),
        int(GameManager.floor_arrival_rate(shop_floor)),
        GameManager.ambiance(), GameManager.seats()], 12))

    for id in GameManager.DECOR:
        var d: Dictionary = GameManager.DECOR[id]
        var have := GameManager.decor_count(shop_floor, id)
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
            nr.add_child(UIKit.tag("khu này %d" % have, UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))
        var everywhere := GameManager.decor_total(id)
        if everywhere > have:
            nr.add_child(UIKit.tag("cả quán %d" % everywhere, UIKit.ACCENT_900, Color(0.31, 0.36, 0.54, 0.12)))
        info.add_child(UIKit.muted(str(d["desc"]), 11))

        var buy := UIKit.button_secondary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(156, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_decor(id, shop_floor):
                _toast("Đã đặt " + str(d["name"]).to_lower() + " vào "
                    + str(GameManager.floor_data(shop_floor)["name"]).to_lower())
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
