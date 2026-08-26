class_name DragScroll
extends Node
## Cho phép cuộn danh sách bằng cách kéo ngón tay, kèm quán tính.
##
## Vì sao phải tự viết: project bật `emulate_mouse_from_touch`, nên sự kiện chạm
## gốc (InputEventScreenTouch/Drag) bị đổi thành sự kiện chuột trước khi tới giao
## diện. ScrollContainer chỉ tự cuộn khi nhận được sự kiện chạm gốc, nên nó không
## bao giờ cuộn được. Ở đây bắt sự kiện sớm trong `_input` rồi cuộn bằng tay.
##
## Dùng:  DragScroll.attach(scroll_container)

const DRAG_THRESHOLD := 14.0   # kéo quá ngần này mới coi là cuộn chứ không phải chạm
const FRICTION := 6.0          # độ hãm của quán tính
const MIN_FLICK := 40.0        # vận tốc nhỏ hơn thì dừng luôn

const AXIS_NONE := 0
const AXIS_V := 1
const AXIS_H := 2

var scroll: ScrollContainer

var _pressed := false
var _scrolling := false
var _moved := 0.0
var _velocity := 0.0


## Gắn bộ cuộn kéo vào một ScrollContainer.
static func attach(target: ScrollContainer) -> DragScroll:
    var d := DragScroll.new()
    d.scroll = target
    d.name = "DragScroll"
    target.add_child(d)
    return d


func _ready() -> void:
    set_process_input(true)
    set_process(true)


## Trục nào cuộn được thì kéo theo trục đó (danh sách dọc, dải quầy ngang).
func _axis() -> int:
    if scroll == null or not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
        return AXIS_NONE
    var vb := scroll.get_v_scroll_bar()
    if vb.max_value > vb.page:
        return AXIS_V
    var hb := scroll.get_h_scroll_bar()
    if hb.max_value > hb.page:
        return AXIS_H
    return AXIS_NONE


func _can_scroll() -> bool:
    return _axis() != AXIS_NONE


func _inside(pos: Vector2) -> bool:
    return scroll.get_global_rect().has_point(pos)


func _input(event: InputEvent) -> void:
    if not _can_scroll():
        return

    # ---- bắt đầu chạm ----
    if event is InputEventScreenTouch or event is InputEventMouseButton:
        if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
            return
        if event.pressed:
            if _inside(event.position):
                _pressed = true
                _scrolling = false
                _moved = 0.0
                _velocity = 0.0
        else:
            # Đã kéo để cuộn thì nuốt luôn cú nhả tay, kẻo nút bên dưới bị bấm nhầm.
            if _scrolling:
                get_viewport().set_input_as_handled()
            _pressed = false
            _scrolling = false

    # ---- đang kéo ----
    elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _pressed):
        if not _pressed:
            return
        var axis := _axis()
        var d: float = event.relative.y if axis == AXIS_V else event.relative.x
        _moved += absf(d)
        if not _scrolling and _moved > DRAG_THRESHOLD:
            _scrolling = true
        if _scrolling:
            if axis == AXIS_V:
                scroll.scroll_vertical -= int(round(d))
            else:
                scroll.scroll_horizontal -= int(round(d))
            var dt := maxf(get_process_delta_time(), 0.0001)
            _velocity = -d / dt
            get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
    # ---- quán tính sau khi nhả tay ----
    if _pressed or absf(_velocity) < MIN_FLICK:
        _velocity = 0.0
        return
    if not _can_scroll():
        _velocity = 0.0
        return
    if _axis() == AXIS_V:
        scroll.scroll_vertical += int(round(_velocity * delta))
    else:
        scroll.scroll_horizontal += int(round(_velocity * delta))
    _velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta)
