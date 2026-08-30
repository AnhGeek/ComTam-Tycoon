class_name TycoonWorld
extends Node3D
## Toà nhà cắt lớp kiểu idle tycoon: các tầng xếp chồng, camera góc nghiêng cố định,
## vuốt dọc để đổi tầng, chạm bong bóng ₫ để thu tiền, chạm quầy để nấu nhanh.

signal station_tapped(id: String)
signal floor_tapped(fid: String)
signal grill_tapped
signal focus_changed(index: int)
signal collected(amount: float)
signal boosted(id: String)
signal furniture_tapped(index: int)
signal placement_changed(valid: bool, zone: String)

# ---------- Kích thước không gian ----------
## Quán chỉ có MỘT TẦNG TRỆT. Các "tầng" trong GameManager giờ là các KHU nằm
## cạnh nhau trên cùng mặt đất, nhìn từ trên xuống kiểu idle tycoon: không mái,
## không tầng lầu, chỉ hai bức tường xa để thấy hết lòng quán.
const FLOOR_H := 3.3               # chiều cao tường (đủ thấp để nhìn chéo xuống không bị che)

## Mỗi khu là một gian nhà nối liền, cách nhau đúng bề dày tường chung.
const WING_GAP := 0.5
const WING_DX := ROOM_W + WING_GAP

# Lò than vỉa hè: đặt nép mé trong, chừa nguyên khoảng vỉa hè cho khách kê bàn.
const GRILL_POS := Vector3(-3.25, 0.0, ROOM_D * 0.5 + 0.95)
const GRILL_MEATS := 6             # số miếng thịt bày trên vỉ cho vui mắt

const SERVICE_SEGMENTS := 12       # số vạch trên vòng "đang ra món"
const MAX_CUSTOMERS := 12          # trần số khách mỗi khu, giữ cho điện thoại yếu chạy mượt
const ACTOR_LOD_RANGE := 1.5       # khu cách tầm nhìn quá xa thì thôi tính hoạt hình
const ROOM_W := 7.6
const ROOM_D := 5.2
const SLAB := 0.3

## Góc nhìn chúc xuống hẳn: thấy trọn mặt sàn, tường thấp không úp lên bàn ghế.
## Góc mở hẹp + camera lùi thật xa = gần như phối cảnh trục đo: bàn ghế ở mép
## dưới khung không còn phình to gấp đôi bàn ghế trong quán nữa.
const CAM_FOV := 20.0
const CAM_PITCH := -42.0
## Nhìn từ phía trước BÊN PHẢI: hai bức tường (sau + trái) đều nằm ở phía xa nên
## không bức nào úp lên lòng quán, đúng kiểu nhà cắt góc của game idle tycoon.
const YAW_HOME := 0.32
const YAW_RANGE := 0.26
## Khung nhìn tính theo BỀ NGANG một khu chứ không theo chiều cao tầng nữa:
## sát nhất là vừa một bộ bàn, xa nhất là thấy cả dãy nhà lẫn lòng đường.
const VIEW_MIN_H := 4.0
const VIEW_MAX_H := 30.0

## Thu phóng: người chơi chụm/xoè hai ngón (hoặc bấm +/-) để kéo khung nhìn ra
## tận vỉa hè. 1.0 = khung mặc định vừa đúng bề ngang quán.
const ZOOM_MIN := 0.62
const ZOOM_MAX := 3.20
const ZOOM_HOME := 1.0

## Kéo hai ngón để dời khung nhìn (xem dãy bàn ngoài đường chẳng hạn).
const PAN_LIMIT_X := 9.0
const PAN_LIMIT_Y := 7.0

# ---------- Vỉa hè trước quán ----------
## Mặt đường thấp hơn nền quán 40cm (có bậc thềm), bàn ngoài đặt ở cao độ này.
const OUT_Y := -0.4
const OUT_Z0 := ROOM_D * 0.5 + 0.85      # sát bậc thềm
const OUT_Z1 := ROOM_D * 0.5 + 3.45      # mép vỉa hè, quá nữa là lòng đường
const OUT_HW := ROOM_W * 0.5 + 0.9       # vỉa hè rộng hơn mặt tiền một chút

# ---------- Bảng màu: sáng, no màu, kiểu game idle hiện đại ----------
const C_SKY := Color8(0xdc, 0xe6, 0xfa)
const C_FLOOR := Color8(0xf2, 0xec, 0xe0)
const C_FLOOR_LINE := Color8(0xdf, 0xd4, 0xc1)
const C_WALL := Color8(0xff, 0xff, 0xff)
const C_WALL_DEEP := Color8(0xed, 0xf1, 0xfa)
const C_STEEL := Color8(0x4c, 0x6f, 0xff)
const C_STEEL_DARK := Color8(0x2b, 0x37, 0x66)
const C_STEEL_LIGHT := Color8(0xb9, 0xc6, 0xe6)
const C_WOOD := Color8(0xc9, 0x8f, 0x5c)
const C_WOOD_DARK := Color8(0xa1, 0x6c, 0x42)
const C_HOT := Color8(0xff, 0x7a, 0x35)
const C_LOCK := Color8(0xc9, 0xcf, 0xdd)
const C_HAZARD := Color8(0xff, 0xb3, 0x2b)
const C_GOLD := Color8(0xff, 0xb3, 0x2b)
const C_ROAD := Color8(0x7b, 0x83, 0x98)
const C_WALK := Color8(0xcf, 0xd6, 0xe4)
const C_PLANT := Color8(0x3f, 0xc0, 0x77)
const C_PLATE := Color8(0xfa, 0xfb, 0xfd)
const C_PLASTIC_BLUE := Color8(0x2f, 0x7a, 0xd8)   # ghế nhựa xanh, đúng kiểu quán cóc
const C_PLASTIC_RED := Color8(0xe0, 0x45, 0x3b)
const C_AWNING := Color8(0xe8, 0x5b, 0x4a)
const C_TILE := Color8(0xdb, 0xe1, 0xec)
const C_EMBER := Color8(0xff, 0x4d, 0x1a)          # than đang đỏ
const C_ASH := Color8(0x4a, 0x44, 0x4d)            # than chưa bén lửa
const C_MEAT := Color8(0xb5, 0x5f, 0x38)           # sườn sống
const C_MEAT_DONE := Color8(0x7a, 0x3a, 0x1e)      # sườn đã cháy cạnh
const C_OK := Color8(0x22, 0xc3, 0x8e)
const C_NO := Color8(0xff, 0x5c, 0x5c)

## Mỗi tầng một màu nhận diện riêng.
const FLOOR_ACCENTS := [
    Color8(0x14, 0xc4, 0xa9),
    Color8(0x4c, 0x6f, 0xff),
    Color8(0x7c, 0x5c, 0xff),
]

const LBL_PX := 0.006

# ---------- Tư thế bưng khay ----------
## Cánh tay buông xuống, cẳng tay gập ngang ra trước — kiểu bưng khay thật.
const CARRY_SHOULDER := -0.34
const CARRY_ELBOW := -1.52
const CARRY_OUT := -0.16      # hơi dang ra ngoài cho khay khỏi đụng người

# ---------- Trạng thái ----------
var focus := 0.0
var target_focus := 0.0
var yaw := YAW_HOME
var zoom := ZOOM_HOME
var pan := Vector2.ZERO       # dời khung nhìn: x ngang theo hướng camera, y dọc
var _time := 0.0
var _view_height := 9.7
var _base_height := 9.7

var cam_pivot: Node3D
var camera: Camera3D
var _floor_nodes: Dictionary = {}
var _station_nodes: Dictionary = {}
var _actors: Array = []
var _seats: Array = []
var _tables: Dictionary = {}      # chỉ số tầng -> Array[Vector3] tâm bàn
var _dragging := false
var _drag_moved := 0.0
var _floats: Array = []
var _service: Dictionary = {}      # chỉ số khu -> vòng chờ món của người phục vụ
var _meters: Array = []            # mọi vòng đếm giờ đang có trong cảnh
var _grill: Dictionary = {}        # các bộ phận của lò than để cập nhật mỗi khung hình
var _reported_floor := -1
var _multi := false                 # đang có từ hai ngón trở lên chạm màn hình
var _multi_hold := 0.0

# ---------- Chế độ đặt bàn ----------
var place_mode := false
var place_kind := ""
var place_floor := 0
var place_zone := "out"
var place_x := 0.0
var place_z := 0.0
var place_rot := 0
var place_valid := false
var place_move_index := -1
var _ghost: Node3D
var _furni_nodes: Array = []
var _furni_by_index: Dictionary = {}   # chỉ số trong GameManager.placed -> node
var _blockers: Dictionary = {}         # tầng -> [{pos, r}] chỗ không kê bàn được


func _ready() -> void:
    _build_environment()
    _build_camera()
    _build_street()
    rebuild()
    GameManager.state_changed.connect(_on_state_changed)
    GameManager.grill_batch_ready.connect(_on_grill_batch)
    set_process_unhandled_input(true)


func _on_state_changed() -> void:
    rebuild()


# ================= Tiện ích dựng hình =================

func _box(parent: Node3D, sx: float, sy: float, sz: float, c: Color, x: float, y: float, z: float,
        rough: float = 0.72) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(sx, sy, sz)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = ComTamChars.mat(c, rough)
    mi.position = Vector3(x, y, z)
    parent.add_child(mi)
    return mi


func _cylinder(parent: Node3D, rt: float, rb: float, h: float, c: Color, x: float, y: float, z: float,
        seg: int = 12) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = rt
    mesh.bottom_radius = rb
    mesh.height = h
    mesh.radial_segments = seg
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = ComTamChars.mat(c, 0.72)
    mi.position = Vector3(x, y, z)
    parent.add_child(mi)
    return mi


func _label3d(parent: Node3D, text: String, size: int, c: Color, x: float, y: float, z: float,
        billboard: bool = true) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.font_size = size
    l.pixel_size = LBL_PX
    l.modulate = c
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
    l.shaded = false
    l.double_sided = true
    l.position = Vector3(x, y, z)
    l.render_priority = 2
    parent.add_child(l)
    return l


# ================= Môi trường & camera =================

func _build_environment() -> void:
    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = C_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color8(0xdb, 0xe4, 0xf5)
    env.ambient_light_energy = 0.78
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 50.0
    sun.shadow_bias = 0.04
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-14, 152, 0)
    fill.light_energy = 0.34
    add_child(fill)


func _build_camera() -> void:
    cam_pivot = Node3D.new()
    cam_pivot.name = "CamPivot"
    add_child(cam_pivot)
    camera = Camera3D.new()
    camera.fov = CAM_FOV
    camera.near = 0.2
    camera.far = 260.0
    camera.rotation_degrees = Vector3(CAM_PITCH, 0, 0)
    cam_pivot.add_child(camera)
    _update_camera()


func _fit_distance() -> float:
    var vp := get_viewport()
    var vsize: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720, 900)
    var aspect := clampf(vsize.x / maxf(vsize.y, 1.0), 0.4, 2.2)
    # Khung mặc định phải ôm trọn một khu: từ tường sau ra tới mép vỉa hè. Nhìn
    # chúc xuống nên chiều sâu mặt đất ăn vào chiều DỌC khung hình theo sin(góc
    # chúc), còn tường thì ăn thêm một đoạn theo cos.
    var pitch := deg_to_rad(-CAM_PITCH)
    var fw := ROOM_W + 1.4                       # bề ngang gian nhà + lề hai bên
    var fd := OUT_Z1 + 0.8 + ROOM_D * 0.5        # tường sau -> mép vỉa hè
    var horiz := fw * absf(cos(yaw)) + fd * absf(sin(yaw))
    var vert := (fw * absf(sin(yaw)) + fd * absf(cos(yaw))) * sin(pitch) + FLOOR_H * cos(pitch)
    _base_height = maxf(vert, horiz / aspect)
    _view_height = clampf(_base_height * zoom, VIEW_MIN_H, VIEW_MAX_H)
    return (_view_height * 0.5) / tan(deg_to_rad(CAM_FOV) * 0.5)


func _update_camera() -> void:
    var d := _fit_distance()
    var pitch := deg_to_rad(-CAM_PITCH)
    camera.position = Vector3(0, sin(pitch) * d, cos(pitch) * d)
    # Tâm nhìn nằm ngay trên mặt sàn của KHU đang xem: đổi khu là trượt ngang,
    # không còn leo lên leo xuống theo tầng nữa.
    var zoom_out := clampf(_view_height / maxf(_base_height, 0.01) - 1.0, 0.0, 1.6)
    var y := 0.7
    # tâm nhìn đặt giữa lòng quán và mép vỉa hè; kéo xa thì lùi thêm ra đường
    var z := 2.5 + zoom_out * 1.5
    # pan.x chạy dọc trục ngang của camera nên kéo tay sang đâu, cảnh trôi theo đó
    var right := Vector3(cos(yaw), 0.0, -sin(yaw))
    cam_pivot.position = Vector3(wing_x(focus), y + pan.y, z) + right * pan.x
    cam_pivot.rotation.y = yaw


## Tâm của khu thứ `index` trên trục ngang (nhận cả số lẻ để trượt mượt giữa hai khu).
func wing_x(index: float) -> float:
    return (index - float(GameManager.FLOORS.size() - 1) * 0.5) * WING_DX


## Thu phóng quanh mức mặc định. `mult` > 1 là kéo ra xa.
func zoom_by(mult: float) -> void:
    zoom = clampf(zoom * mult, ZOOM_MIN, ZOOM_MAX)


func zoom_ratio() -> float:
    return (zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN)


## Dời khung nhìn theo quãng ngón tay đã trượt (đơn vị điểm ảnh màn hình).
func pan_by(delta_px: Vector2) -> void:
    var vp := get_viewport()
    var h: float = vp.get_visible_rect().size.y if vp != null else 600.0
    var wpp := _view_height / maxf(h, 1.0)      # mỗi điểm ảnh là bấy nhiêu mét
    pan.x = clampf(pan.x - delta_px.x * wpp, -PAN_LIMIT_X, PAN_LIMIT_X)
    pan.y = clampf(pan.y + delta_px.y * wpp, -PAN_LIMIT_Y, PAN_LIMIT_Y)


## Về lại khung nhìn gốc của tầng đang xem.
func reset_view() -> void:
    zoom = ZOOM_HOME
    pan = Vector2.ZERO
    yaw = YAW_HOME


# ================= Mặt đường dưới chân toà nhà =================

func _build_street() -> void:
    var s := Node3D.new()
    s.name = "Street"
    s.position = Vector3(0, -0.4, 0)
    add_child(s)
    var hd := ROOM_D * 0.5
    # Cả dãy nhà nằm trên một mặt đất duy nhất nên nền phố phải dài hơn dãy nhà.
    var span := float(GameManager.FLOORS.size()) * WING_DX + 18.0
    var half := span * 0.5
    # thảm cỏ chạy vòng phía sau: nhìn từ trên xuống là thấy hết đất sau lưng quán
    _box(s, span, 0.16, 26.0, C_PLANT, 0, -0.12, -hd - 13.6, 0.95)
    _box(s, span, 0.2, 7.4, C_WALK, 0, -0.1, hd + 3.0)
    _box(s, span, 0.14, 10.0, C_ROAD, 0, -0.2, hd + 11.6)
    _box(s, span, 0.1, 0.22, Color8(0xb9, 0xc0, 0xcf), 0, -0.05, hd + 6.6)   # mép bó vỉa
    for i in int(span / 3.6):
        _box(s, 1.1, 0.02, 0.16, Color8(0xe6, 0xea, 0xee), -half + 1.8 + i * 3.6, -0.12, hd + 11.0)
    # xe máy dựng nép hai bên cho khoảng giữa vỉa hè trống chỗ kê bàn
    for bx in [-half + 3.4, -half + 4.8, half - 4.8, half - 3.4]:
        _box(s, 0.42, 0.32, 1.2, C_STEEL_DARK, bx, 0.2, hd + 5.6)
        _cylinder(s, 0.23, 0.23, 0.1, Color8(0x3a, 0x3e, 0x42), bx, 0.14, hd + 5.12, 12).rotation_degrees = Vector3(0, 0, 90)
        _cylinder(s, 0.23, 0.23, 0.1, Color8(0x3a, 0x3e, 0x42), bx, 0.14, hd + 6.08, 12).rotation_degrees = Vector3(0, 0, 90)
        _box(s, 0.1, 0.4, 0.15, C_STEEL_LIGHT, bx, 0.52, hd + 5.2)
    for tx in [-half + 1.4, half - 1.4]:
        _cylinder(s, 0.16, 0.2, 1.5, Color8(0x7a, 0x6a, 0x5c), tx, 0.75, hd + 3.0, 8)
        _cylinder(s, 0.1, 1.0, 1.5, C_PLANT, tx, 2.1, hd + 3.0, 8)
    # bụi cây sau lưng quán cho khoảng đất trống đỡ trơ
    for i in int(span / 4.2):
        var bx2 := -half + 2.4 + float(i) * 4.2
        _cylinder(s, 0.9, 1.0, 0.7, Color8(0x35, 0xa8, 0x66), bx2, 0.35, -hd - 2.6, 10)
        _cylinder(s, 0.55, 0.62, 0.5, C_PLANT, bx2 + 0.8, 0.25, -hd - 3.4, 10)
    # hàng rào sắt & nhà bên kia đường cho có chiều sâu phố
    for i in int(span / 3.1):
        _box(s, 0.08, 1.1, 0.08, Color8(0x5c, 0x6b, 0x54), -half + 1.0 + i * 3.1, 0.55, hd + 6.9)


# ================= Dựng các tầng =================

func rebuild() -> void:
    for c in _floor_nodes.values():
        (c as Node).queue_free()
    _floor_nodes.clear()
    _station_nodes.clear()
    _actors.clear()
    _seats.clear()
    _tables.clear()
    _furni_nodes.clear()
    _furni_by_index.clear()
    _blockers.clear()
    _service.clear()
    _meters.clear()
    _grill.clear()

    for i in GameManager.FLOORS.size():
        var f: Dictionary = GameManager.FLOORS[i]
        var fid := str(f["id"])
        var node := Node3D.new()
        node.name = "Wing_" + fid
        node.position = Vector3(wing_x(float(i)), 0, 0)
        add_child(node)
        _floor_nodes[fid] = node
        if GameManager.is_floor_unlocked(fid):
            _build_floor(node, fid, i)
        else:
            _build_locked_floor(node, fid, f)


## 4 quầy xếp đều dọc tường sau; đủ hẹp để không bị cắt ở mép màn hình.
func _station_slot(i: int) -> Vector3:
    return Vector3(-2.7 + float(i) * 1.8, 0, -ROOM_D * 0.5 + 1.15)


func _build_floor(node: Node3D, fid: String, index: int) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    var accent: Color = FLOOR_ACCENTS[index % FLOOR_ACCENTS.size()]
    _blockers[index] = []
    # mỗi khu có cửa riêng ra vỉa hè: chừa lối vào, đừng kê bàn chắn ngang
    (_blockers[index] as Array).append({"pos": Vector2(hw - 0.5, hd - 0.9), "r": 0.95})

    # sàn + gờ sàn màu nhận diện khu
    _box(node, ROOM_W, SLAB, ROOM_D, C_FLOOR, 0, -SLAB * 0.5, 0, 0.8)
    _box(node, ROOM_W + 0.26, 0.14, ROOM_D + 0.26, accent, 0, -SLAB - 0.07, 0, 0.5)
    var line_mat := ComTamChars.mat(C_FLOOR_LINE, 0.85)
    for gx in range(1, int(ROOM_W)):
        _box(node, 0.025, 0.014, ROOM_D - 0.3, C_FLOOR_LINE, -hw + gx, 0.009, 0).material_override = line_mat
    for gz in range(1, int(ROOM_D)):
        _box(node, ROOM_W - 0.3, 0.014, 0.025, C_FLOOR_LINE, 0, 0.009, -hd + gz).material_override = line_mat

    # Nhà trệt không mái: chỉ dựng tường sau và tường trái, hai mặt còn lại để
    # trống hẳn cho góc nhìn chúc xuống thấy trọn lòng quán.
    var wall_h := FLOOR_H - SLAB
    _box(node, ROOM_W, wall_h, 0.16, C_WALL, 0, wall_h * 0.5, -hd, 0.9)
    _box(node, 0.16, wall_h, ROOM_D, C_WALL_DEEP, -hw, wall_h * 0.5, 0, 0.9)
    # gờ mép tường (thay cho diềm mái): viền màu chạy trên đầu hai bức tường
    _box(node, ROOM_W + 0.3, 0.16, 0.34, accent, 0, wall_h + 0.05, -hd, 0.5)
    _box(node, 0.34, 0.16, ROOM_D + 0.3, accent, -hw, wall_h + 0.05, 0, 0.5)
    _box(node, ROOM_W, 0.16, 0.07, accent, 0, 0.08, -hd + 0.1, 0.5)
    _box(node, 0.07, 0.16, ROOM_D, accent, -hw + 0.1, 0.08, 0, 0.5)

    # bảng tên khu gắn trên tường sau, ngay dưới mép tường
    var f := GameManager.floor_data(fid)
    _box(node, ROOM_W - 1.6, 0.78, 0.1, C_STEEL_DARK, 0, wall_h - 0.62, -hd + 0.13, 0.4)
    _label3d(node, str(f["name"]).to_upper(), 40, Color8(0xf6, 0xf8, 0xfc),
        0, wall_h - 0.5, -hd + 0.2, false)
    _label3d(node, "KHU %d" % (index + 1), 26, accent, 0, wall_h - 0.9, -hd + 0.2, false)

    # quầy bếp dọc tường sau
    _box(node, ROOM_W - 0.5, 0.95, 1.0, C_WOOD, 0, 0.48, -hd + 1.15)
    _box(node, ROOM_W - 0.5, 0.16, 1.02, accent, 0, 0.9, -hd + 1.15, 0.5)
    _box(node, ROOM_W - 0.3, 0.1, 1.16, C_WALL, 0, 1.02, -hd + 1.15, 0.55)

    # vỉa hè trước quán chạy suốt cả dãy; riêng khu trệt mới có lò than + bảng hiệu
    _build_terrace(node, accent, index == 0)

    # quầy hàng
    var sids := GameManager.stations_on_floor(fid)
    for i in sids.size():
        _build_station(node, str(sids[i]), _station_slot(i), index)

    # bàn ăn có sẵn của quán: nhà trệt không còn cầu thang nên kê được cả hai bên
    var spots: Array = [Vector2(-2.2, 0.5), Vector2(2.6, 0.5)]
    _tables[index] = []
    for i in spots.size():
        _build_table(node, spots[i], index)

    _build_decor(node, index, accent)
    _build_placed(node, index)
    _populate(node, fid, index)


# ---------- Lò than nướng sườn ngoài vỉa hè ----------

func _emissive(node: MeshInstance3D, c: Color, power: float) -> void:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = power
    node.material_override = m


## Xe lò than: thùng tôn trên chân sắt, lòng đầy than đỏ, vỉ nướng bắc ngang,
## mấy miếng sườn nằm trên vỉ và khói bốc lên nghi ngút phía trước.
func _build_grill_stall(t: Node3D, accent: Color) -> void:
    var g := Node3D.new()
    g.name = "GrillStall"
    g.position = GRILL_POS
    t.add_child(g)

    # chân sắt + thùng lò
    for sx in [-0.66, 0.66]:
        for sz in [-0.2, 0.2]:
            _box(g, 0.05, 0.62, 0.05, C_STEEL_DARK, sx, 0.31, sz)
    _box(g, 1.5, 0.1, 0.56, C_STEEL_DARK, 0, 0.2, 0, 0.6)      # kệ để đồ dưới gầm
    _box(g, 1.5, 0.34, 0.56, C_STEEL_DARK, 0, 0.79, 0, 0.45)
    _box(g, 1.54, 0.06, 0.6, accent, 0, 0.97, 0, 0.5)
    _box(g, 1.5, 0.16, 0.06, C_STEEL, 0, 0.88, 0.31, 0.5)      # tấm chắn gió phía trước

    # lớp than trong lòng lò
    var embers: Array = []
    for i in 7:
        var e := _box(g, 0.17, 0.05, 0.3, C_ASH, -0.58 + float(i) * 0.19, 0.9, 0, 0.9)
        _emissive(e, C_EMBER, 1.6)
        embers.append(e)

    # vỉ nướng: mấy thanh sắt bắc ngang miệng lò
    for i in 9:
        _box(g, 0.025, 0.02, 0.5, C_STEEL_LIGHT, -0.6 + float(i) * 0.15, 1.0, 0, 0.35)
    _box(g, 1.3, 0.025, 0.025, C_STEEL_LIGHT, 0, 1.0, -0.24, 0.35)
    _box(g, 1.3, 0.025, 0.025, C_STEEL_LIGHT, 0, 1.0, 0.24, 0.35)

    # sườn nằm trên vỉ
    var meats: Array = []
    for i in GRILL_MEATS:
        var pivot := Node3D.new()
        pivot.position = Vector3(-0.52 + float(i) * 0.21, 1.03, randf_range(-0.1, 0.1))
        g.add_child(pivot)
        var slab := _box(pivot, 0.17, 0.045, 0.34, C_MEAT, 0, 0, 0, 0.55)
        _box(pivot, 0.05, 0.05, 0.36, C_WOOD_DARK, 0.07, 0.0, 0, 0.7)   # dải mỡ
        meats.append({"pivot": pivot, "slab": slab, "phase": randf() * TAU})

    # ngọn lửa liếm qua vỉ: hai lớp, lõi vàng bên trong, lưỡi cam bên ngoài
    var flames: Array = []
    for i in 9:
        var fx := -0.58 + float(i) * 0.145
        var outer := _cylinder(g, 0.0, 0.085, 0.42, C_HOT, fx, 1.14, randf_range(-0.12, 0.12), 6)
        _emissive(outer, C_HOT, 2.6)
        flames.append({"node": outer, "y0": 1.14, "scale": randf_range(0.8, 1.35),
            "speed": randf_range(4.2, 7.5), "phase": randf() * TAU})
        if i % 2 == 0:
            var core := _cylinder(g, 0.0, 0.05, 0.24, C_GOLD, fx, 1.06, 0.0, 6)
            _emissive(core, Color8(0xff, 0xd9, 0x4a), 3.4)
            flames.append({"node": core, "y0": 1.06, "scale": randf_range(0.7, 1.1),
                "speed": randf_range(6.0, 9.0), "phase": randf() * TAU})

    # ánh lửa hắt ra vỉa hè
    var glow := OmniLight3D.new()
    glow.position = Vector3(0, 1.25, 0)
    glow.light_color = Color8(0xff, 0x8a, 0x3d)
    glow.omni_range = 3.2
    glow.light_energy = 1.6
    glow.shadow_enabled = false
    g.add_child(glow)

    # khói nghi ngút trước lò
    var smoke: Array = []
    for i in 14:
        var sm := StandardMaterial3D.new()
        sm.albedo_color = Color(0.9, 0.91, 0.94, 0.46)
        sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var sp := _cylinder(g, 0.16, 0.12, 0.16, Color.WHITE,
            randf_range(-0.62, 0.62), 1.15 + randf() * 2.2, randf_range(0.16, 0.38), 8)
        sp.material_override = sm
        smoke.append({"node": sp, "y0": 1.15, "x0": sp.position.x,
            "speed": randf_range(0.5, 0.95), "drift": randf_range(-0.2, 0.2)})

    # bao than dựng cạnh lò + bảng hiệu
    _box(g, 0.36, 0.44, 0.3, C_ASH, -0.95, 0.22, 0.1, 0.95)
    _box(g, 0.3, 0.1, 0.24, C_STEEL_DARK, -0.95, 0.46, 0.1, 0.8)
    _label3d(g, "SƯỜN NƯỚNG", 22, accent, 0, 1.62, 0)

    var area := _touch_area(g, "grill", "grill", Vector3(0, 0.9, 0), Vector3(2.0, 1.9, 1.5))
    area.collision_layer = 1

    _grill = {"node": g, "meats": meats, "flames": flames, "embers": embers,
        "smoke": smoke, "glow": glow, "flip": 0.0, "away": false}


## Nhịp sống của lò: than phập phồng, lửa nhấp nháy, khói bay lên và thịt đổi màu
## dần theo tiến độ mẻ nướng. Lò tắt thì than xám lại, hết khói.
func _update_grill(dt: float) -> void:
    if _grill.is_empty() or not is_instance_valid(_grill["node"] as Node3D):
        return
    var on := GameManager.grill_running()
    var prog := clampf(GameManager.grill_progress, 0.0, 1.0)
    var beat := 0.5 + 0.5 * sin(_time * 3.1)

    for e in _grill["embers"]:
        var m := (e as MeshInstance3D).material_override as StandardMaterial3D
        if m == null:
            continue
        m.emission_energy_multiplier = (1.1 + beat * 1.3) if on else 0.0
        m.albedo_color = C_EMBER if on else C_ASH

    for f in _grill["flames"]:
        var fl: MeshInstance3D = f["node"]
        fl.visible = on
        if not on:
            continue
        var wob := 0.45 + 0.75 * absf(sin(_time * float(f["speed"]) + float(f["phase"])))
        var sc: float = float(f["scale"])
        fl.scale = Vector3(sc * (0.8 + wob * 0.35), sc * wob * 1.35, sc * (0.8 + wob * 0.35))
        fl.position.y = float(f["y0"]) + wob * 0.06
        fl.rotation.z = sin(_time * 3.0 + float(f["phase"])) * 0.22

    var glow = _grill.get("glow")
    if glow != null and is_instance_valid(glow):
        var lamp: OmniLight3D = glow
        lamp.visible = on
        lamp.light_energy = 1.1 + beat * 1.1

    for smk in _grill["smoke"]:
        var n: Node3D = smk["node"]
        n.visible = on
        if not on:
            continue
        n.position.y += dt * float(smk["speed"])
        var rise: float = n.position.y - float(smk["y0"])
        n.position.x = float(smk["x0"]) + sin(_time * 1.1 + rise * 1.6) * 0.18 \
            + float(smk["drift"]) * rise
        var mm := n.material_override as StandardMaterial3D
        if mm != null:
            mm.albedo_color.a = maxf(0.0, 0.46 * (1.0 - rise / 2.4))
        n.scale = Vector3.ONE * (0.7 + rise * 0.85)
        if rise > 2.4:
            n.position.y = float(smk["y0"])
            n.scale = Vector3.ONE

    # người đứng lò bưng mẻ đi giao thì vỉ trống trơn, về tới nơi mới xếp thịt lại
    var away := bool(_grill.get("away", false))
    for mt in _grill["meats"]:
        (mt["pivot"] as Node3D).visible = not away

    # miếng thịt: chín dần theo mẻ, thỉnh thoảng được lật một cái
    _grill["flip"] = float(_grill["flip"]) + (dt if on else 0.0)
    if away:
        return
    var flip_t := float(_grill["flip"])
    for i in (_grill["meats"] as Array).size():
        var mt: Dictionary = _grill["meats"][i]
        var pivot: Node3D = mt["pivot"]
        var slab: MeshInstance3D = mt["slab"]
        # mỗi miếng lật lệch pha nhau cho tự nhiên
        var k := fmod(flip_t * 0.55 + float(i) * 0.37, 1.0)
        var flipping := k > 0.86
        var turn := 0.0
        if flipping:
            turn = (k - 0.86) / 0.14
        pivot.rotation.z = sin(turn * PI) * PI * (1.0 if int(flip_t * 0.55 + float(i) * 0.37) % 2 == 0 else -1.0)
        pivot.position.y = 1.03 + sin(turn * PI) * 0.12
        var mat := slab.material_override as StandardMaterial3D
        if mat != null:
            mat.albedo_color = C_MEAT.lerp(C_MEAT_DONE, prog if on else 0.0)


## Anh Tư đứng lò: mặc định lật sườn tại chỗ, hễ xong một mẻ thì bưng khay
## thịt qua cửa vào quầy trong quán rồi quay trở ra lò.
func _build_griller(node: Node3D) -> void:
    var stand := GRILL_POS + Vector3(0.0, 0.0, -0.62)
    stand.y = OUT_Y
    var ch := ComTamChars.build("tu")
    ch.position = stand
    ch.rotation.y = 0.0
    node.add_child(ch)
    var rig := ComTamChars.rig_of(ch)

    # khay sườn: chỉ hiện lúc đang bưng vào trong
    var tray := MeshInstance3D.new()
    var tm := BoxMesh.new()
    tm.size = Vector3(0.4, 0.04, 0.3)
    tray.mesh = tm
    tray.material_override = ComTamChars.mat(C_STEEL_LIGHT)
    rig["arms"][1]["elbow"].add_child(tray)
    tray.position = Vector3(0, -0.3, 0.05)
    for i in 3:
        _box(tray, 0.09, 0.05, 0.2, C_MEAT_DONE, -0.11 + float(i) * 0.11, 0.045, 0, 0.55)
    tray.visible = false

    _actors.append({"node": ch, "rig": rig, "mode": "griller", "floor": 0,
        "state": "grill", "t": 0.0, "phase": randf() * 2.0, "tray": tray,
        "home": stand, "path": [], "y": OUT_Y, "carry": 0})


## Đường bưng khay từ lò than vào quầy trong quán rồi quay ra.
func _grill_route(back: bool) -> Array:
    var hd := ROOM_D * 0.5
    var door_out := Vector3(ROOM_W * 0.5 - 1.0, OUT_Y, hd + 1.0)
    var door_in := Vector3(ROOM_W * 0.5 - 1.0, 0.0, hd - 0.75)
    var counter := Vector3(_station_slot(0).x, 0.0, -hd + 2.15)
    var home := GRILL_POS + Vector3(0.0, 0.0, -0.62)
    home.y = OUT_Y
    if back:
        return [door_in, door_out, home]
    return [door_out, door_in, counter]


func _update_griller(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    var tray: Node3D = a["tray"]
    a["t"] = float(a["t"]) + delta
    if not _grill.is_empty():
        _grill["away"] = str(a["state"]) != "grill"

    match str(a["state"]):
        "grill":
            tray.visible = false
            node.rotation.y = 0.0
            if GameManager.grill_running():
                ComTamChars.grill_flip(rig, t)
            else:
                ComTamChars.idle(rig, t)     # hết than hoặc hết sườn thì đứng chơi
            if int(a["carry"]) > 0:
                a["state"] = "carry_in"
                a["path"] = _grill_route(false)
                a["t"] = 0.0
        "carry_in":
            tray.visible = true
            if _follow_path(a, node, rig, t, delta, 1.5):
                a["state"] = "drop"
                a["t"] = 0.0
                node.rotation.y = PI
            _carry_pose(rig)
            _level_tray(tray)
        "drop":
            # đặt khay sườn xuống quầy
            ComTamChars.idle(rig, t)
            rig["torso"].rotation.x = 0.2
            tray.visible = float(a["t"]) < 0.6
            if float(a["t"]) > 1.2:
                rig["torso"].rotation.x = 0.0
                a["carry"] = 0
                a["state"] = "carry_back"
                a["path"] = _grill_route(true)
                a["t"] = 0.0
        "carry_back":
            tray.visible = false
            if _follow_path(a, node, rig, t, delta, 1.6):
                a["state"] = "grill"
                a["t"] = 0.0
                node.position = a["home"]
                node.rotation.y = 0.0

    node.position.y = move_toward(node.position.y, float(a.get("y", OUT_Y)), delta * 1.8)


## Mẻ nướng xong: cho người đứng lò bưng vào và bắn con số lên cho thấy.
func _on_grill_batch(count: int) -> void:
    for a in _actors:
        if str(a["mode"]) == "griller":
            a["carry"] = count
            break
    var g = _grill.get("node")
    if g != null and is_instance_valid(g as Node3D):
        spawn_float("+%d miếng" % count, (g as Node3D).global_position + Vector3(0, 2.0, 0), C_HOT)


# ---------- Vỉa hè trước quán: mái hiên, bậc thềm, tủ kính ----------

func _build_terrace(node: Node3D, accent: Color, with_grill: bool = true) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    var t := Node3D.new()
    t.name = "Terrace"
    t.position = Vector3(0, OUT_Y, 0)
    node.add_child(t)

    # Nền gạch vỉa hè: đúng bằng một nhịp nhà, ghép lại thành dải liền suốt dãy
    # (rộng hơn thì hai khu cạnh nhau chèn mặt lên nhau, nhìn loang lổ).
    _box(t, WING_DX, 0.08, OUT_Z1 - hd + 0.6, C_TILE, 0, 0.04, (OUT_Z1 + hd) * 0.5, 0.9)
    var line_mat := ComTamChars.mat(C_FLOOR_LINE, 0.9)
    for i in 8:
        _box(t, 0.03, 0.02, OUT_Z1 - hd + 0.5, C_FLOOR_LINE,
            -WING_DX * 0.5 + 0.5 + i * 1.1, 0.085,
            (OUT_Z1 + hd) * 0.5).material_override = line_mat
    for i in 4:
        _box(t, WING_DX - 0.1, 0.02, 0.03, C_FLOOR_LINE, 0, 0.085,
            hd + 0.5 + i * 0.9).material_override = line_mat

    if with_grill:
        _build_grill_stall(t, accent)

    # bậc thềm bước lên nền quán
    _box(t, ROOM_W + 1.0, 0.4, 0.55, C_WALL_DEEP, 0, 0.2, hd + 0.28, 0.85)
    _box(t, ROOM_W + 1.0, 0.06, 0.6, accent, 0, 0.42, hd + 0.28, 0.5)

    # Bảng hiệu chỉ dựng một cái ở đầu dãy (khu trệt), nép mé trái vỉa hè. Dựng
    # mỗi khu một cái thì cả dãy toàn cột, che mất lòng quán khi nhìn chúc xuống.
    if with_grill:
        var sg := Node3D.new()
        sg.position = Vector3(-hw - 0.75, 0, hd + 1.7)
        sg.rotation.y = 0.34
        t.add_child(sg)
        _cylinder(sg, 0.06, 0.07, 2.0, C_STEEL_LIGHT, 0, 1.0, 0, 8)
        _box(sg, 0.9, 1.8, 0.1, C_STEEL_DARK, 0, 2.3, 0, 0.4)
        _box(sg, 0.98, 0.16, 0.14, C_GOLD, 0, 3.18, 0, 0.4)
        _label3d(sg, "CƠM
TẤM", 40, C_GOLD, 0, 2.65, 0.08, false)
        _label3d(sg, "QUÁN
VỈA HÈ", 20, Color8(0xdf, 0xe6, 0xff), 0, 1.85, 0.08, false)

    # Tủ kính cũ đã bỏ: chỗ đó bây giờ là lò than, để lại thì nó úp kín cái lò.
    _cylinder(t, 0.34, 0.36, 0.5, C_STEEL_LIGHT, hw - 0.8, 0.33, hd + 0.95, 14)
    _cylinder(t, 0.36, 0.36, 0.08, C_STEEL, hw - 0.8, 0.62, hd + 0.95, 14)
    # chồng ghế nhựa dự phòng xếp cạnh tường
    for i in 4:
        _cylinder(t, 0.17, 0.19, 0.1, C_PLASTIC_BLUE if i % 2 == 0 else C_PLASTIC_RED,
            hw - 0.2, 0.16 + float(i) * 0.09, hd + 1.7, 12)


# ---------- Bàn ghế do người chơi tự đặt ----------

## Vị trí bốn/sáu chỗ ngồi quanh một bộ bàn, tính theo tâm bàn.
func _seat_offsets(kind: String) -> Array:
    match kind:
        "stool_set":
            return [Vector2(-0.74, 0), Vector2(0.74, 0), Vector2(0, -0.74), Vector2(0, 0.74)]
        "table_steel":
            return [Vector2(-0.78, 0), Vector2(0.78, 0), Vector2(0, -0.78), Vector2(0, 0.78)]
        "table_wood":
            return [Vector2(-0.72, -0.7), Vector2(0.0, -0.7), Vector2(0.72, -0.7),
                Vector2(-0.72, 0.7), Vector2(0.0, 0.7), Vector2(0.72, 0.7)]
        _:
            return []


func _seat_style(kind: String) -> String:
    return "stool" if kind == "stool_set" else "chair"


## Mặt bàn của mỗi bộ cao bao nhiêu — để đặt dĩa nằm đúng trên mặt gỗ.
func _table_top(kind: String) -> float:
    match kind:
        "stool_set":
            return 0.47
        "table_steel":
            return 0.76
        "table_wood":
            return 0.805
        _:
            return 0.77


## Nửa chiều bày biện của mặt bàn: dĩa kéo vào trong chừng này thì còn nằm gọn
## trên bàn chứ không lơ lửng ngoài mép.
func _table_reach(kind: String) -> Vector2:
    match kind:
        "stool_set":
            return Vector2(0.28, 0.28)
        "table_steel":
            return Vector2(0.42, 0.42)
        "table_wood":
            return Vector2(0.9, 0.3)
        _:
            return Vector2(0.38, 0.38)


## Dựng phần nhìn thấy của một bộ bàn ghế tại gốc toạ độ của `holder`.
func _build_furniture_body(holder: Node3D, kind: String) -> void:
    match kind:
        "stool_set":
            # bàn thấp mặt gỗ + bốn ghế nhựa: đúng bộ bàn quán cóc vỉa hè
            _box(holder, 0.95, 0.06, 0.95, C_WOOD, 0, 0.44, 0, 0.7)
            _box(holder, 0.99, 0.04, 0.99, C_WOOD_DARK, 0, 0.4, 0, 0.7)
            for d in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
                _box(holder, 0.06, 0.4, 0.06, C_STEEL_LIGHT, d.x, 0.2, d.y)
            # chai nước mắm, tương ớt, ống đũa để giữa bàn
            _cylinder(holder, 0.045, 0.05, 0.2, Color8(0x8a, 0x4b, 0x2a), -0.14, 0.57, 0.06, 8)
            _cylinder(holder, 0.045, 0.05, 0.18, C_HOT, 0.0, 0.56, -0.08, 8)
            _cylinder(holder, 0.06, 0.06, 0.16, C_STEEL_LIGHT, 0.16, 0.55, 0.08, 8)
            var offs: Array = _seat_offsets(kind)
            for i in offs.size():
                var o: Vector2 = offs[i]
                var col: Color = C_PLASTIC_BLUE if i % 2 == 0 else C_PLASTIC_RED
                _cylinder(holder, 0.17, 0.15, 0.05, col, o.x, 0.24, o.y, 12)
                for sx in [-0.11, 0.11]:
                    for sz in [-0.11, 0.11]:
                        _box(holder, 0.03, 0.22, 0.03, col, o.x + sx, 0.11, o.y + sz, 0.8)
        "table_steel":
            _box(holder, 1.3, 0.08, 1.3, C_STEEL_LIGHT, 0, 0.72, 0, 0.35)
            _cylinder(holder, 0.1, 0.1, 0.68, C_STEEL_LIGHT, 0, 0.36, 0, 10)
            _cylinder(holder, 0.36, 0.36, 0.06, C_STEEL_LIGHT, 0, 0.05, 0, 12)
            _cylinder(holder, 0.2, 0.2, 0.03, C_PLATE, 0, 0.78, 0, 14)
            for o2 in _seat_offsets(kind):
                _cylinder(holder, 0.2, 0.17, 0.06, C_STEEL, o2.x, 0.45, o2.y, 12)
                _cylinder(holder, 0.05, 0.05, 0.42, C_STEEL_LIGHT, o2.x, 0.22, o2.y, 8)
        "table_wood":
            _box(holder, 2.3, 0.09, 1.0, C_WOOD, 0, 0.76, 0, 0.7)
            _box(holder, 2.34, 0.05, 1.04, C_WOOD_DARK, 0, 0.71, 0, 0.7)
            for d3 in [Vector2(-1.0, -0.38), Vector2(1.0, -0.38), Vector2(-1.0, 0.38), Vector2(1.0, 0.38)]:
                _box(holder, 0.09, 0.71, 0.09, C_WOOD_DARK, d3.x, 0.36, d3.y)
            _cylinder(holder, 0.2, 0.2, 0.03, C_PLATE, -0.6, 0.82, 0, 14)
            _cylinder(holder, 0.2, 0.2, 0.03, C_PLATE, 0.6, 0.82, 0, 14)
            for o3 in _seat_offsets(kind):
                var back: float = -0.2 if o3.y < 0.0 else 0.2
                _box(holder, 0.4, 0.07, 0.4, C_WOOD, o3.x, 0.45, o3.y, 0.7)
                _box(holder, 0.4, 0.42, 0.06, C_WOOD_DARK, o3.x, 0.66, o3.y + back, 0.7)
                for sx2 in [-0.15, 0.15]:
                    for sz2 in [-0.15, 0.15]:
                        _box(holder, 0.05, 0.42, 0.05, C_WOOD_DARK, o3.x + sx2, 0.21, o3.y + sz2)
        "parasol":
            _cylinder(holder, 0.36, 0.4, 0.12, C_STEEL_DARK, 0, 0.06, 0, 12)
            _cylinder(holder, 0.05, 0.05, 2.3, C_WOOD_DARK, 0, 1.15, 0, 8)
            _cylinder(holder, 0.06, 1.55, 0.5, C_AWNING, 0, 2.25, 0, 16)
            _cylinder(holder, 1.5, 1.5, 0.05, Color8(0xfa, 0xf6, 0xef), 0, 2.02, 0, 16)
        _:
            _box(holder, 1.0, 0.7, 1.0, C_WOOD, 0, 0.35, 0)


## Dựng toàn bộ bàn ghế người chơi đã đặt trên một tầng.
func _build_placed(node: Node3D, index: int) -> void:
    for i in GameManager.placed.size():
        var it: Dictionary = GameManager.placed[i]
        if int(it.get("floor", 0)) != index:
            continue
        var kind := str(it.get("kind", ""))
        if not GameManager.FURNITURE.has(kind):
            continue
        var out := str(it.get("zone", "in")) == "out"
        var y: float = OUT_Y if out else 0.0
        var holder := Node3D.new()
        holder.name = "Furni_%d" % i
        holder.position = Vector3(float(it.get("x", 0.0)), y, float(it.get("z", 0.0)))
        holder.rotation.y = float(int(it.get("rot", 0))) * PI * 0.5
        node.add_child(holder)
        _build_furniture_body(holder, kind)
        _furni_nodes.append(holder)
        _furni_by_index[i] = holder

        var area := _touch_area(holder, "furni", str(i), Vector3(0, 0.5, 0), Vector3(1.3, 1.2, 1.3))
        area.collision_layer = 1

        var offs: Array = _seat_offsets(kind)
        if offs.is_empty():
            continue
        var centre := Vector3(holder.position.x, y, holder.position.z)
        (_tables[index] as Array).append(centre)
        var tid := (_tables[index] as Array).size() - 1
        var style := _seat_style(kind)
        var top := _table_top(kind)
        var reach := _table_reach(kind)
        for o in offs:
            var ro: Vector2 = o.rotated(holder.rotation.y) * 1.02
            # dĩa kéo từ chỗ ngồi vào trong mặt bàn, ngay tầm tay người đó
            var po := Vector2(clampf(o.x, -reach.x, reach.x),
                clampf(o.y, -reach.y, reach.y)).rotated(holder.rotation.y)
            _seats.append({"pos": Vector3(centre.x + ro.x, y, centre.z + ro.y),
                "look": centre, "floor": index, "taken": false, "style": style, "out": out,
                "y": y, "table": tid, "plate": Vector3(centre.x + po.x, y + top, centre.z + po.y),
                "plate_yaw": atan2(ro.x - po.x, ro.y - po.y)})


func _build_table(node: Node3D, spot: Vector2, index: int) -> void:
    _box(node, 1.15, 0.1, 1.15, C_WOOD, spot.x, 0.72, spot.y, 0.65)
    _box(node, 0.13, 0.72, 0.13, C_WOOD_DARK, spot.x, 0.36, spot.y)
    _box(node, 0.8, 0.08, 0.8, C_WOOD_DARK, spot.x, 0.045, spot.y)
    _cylinder(node, 0.18, 0.18, 0.03, C_PLATE, spot.x, 0.79, spot.y, 14)
    _cylinder(node, 0.1, 0.1, 0.05, C_HOT, spot.x, 0.82, spot.y, 12)
    (_tables[index] as Array).append(Vector3(spot.x, 0, spot.y))
    (_blockers[index] as Array).append({"pos": spot, "r": 0.65})
    var tid := (_tables[index] as Array).size() - 1
    # bốn ghế quanh bàn: mở tầng là thêm đúng 4 chỗ như lời hứa ở thẻ mở tầng
    for d in [Vector2(-0.75, 0), Vector2(0.75, 0), Vector2(0, -0.75), Vector2(0, 0.75)]:
        _cylinder(node, 0.21, 0.17, 0.4, C_HOT if d.x > 0.0 else C_STEEL, spot.x + d.x, 0.2, spot.y + d.y, 12)
        var sv: Vector2 = d * 1.05
        var pv: Vector2 = d * 0.5
        _seats.append({"pos": Vector3(spot.x + sv.x, 0, spot.y + sv.y),
            "look": Vector3(spot.x, 0, spot.y), "floor": index, "taken": false,
            "style": "chair", "out": false, "y": 0.0, "table": tid,
            "plate": Vector3(spot.x + pv.x, 0.77, spot.y + pv.y),
            "plate_yaw": atan2(sv.x - pv.x, sv.y - pv.y)})


func _build_decor(node: Node3D, index: int, accent: Color) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    if int(GameManager.decor.get("plant", 0)) > 0:
        _cylinder(node, 0.22, 0.26, 0.36, C_WOOD_DARK, -hw + 0.55, 0.18, hd - 0.6, 10)
        _cylinder(node, 0.05, 0.26, 0.9, C_PLANT, -hw + 0.55, 0.78, hd - 0.6, 8)
    if int(GameManager.decor.get("aquarium", 0)) > 0:
        _box(node, 1.0, 0.6, 0.4, C_WOOD_DARK, hw - 0.75, 0.3, -hd + 2.2)
        _box(node, 0.9, 0.55, 0.34, Color8(0x8f, 0xbc, 0xd8), hw - 0.75, 0.86, -hd + 2.2, 0.3)
    if int(GameManager.decor.get("fan", 0)) > 0:
        _cylinder(node, 0.07, 0.1, 1.5, C_STEEL_LIGHT, -hw + 0.55, 0.75, -hd + 0.7, 8)
        _cylinder(node, 0.36, 0.36, 0.1, C_STEEL, -hw + 0.55, 1.55, -hd + 0.7, 14)
    var lanterns := mini(int(GameManager.decor.get("lantern", 0)), 4)
    for i in lanterns:
        _cylinder(node, 0.14, 0.14, 0.34, Color8(0xc4, 0x6b, 0x4a), -1.7 + i * 1.15, FLOOR_H - 0.75, hd - 0.7, 10)
    # Chó cỏ: mua một con thì khu nào cũng có một con chạy loăng quăng. Nhiều
    # nhất hai con mỗi khu, đông quá thì rối mắt mà máy yếu cũng nặng thêm.
    var dogs := mini(int(GameManager.decor.get("dog", 0)), 2)
    for i in dogs:
        var dog := ComTamChars.build_dog()
        var spot := _dog_target(index)
        dog.position = spot
        node.add_child(dog)
        _actors.append({"node": dog, "rig": ComTamChars.dog_rig_of(dog), "mode": "dog",
            "floor": index, "state": "sniff", "t": randf() * 2.0, "target": spot,
            "phase": randf() * 3.0})
    if int(GameManager.decor.get("sign", 0)) > 0:
        _box(node, 2.2, 0.4, 0.1, C_GOLD, 0, FLOOR_H - 1.55, -hd + 0.2, 0.35)


# ---------- Quầy hàng ----------

func _build_station(parent: Node3D, sid: String, pos: Vector3, floor_index: int) -> void:
    var open := GameManager.is_station_open(sid)
    var accent: Color = FLOOR_ACCENTS[floor_index % FLOOR_ACCENTS.size()]

    var holder := Node3D.new()
    holder.name = "St_" + sid
    holder.position = pos
    parent.add_child(holder)

    var body_col := C_STEEL_DARK if open else C_LOCK
    var trim := accent if open else C_LOCK
    var smoke: Array = []

    match sid:
        "grill", "bbq":
            _box(holder, 0.98, 0.3, 0.72, body_col, 0, 1.16, 0)
            _box(holder, 1.02, 0.08, 0.76, trim, 0, 1.0, 0, 0.5)
            if open:
                for i in 3:
                    var e := _box(holder, 0.2, 0.06, 0.54, C_HOT, -0.27 + i * 0.27, 1.33, 0, 0.4)
                    var em := StandardMaterial3D.new()
                    em.albedo_color = C_HOT
                    em.emission_enabled = true
                    em.emission = C_HOT
                    em.emission_energy_multiplier = 1.4
                    e.material_override = em
                for i in 4:
                    var sm := StandardMaterial3D.new()
                    sm.albedo_color = Color(0.9, 0.92, 0.95, 0.42)
                    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    var sp := _cylinder(holder, 0.12, 0.12, 0.12, Color.WHITE, randf_range(-0.35, 0.35), 1.6 + randf() * 1.0, 0, 8)
                    sp.material_override = sm
                    smoke.append({"node": sp, "y0": sp.position.y})
        "rice", "dessert":
            _cylinder(holder, 0.33, 0.36, 0.58, Color8(0xf3, 0xf5, 0xfa), 0, 1.29, 0, 14)
            _cylinder(holder, 0.35, 0.35, 0.09, trim, 0, 1.61, 0, 14)
        "prep", "combo", "vip":
            _box(holder, 0.88, 0.2, 0.64, trim, 0, 1.1, 0, 0.55)
            _cylinder(holder, 0.14, 0.14, 0.05, C_PLATE, -0.2, 1.22, 0, 12)
            _cylinder(holder, 0.14, 0.14, 0.05, C_PLATE, 0.13, 1.22, 0, 12)
        "drink", "juice":
            _box(holder, 0.7, 1.5, 0.58, Color8(0xf3, 0xf5, 0xfa), 0, 0.75, -0.1)
            _box(holder, 0.74, 0.12, 0.62, trim, 0, 1.45, -0.1, 0.5)
            _box(holder, 0.58, 1.0, 0.06, Color8(0xa8, 0xd8, 0xf0), 0, 1.0, 0.2, 0.25)
        _:
            _box(holder, 0.9, 0.5, 0.7, body_col, 0, 1.25, 0)

    # Trên đầu quầy giờ để trống hẳn: không thanh tiến độ, không nhãn tên, không
    # bảng tiền vàng che mất người đứng bếp. Tiến độ từng quầy đã có ở dải quầy
    # bên phải màn hình, còn tiền thì bấm nút THU (hoặc thuê quản lý) là gom hết.
    _touch_area(holder, "boost", sid, Vector3(0, 1.05, 0), Vector3(1.2, 1.9, 1.15))

    _station_nodes[sid] = {
        "holder": holder, "smoke": smoke, "floor": floor_index, "punch": 0.0,
    }


## Vòng đếm giờ treo trên đầu một nhân vật, dùng ở hai chỗ: người phục vụ (xanh
## — còn bao lâu nữa có đĩa để bưng) và khách ngồi bàn (đỏ — còn bao lâu nữa thì
## họ hết kiên nhẫn). Vẽ bằng mấy vạch xếp thành vòng, sáng dần theo tiến độ.
func _make_meter(host: Node3D, y: float, radius: float, lit: Color,
        centre_c: Color) -> Dictionary:
    var ring := Node3D.new()
    ring.name = "Meter"
    ring.position = Vector3(0, y, 0)
    ring.visible = false
    host.add_child(ring)

    _cylinder(ring, radius, radius, 0.04, Color8(0x22, 0x2c, 0x44), 0, 0, 0.03, 20) \
        .rotation_degrees = Vector3(90, 0, 0)

    var segs: Array = []
    for i in SERVICE_SEGMENTS:
        var ang := TAU * float(i) / float(SERVICE_SEGMENTS) - PI * 0.5
        var seg := _box(ring, radius * 0.26, radius * 0.42, 0.03, C_STEEL_LIGHT,
            cos(ang) * radius * 0.7, -sin(ang) * radius * 0.7, 0.06, 0.4)
        seg.rotation.z = -ang - PI * 0.5
        segs.append(seg)

    _cylinder(ring, radius * 0.3, radius * 0.3, 0.03, C_PLATE, 0, 0, 0.07, 14) \
        .rotation_degrees = Vector3(90, 0, 0)
    _cylinder(ring, radius * 0.17, radius * 0.17, 0.04, centre_c, 0, 0, 0.09, 12) \
        .rotation_degrees = Vector3(90, 0, 0)

    var meter := {"node": ring, "segs": segs, "ratio": 0.0, "lit": lit}
    _meters.append(meter)
    return meter


## Vòng của người phục vụ: chạy nhanh chậm theo TỔNG sức làm của mọi quầy trong
## khu (xem GameManager.service_time), chỉ hiện lúc người ta đứng chờ món ở quầy.
func _build_service_meter(server: Node3D, index: int, accent: Color) -> void:
    _service[index] = _make_meter(server, 2.25, 0.27, C_OK, accent)


## Vòng luôn quay mặt về phía máy quay (máy quay chỉ đổi hướng ngang) và sáng
## dần theo tiến độ của riêng nó.
func _update_service(_delta: float) -> void:
    var keep: Array = []
    for m in _meters:
        var ring: Node3D = m["node"]
        if not is_instance_valid(ring):
            continue
        keep.append(m)
        if not ring.visible:
            continue
        # nhân vật xoay hướng nào cũng mặc: đặt hướng TUYỆT ĐỐI cho vòng
        ring.global_rotation = Vector3(deg_to_rad(CAM_PITCH), yaw, 0)
        var ratio := clampf(float(m["ratio"]), 0.0, 1.0)
        var lit_n := int(round(ratio * float(SERVICE_SEGMENTS)))
        var lit_c: Color = m["lit"]
        var segs: Array = m["segs"]
        for i in segs.size():
            var seg: MeshInstance3D = segs[i]
            var c: Color = lit_c if i < lit_n else Color8(0x3a, 0x46, 0x63)
            var mat := seg.material_override as StandardMaterial3D
            if mat != null and mat.albedo_color != c:
                seg.material_override = ComTamChars.mat(c, 0.4)
    if keep.size() != _meters.size():
        _meters = keep


## Bật/tắt và đặt tiến độ cho một vòng đếm giờ.
func _set_meter(meter, ratio: float, show: bool = true) -> void:
    if meter == null:
        return
    var m: Dictionary = meter
    m["ratio"] = clampf(ratio, 0.0, 1.0)
    var ring: Node3D = m["node"]
    if is_instance_valid(ring) and ring.visible != show:
        ring.visible = show


func _touch_area(parent: Node3D, kind: String, id: String, pos: Vector3, size: Vector3) -> Area3D:
    var area := Area3D.new()
    area.position = pos
    var shape := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    shape.shape = bs
    area.add_child(shape)
    area.set_meta("kind", kind)
    area.set_meta("id", id)
    parent.add_child(area)
    return area


# ---------- Tầng chưa mở ----------

func _build_locked_floor(node: Node3D, fid: String, f: Dictionary) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    _box(node, ROOM_W, SLAB, ROOM_D, C_LOCK, 0, -SLAB * 0.5, 0, 0.9)
    _box(node, ROOM_W + 0.26, 0.14, ROOM_D + 0.26, C_HAZARD, 0, -SLAB - 0.07, 0, 0.5)
    # Lô đất chưa xây: rào lưới quây quanh ba mặt cho thấy rõ đây là chỗ mở rộng.
    var fence_h := 1.5
    for i in 5:
        _box(node, 0.1, fence_h, 0.1, C_HAZARD, -hw + 0.7 + i * 1.6, fence_h * 0.5, -hd + 0.4)
    _box(node, ROOM_W - 0.8, 0.08, 0.08, C_HAZARD, 0, 0.65, -hd + 0.4)
    _box(node, ROOM_W - 0.8, 0.08, 0.08, C_HAZARD, 0, 1.4, -hd + 0.4)
    for sx in [-hw + 0.4, hw - 0.4]:
        _box(node, 0.1, fence_h, 0.1, C_HAZARD, sx, fence_h * 0.5, 0.0)
        _box(node, 0.08, 0.08, ROOM_D - 0.9, C_HAZARD, sx, 1.4, 0.0)
    _box(node, 0.8, 0.6, 0.7, C_WOOD, -1.9, 0.3, 0.8)
    _box(node, 0.7, 0.5, 0.6, C_STEEL, 1.7, 0.25, 0.4)

    var sign := Node3D.new()
    sign.position = Vector3(0, 1.5, 0.6)
    sign.rotation.y = -YAW_HOME
    node.add_child(sign)
    _box(sign, 3.2, 1.4, 0.1, C_STEEL_DARK, 0, 0, 0, 0.4)
    _label3d(sign, str(f["name"]).to_upper(), 36, Color8(0xf6, 0xf8, 0xfc), 0, 0.42, 0.09, false)
    _label3d(sign, UIKit.money_short(float(f["cost"])) + " ₫", 42, C_GOLD, 0, 0.0, 0.09, false)
    _label3d(sign, "CHẠM ĐỂ MỞ KHU", 24, Color8(0xc2, 0xcd, 0xe8), 0, -0.4, 0.09, false)

    var area := Area3D.new()
    area.position = Vector3(0, 1.5, 0.6)
    var shape := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(4.0, 2.0, 1.6)
    shape.shape = bs
    area.add_child(shape)
    area.set_meta("kind", "floor")
    area.set_meta("id", fid)
    node.add_child(area)


# ---------- Nhân vật ----------

## Đĩa cơm nhỏ đặt trên khay của người phục vụ.
func _make_dish(parent: Node3D) -> Node3D:
    var dish := Node3D.new()
    parent.add_child(dish)
    _cylinder(dish, 0.13, 0.13, 0.025, C_PLATE, 0, 0, 0, 12)
    _cylinder(dish, 0.075, 0.075, 0.04, C_HOT, 0, 0.03, 0, 10)
    _box(dish, 0.05, 0.03, 0.09, C_WOOD, 0.09, 0.02, 0)
    return dish


func _populate(node: Node3D, fid: String, index: int) -> void:
    var hd := ROOM_D * 0.5
    var open_stations: Array = []
    for sid in GameManager.stations_on_floor(fid):
        if GameManager.is_station_open(str(sid)):
            open_stations.append(str(sid))

    # người đứng lò than ngoài vỉa hè (chỉ tầng trệt, quầy nướng nằm ngoài đó)
    var skip_cook := -1
    if index == 0 and open_stations.has("grill"):
        skip_cook = open_stations.find("grill")
        _build_griller(node)

    # đầu bếp đứng sau quầy
    var cook_keys := ["hai", "bay", "tu", "minh"]
    for i in mini(open_stations.size(), 3):
        if i == skip_cook:
            continue
        var sp := _station_slot(i)
        var ch := ComTamChars.build(cook_keys[i % cook_keys.size()])
        ch.position = Vector3(sp.x, 0, sp.z - 0.9)
        ch.rotation.y = 0.0
        node.add_child(ch)
        _actors.append({"node": ch, "rig": ComTamChars.rig_of(ch), "mode": "cook",
            "floor": index, "phase": randf() * 3.0})

    # người phục vụ: lấy đĩa ở quầy -> bưng ra bàn -> quay lại quầy
    var linh := ComTamChars.build("linh")
    var pickup := Vector3(0.0, 0, -hd + 2.15)
    linh.position = pickup
    node.add_child(linh)
    var rig := ComTamChars.rig_of(linh)
    var tray := MeshInstance3D.new()
    var tm := BoxMesh.new()
    tm.size = Vector3(0.34, 0.04, 0.26)
    tray.mesh = tm
    tray.material_override = ComTamChars.mat(C_STEEL_LIGHT)
    rig["arms"][1]["elbow"].add_child(tray)
    tray.position = Vector3(0, -0.30, 0.05)
    var dish := _make_dish(tray)
    dish.position = Vector3(0, 0.045, 0)
    dish.visible = false
    _build_service_meter(linh, index, FLOOR_ACCENTS[index % FLOOR_ACCENTS.size()])
    _actors.append({"node": linh, "rig": rig, "mode": "server", "floor": index,
        "state": "wait", "t": 0.0, "dish": dish, "tray": tray, "pickup": pickup,
        "target": pickup, "y": 0.0, "phase": 0.0})

    # khách: tầng trệt thì đi dọc vỉa hè tới, tầng trên vào từ cầu thang
    var seats_here := 0
    for s in _seats:
        if int(s["floor"]) == index:
            seats_here += 1
    # Càng nhiều chỗ ngồi thì quán càng đông: khách bám theo số ghế thật của tầng
    # (kể cả bàn người chơi mới kê), chặn trên 12 người/tầng cho máy yếu thở được.
    var count := clampi(int(round(float(seats_here) * 0.7)), 4, MAX_CUSTOMERS)
    count = mini(count, maxi(4, int(GameManager.arrival_rate())))
    for i in count:
        var key: String = str(ComTamChars.CUSTOMER_KEYS[randi() % ComTamChars.CUSTOMER_KEYS.size()])
        var ch2 := ComTamChars.build(key)
        var rig2 := ComTamChars.rig_of(ch2)
        var spawn := _spawn_point(index, i)
        ch2.position = spawn
        node.add_child(ch2)
        # dĩa cơm tấm của riêng người này: treo sẵn ở tầng, bưng ra mới hiện
        var plate := ComTamChars.build_com_tam_plate()
        plate.visible = false
        node.add_child(plate)
        _actors.append({"node": ch2, "rig": rig2, "mode": "customer", "key": key,
            "floor": index, "state": "enter", "t": -float(i) * 0.9, "seat": null,
            "slot": i, "spawn": spawn, "y": spawn.y, "path": [], "chatty": i % 3 == 0,
            "meal": ComTamChars.attach_meal(rig2), "phase": randf() * 2.0, "plate": plate,
            "meter": _make_meter(ch2, 2.25, 0.24, C_NO, C_NO)})


# ================= Vòng lặp =================

func _process(delta: float) -> void:
    _time += delta
    if _multi:
        _multi_hold -= delta
        if _multi_hold <= 0.0:
            _multi = false
    if not _dragging:
        target_focus = clampf(round(target_focus), 0.0, float(GameManager.FLOORS.size() - 1))
        yaw = lerpf(yaw, YAW_HOME, minf(delta * 2.0, 1.0))
    focus = lerpf(focus, target_focus, minf(delta * 7.0, 1.0))
    var now_floor := current_floor()
    if now_floor != _reported_floor:
        _reported_floor = now_floor
        focus_changed.emit(now_floor)
    _update_camera()
    _update_stations()
    _update_service(delta)
    _update_grill(delta)
    _update_actors(delta)
    _update_floats(delta)


func _update_stations() -> void:
    var dt := get_process_delta_time()
    for sid in _station_nodes:
        var st: Dictionary = _station_nodes[sid]
        var holder: Node3D = st["holder"]

        # nhún một cái khi vừa được thúc nấu nhanh
        var punch := float(st["punch"])
        if punch > 0.0:
            punch = maxf(0.0, punch - dt * 3.5)
            st["punch"] = punch
            var sc := 1.0 + sin(punch * PI) * 0.06
            holder.scale = Vector3(sc, sc, sc)
        elif holder.scale.x != 1.0:
            holder.scale = Vector3.ONE

        for smk in st["smoke"]:
            var n: Node3D = smk["node"]
            n.position.y += dt * 0.4
            var rise: float = n.position.y - float(smk["y0"])
            var m := n.material_override as StandardMaterial3D
            if m != null:
                m.albedo_color.a = maxf(0.0, 0.42 * (1.0 - rise / 1.5))
            if rise > 1.5:
                n.position.y = float(smk["y0"])
                n.position.x = randf_range(-0.35, 0.35)


func _step_toward(node: Node3D, target: Vector3, speed: float, delta: float) -> bool:
    var d := Vector2(target.x - node.position.x, target.z - node.position.z)
    var dist := d.length()
    if dist < 0.09:
        return true
    node.position.x += (d.x / dist) * speed * delta
    node.position.z += (d.y / dist) * speed * delta
    node.rotation.y = atan2(d.x, d.y)
    return false


func _update_actors(delta: float) -> void:
    for a in _actors:
        var node: Node3D = a["node"]
        if not is_instance_valid(node):
            continue
        # quán đông người: khu nào cách tầm nhìn quá xa thì khỏi tính hoạt hình
        # (kéo khung ra xa thì thấy nhiều khu hơn nên nới luôn tầm tính)
        if absf(float(int(a["floor"])) - focus) > ACTOR_LOD_RANGE * maxf(1.0, zoom):
            continue
        var rig: Dictionary = a["rig"]
        var t: float = _time + float(a["phase"])
        match str(a["mode"]):
            "cook":
                ComTamChars.cook(rig, t)
            "server":
                _update_server(a, node, rig, t, delta)
            "dog":
                _update_dog(a, node, rig, t, delta)
            "customer":
                _update_customer(a, node, rig, t, delta)
            "griller":
                _update_griller(a, node, rig, t, delta)


## Người phục vụ bưng khay: nhận đĩa ở quầy, đĩa nằm trên khay suốt đường đi,
## tới bàn thì cúi đặt xuống và đĩa biến mất khỏi khay.
func _update_server(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    var dish: Node3D = a["dish"]
    var carrying := false
    a["t"] = float(a["t"]) + delta

    match str(a["state"]):
        "wait":
            # Đứng ở quầy chờ món ra. Chờ bao lâu là do TỔNG sức làm của mọi quầy
            # trong khu, và vòng trên đầu chạy đúng theo quãng chờ này.
            ComTamChars.idle(rig, t)
            node.rotation.y = PI
            var fid := str(GameManager.FLOORS[int(a["floor"])]["id"])
            var wait_for := GameManager.service_time(fid)
            _set_service_ratio(int(a["floor"]), float(a["t"]) / wait_for, true)
            if float(a["t"]) < wait_for:
                return
            # Có đĩa rồi: tìm người ĐANG NGỒI BÀN chờ ăn, ai chờ lâu nhất đi trước.
            # Không có ai chờ thì cứ ôm đĩa đứng đó, không bưng ra bàn trống nữa.
            var guest = _pick_hungry(int(a["floor"]))
            if guest == null:
                a["t"] = wait_for
                return
            var g: Dictionary = guest
            g["booked"] = true
            a["guest"] = g
            a["target"] = _guest_spot(g)
            a["state"] = "deliver"
            a["t"] = 0.0
            # bưng được đĩa rồi thì tắt vòng, đi giao đã
            _set_service_ratio(int(a["floor"]), 0.0, false)
        "deliver":
            carrying = true
            var tgt: Vector3 = a["target"]
            a["y"] = tgt.y
            # khách bỏ về giữa chừng thì khỏi giao, quay lại quầy
            if not _guest_waiting(a.get("guest")):
                a["guest"] = null
                a["state"] = "return"
                a["t"] = 0.0
                return
            # dừng cạnh khách chứ không chui vào giữa bàn
            var away := node.position - tgt
            away.y = 0.0
            if away.length() < 0.05:
                away = Vector3(0, 0, 1)
            var stop: Vector3 = tgt + away.normalized() * 0.85
            if _step_toward(node, stop, 2.05, delta):
                a["state"] = "serve"
                a["t"] = 0.0
                node.rotation.y = atan2(tgt.x - node.position.x, tgt.z - node.position.z)
            else:
                ComTamChars.walk(rig, t, 8.0)
        "serve":
            # cúi đặt đĩa xuống bàn: đĩa rời khay, khách bắt đầu ăn
            ComTamChars.idle(rig, t)
            rig["torso"].rotation.x = 0.18
            carrying = float(a["t"]) < 0.5
            if float(a["t"]) > 0.5 and a.get("guest") != null:
                _serve_guest(a["guest"])
                a["guest"] = null
            if float(a["t"]) > 1.1:
                a["state"] = "return"
                a["t"] = 0.0
        "return":
            rig["torso"].rotation.x = 0.0
            a["y"] = 0.0
            if _step_toward(node, a["pickup"], 2.25, delta):
                a["state"] = "wait"
                a["t"] = 0.0
            else:
                ComTamChars.walk(rig, t, 8.0)

    dish.visible = carrying
    node.position.y = move_toward(node.position.y, float(a.get("y", 0.0)), delta * 1.8)
    _carry_pose(rig)
    _level_tray(a["tray"])


## Một chỗ bất kỳ trong lòng quán để con chó lững thững đi tới.
func _dog_target(floor_i: int) -> Vector3:
    for _try in 8:
        var r := _dog_bounds()
        var p := Vector3(randf_range(r.position.x, r.end.x), 0.0,
            randf_range(r.position.y, r.end.y))
        # tránh chui vào bàn ghế cho khỏi lồng vào nhau
        var clear := true
        for c in _tables.get(floor_i, []):
            var tp: Vector3 = c
            if Vector2(p.x - tp.x, p.z - tp.z).length() < 1.0:
                clear = false
                break
        if clear:
            return p
    return Vector3(0, 0, ROOM_D * 0.5 - 1.6)


## Khoảnh sân con chó được phép đi: chừa hẳn một mét với ba bức tường VÀ với mép
## trước để trống — bén mảng ra tới đó là trông như nó chạy ra vỉa hè.
func _dog_bounds() -> Rect2:
    var hw := ROOM_W * 0.5 - 1.0
    var z0 := -ROOM_D * 0.5 + 2.1        # sau lưng là quầy bếp, không chui vào
    var z1 := ROOM_D * 0.5 - 1.25        # mép trước quán
    return Rect2(-hw, z0, hw * 2.0, z1 - z0)


## Chó: đi tới một chỗ, đứng hít hà một lát, rồi lại chọn chỗ khác.
func _update_dog(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    a["t"] = float(a["t"]) + delta
    # Chốt cứng: dù có chuyện gì thì con chó cũng không ra khỏi lòng quán. Khách
    # đi ngang, bàn ghế dời chỗ hay khung hình giật đều không đẩy nó ra được.
    var pen := _dog_bounds().grow(0.15)
    node.position.x = clampf(node.position.x, pen.position.x, pen.end.x)
    node.position.z = clampf(node.position.z, pen.position.y, pen.end.y)
    node.position.y = 0.0
    match str(a["state"]):
        "walk":
            ComTamChars.dog_walk(rig, t, 7.0)
            if _step_toward(node, a["target"], 0.85, delta) or float(a["t"]) > 12.0:
                a["state"] = "sniff"
                a["t"] = 0.0
        _:
            ComTamChars.dog_sniff(rig, t)
            if float(a["t"]) > 1.6 + randf() * 2.4:
                a["target"] = _dog_target(int(a["floor"]))
                a["state"] = "walk"
                a["t"] = 0.0


## Người khách đang ngồi bàn chờ cơm lâu nhất trong khu, và chưa có ai bưng cho.
func _pick_hungry(floor_i: int):
    var best = null
    var best_wait := -1.0
    for c in _actors:
        if str(c.get("mode", "")) != "customer" or int(c.get("floor", -1)) != floor_i:
            continue
        if str(c.get("state", "")) != "wait_food" or bool(c.get("booked", false)):
            continue
        if float(c["t"]) > best_wait:
            best_wait = float(c["t"])
            best = c
    return best


## Chỗ để đặt đĩa: ngay trên bàn của người khách đó (khách nào cũng có ghế).
func _guest_spot(g: Dictionary) -> Vector3:
    var seat = g.get("seat")
    if seat != null:
        var sd: Dictionary = seat
        var look: Vector3 = sd["look"]
        return Vector3(look.x, float(sd.get("y", 0.0)), look.z)
    var node: Node3D = g["node"]
    return node.position


## Bày dĩa cơm tấm xuống trước mặt khách (hoặc dọn đi khi khách rời bàn).
func _show_plate(g: Dictionary, on: bool) -> void:
    var plate = g.get("plate")
    if plate == null or not is_instance_valid(plate as Node):
        return
    var node: Node3D = plate
    node.visible = on
    if not on:
        return
    var seat = g.get("seat")
    if seat == null:
        node.visible = false
        return
    var sd: Dictionary = seat
    node.position = sd.get("plate", Vector3(0, 0.77, 0))
    node.rotation.y = float(sd.get("plate_yaw", 0.0))


## Người này còn ngồi đó chờ không (có thể đã bỏ về lúc mình đang đi tới).
func _guest_waiting(guest) -> bool:
    if guest == null:
        return false
    var g: Dictionary = guest
    return str(g.get("state", "")) == "wait_food" and is_instance_valid(g["node"] as Node)


## Đặt đĩa xuống: tắt vòng đỏ, khách chuyển sang ăn.
func _serve_guest(guest) -> void:
    if not _guest_waiting(guest):
        return
    var g: Dictionary = guest
    g["state"] = "eat"
    g["t"] = 0.0
    g["booked"] = false
    _show_plate(g, true)
    _set_meter(g.get("meter"), 0.0, false)


## Đặt tiến độ (và cho ẩn/hiện) vòng chờ món của người phục vụ trong một khu.
func _set_service_ratio(index: int, ratio: float, show: bool = true) -> void:
    _set_meter(_service.get(index), ratio, show)


## Tay cầm khay giữ nguyên tư thế bưng, kể cả lúc đang bước đi.
func _carry_pose(rig: Dictionary) -> void:
    var sh: Node3D = rig["arms"][1]["shoulder"]
    var el: Node3D = rig["arms"][1]["elbow"]
    sh.rotation.x = CARRY_SHOULDER
    sh.rotation.z = CARRY_OUT
    el.rotation.x = CARRY_ELBOW


## Khay phải NẰM NGANG trong không gian thật, chỉ xoay theo hướng người đi.
## Khay là con của cẳng tay, nếu để nó ăn theo góc xoay của tay thì sẽ dựng
## đứng như tấm biển — nên mỗi khung hình phải san phẳng lại độ nghiêng.
func _level_tray(tray: Node3D) -> void:
    var yaw_now := tray.global_basis.get_euler().y
    tray.global_basis = Basis.from_euler(Vector3(0.0, yaw_now, 0.0))


## Khách xuất hiện ở đâu: khu nào cũng nằm mặt tiền nên ai cũng đi bộ dọc vỉa hè
## tới cửa khu của mình (toạ độ tính trong hệ của khu, khỏi lo khu nằm đâu).
func _spawn_point(_floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    var side := 1.0 if slot % 2 == 0 else -1.0
    return Vector3(side * (OUT_HW + 2.2 + float(slot % 6) * 0.5), OUT_Y, hd + 4.6)


## Chỗ đứng chờ bàn: nép mé ngoài vỉa hè, đông thì xếp thành nhiều hàng để
## không kéo dài mãi ra khỏi khung hình.
func _wait_point(_floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    var col := slot % 5
    var row := int(slot / 5.0)
    return Vector3(-2.0 + float(col) * 1.0, OUT_Y, hd + 4.7 + float(row) * 0.9)


## Lối ra: khách đi bộ ra khỏi khung theo vỉa hè.
func _exit_point(_floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    var side := -1.0 if slot % 2 == 0 else 1.0
    return Vector3(side * (OUT_HW + 3.0), OUT_Y, hd + 4.9 + float(slot % 3) * 0.7)


## Đường đi tới đích; nếu phải ra/vào quán thì chèn thêm chặng qua cửa.
func _route(node_pos: Vector3, dest: Vector3, dest_out: bool, _floor_i: int) -> Array:
    var hd := ROOM_D * 0.5
    var outside_now := node_pos.z > hd
    if dest_out == outside_now:
        return [dest]
    var door_in := Vector3(ROOM_W * 0.5 - 1.0, 0.0, hd - 0.75)
    var door_out := Vector3(ROOM_W * 0.5 - 1.0, OUT_Y, hd + 1.0)
    if dest_out:
        return [door_in, door_out, dest]
    return [door_out, door_in, dest]


## Đi hết các chặng trong a["path"]; trả về true khi tới nơi.
func _follow_path(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float,
        speed: float) -> bool:
    var path: Array = a["path"]
    if path.is_empty():
        return true
    var tgt: Vector3 = path[0]
    # moi lan doi chang thi nho lai diem xuat phat, de noi suy cao do cho muot
    if not a.has("seg_to") or (a["seg_to"] as Vector3) != tgt:
        a["seg_to"] = tgt
        a["seg_from"] = node.position
    var seg_from: Vector3 = a["seg_from"]
    var seg_len := Vector2(tgt.x - seg_from.x, tgt.z - seg_from.z).length()
    var climbing := absf(tgt.y - seg_from.y) > 0.5 and seg_len > 0.05
    if climbing:
        ComTamChars.climb(rig, t, tgt.y > seg_from.y)
    else:
        ComTamChars.walk(rig, t, 8.0)
    a["y"] = tgt.y
    var done := _step_toward(node, tgt, speed * (0.72 if climbing else 1.0), delta)
    if seg_len > 0.05:
        # buoc toi dau thi cao toi do, chan moi bam dung mat bac
        var left := Vector2(tgt.x - node.position.x, tgt.z - node.position.z).length()
        node.position.y = lerpf(seg_from.y, tgt.y, clampf(1.0 - left / seg_len, 0.0, 1.0))
    if done:
        node.position.y = tgt.y
        path.remove_at(0)
        return path.is_empty()
    return false


func _update_customer(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    a["t"] = float(a["t"]) + delta
    if float(a["t"]) < 0.0:
        node.visible = false
        return
    node.visible = true
    var floor_i := int(a["floor"])
    var slot := int(a["slot"])
    var meal: Dictionary = a["meal"]
    # bước lên thềm / bước xuống vỉa hè: cao độ nhích dần chứ không nhảy cóc
    node.position.y = move_toward(node.position.y, float(a["y"]), delta * 1.8)

    match str(a["state"]):
        "enter":
            if (a["path"] as Array).is_empty():
                a["path"] = _route(node.position, _wait_point(floor_i, slot), true, floor_i)
            if _follow_path(a, node, rig, t, delta, 1.3):
                a["state"] = "queue"
                a["t"] = 0.0
        "queue":
            node.rotation.y = 0.35
            ComTamChars.idle(rig, t)
            if float(a["t"]) > 1.5 + float(slot) * 0.8:
                var seat = _take_seat(floor_i)
                if seat != null:
                    a["seat"] = seat
                    var sd: Dictionary = seat
                    a["path"] = _route(node.position, sd["pos"], bool(sd.get("out", false)), floor_i)
                    a["state"] = "walk_seat"
        "walk_seat":
            if _follow_path(a, node, rig, t, delta, 1.35):
                # ngồi xuống rồi nhưng CHƯA có cơm: bắt đầu đếm giờ chờ phục vụ
                a["state"] = "wait_food"
                a["t"] = 0.0
                a["booked"] = false
                var seat2: Dictionary = a["seat"]
                var look: Vector3 = seat2["look"]
                node.rotation.y = atan2(look.x - node.position.x, look.z - node.position.z)
                # người đã thu nhỏ nên phải kênh lên cho mông chạm đúng mặt ghế
                a["y"] = float(seat2["y"]) + ComTamChars.seat_lift(str(seat2.get("style", "chair")))
                _set_meter(a.get("meter"), 0.0, true)
        "wait_food":
            # Ngồi ngóng: vòng ĐỎ trên đầu đầy dần. Đầy mà chưa ai bưng cơm ra thì
            # đứng dậy đi về, và quán mất uy tín theo tính khí của loại khách đó.
            var seat_w: Dictionary = a["seat"]
            if str(seat_w.get("style", "chair")) == "stool":
                ComTamChars.sit_stool(rig, t, true)
            else:
                ComTamChars.sit(rig, t)
            (meal["bowl"] as Node3D).visible = false
            (meal["sticks"] as Node3D).visible = false
            var patience := GameManager.CUSTOMER_PATIENCE
            _set_meter(a.get("meter"), float(a["t"]) / patience, true)
            if float(a["t"]) > patience:
                var lost := GameManager.customer_gave_up(str(a.get("key", "")))
                spawn_float("-%d uy tín" % lost, node.global_position + Vector3(0, 1.9, 0), C_NO)
                _set_meter(a.get("meter"), 0.0, false)
                _show_plate(a, false)
                ComTamChars.stand_up(rig)
                seat_w["taken"] = false
                a["seat"] = null
                a["booked"] = false
                a["path"] = _route(node.position, _exit_point(floor_i, slot), true, floor_i)
                a["state"] = "leave"
        "eat":
            var seat3: Dictionary = a["seat"]
            var chatty := bool(a["chatty"])
            if str(seat3.get("style", "chair")) == "stool":
                # ghế nhựa thấp: ngồi co gối kiểu quán vỉa hè
                ComTamChars.sit_stool(rig, t, chatty)
            else:
                ComTamChars.sit(rig, t)
            (meal["bowl"] as Node3D).visible = not chatty
            (meal["sticks"] as Node3D).visible = not chatty
            if float(a["t"]) > 11.0:
                # ăn xong, no nê ra về: quán được tiếng thơm
                var gained := GameManager.customer_finished()
                spawn_float("+%d uy tín" % gained,
                    node.global_position + Vector3(0, 1.9, 0), C_OK)
                _set_meter(a.get("meter"), 0.0, false)
                _show_plate(a, false)
                ComTamChars.stand_up(rig)
                (meal["bowl"] as Node3D).visible = false
                (meal["sticks"] as Node3D).visible = false
                seat3["taken"] = false
                a["seat"] = null
                a["path"] = _route(node.position, _exit_point(floor_i, slot), true, floor_i)
                a["state"] = "leave"
        "leave":
            if _follow_path(a, node, rig, t, delta, 1.5):
                a["state"] = "enter"
                a["t"] = -randf() * 4.0
                a["path"] = []
                var sp2: Vector3 = a["spawn"]
                node.position = sp2
                a["y"] = sp2.y


## Khách vào thì tìm bàn còn TRỐNG HẲN trước — mỗi bàn một người rồi mới ghép bàn.
## Hết bàn trống thì bốc ngẫu nhiên một ghế còn thừa; trong quán hay ngoài vỉa hè
## đều có cửa như nhau, nên bàn người chơi mới kê cũng có khách ngồi ngay.
func _take_seat(floor_i: int):
    var free: Array = []
    var busy: Dictionary = {}
    for s in _seats:
        if int(s["floor"]) != floor_i:
            continue
        if bool(s["taken"]):
            busy[int(s.get("table", -1))] = true
        else:
            free.append(s)
    if free.is_empty():
        return null
    var quiet: Array = []
    for s in free:
        if not busy.has(int(s.get("table", -1))):
            quiet.append(s)
    var pool: Array = quiet if not quiet.is_empty() else free
    var pick: Dictionary = pool[randi() % pool.size()]
    pick["taken"] = true
    return pick


# ---------- Chữ tiền bay lên ----------

func spawn_float(text: String, world_pos: Vector3, color: Color = C_GOLD) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 46
    l.pixel_size = LBL_PX
    l.modulate = color
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.shaded = false
    l.no_depth_test = true
    l.render_priority = 5
    l.position = world_pos
    add_child(l)
    _floats.append({"node": l, "t": 0.0})


func _update_floats(delta: float) -> void:
    var keep: Array = []
    for f in _floats:
        f["t"] = float(f["t"]) + delta
        var l: Label3D = f["node"]
        if not is_instance_valid(l):
            continue
        l.position.y += delta * 1.4
        l.modulate.a = clampf(1.0 - float(f["t"]) / 1.2, 0.0, 1.0)
        if float(f["t"]) >= 1.2:
            l.queue_free()
        else:
            keep.append(f)
    _floats = keep


# ================= Điều khiển =================

## Dự án bật `emulate_mouse_from_touch`: ngón ĐẦU TIÊN luôn được máy dịch thành
## sự kiện chuột, nên một ngón (chạm, kéo đổi tầng, xoay) đọc từ NHÁNH CHUỘT là
## chắc ăn nhất. Sự kiện cảm ứng thật không chui được xuống tới SubViewport này,
## vì vậy cử chỉ hai ngón do `restaurant_view._input()` bắt rồi gọi ngược vào
## `zoom_by()` / `pan_by()` / `gesture_active()`.
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_by(0.92)
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_by(1.08)
            return
        if event.button_index != MOUSE_BUTTON_LEFT:
            return
        if event.pressed:
            if not _multi:
                _begin_drag()
        else:
            _end_drag(event.position)
        return

    if event is InputEventMouseMotion and _dragging:
        _move_drag(event.relative, event.position)


## Màn hình quán báo xuống: đang có cử chỉ hai ngón. Giữ thêm một nhịp ngắn để
## nuốt luôn cú "nhả chuột" giả lập ở cuối cử chỉ, tránh bị tính thành một cú chạm.
func gesture_active(on: bool) -> void:
    if on:
        _multi = true
        _multi_hold = 0.35
        _dragging = false


func _begin_drag() -> void:
    _dragging = true
    _drag_moved = 0.0


func _end_drag(pos: Vector2) -> void:
    if _multi:
        _dragging = false
        return
    if _dragging and _drag_moved < 14.0:
        if place_mode:
            _place_from_screen(pos)
        else:
            _handle_tap(pos)
    _dragging = false


func _move_drag(rel: Vector2, pos: Vector2) -> void:
    if _multi:
        return
    _drag_moved += rel.length()
    if place_mode:
        # đang kê bàn: kéo tay là rê bàn, không đổi tầng
        _place_from_screen(pos)
        return
    if not _dragging:
        return
    # Dãy nhà nằm ngang nên vuốt NGANG là đi qua khu bên cạnh; vuốt dọc chỉ hé
    # nghiêng khung nhìn một chút cho đỡ cứng.
    var vw := maxf(get_viewport().get_visible_rect().size.x, 1.0)
    target_focus = clampf(target_focus - rel.x / vw * 2.2, 0.0, float(GameManager.FLOORS.size() - 1))
    yaw = clampf(yaw - rel.y * 0.0016, YAW_HOME - YAW_RANGE, YAW_HOME + YAW_RANGE)


# ================= Kê bàn: chọn chỗ rồi đặt xuống =================

## Giao điểm của tia nhìn với mặt phẳng ngang cao độ `y`. Trả null nếu tia đi ngược.
func _ray_plane(from: Vector3, dir: Vector3, y: float):
    if absf(dir.y) < 0.0001:
        return null
    var k := (y - from.y) / dir.y
    if k < 0.0:
        return null
    return from + dir * k


func _zone_rect(zone: String) -> Dictionary:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    if zone == "out":
        # chừa dải sát mặt tiền cho lò than và lối bưng đồ ra vào
        return {"x0": -OUT_HW + 0.5, "x1": OUT_HW - 0.5, "z0": OUT_Z0 + 0.55, "z1": OUT_Z1}
    return {"x0": -hw + 0.9, "x1": hw - 0.9, "z0": -hd + 2.0, "z1": hd - 0.6}


func _furni_radius(kind: String) -> float:
    var d: Dictionary = GameManager.FURNITURE.get(kind, {})
    return maxf(float(d.get("w", 1.5)), float(d.get("d", 1.5))) * 0.5


## Nửa chiều ngang / nửa chiều sâu của bộ bàn sau khi xoay. Dùng hình chữ nhật thật
## thay vì một vòng tròn bán kính cạnh dài nhất: bàn gỗ 2.7×1.6 mà tính như vòng
## tròn 1.35 thì cả phòng không còn chỗ nào kê được.
func _furni_half(kind: String, rot: int) -> Vector2:
    var d: Dictionary = GameManager.FURNITURE.get(kind, {})
    var hx := float(d.get("w", 1.5)) * 0.5
    var hz := float(d.get("d", 1.5)) * 0.5
    return Vector2(hz, hx) if rot % 2 == 1 else Vector2(hx, hz)


## Chỗ này kê được không: phải nằm gọn trong khu vực cho phép và không đè lên
## bàn khác, cầu thang hay lối vào.
func _spot_ok(kind: String, floor_i: int, zone: String, x: float, z: float, rot: int = 0) -> bool:
    var h := _furni_half(kind, rot)
    var rect := _zone_rect(zone)
    if x - h.x < float(rect["x0"]) - 0.15 or x + h.x > float(rect["x1"]) + 0.15:
        return false
    if z - h.y < float(rect["z0"]) - 0.15 or z + h.y > float(rect["z1"]) + 0.15:
        return false
    var here := Vector2(x, z)
    for i in GameManager.placed.size():
        if i == place_move_index:
            continue
        var it: Dictionary = GameManager.placed[i]
        if int(it.get("floor", 0)) != floor_i or str(it.get("zone", "in")) != zone:
            continue
        var other := Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0)))
        var oh := _furni_half(str(it.get("kind", "")), int(it.get("rot", 0)))
        # hai hình chữ nhật chềm nhau (chừa 20cm lối đi giữa hai bàn)
        if absf(here.x - other.x) < h.x + oh.x + 0.2 and absf(here.y - other.y) < h.y + oh.y + 0.2:
            return false
    if zone == "in":
        for b in _blockers.get(floor_i, []):
            var bp: Vector2 = b["pos"]
            if b.has("half"):
                # vật cản hình hộp (cầu thang): hai chữ nhật chềm nhau là hỏng
                var bh: Vector2 = b["half"]
                if absf(here.x - bp.x) < h.x + bh.x and absf(here.y - bp.y) < h.y + bh.y:
                    return false
                continue
            # điểm trên hình chữ nhật gần tâm vật cản nhất
            var near := Vector2(clampf(bp.x, x - h.x, x + h.x), clampf(bp.y, z - h.y, z + h.y))
            if near.distance_to(bp) < float(b["r"]):
                return false
    return true


## Bắt đầu kê một bộ bàn. `move_index` >= 0 nghĩa là dời bàn đã đặt sẵn.
func begin_placement(kind: String, move_index: int = -1) -> void:
    if not GameManager.FURNITURE.has(kind):
        return
    cancel_placement()
    place_kind = kind
    place_move_index = move_index
    place_mode = true
    var allow := str(GameManager.FURNITURE[kind].get("zone", "any"))
    place_floor = current_floor()
    # tầng chưa mở khoá thì chưa có sàn thật để kê: lùi về quán vỉa hè
    if not GameManager.is_floor_unlocked(str(GameManager.FLOORS[place_floor]["id"])):
        place_floor = 0
    place_rot = 0
    if allow == "out":
        place_floor = 0
        place_zone = "out"
    elif allow == "in":
        place_zone = "in"
    else:
        place_zone = "out" if place_floor == 0 else "in"

    if move_index >= 0 and move_index < GameManager.placed.size():
        var it: Dictionary = GameManager.placed[move_index]
        place_floor = int(it.get("floor", 0))
        place_zone = str(it.get("zone", "in"))
        place_x = float(it.get("x", 0.0))
        place_z = float(it.get("z", 0.0))
        place_rot = int(it.get("rot", 0))
        if _furni_by_index.has(move_index):
            (_furni_by_index[move_index] as Node3D).visible = false
    else:
        var rect := _zone_rect(place_zone)
        place_x = 0.0
        place_z = (float(rect["z0"]) + float(rect["z1"])) * 0.5

    target_focus = float(place_floor)
    if place_zone == "out":
        zoom = maxf(zoom, 1.25)
    _make_ghost()
    _refresh_ghost()


func rotate_placement() -> void:
    if not place_mode:
        return
    place_rot = (place_rot + 1) % 2
    _refresh_ghost()


func cancel_placement() -> void:
    if _ghost != null and is_instance_valid(_ghost):
        _ghost.queue_free()
    _ghost = null
    if place_move_index >= 0 and _furni_by_index.has(place_move_index):
        (_furni_by_index[place_move_index] as Node3D).visible = true
    place_move_index = -1
    if place_mode:
        place_mode = false
        placement_changed.emit(false, "")


func confirm_placement() -> bool:
    if not place_mode or not place_valid:
        return false
    var ok := false
    if place_move_index >= 0:
        ok = GameManager.move_furniture(place_move_index, place_floor, place_zone,
            place_x, place_z, place_rot)
    else:
        ok = GameManager.place_furniture(place_kind, place_floor, place_zone,
            place_x, place_z, place_rot) >= 0
    place_move_index = -1
    place_mode = false
    if _ghost != null and is_instance_valid(_ghost):
        _ghost.queue_free()
    _ghost = null
    placement_changed.emit(false, "")
    return ok


func _make_ghost() -> void:
    _ghost = Node3D.new()
    _ghost.name = "Ghost"
    add_child(_ghost)
    var body := Node3D.new()
    body.name = "Body"
    _ghost.add_child(body)
    _build_furniture_body(body, place_kind)
    var pad := _box(_ghost, 1.0, 0.04, 1.0, C_OK, 0, 0.02, 0, 0.4)
    pad.name = "Pad"
    var r := _furni_radius(place_kind) * 2.0 + 0.3
    pad.mesh.size = Vector3(r, 0.04, r)


func _tint(node: Node, c: Color) -> void:
    if node is MeshInstance3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(c.r, c.g, c.b, 0.55)
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        (node as MeshInstance3D).material_override = m
    for ch in node.get_children():
        _tint(ch, c)


## Cập nhật bóng mờ bàn đang kê + báo cho giao diện biết chỗ này có đặt được không.
func _refresh_ghost() -> void:
    if _ghost == null or not is_instance_valid(_ghost):
        return
    var y: float = OUT_Y if place_zone == "out" else 0.0
    # place_x/z là toạ độ TRONG khu, còn bóng mờ treo thẳng dưới gốc cảnh nên
    # phải cộng thêm vị trí ngang của khu đang kê.
    _ghost.position = Vector3(wing_x(float(place_floor)) + place_x, y, place_z)
    _ghost.rotation.y = float(place_rot) * PI * 0.5
    place_valid = _spot_ok(place_kind, place_floor, place_zone, place_x, place_z, place_rot)
    _tint(_ghost, C_OK if place_valid else C_NO)
    placement_changed.emit(place_valid, place_zone)


## Đổi điểm chạm trên màn hình thành ô đặt bàn (bám lưới 10cm, kẹp trong khu vực).
func _place_from_screen(sp: Vector2) -> void:
    if camera == null or not place_mode:
        return
    var from := camera.project_ray_origin(sp)
    var dir := camera.project_ray_normal(sp)
    var allow := str(GameManager.FURNITURE.get(place_kind, {}).get("zone", "any"))
    # khu nào cũng có vỉa hè riêng trước cửa nên chỗ nào cũng kê bàn ngoài được
    var can_out := allow != "in"
    var can_in := allow != "out"
    var hd := ROOM_D * 0.5
    var p_out = _ray_plane(from, dir, OUT_Y) if can_out else null
    var p_in = _ray_plane(from, dir, 0.0) if can_in else null

    var hit = null
    if p_out != null and (p_out as Vector3).z > hd + 0.3:
        hit = p_out
        place_zone = "out"
    elif p_in != null:
        hit = p_in
        place_zone = "in"
    elif p_out != null:
        hit = p_out
        place_zone = "out"
    if hit == null:
        return

    var rect := _zone_rect(place_zone)
    var h := _furni_half(place_kind, place_rot)
    var hp: Vector3 = hit
    # đổi từ toạ độ cảnh về toạ độ trong khu trước khi kẹp vào vùng cho phép
    var local_x: float = hp.x - wing_x(float(place_floor))
    place_x = clampf(snappedf(local_x, 0.1), float(rect["x0"]) - 0.1 + h.x, float(rect["x1"]) + 0.1 - h.x)
    place_z = clampf(snappedf(hp.z, 0.1), float(rect["z0"]) - 0.1 + h.y, float(rect["z1"]) + 0.1 - h.y)
    _refresh_ghost()

func _handle_tap(screen_pos: Vector2) -> void:
    if camera == null:
        return
    var from := camera.project_ray_origin(screen_pos)
    var dir := camera.project_ray_normal(screen_pos)
    var params := PhysicsRayQueryParameters3D.create(from, from + dir * 250.0)
    params.collide_with_areas = true
    params.collide_with_bodies = false
    var hit := get_world_3d().direct_space_state.intersect_ray(params)
    if hit.is_empty():
        return
    var col: Node = hit["collider"]
    var kind := str(col.get_meta("kind", ""))
    var id := str(col.get_meta("id", ""))

    match kind:
        "boost":
            # Chạm vào quầy là MỞ BẢNG nâng cấp. Trước đây cú chạm bị nuốt luôn
            # vào việc nấu nhanh nên chẳng ai tìm ra bảng; nút nấu nhanh bây giờ
            # nằm sẵn trong bảng đó.
            station_tapped.emit(id)
        "furni":
            furniture_tapped.emit(int(id))
        "floor":
            floor_tapped.emit(id)
        "grill":
            grill_tapped.emit()


func go_to_floor(index: int) -> void:
    target_focus = clampf(float(index), 0.0, float(GameManager.FLOORS.size() - 1))
    pan = Vector2.ZERO


func current_floor() -> int:
    return int(round(focus))
