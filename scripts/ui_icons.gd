class_name UIIcon
extends Control
## Bộ biểu tượng vẽ tay bằng hình khối, không cần file ảnh.
##
## Game idle kiểu này sống nhờ mấy cái icon vuông vắn: ghế, sao, tờ tiền, dấu X.
## Vẽ thẳng bằng `_draw()` thì icon nét căng ở mọi cỡ màn hình và đổi màu được
## theo trạng thái (khoá thì xám, mở thì xanh) mà không phải nhập thêm tài nguyên.

var kind := "seat"
var color := Color.WHITE
var accent := Color(1, 1, 1, 0.55)


static func make(icon_kind: String, size: float, c: Color = Color.WHITE,
        c2: Color = Color(0, 0, 0, 0)) -> UIIcon:
    var i := UIIcon.new()
    i.kind = icon_kind
    i.color = c
    i.accent = c2 if c2.a > 0.0 else Color(c.r, c.g, c.b, 0.5)
    i.custom_minimum_size = Vector2(size, size)
    i.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return i


func _ready() -> void:
    resized.connect(queue_redraw)


## Hộp vuông giữa control: mọi hình vẽ bên dưới tính theo ô 0..1 trong hộp này.
func _box() -> Rect2:
    var s: float = minf(size.x, size.y)
    return Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _r(bx: Rect2, x: float, y: float, w: float, h: float, c: Color, rad: float = 0.0) -> void:
    var rect := Rect2(bx.position + Vector2(x, y) * bx.size.x,
        Vector2(w, h) * bx.size.x)
    if rad > 0.0:
        draw_style_box(_rounded(c, rad * bx.size.x), rect)
    else:
        draw_rect(rect, c)


func _rounded(c: Color, rad: float) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = c
    sb.set_corner_radius_all(int(rad))
    return sb


func _draw() -> void:
    var b := _box()
    var s := b.size.x
    match kind:
        "seat":
            # ghế băng nhìn chính diện: lưng tựa + hai đệm ngồi
            _r(b, 0.08, 0.24, 0.84, 0.30, color, 0.07)
            _r(b, 0.08, 0.58, 0.38, 0.20, color, 0.05)
            _r(b, 0.54, 0.58, 0.38, 0.20, color, 0.05)
            _r(b, 0.14, 0.78, 0.08, 0.12, color, 0.03)
            _r(b, 0.78, 0.78, 0.08, 0.12, color, 0.03)
        "star":
            var pts := PackedVector2Array()
            for i in 10:
                var ang := -PI * 0.5 + float(i) * PI / 5.0
                var rad: float = s * (0.48 if i % 2 == 0 else 0.2)
                pts.append(b.position + b.size * 0.5 + Vector2(cos(ang), sin(ang)) * rad)
            draw_colored_polygon(pts, color)
        "cash":
            _r(b, 0.06, 0.26, 0.88, 0.48, color, 0.08)
            draw_circle(b.position + b.size * Vector2(0.5, 0.5), s * 0.13, accent)
            _r(b, 0.12, 0.32, 0.06, 0.36, accent, 0.03)
            _r(b, 0.82, 0.32, 0.06, 0.36, accent, 0.03)
        "close":
            var w := s * 0.13
            var p0 := b.position + b.size * 0.27
            var p1 := b.position + b.size * 0.73
            draw_line(p0, p1, color, w, true)
            draw_line(Vector2(p1.x, p0.y), Vector2(p0.x, p1.y), color, w, true)
        "lock":
            _r(b, 0.2, 0.46, 0.6, 0.42, color, 0.1)
            draw_arc(b.position + b.size * Vector2(0.5, 0.46), s * 0.22, PI, TAU, 14,
                color, s * 0.11, true)
        "arrow_up":
            var cx := b.position.x + s * 0.5
            var tip := Vector2(cx, b.position.y + s * 0.14)
            draw_colored_polygon(PackedVector2Array([tip,
                Vector2(cx - s * 0.34, b.position.y + s * 0.5),
                Vector2(cx + s * 0.34, b.position.y + s * 0.5)]), color)
            _r(b, 0.34, 0.5, 0.32, 0.36, color, 0.04)
        "manager":
            # thẻ quản lý: hai lá bài chồng nhau
            _r(b, 0.14, 0.2, 0.46, 0.62, accent, 0.07)
            _r(b, 0.36, 0.14, 0.5, 0.68, color, 0.07)
        "chart":
            _r(b, 0.12, 0.56, 0.18, 0.32, color, 0.04)
            _r(b, 0.41, 0.36, 0.18, 0.52, color, 0.04)
            _r(b, 0.7, 0.16, 0.18, 0.72, color, 0.04)
        "plant":
            draw_circle(b.position + b.size * Vector2(0.36, 0.34), s * 0.17, color)
            draw_circle(b.position + b.size * Vector2(0.64, 0.34), s * 0.17, color)
            draw_circle(b.position + b.size * Vector2(0.5, 0.2), s * 0.16, color)
            _r(b, 0.47, 0.3, 0.06, 0.34, accent, 0.02)
            _r(b, 0.28, 0.62, 0.44, 0.26, color, 0.06)
        "cup":
            draw_colored_polygon(PackedVector2Array([
                b.position + b.size * Vector2(0.24, 0.22),
                b.position + b.size * Vector2(0.76, 0.22),
                b.position + b.size * Vector2(0.66, 0.86),
                b.position + b.size * Vector2(0.34, 0.86)]), color)
            _r(b, 0.24, 0.3, 0.52, 0.08, accent)
        "bowl":
            draw_arc(b.position + b.size * Vector2(0.5, 0.44), s * 0.34, 0.0, PI, 18,
                color, s * 0.13, true)
            _r(b, 0.12, 0.74, 0.76, 0.1, color, 0.05)
        "flame":
            draw_colored_polygon(PackedVector2Array([
                b.position + b.size * Vector2(0.5, 0.1),
                b.position + b.size * Vector2(0.84, 0.56),
                b.position + b.size * Vector2(0.5, 0.9),
                b.position + b.size * Vector2(0.16, 0.56)]), color)
            draw_circle(b.position + b.size * Vector2(0.5, 0.62), s * 0.16, accent)
        "person":
            draw_circle(b.position + b.size * Vector2(0.5, 0.3), s * 0.17, color)
            draw_arc(b.position + b.size * Vector2(0.5, 0.92), s * 0.34, PI, TAU, 18,
                color, s * 0.2, true)
        _:
            _r(b, 0.16, 0.16, 0.68, 0.68, color, 0.1)
