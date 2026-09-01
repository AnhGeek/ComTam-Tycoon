extends Control
## Màn hình mua sắm: nguyên liệu · nhân viên · trang trí · kho lạnh · kho đồ khô.
##
## Hai tab kho dùng chung một hàm dựng (`_build_store`) vì tủ lạnh và kệ đồ khô
## chạy y hệt nhau: mỗi khu tự mua của khu mình, nâng cấp riêng, chỗ trữ góp chung.
## `store_kind` nói tab đó là kho nào trong `GameManager.STORAGE`.

const TABS := [
    {"id": "ingredients", "label": "Nguyên liệu"},
    {"id": "staff", "label": "Nhân viên"},
    {"id": "decor", "label": "Trang trí"},
    {"id": "cold", "label": "Kho lạnh", "store_kind": "fridge"},
    {"id": "dry", "label": "Kho khô", "store_kind": "pantry"},
]


## Tab đang mở là kho nào — rỗng nghĩa là tab đó không phải tab kho.
static func store_kind_of(tab: String) -> String:
    for t in TABS:
        if str(t["id"]) == tab:
            return str(t.get("store_kind", ""))
    return ""

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
## Kho vừa đổi, khung hình sau dựng lại danh sách một lần (xem _mark_dirty).
var list_dirty := false


func _ready() -> void:
    _build()
    GameManager.money_changed.connect(_refresh_money)
    # Đừng nối thẳng vào _rebuild_list: kho nhúc nhích liên tục (quầy ra mẻ mỗi
    # giây, quản lý đi chợ, nhập nhanh cả loạt) mà mỗi tiếng lại dựng lại cả
    # danh sách thì màn này giật, nặng nhất là lúc nhập cho cả 3 khu. Chỉ ghi
    # dấu "cần dựng lại" rồi dựng đúng một lần ở khung hình kế tiếp.
    GameManager.stock_changed.connect(_mark_dirty)
    GameManager.state_changed.connect(_mark_dirty)
    _rebuild_list()
    _refresh_money()


## Ghi dấu để khung hình sau dựng lại, thay vì dựng ngay tại chỗ.
func _mark_dirty() -> void:
    list_dirty = true


func _process(delta: float) -> void:
    if list_dirty:
        list_dirty = false
        _rebuild_list()

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


## Danh sách khu trên đầu trang. Giờ tab nào cũng cần: kho lạnh và kho đồ khô
## tách riêng theo khu rồi, nên nhập hàng cũng là nhập cho một khu.
func _refresh_floor_row() -> void:
    if floor_row == null:
        return
    for c in floor_row.get_children():
        c.queue_free()
    if shop_floor.is_empty() or not GameManager.is_floor_unlocked(shop_floor):
        shop_floor = str(GameManager.FLOORS[0]["id"])
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
    if current == "ingredients":
        floor_note.text = "Đang nhập hàng về kho của: %s · mỗi khu một kho riêng" % fname
    elif current == "staff":
        floor_note.text = "Đang thuê người cho: %s · lương khu này %s ₫/ngày" % [
            fname, UIKit.money(GameManager.floor_salary(shop_floor))]
    elif not store_kind_of(current).is_empty():
        var kind := store_kind_of(current)
        floor_note.text = "%s của: %s · %d cái, cấp %d" % [
            str(GameManager.STORAGE[kind]["unit_name"]), fname,
            GameManager.store_count(kind, shop_floor),
            GameManager.store_level(kind, shop_floor)]
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
            _build_store("fridge")
        "dry":
            _build_store("pantry")
    _refresh_money()


func _build_ingredients() -> void:
    var fname := str(GameManager.floor_data(shop_floor)["name"])
    list_box.add_child(UIKit.section("Kho của %s — mua theo lố" % fname.to_lower()))

    var quick := UIKit.button_primary("NHẬP NHANH CHO ĐẦY KHO %s" % fname.to_upper(), 13)
    quick.custom_minimum_size = Vector2(0, 71)
    quick.pressed.connect(func():
        # món nào đã đầy thì thôi, món nào thiếu vẫn nhập — hết tiền mới chịu
        var thieu := _has_low_stock(shop_floor)
        var n := GameManager.buy_all_low(shop_floor)
        if n > 0:
            _toast("Đã nhập %d loại nguyên liệu" % n)
        elif thieu:
            _toast("Không đủ tiền nhập hàng")
        else:
            _toast("Kho khu này đang đầy, khỏi nhập"))
    list_box.add_child(quick)

    # Ba khu ba cái kho nên bấm qua bấm lại mỏi tay: cho luôn một nút nhập đầy cả quán.
    var quick_all := UIKit.button_secondary("NHẬP ĐẦY KHO CẢ 3 KHU", 13)
    quick_all.custom_minimum_size = Vector2(0, 71)
    quick_all.pressed.connect(func():
        var n := GameManager.buy_all_low_everywhere()
        if n > 0:
            _toast("Đã đi một vòng chợ cho cả quán")
        else:
            _toast("Không nhập được gì — kho đầy hoặc hết tiền"))
    list_box.add_child(quick_all)

    for id in GameManager.shop_ingredients():
        var d: Dictionary = GameManager.INGREDIENTS[id]
        var qty := float(GameManager.stock_at(shop_floor, str(id)))
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
        var nr := HBoxContainer.new()
        nr.add_theme_constant_override("separation", 6)
        info.add_child(nr)
        nr.add_child(UIKit.label(str(d["name"]), 15, UIKit.ACCENT_900))
        # nói luôn món này nằm kho nào, để biết phải kê thêm tủ hay thêm kệ
        var kind := GameManager.storage_of(str(id))
        if not kind.is_empty():
            nr.add_child(UIKit.tag(str(GameManager.STORAGE[kind]["name"]).to_lower(),
                UIKit.ACCENT_900, Color(0.31, 0.36, 0.54, 0.12)))

        # Mỗi món một trần riêng, do kho của nó ở KHU NÀY quyết định.
        var cap := float(GameManager.item_capacity(str(id), shop_floor))
        var full := cap > 0.0 and qty >= cap
        var low := cap > 0.0 and qty <= cap * 0.15
        var stock_col := UIKit.BAD if low else UIKit.N700
        info.add_child(UIKit.label("Còn %d/%d %s · lố %d · %s ₫/%s" % [
            int(qty), int(cap), str(d["unit"]), pack,
            UIKit.money(float(d["price"])), str(d["unit"])], 11, stock_col))
        # cả quán gom lại bao nhiêu, để biết còn khu nào đang ôm hàng hộ
        info.add_child(UIKit.muted("cả quán: %d/%d %s" % [
            int(GameManager.stock_total(str(id))),
            GameManager.item_capacity_all(str(id)), str(d["unit"])], 10))
        var bar_col: Color = UIKit.BAD if low else (UIKit.WARN if full else UIKit.ACCENT)
        info.add_child(UIKit.bar(clampf(qty / maxf(cap, 1.0) * 100.0, 0.0, 100.0), bar_col, 5))
        if full:
            info.add_child(UIKit.muted("%s đầy — kê thêm %s mới nhập được nữa" % [
                str(GameManager.STORAGE[kind]["name"]),
                str(GameManager.STORAGE[kind]["unit_name"]).to_lower()], 11))

        # kho đầy thì cái nút cũng thôi mời gọi, khỏi bấm cho mất công
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
            if GameManager.buy_ingredient(id, 1, shop_floor):
                _toast("Đã nhập %s về %s" % [str(d["name"]).to_lower(), fname.to_lower()])
            elif GameManager.stock_room(str(id), shop_floor) <= 0.0:
                _toast("Kho khu này đầy rồi — kê thêm chỗ trữ đi")
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
        list_box.add_child(card)


## Một tab kho — dùng chung cho tủ lạnh và kệ đồ khô, hai thứ chạy y hệt nhau:
## mỗi khu tự mua của khu mình, nâng cấp riêng, nhưng chỗ trữ thì góp chung vào
## một cái kho của quán, vì kho nguyên liệu xưa giờ vẫn dùng chung.
func _build_store(kind: String) -> void:
    var st: Dictionary = GameManager.STORAGE[kind]
    var fname := str(GameManager.floor_data(shop_floor)["name"])
    var unit_name := str(st["unit_name"])
    list_box.add_child(UIKit.section(unit_name + " " + fname.to_lower() + " — chỗ trữ hàng"))
    list_box.add_child(UIKit.muted(str(st["desc"]), 12))

    var have := GameManager.store_count(kind, shop_floor)
    var lv := GameManager.store_level(kind, shop_floor)

    # ---- thẻ 1: kê thêm một cái nữa cho khu này
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
    nr.add_child(UIKit.label(unit_name, 15, UIKit.ACCENT_900))
    if have > 0:
        nr.add_child(UIKit.tag("khu này %d/%d" % [have, GameManager.store_max(kind)],
            UIKit.OK, Color(0.31, 0.54, 0.36, 0.14)))
    info.add_child(UIKit.muted("Mỗi cái cấp %d trữ thêm: %s" % [
        lv, _slot_line(kind, lv)], 11))
    if GameManager.store_at_max(kind, shop_floor):
        var no_room := UIKit.button_secondary("HẾT CHỖ KÊ", 13)
        no_room.custom_minimum_size = Vector2(156, 75)
        no_room.disabled = true
        h.add_child(no_room)
    else:
        var cost := GameManager.store_cost(kind, shop_floor)
        var buy := UIKit.button_primary(UIKit.money_short(cost) + " ₫", 13)
        buy.custom_minimum_size = Vector2(156, 75)
        buy.set_meta("cost", cost)
        buy.pressed.connect(func():
            if GameManager.buy_store(kind, shop_floor):
                _toast("Đã kê thêm %s cho %s" % [unit_name.to_lower(), fname.to_lower()])
            else:
                _toast("Không đủ tiền"))
        h.add_child(buy)
    list_box.add_child(card)

    # ---- thẻ 2: nâng cấp, mọi cái của khu này cùng rộng ra một nấc
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
    nr2.add_child(UIKit.label("Nâng cấp " + unit_name.to_lower(), 15, UIKit.ACCENT_900))
    nr2.add_child(UIKit.tag("C%d/%d" % [lv, GameManager.MAX_LEVEL],
        UIKit.ACCENT_900, Color(0.31, 0.36, 0.54, 0.12)))
    if lv < GameManager.MAX_LEVEL:
        info2.add_child(UIKit.muted("Lên cấp %d thì mỗi cái trữ thêm: %s" % [
            lv + 1, _slot_line(kind, lv + 1)], 11))
    else:
        info2.add_child(UIKit.muted("Đã kịch cấp", 11))
    if have <= 0:
        var none := UIKit.button_secondary("CHƯA CÓ CÁI NÀO", 13)
        none.custom_minimum_size = Vector2(156, 75)
        none.disabled = true
        h2.add_child(none)
    elif GameManager.store_level_at_max(kind, shop_floor):
        var maxed := UIKit.button_secondary("ĐÃ TỐI ĐA", 13)
        maxed.custom_minimum_size = Vector2(156, 75)
        maxed.disabled = true
        h2.add_child(maxed)
    else:
        var ucost := GameManager.store_upgrade_cost(kind, shop_floor)
        var up := UIKit.button_secondary(UIKit.money_short(ucost) + " ₫", 13)
        up.custom_minimum_size = Vector2(156, 75)
        up.set_meta("cost", ucost)
        up.pressed.connect(func():
            if GameManager.upgrade_store(kind, shop_floor):
                _toast("%s %s lên cấp %d" % [unit_name, fname.to_lower(),
                    GameManager.store_level(kind, shop_floor)])
            else:
                _toast("Không đủ tiền"))
        h2.add_child(up)
    list_box.add_child(card2)

    # ---- kho này đang chứa gì, mỗi món một trần riêng
    list_box.add_child(UIKit.spacer(6))
    list_box.add_child(UIKit.section("%s đang trữ" % fname))
    for cid in st["items"]:
        var ing: Dictionary = GameManager.INGREDIENTS[cid]
        var qty := float(GameManager.stock_at(shop_floor, str(cid)))
        var cap := float(GameManager.item_capacity(str(cid), shop_floor))
        var row := UIKit.card(9)
        var rv := VBoxContainer.new()
        rv.add_theme_constant_override("separation", 3)
        row.add_child(rv)
        rv.add_child(UIKit.label("%s — %d/%d %s" % [
            str(ing["name"]), int(qty), int(cap), str(ing["unit"])], 13, UIKit.ACCENT_900))
        rv.add_child(UIKit.bar(clampf(qty / maxf(cap, 1.0) * 100.0, 0.0, 100.0),
            UIKit.WARN if qty >= cap else UIKit.ACCENT, 5))
        # trần của khu này gồm phần có sẵn cộng phần mấy cái tủ/kệ khu này góp
        rv.add_child(UIKit.muted("có sẵn %d · tủ kệ khu này góp %d · cả quán %d/%d" % [
            GameManager.store_cap_base(kind, str(cid)),
            GameManager.store_floor_capacity(kind, shop_floor, str(cid)),
            int(GameManager.stock_total(str(cid))),
            GameManager.item_capacity_all(str(cid))], 11))
        list_box.add_child(row)


## Một cái tủ/kệ cấp `lv` trữ thêm được gì — viết gọn thành một dòng.
func _slot_line(kind: String, lv: int) -> String:
    var parts: Array = []
    for cid in GameManager.STORAGE[kind]["items"]:
        parts.append("%d %s" % [GameManager.store_slot(kind, str(cid), lv),
            str(GameManager.INGREDIENTS[cid]["unit"])])
    return " · ".join(parts)


## Còn món nào chưa đầy kho không — để cái toast nói cho đúng chuyện.
func _has_low_stock(fid: String) -> bool:
    for id in GameManager.shop_ingredients():
        if GameManager.stock_at(fid, str(id)) < GameManager.stock_target(str(id), fid):
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
