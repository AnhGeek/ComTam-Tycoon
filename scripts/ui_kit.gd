class_name UIKit
## Hệ thống giao diện kiểu game idle hiện đại: nền sáng, thẻ bo tròn,
## nút màu no và đổ bóng nhẹ, điểm nhấn vàng cho tiền.

# ---------- Bảng màu ----------
const BG := Color("eef1f8")          # nền chung, xanh xám rất nhạt
const BG_DEEP := Color("e3e8f4")
const SURFACE := Color("ffffff")
const CARD := Color("ffffff")
const TEXT := Color("16203a")
const TEXT_SOFT := Color("55618a")

const PRIMARY := Color("4c6fff")     # xanh dương chủ đạo
const PRIMARY_DARK := Color("3454e0")
const PRIMARY_LIGHT := Color("dfe6ff")

const VIOLET := Color("7c5cff")
const TEAL := Color("14c4a9")
const GOLD := Color("ffb32b")        # tiền
const GOLD_DARK := Color("e2951a")
const CORAL := Color("ff6f5c")

const OK := Color("22c38e")
const BAD := Color("ff5c5c")
const WARN := Color("ff9f43")

const N100 := Color("f6f8fd")
const N200 := Color("e9edf7")
const N300 := Color("d7ddec")
const N400 := Color("b9c2da")
const N600 := Color("8792b3")
const N700 := Color("6b7699")
const N800 := Color("47527a")

# tương thích với tên cũ dùng rải rác trong các màn hình
const ACCENT := PRIMARY
const ACCENT_100 := PRIMARY_LIGHT
const ACCENT_400 := Color("93a8ff")
const ACCENT_700 := PRIMARY_DARK
const ACCENT_800 := Color("2b3f9e")
const ACCENT_900 := Color("1d2a63")

# ---------- Kích thước ----------
## Viewport rộng 720 ăn khớp 1:1 với màn hình điện thoại 720px, mà mật độ điểm ảnh
## của máy là ~1,7 px mỗi dp. Nên mọi cỡ chữ khai báo trong code phải nhân lên
## chừng đó thì trên máy mới đọc được và nút mới đủ to để chạm.
const UI_SCALE := 1.6
const PAD := 18
const GAP := 12
const RADIUS := 18
const RADIUS_SM := 12


## Quy đổi cỡ chữ khai báo trong code sang cỡ thật trên màn hình.
static func fs(n: int) -> int:
    return int(round(float(n) * UI_SCALE))


## Quy đổi kích thước vùng chạm (nút, thẻ) sang cỡ thật.
static func px(n: float) -> float:
    return round(n * UI_SCALE)


# ---------- StyleBox ----------
static func flat(bg: Color, border_w: int = 0, border_c: Color = N300, radius: int = RADIUS) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.set_corner_radius_all(radius)
    sb.set_content_margin_all(PAD)
    if border_w > 0:
        sb.set_border_width_all(border_w)
        sb.border_color = border_c
    return sb


static func flat_pad(bg: Color, pad: int, border_w: int = 0, border_c: Color = N300,
        radius: int = RADIUS) -> StyleBoxFlat:
    var sb := flat(bg, border_w, border_c, radius)
    sb.set_content_margin_all(pad)
    return sb


## Thẻ nổi: bo tròn + bóng đổ mềm.
static func card_style(bg: Color = CARD, pad: int = PAD, radius: int = RADIUS) -> StyleBoxFlat:
    var sb := flat_pad(bg, pad, 0, N300, radius)
    sb.shadow_color = Color(0.09, 0.13, 0.29, 0.10)
    sb.shadow_size = 8
    sb.shadow_offset = Vector2(0, 3)
    return sb


## Nút nổi khối: bóng đậm hơn cho cảm giác bấm được.
static func button_style(bg: Color, radius: int = RADIUS_SM, shadow: float = 0.28) -> StyleBoxFlat:
    var sb := flat_pad(bg, 12, 0, bg, radius)
    sb.shadow_color = Color(bg.r * 0.4, bg.g * 0.4, bg.b * 0.55, shadow)
    sb.shadow_size = 6
    sb.shadow_offset = Vector2(0, 3)
    return sb


# ---------- Chữ ----------
static func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", fs(size))
    l.add_theme_color_override("font_color", color)
    return l


static func heading(text: String, size: int = 18, color: Color = TEXT) -> Label:
    return label(text, size, color)


static func section(text: String) -> Label:
    return label(text.to_upper(), 11, N600)


static func muted(text: String, size: int = 12) -> Label:
    return label(text, size, TEXT_SOFT)


# ---------- Nút ----------
static func _style_button(b: Button, bg: Color, fg: Color, border_c: Color, border_w: int) -> void:
    if border_w > 0:
        var n := flat_pad(bg, 12, border_w, border_c, RADIUS_SM)
        var h := flat_pad(bg.lightened(0.06), 12, border_w, border_c, RADIUS_SM)
        var pr := flat_pad(bg.darkened(0.08), 12, border_w, border_c.darkened(0.1), RADIUS_SM)
        b.add_theme_stylebox_override("normal", n)
        b.add_theme_stylebox_override("hover", h)
        b.add_theme_stylebox_override("pressed", pr)
    else:
        b.add_theme_stylebox_override("normal", button_style(bg))
        b.add_theme_stylebox_override("hover", button_style(bg.lightened(0.08)))
        b.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.12), RADIUS_SM, 0.12))
    b.add_theme_stylebox_override("disabled", flat_pad(N200, 12, 0, N200, RADIUS_SM))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_color_override("font_color", fg)
    b.add_theme_color_override("font_hover_color", fg)
    b.add_theme_color_override("font_pressed_color", fg)
    b.add_theme_color_override("font_focus_color", fg)
    b.add_theme_color_override("font_disabled_color", N600)


static func button_primary(text: String, size: int = 15) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs(size))
    _style_button(b, PRIMARY, Color.WHITE, PRIMARY, 0)
    return b


## Nút tiền: dùng cho thu tiền, mua bằng tiền.
static func button_gold(text: String, size: int = 14) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs(size))
    _style_button(b, GOLD, Color("40300a"), GOLD, 0)
    return b


static func button_secondary(text: String, size: int = 14) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs(size))
    _style_button(b, PRIMARY_LIGHT, PRIMARY_DARK, PRIMARY_LIGHT, 0)
    return b


static func button_ghost(text: String, size: int = 13) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs(size))
    _style_button(b, Color(0, 0, 0, 0), N700, N300, 1)
    return b


static func button_danger(text: String, size: int = 14) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs(size))
    _style_button(b, BAD, Color.WHITE, BAD, 0)
    return b


# ---------- Thẻ / khung ----------
static func card(pad: int = PAD) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", card_style(CARD, pad))
    return p


static func plain_panel(bg: Color, pad: int = PAD, radius: int = 0) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", flat_pad(bg, pad, 0, bg, radius))
    return p


## Ô nhãn nhỏ bo tròn (tag).
static func tag(text: String, fg: Color = PRIMARY_DARK, bg: Color = PRIMARY_LIGHT) -> PanelContainer:
    var p := PanelContainer.new()
    var sb := flat_pad(bg, 0, 0, bg, 999)
    sb.content_margin_left = 9
    sb.content_margin_right = 9
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    p.add_theme_stylebox_override("panel", sb)
    p.add_child(label(text, 11, fg))
    return p


static func bar(value: float = 0.0, color: Color = PRIMARY, height: int = 8) -> ProgressBar:
    height = int(px(height))
    var pb := ProgressBar.new()
    pb.min_value = 0.0
    pb.max_value = 100.0
    pb.value = value
    pb.show_percentage = false
    pb.custom_minimum_size = Vector2(0, height)
    var bg_sb := StyleBoxFlat.new()
    bg_sb.bg_color = N200
    bg_sb.set_corner_radius_all(height / 2)
    var fg_sb := StyleBoxFlat.new()
    fg_sb.bg_color = color
    fg_sb.set_corner_radius_all(height / 2)
    pb.add_theme_stylebox_override("background", bg_sb)
    pb.add_theme_stylebox_override("fill", fg_sb)
    return pb


static func separator() -> HSeparator:
    var s := HSeparator.new()
    var sb := StyleBoxLine.new()
    sb.color = N200
    sb.thickness = 1
    s.add_theme_stylebox_override("separator", sb)
    return s


static func spacer(h: int = 0) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    if h == 0:
        c.size_flags_vertical = Control.SIZE_EXPAND_FILL
    return c


## Ô nhập số (màn hình đặt giá).
static func style_spinbox(spin: SpinBox) -> void:
    var le := spin.get_line_edit()
    le.add_theme_font_size_override("font_size", fs(15))
    le.add_theme_color_override("font_color", TEXT)
    le.add_theme_color_override("font_uneditable_color", N600)
    le.add_theme_color_override("caret_color", PRIMARY)
    le.add_theme_color_override("font_selected_color", Color.WHITE)
    le.add_theme_color_override("selection_color", PRIMARY)
    le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
    le.add_theme_stylebox_override("normal", flat_pad(N100, 8, 2, N300, RADIUS_SM))
    le.add_theme_stylebox_override("read_only", flat_pad(N200, 8, 2, N200, RADIUS_SM))
    le.add_theme_stylebox_override("focus", flat_pad(PRIMARY_LIGHT, 8, 2, PRIMARY, RADIUS_SM))
    spin.add_theme_color_override("up_icon_modulate", PRIMARY)
    spin.add_theme_color_override("down_icon_modulate", PRIMARY)


# ---------- Định dạng số ----------
## 1234567 -> "1.234.567"
static func money(value: float) -> String:
    var neg := value < 0.0
    var s := str(int(round(absf(value))))
    var out := ""
    var count := 0
    for i in range(s.length() - 1, -1, -1):
        out = s[i] + out
        count += 1
        if count % 3 == 0 and i > 0:
            out = "." + out
    return ("-" if neg else "") + out


## 1234567 -> "1,2Tr" ; 12400 -> "12,4N"
static func money_short(value: float) -> String:
    var v := absf(value)
    var sign_s := "-" if value < 0.0 else ""
    if v >= 1000000000.0:
        return sign_s + ("%.1f" % (v / 1000000000.0)).replace(".", ",") + "Tỷ"
    if v >= 1000000.0:
        return sign_s + ("%.1f" % (v / 1000000.0)).replace(".", ",") + "Tr"
    if v >= 1000.0:
        return sign_s + ("%.1f" % (v / 1000.0)).replace(".", ",") + "N"
    return sign_s + str(int(v))
