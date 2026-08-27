class_name StarBadge
extends Control
## Ngôi sao uy tín: vẽ nổi khối kiểu 3D và luôn động đậy.
##
## Sao chạy DỌC THEO thanh tiến độ (uy tín tới đâu, sao đứng tới đó) nên nó phải
## tự sống: thở phập phồng, thỉnh thoảng loé sáng, và cứ dăm giây lại xoay trọn
## một vòng quanh chính nó. Vẽ bằng `_draw()` để không cần tài nguyên ảnh.

## Màu thân sao. Mặt sáng, mặt tối và viền đều suy ra từ màu này.
@export var body := Color("c46bff")

var value := 0: set = _set_value

const POINTS := 5
const INNER := 0.42          # bán kính đỉnh trong so với đỉnh ngoài
const PULSE_SPEED := 2.3     # nhịp thở
const PULSE_AMOUNT := 0.09   # thở phồng thêm bao nhiêu
const TWINKLE_EVERY := 2.6   # mấy giây loé một lần
const SPIN_EVERY := 7.0      # mấy giây xoay trọn một vòng
const SPIN_TIME := 0.9       # xoay một vòng mất bao lâu

var _t := 0.0
var _spin := 0.0
var _spin_left := 0.0
var _twinkle := 0.0
var _label: Label


func _set_value(v: int) -> void:
    value = v
    if _label != null:
        _label.text = str(v)


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label = Label.new()
    _label.text = str(value)
    _label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", int(size.x * 0.34))
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.add_theme_color_override("font_outline_color", body.darkened(0.55))
    _label.add_theme_constant_override("outline_size", int(maxf(size.x * 0.05, 2.0)))
    add_child(_label)
    resized.connect(func():
        pivot_offset = size * 0.5
        _label.add_theme_font_size_override("font_size", int(size.x * 0.34)))
    pivot_offset = size * 0.5


func _process(delta: float) -> void:
    _t += delta

    # thở: to nhỏ quanh cỡ gốc
    var pulse := 1.0 + sin(_t * PULSE_SPEED) * PULSE_AMOUNT
    scale = Vector2(pulse, pulse)

    # xoay trọn vòng: cứ SPIN_EVERY giây lại quay một lần cho vui mắt
    if _spin_left > 0.0:
        _spin_left = maxf(0.0, _spin_left - delta)
        _spin = (1.0 - _spin_left / SPIN_TIME) * TAU
    else:
        _spin = 0.0
        if fmod(_t, SPIN_EVERY) < delta:
            _spin_left = SPIN_TIME

    # loé sáng: một nhịp ngắn rồi tắt
    var phase := fmod(_t, TWINKLE_EVERY)
    _twinkle = clampf(1.0 - phase / 0.45, 0.0, 1.0)
    queue_redraw()


## Các đỉnh của ngôi sao, có thể xoay và phóng to theo ý.
func _star_points(centre: Vector2, radius: float, spin: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in POINTS * 2:
        var ang := -PI * 0.5 + spin + float(i) * PI / float(POINTS)
        var r: float = radius if i % 2 == 0 else radius * INNER
        pts.append(centre + Vector2(cos(ang), sin(ang)) * r)
    return pts


func _draw() -> void:
    var c := size * 0.5
    var r := minf(size.x, size.y) * 0.5

    # 1. bóng đổ phía dưới cho sao có bề dày
    draw_colored_polygon(_star_points(c + Vector2(0, r * 0.12), r * 0.98, _spin),
        body.darkened(0.55))
    # 2. thân sao
    draw_colored_polygon(_star_points(c, r * 0.98, _spin), body)
    # 3. mặt sáng lệch lên trên bên trái: đúng chỗ ánh sáng hắt vào khối nổi
    draw_colored_polygon(_star_points(c - Vector2(r * 0.08, r * 0.1), r * 0.6, _spin),
        body.lightened(0.42))

    # 4. loé sáng: một chữ thập mảnh chạy ngang qua đỉnh sao
    if _twinkle > 0.01:
        var glow := Color(1, 1, 1, _twinkle)
        var arm := r * (0.5 + _twinkle * 0.5)
        var tip := c + Vector2(r * 0.55, -r * 0.55)
        draw_line(tip - Vector2(arm, 0), tip + Vector2(arm, 0), glow, maxf(r * 0.07, 1.0), true)
        draw_line(tip - Vector2(0, arm), tip + Vector2(0, arm), glow, maxf(r * 0.07, 1.0), true)
