extends Control
## Khung chính: 4 màn hình Quán / Nhiệm vụ / Mua sắm / Cài đặt.
##
## Máy cầm ngang: thanh điều hướng dựng DỌC bên trái. Để nằm dưới như kiểu dọc
## thì mất đứt hơn trăm điểm ảnh chiều cao vốn đã rất hiếm khi màn hình xoay ngang.

const RestaurantViewScene := preload("res://views/restaurant_view.tscn")
const MissionsViewScene := preload("res://views/missions_view.tscn")
const ShoppingViewScene := preload("res://views/shopping_view.tscn")
const SettingsViewScene := preload("res://views/settings_view.tscn")

const TABS := [
    {"id": "restaurant", "label": "Quán", "glyph": "🍚"},
    {"id": "missions", "label": "Nhiệm vụ", "glyph": "🎯"},
    {"id": "shopping", "label": "Mua sắm", "glyph": "🛒"},
    {"id": "settings", "label": "Cài đặt", "glyph": "⚙"},
]

var content: Control
var views: Dictionary = {}
var buttons: Dictionary = {}
var glyphs: Dictionary = {}
var labels: Dictionary = {}
var safe_box: MarginContainer
var badge: Panel
var badge_label: Label
var current := "restaurant"


func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = UIKit.BG
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # Lề an toàn: chừa chỗ cho thanh trạng thái phía trên và thanh điều hướng
    # (hoặc vạch vuốt) phía dưới của điện thoại.
    safe_box = MarginContainer.new()
    safe_box.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(safe_box)

    var root := HBoxContainer.new()
    root.add_theme_constant_override("separation", 0)
    safe_box.add_child(root)

    root.add_child(_build_nav())

    content = Control.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.clip_contents = true
    root.add_child(content)

    for t in TABS:
        var id := str(t["id"])
        var v: Control
        match id:
            "restaurant":
                v = RestaurantViewScene.instantiate()
            "missions":
                v = MissionsViewScene.instantiate()
            "shopping":
                v = ShoppingViewScene.instantiate()
            _:
                v = SettingsViewScene.instantiate()
        content.add_child(v)
        v.set_anchors_preset(Control.PRESET_FULL_RECT)
        v.visible = false
        views[id] = v

    switch_tab("restaurant")

    GameManager.missions_changed.connect(_refresh_badge)
    GameManager.money_changed.connect(_refresh_badge)
    _refresh_badge()

    _apply_safe_area()
    get_tree().get_root().size_changed.connect(_apply_safe_area)


## Đổi vùng an toàn của máy (pixel màn hình) sang đơn vị viewport rồi đặt làm lề.
func _apply_safe_area() -> void:
    if safe_box == null:
        return
    var win := DisplayServer.window_get_size()
    if win.x <= 0 or win.y <= 0:
        return
    var safe := DisplayServer.get_display_safe_area()
    var vp := get_viewport_rect().size
    var sy := vp.y / float(win.y)
    var sx := vp.x / float(win.x)
    var top := int(maxf(0.0, float(safe.position.y) * sy))
    var bottom := int(maxf(0.0, float(win.y - (safe.position.y + safe.size.y)) * sy))
    # Nằm ngang thì tai thỏ nhảy sang bên hông, nên phải chừa lề trái/phải nữa
    # chứ không chỉ trên/dưới như lúc cầm dọc. Game chạy toàn màn hình (ẩn thanh
    # trạng thái và thanh điều hướng) nên không cần chừa thêm gì cho hệ điều hành.
    var left := int(maxf(0.0, float(safe.position.x) * sx))
    var right := int(maxf(0.0, float(win.x - (safe.position.x + safe.size.x)) * sx))
    safe_box.add_theme_constant_override("margin_top", top)
    safe_box.add_theme_constant_override("margin_bottom", bottom)
    safe_box.add_theme_constant_override("margin_left", left)
    safe_box.add_theme_constant_override("margin_right", right)


func _build_nav() -> Control:
    var panel := PanelContainer.new()
    var sb := UIKit.flat_pad(Color.WHITE, 0, 0, Color.WHITE, 0)
    sb.border_width_right = 1
    sb.border_color = UIKit.N200
    sb.shadow_color = Color(0.09, 0.13, 0.29, 0.10)
    sb.shadow_size = 10
    sb.shadow_offset = Vector2(2, 0)
    panel.add_theme_stylebox_override("panel", sb)

    var row := VBoxContainer.new()
    row.add_theme_constant_override("separation", 0)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(row)

    for t in TABS:
        var id := str(t["id"])
        var b := Button.new()
        b.size_flags_vertical = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size = Vector2(126, 0)
        b.flat = true
        b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        b.add_theme_stylebox_override("hover", UIKit.flat_pad(UIKit.N100, 0, 0, UIKit.N100, 0))
        b.add_theme_stylebox_override("pressed", UIKit.flat_pad(UIKit.N200, 0, 0, UIKit.N200, 0))
        b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        b.pressed.connect(switch_tab.bind(id))
        row.add_child(b)

        var v := VBoxContainer.new()
        v.set_anchors_preset(Control.PRESET_FULL_RECT)
        v.alignment = BoxContainer.ALIGNMENT_CENTER
        v.add_theme_constant_override("separation", 3)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(v)

        var g := UIKit.label(str(t["glyph"]), 17, UIKit.N600)
        g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(g)
        var l := UIKit.label(str(t["label"]), 10, UIKit.N600)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(l)

        # chấm đỏ báo phần thưởng đang chờ, gắn vào tab Nhiệm vụ
        if id == "missions":
            badge = Panel.new()
            var bsb := StyleBoxFlat.new()
            bsb.bg_color = UIKit.BAD
            bsb.set_corner_radius_all(999)
            badge.add_theme_stylebox_override("panel", bsb)
            badge.set_anchors_preset(Control.PRESET_CENTER)
            badge.offset_left = 18
            badge.offset_top = -34
            badge.offset_right = 52
            badge.offset_bottom = 0
            badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            badge.visible = false
            b.add_child(badge)
            badge_label = UIKit.label("", 12, Color.WHITE)
            badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
            badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            badge.add_child(badge_label)

        buttons[id] = b
        glyphs[id] = g
        labels[id] = l
    return panel


func _refresh_badge() -> void:
    if badge == null:
        return
    var n := GameManager.missions_ready()
    badge.visible = n > 0
    badge_label.text = str(n)


func switch_tab(id: String) -> void:
    current = id
    for key in views:
        (views[key] as Control).visible = key == id
    for key in buttons:
        var active: bool = key == id
        (glyphs[key] as Label).add_theme_color_override("font_color",
            UIKit.PRIMARY if active else UIKit.N600)
        (labels[key] as Label).add_theme_color_override("font_color",
            UIKit.PRIMARY if active else UIKit.N600)
        var b: Button = buttons[key]
        if active:
            var sb := UIKit.flat_pad(UIKit.PRIMARY_LIGHT, 0, 0, UIKit.PRIMARY_LIGHT, 0)
            sb.border_width_left = 3
            sb.border_color = UIKit.PRIMARY
            b.add_theme_stylebox_override("normal", sb)
        else:
            b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        GameManager.save_game()
