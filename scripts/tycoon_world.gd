class_name TycoonWorld
extends Node3D
## Toà nhà cắt lớp kiểu idle tycoon: các tầng xếp chồng, camera góc nghiêng cố định,
## vuốt dọc để đổi tầng, chạm bong bóng ₫ để thu tiền, chạm quầy để nấu nhanh.

signal station_tapped(id: String)
signal floor_tapped(fid: String)
signal focus_changed(index: int)
signal collected(amount: float)
signal boosted(id: String)
signal furniture_tapped(index: int)
signal placement_changed(valid: bool, zone: String)

# ---------- Kích thước không gian ----------
## Trần cao là có chủ đích. Màn hình điện thoại rất cao và hẹp: muốn thấy đủ bề
## ngang của quán thì khung nhìn buộc phải cao theo. Trần thấp -> lọt luôn tầng
## trên vào khung hình. Trần cao thì tầng đang xem chiếm gần hết màn hình.
const FLOOR_H := 7.4
const ROOM_W := 7.6
const ROOM_D := 5.2
const SLAB := 0.3

const CAM_FOV := 34.0
const CAM_PITCH := -17.0
const YAW_HOME := -0.32
const YAW_RANGE := 0.26
const VIEW_MIN_FLOORS := 1.15
const VIEW_MAX_FLOORS := 3.4

## Thu phóng: người chơi chụm/xoè hai ngón (hoặc bấm +/-) để kéo khung nhìn ra
## tận vỉa hè. 1.0 = khung mặc định vừa đúng bề ngang quán.
const ZOOM_MIN := 0.62
const ZOOM_MAX := 2.10
const ZOOM_HOME := 1.0

## Kéo hai ngón để dời khung nhìn (xem dãy bàn ngoài đường chẳng hạn).
const PAN_LIMIT_X := 7.0
const PAN_LIMIT_Y := 8.0

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
    var extent := ROOM_W * absf(cos(yaw)) + ROOM_D * absf(sin(yaw))
    # Khung mặc định phải ôm cả bề ngang quán LẪN dải vỉa hè phía trước. Vỉa hè
    # nằm gần camera hơn nên nở to trong khung, vì vậy phải lấy dư chiều cao.
    _base_height = maxf(extent / aspect * 0.95, FLOOR_H * 1.2)
    _view_height = clampf(_base_height * zoom, VIEW_MIN_FLOORS * FLOOR_H, VIEW_MAX_FLOORS * FLOOR_H)
    return (_view_height * 0.5) / tan(deg_to_rad(CAM_FOV) * 0.5)


func _update_camera() -> void:
    var d := _fit_distance()
    var pitch := deg_to_rad(-CAM_PITCH)
    camera.position = Vector3(0, sin(pitch) * d, cos(pitch) * d)
    # Tầng trệt có vỉa hè ở phía trước nên hạ tâm nhìn xuống và đẩy ra ngoài
    # đường; càng kéo xa càng thấy nhiều mặt tiền + hàng bàn ngoài trời.
    var street_bias := clampf(1.0 - focus, 0.0, 1.0)
    var zoom_out := clampf(_view_height / maxf(_base_height, 0.01) - 1.0, 0.0, 1.3)
    var y := focus * FLOOR_H + FLOOR_H * 0.44 - street_bias * (1.25 + zoom_out * 1.5)
    var z := 0.2 + street_bias * (0.75 + zoom_out * 1.5)
    # pan.x chạy dọc trục ngang của camera nên kéo tay sang đâu, cảnh trôi theo đó
    var right := Vector3(cos(yaw), 0.0, -sin(yaw))
    cam_pivot.position = Vector3(0, y + pan.y, z) + right * pan.x
    cam_pivot.rotation.y = yaw


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
    _box(s, 30, 0.2, 7.4, C_WALK, 0, -0.1, hd + 3.0)
    _box(s, 30, 0.14, 10.0, C_ROAD, 0, -0.2, hd + 11.6)
    _box(s, 30, 0.1, 0.22, Color8(0xb9, 0xc0, 0xcf), 0, -0.05, hd + 6.6)   # mép bó vỉa
    for i in 8:
        _box(s, 1.1, 0.02, 0.16, Color8(0xe6, 0xea, 0xee), -14 + i * 3.6, -0.12, hd + 11.0)
    # xe máy dựng nép hai bên cho khoảng giữa vỉa hè trống chỗ kê bàn
    for bx in [-6.6, -5.2, 6.0, 7.4]:
        _box(s, 0.42, 0.32, 1.2, C_STEEL_DARK, bx, 0.2, hd + 5.6)
        _cylinder(s, 0.23, 0.23, 0.1, Color8(0x3a, 0x3e, 0x42), bx, 0.14, hd + 5.12, 12).rotation_degrees = Vector3(0, 0, 90)
        _cylinder(s, 0.23, 0.23, 0.1, Color8(0x3a, 0x3e, 0x42), bx, 0.14, hd + 6.08, 12).rotation_degrees = Vector3(0, 0, 90)
        _box(s, 0.1, 0.4, 0.15, C_STEEL_LIGHT, bx, 0.52, hd + 5.2)
    for tx in [-8.2, 8.4]:
        _cylinder(s, 0.16, 0.2, 1.5, Color8(0x7a, 0x6a, 0x5c), tx, 0.75, hd + 3.0, 8)
        _cylinder(s, 0.1, 1.0, 1.5, C_PLANT, tx, 2.1, hd + 3.0, 8)
    # hàng rào sắt & nhà bên kia đường cho có chiều sâu phố
    for i in 10:
        _box(s, 0.08, 1.1, 0.08, Color8(0x5c, 0x6b, 0x54), -14 + i * 3.1, 0.55, hd + 6.9)


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

    for i in GameManager.FLOORS.size():
        var f: Dictionary = GameManager.FLOORS[i]
        var fid := str(f["id"])
        var node := Node3D.new()
        node.name = "Floor_" + fid
        node.position = Vector3(0, i * FLOOR_H, 0)
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
    if index < GameManager.FLOORS.size() - 1:
        (_blockers[index] as Array).append({"pos": Vector2(hw - 0.7, -hd + 1.2), "r": 1.25})   # cầu thang
    if index == 0:
        (_blockers[index] as Array).append({"pos": Vector2(hw - 0.5, hd - 0.9), "r": 0.95})    # lối vào

    # sàn + gờ sàn màu nhận diện tầng
    _box(node, ROOM_W, SLAB, ROOM_D, C_FLOOR, 0, -SLAB * 0.5, 0, 0.8)
    _box(node, ROOM_W + 0.26, 0.14, ROOM_D + 0.26, accent, 0, -SLAB - 0.07, 0, 0.5)
    var line_mat := ComTamChars.mat(C_FLOOR_LINE, 0.85)
    for gx in range(1, int(ROOM_W)):
        _box(node, 0.025, 0.014, ROOM_D - 0.3, C_FLOOR_LINE, -hw + gx, 0.009, 0).material_override = line_mat
    for gz in range(1, int(ROOM_D)):
        _box(node, ROOM_W - 0.3, 0.014, 0.025, C_FLOOR_LINE, 0, 0.009, -hd + gz).material_override = line_mat

    # hai tường xa (cắt lớp: bỏ tường trước và trần)
    _box(node, ROOM_W, FLOOR_H - SLAB, 0.16, C_WALL, 0, (FLOOR_H - SLAB) * 0.5, -hd, 0.9)
    _box(node, 0.16, FLOOR_H - SLAB, ROOM_D, C_WALL_DEEP, -hw, (FLOOR_H - SLAB) * 0.5, 0, 0.9)
    _box(node, ROOM_W, 0.16, 0.07, accent, 0, 0.08, -hd + 0.1, 0.5)
    _box(node, 0.07, 0.16, ROOM_D, accent, -hw + 0.1, 0.08, 0, 0.5)

    # bảng hiệu tầng treo cao trên tường sau (trần cao nên còn nhiều chỗ trống)
    var f := GameManager.floor_data(fid)
    _box(node, ROOM_W - 1.6, 0.9, 0.1, C_STEEL_DARK, 0, 5.0, -hd + 0.13, 0.4)
    _label3d(node, str(f["name"]).to_upper(), 44, Color8(0xf6, 0xf8, 0xfc), 0, 5.15, -hd + 0.2, false)
    _label3d(node, "TẦNG %d" % (index + 1), 30, accent, 0, 4.7, -hd + 0.2, false)

    # đèn thả trần
    for lx in [-2.3, 0.0, 2.3]:
        _cylinder(node, 0.02, 0.02, 0.9, C_STEEL_DARK, lx, FLOOR_H - 0.75, 0.4, 6)
        _cylinder(node, 0.32, 0.16, 0.26, accent, lx, FLOOR_H - 1.3, 0.4, 12)

    # quầy bếp dọc tường sau
    _box(node, ROOM_W - 0.5, 0.95, 1.0, C_WOOD, 0, 0.48, -hd + 1.15)
    _box(node, ROOM_W - 0.5, 0.16, 1.02, accent, 0, 0.9, -hd + 1.15, 0.5)
    _box(node, ROOM_W - 0.3, 0.1, 1.16, C_WALL, 0, 1.02, -hd + 1.15, 0.55)

    if index == 0:
        _box(node, 0.18, 2.4, 1.5, C_STEEL_LIGHT, hw - 0.09, 1.2, hd - 0.9, 0.4)
        _label3d(node, "LỐI VÀO", 26, accent, hw - 0.32, 2.85, hd - 0.9)
        _build_terrace(node, accent)
    if index < GameManager.FLOORS.size() - 1:
        var steps := int(FLOOR_H / 0.62)
        for i in steps:
            _box(node, 1.0, 0.14, 0.3, accent if i % 2 == 0 else C_STEEL_LIGHT,
                hw - 0.7, 0.2 + i * 0.62, -hd + 0.6 + i * 0.16, 0.6)

    # quầy hàng
    var sids := GameManager.stations_on_floor(fid)
    for i in sids.size():
        _build_station(node, str(sids[i]), _station_slot(i), index)

    # bàn ăn có sẵn của quán
    var spots := [Vector2(-2.1, 0.5), Vector2(2.1, 0.5)]
    _tables[index] = []
    for i in spots.size():
        _build_table(node, spots[i], index)

    _build_decor(node, index, accent)
    _build_placed(node, index)
    _populate(node, fid, index)


# ---------- Vỉa hè trước quán: mái hiên, bậc thềm, tủ kính ----------

func _build_terrace(node: Node3D, accent: Color) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    var t := Node3D.new()
    t.name = "Terrace"
    t.position = Vector3(0, OUT_Y, 0)
    node.add_child(t)

    # nền gạch vỉa hè + đường ron cho thấy rõ cao độ thấp hơn nền quán
    _box(t, OUT_HW * 2.0 + 1.2, 0.08, OUT_Z1 - hd + 0.6, C_TILE, 0, 0.04, (OUT_Z1 + hd) * 0.5, 0.9)
    var line_mat := ComTamChars.mat(C_FLOOR_LINE, 0.9)
    for i in 9:
        _box(t, 0.03, 0.02, OUT_Z1 - hd + 0.5, C_FLOOR_LINE, -4.4 + i * 1.1, 0.085,
            (OUT_Z1 + hd) * 0.5).material_override = line_mat
    for i in 4:
        _box(t, OUT_HW * 2.0 + 1.0, 0.02, 0.03, C_FLOOR_LINE, 0, 0.085,
            hd + 0.5 + i * 0.9).material_override = line_mat

    # bậc thềm bước lên nền quán
    _box(t, ROOM_W + 1.0, 0.4, 0.55, C_WALL_DEEP, 0, 0.2, hd + 0.28, 0.85)
    _box(t, ROOM_W + 1.0, 0.06, 0.6, accent, 0, 0.42, hd + 0.28, 0.5)

    # Mái hiên chỉ là tấm che hẹp ngay mặt tiền. Vươn dài ra vỉa hè thì nhìn từ
    # trên xuống nó úp kín bàn ngoài trời, không thấy khách ngồi nữa.
    var aw := Node3D.new()
    aw.position = Vector3(0, 6.25, hd + 0.1)
    aw.rotation.x = -0.2
    t.add_child(aw)
    var strips := 12
    for i in strips:
        var c: Color = C_AWNING if i % 2 == 0 else Color8(0xfa, 0xf6, 0xef)
        _box(aw, (ROOM_W + 1.4) / float(strips), 0.08, 1.0, c,
            -(ROOM_W + 1.4) * 0.5 + (float(i) + 0.5) * (ROOM_W + 1.4) / float(strips), 0, 0.5, 0.8)
    _box(aw, ROOM_W + 1.5, 0.26, 0.08, C_AWNING, 0, -0.06, 1.0, 0.7)

    # Bảng hiệu dựng nép sang mép trái vỉa hè. Treo giữa mặt tiền thì nó che mất
    # cả dãy quầy bên trong, vì mặt trước quán là mặt cắt để trống.
    var sg := Node3D.new()
    sg.position = Vector3(-hw - 0.75, 0, hd + 1.7)
    sg.rotation.y = 0.34
    t.add_child(sg)
    _cylinder(sg, 0.06, 0.07, 2.6, C_STEEL_LIGHT, 0, 1.3, 0, 8)
    _box(sg, 0.9, 2.2, 0.1, C_STEEL_DARK, 0, 2.9, 0, 0.4)
    _box(sg, 0.98, 0.16, 0.14, C_GOLD, 0, 3.95, 0, 0.4)
    _label3d(sg, "CƠM
TẤM", 40, C_GOLD, 0, 3.35, 0.08, false)
    _label3d(sg, "QUÁN
VỈA HÈ", 20, Color8(0xdf, 0xe6, 0xff), 0, 2.3, 0.08, false)

    # tủ kính bày sườn + nồi cơm to đặt sát mặt tiền
    _box(t, 1.5, 0.75, 0.6, C_WOOD_DARK, -hw + 0.9, 0.42, hd + 0.95)
    _box(t, 1.45, 0.55, 0.55, Color8(0xd8, 0xe8, 0xf2), -hw + 0.9, 1.07, hd + 0.95, 0.2)
    _box(t, 1.5, 0.08, 0.62, accent, -hw + 0.9, 1.38, hd + 0.95, 0.5)
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
        var style := _seat_style(kind)
        for o in offs:
            var ro: Vector2 = o.rotated(holder.rotation.y)
            _seats.append({"pos": Vector3(centre.x + ro.x * 1.02, y, centre.z + ro.y * 1.02),
                "look": centre, "floor": index, "taken": false, "style": style, "out": out, "y": y})


func _build_table(node: Node3D, spot: Vector2, index: int) -> void:
    _box(node, 1.15, 0.1, 1.15, C_WOOD, spot.x, 0.72, spot.y, 0.65)
    _box(node, 0.13, 0.72, 0.13, C_WOOD_DARK, spot.x, 0.36, spot.y)
    _box(node, 0.8, 0.08, 0.8, C_WOOD_DARK, spot.x, 0.045, spot.y)
    _cylinder(node, 0.18, 0.18, 0.03, C_PLATE, spot.x, 0.79, spot.y, 14)
    _cylinder(node, 0.1, 0.1, 0.05, C_HOT, spot.x, 0.82, spot.y, 12)
    (_tables[index] as Array).append(Vector3(spot.x, 0, spot.y))
    (_blockers[index] as Array).append({"pos": spot, "r": 0.7})
    for d in [Vector2(-0.75, 0), Vector2(0.75, 0)]:
        _cylinder(node, 0.21, 0.17, 0.4, C_HOT if d.x > 0.0 else C_STEEL, spot.x + d.x, 0.2, spot.y + d.y, 12)
        _seats.append({"pos": Vector3(spot.x + d.x * 1.05, 0, spot.y + d.y * 1.05),
            "look": Vector3(spot.x, 0, spot.y), "floor": index, "taken": false,
            "style": "chair", "out": false, "y": 0.0})


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
        _cylinder(node, 0.14, 0.14, 0.34, Color8(0xc4, 0x6b, 0x4a), -1.7 + i * 1.15, FLOOR_H - 1.9, hd - 0.7, 10)
    if int(GameManager.decor.get("sign", 0)) > 0:
        _box(node, 2.2, 0.4, 0.1, C_GOLD, 0, 3.3, -hd + 0.2, 0.35)


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

    var bar_y := 2.05
    var name_y := 2.34
    var bubble_y := 2.95

    # thanh tiến độ mẻ
    var bar_root := Node3D.new()
    bar_root.position = Vector3(0, bar_y, 0)
    holder.add_child(bar_root)
    _box(bar_root, 0.9, 0.1, 0.05, Color8(0xe5, 0xea, 0xf5), 0, 0, 0, 0.6)
    var fill := _box(bar_root, 0.84, 0.07, 0.07, accent, 0, 0, 0.01, 0.4)

    # chỉ hiện nhãn khi quầy còn khoá; tên quầy đã có ở dải quầy dưới màn hình
    var name_label := _label3d(holder, "", 24, C_LOCK, 0, name_y, 0)
    name_label.outline_size = 14
    name_label.outline_modulate = Color(1, 1, 1, 0.92)
    name_label.visible = not open

    # bong bóng tiền
    var bubble := Node3D.new()
    bubble.position = Vector3(0, bubble_y, 0)
    bubble.visible = false
    holder.add_child(bubble)
    var bmat := StandardMaterial3D.new()
    bmat.albedo_color = C_GOLD
    bmat.emission_enabled = true
    bmat.emission = C_GOLD
    bmat.emission_energy_multiplier = 0.45
    bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    var plate := _box(bubble, 1.02, 0.38, 0.04, C_GOLD, 0, 0, 0, 0.35)
    plate.material_override = bmat
    var bubble_label := _label3d(bubble, "", 25, Color8(0x40, 0x30, 0x0a), 0, 0, 0.05)

    _touch_area(holder, "boost", sid, Vector3(0, 1.05, 0), Vector3(1.2, 1.9, 1.15))
    var bubble_area := _touch_area(holder, "collect", sid, Vector3(0, bubble_y, 0), Vector3(1.12, 0.5, 0.4))

    _station_nodes[sid] = {
        "holder": holder, "bubble": bubble, "bubble_label": bubble_label,
        "name_label": name_label, "fill": fill, "bubble_y": bubble_y,
        "bubble_area": bubble_area, "smoke": smoke, "floor": floor_index,
        "punch": 0.0,
    }


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
    for i in 4:
        _box(node, 0.1, FLOOR_H - 1.0, 0.1, C_HAZARD, -hw + 0.7 + i * 1.4, (FLOOR_H - 1.0) * 0.5, -hd + 0.6)
    _box(node, ROOM_W - 1.2, 0.08, 0.08, C_HAZARD, 0, 1.6, -hd + 0.6)
    _box(node, ROOM_W - 1.2, 0.08, 0.08, C_HAZARD, 0, 3.4, -hd + 0.6)
    _box(node, 0.8, 0.6, 0.7, C_WOOD, -1.9, 0.3, 0.8)
    _box(node, 0.7, 0.5, 0.6, C_STEEL, 1.7, 0.25, 0.4)

    var sign := Node3D.new()
    sign.position = Vector3(0, 2.1, 0.6)
    sign.rotation.y = -YAW_HOME
    node.add_child(sign)
    _box(sign, 3.2, 1.4, 0.1, C_STEEL_DARK, 0, 0, 0, 0.4)
    _label3d(sign, str(f["name"]).to_upper(), 36, Color8(0xf6, 0xf8, 0xfc), 0, 0.42, 0.09, false)
    _label3d(sign, UIKit.money_short(float(f["cost"])) + " ₫", 42, C_GOLD, 0, 0.0, 0.09, false)
    _label3d(sign, "CHẠM ĐỂ MỞ TẦNG", 24, Color8(0xc2, 0xcd, 0xe8), 0, -0.4, 0.09, false)

    var area := Area3D.new()
    area.position = Vector3(0, 2.1, 0.6)
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

    # đầu bếp đứng sau quầy
    var cook_keys := ["hai", "bay", "tu", "minh"]
    for i in mini(open_stations.size(), 3):
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
    _actors.append({"node": linh, "rig": rig, "mode": "server", "floor": index,
        "state": "wait", "t": 0.0, "dish": dish, "tray": tray, "pickup": pickup,
        "target": pickup, "y": 0.0, "phase": 0.0})

    # khách: tầng trệt thì đi dọc vỉa hè tới, tầng trên vào từ cầu thang
    var seats_here := 0
    for s in _seats:
        if int(s["floor"]) == index:
            seats_here += 1
    var count := clampi(int(GameManager.arrival_rate() / 3.0), 2, maxi(2, mini(seats_here, 7)))
    for i in count:
        var key: String = str(ComTamChars.CUSTOMER_KEYS[randi() % ComTamChars.CUSTOMER_KEYS.size()])
        var ch2 := ComTamChars.build(key)
        var rig2 := ComTamChars.rig_of(ch2)
        var spawn := _spawn_point(index, i)
        ch2.position = spawn
        node.add_child(ch2)
        _actors.append({"node": ch2, "rig": rig2, "mode": "customer",
            "floor": index, "state": "enter", "t": -float(i) * 1.8, "seat": null,
            "slot": i, "spawn": spawn, "y": spawn.y, "path": [], "chatty": i % 3 == 0,
            "meal": ComTamChars.attach_meal(rig2), "phase": randf() * 2.0})


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
    _update_actors(delta)
    _update_floats(delta)


func _update_stations() -> void:
    var dt := get_process_delta_time()
    for sid in _station_nodes:
        var st: Dictionary = _station_nodes[sid]
        var open := GameManager.is_station_open(str(sid))
        var holder: Node3D = st["holder"]

        var amount := float(GameManager.pending.get(sid, 0.0))
        var bubble: Node3D = st["bubble"]
        if amount >= 1.0:
            bubble.visible = true
            (st["bubble_label"] as Label3D).text = UIKit.money_short(amount) + " ₫"
            bubble.position.y = float(st["bubble_y"]) + sin(_time * 2.6) * 0.08
            var k := 1.0 + sin(_time * 4.2) * 0.05
            bubble.scale = Vector3(k, k, k)
        elif bubble.visible:
            bubble.visible = false
        (st["bubble_area"] as Area3D).collision_layer = 1 if bubble.visible else 0

        var nm: Label3D = st["name_label"]
        nm.visible = not open
        if nm.visible:
            nm.text = str(GameManager.STATIONS[sid]["name"]).to_upper() + " · KHOÁ"
            var away := absf(float(int(st["floor"])) - focus)
            nm.modulate.a = clampf(1.0 - away * 0.85, 0.1, 1.0)

        var pr := clampf(float(GameManager.progress.get(sid, 0.0)), 0.0, 1.0) if open else 0.0
        var fill: MeshInstance3D = st["fill"]
        fill.scale.x = maxf(pr, 0.001)
        fill.position.x = -(1.0 - pr) * 0.42

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
        var rig: Dictionary = a["rig"]
        var t: float = _time + float(a["phase"])
        match str(a["mode"]):
            "cook":
                ComTamChars.cook(rig, t)
            "server":
                _update_server(a, node, rig, t, delta)
            "customer":
                _update_customer(a, node, rig, t, delta)


## Người phục vụ bưng khay: nhận đĩa ở quầy, đĩa nằm trên khay suốt đường đi,
## tới bàn thì cúi đặt xuống và đĩa biến mất khỏi khay.
func _update_server(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    var dish: Node3D = a["dish"]
    var carrying := false
    a["t"] = float(a["t"]) + delta

    match str(a["state"]):
        "wait":
            # đứng ở quầy chờ món ra
            ComTamChars.idle(rig, t)
            node.rotation.y = PI
            if float(a["t"]) > 1.4:
                var target = _pick_table(int(a["floor"]))
                if target != null:
                    a["target"] = target
                    a["state"] = "deliver"
                    a["t"] = 0.0
        "deliver":
            carrying = true
            var tgt: Vector3 = a["target"]
            a["y"] = tgt.y
            # dừng cạnh bàn chứ không chui vào giữa bàn
            var away := node.position - tgt
            away.y = 0.0
            if away.length() < 0.05:
                away = Vector3(0, 0, 1)
            var stop: Vector3 = tgt + away.normalized() * 0.85
            if _step_toward(node, stop, 1.45, delta):
                a["state"] = "serve"
                a["t"] = 0.0
                node.rotation.y = atan2(tgt.x - node.position.x, tgt.z - node.position.z)
            else:
                ComTamChars.walk(rig, t, 8.0)
        "serve":
            # cúi đặt đĩa xuống bàn: đĩa rời khay
            ComTamChars.idle(rig, t)
            rig["torso"].rotation.x = 0.18
            if float(a["t"]) > 1.1:
                a["state"] = "return"
                a["t"] = 0.0
        "return":
            rig["torso"].rotation.x = 0.0
            a["y"] = 0.0
            if _step_toward(node, a["pickup"], 1.55, delta):
                a["state"] = "wait"
                a["t"] = 0.0
            else:
                ComTamChars.walk(rig, t, 8.0)

    dish.visible = carrying
    node.position.y = move_toward(node.position.y, float(a.get("y", 0.0)), delta * 1.8)
    _carry_pose(rig)
    _level_tray(a["tray"])


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


func _pick_table(floor_i: int):
    var list: Array = _tables.get(floor_i, [])
    if list.is_empty():
        return null
    return list[randi() % list.size()]


## Khách xuất hiện ở đâu: tầng trệt đi bộ dọc vỉa hè tới, tầng trên từ cầu thang.
func _spawn_point(floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    if floor_i == 0:
        var side := 1.0 if slot % 2 == 0 else -1.0
        return Vector3(side * (OUT_HW + 2.2 + float(slot) * 0.5), OUT_Y, hd + 4.6)
    return Vector3(ROOM_W * 0.5 - 0.9, 0.0, -hd + 1.4 + float(slot) * 0.4)


## Chỗ đứng chờ bàn: ngoài trệt thì đứng nép mé vỉa hè, tầng trên đứng trong quán.
func _wait_point(floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    if floor_i == 0:
        return Vector3(-1.4 + float(slot) * 1.0, OUT_Y, hd + 4.7)
    return Vector3(2.3, 0.0, 0.1 + float(slot) * 0.55)


## Lối ra: khách trệt đi bộ ra khỏi khung theo vỉa hè.
func _exit_point(floor_i: int, slot: int) -> Vector3:
    var hd := ROOM_D * 0.5
    if floor_i == 0:
        var side := -1.0 if slot % 2 == 0 else 1.0
        return Vector3(side * (OUT_HW + 3.0), OUT_Y, hd + 4.9)
    return Vector3(ROOM_W * 0.5 - 0.9, 0.0, -hd + 1.2)


## Đường đi tới đích; nếu phải ra/vào quán thì chèn thêm chặng qua cửa.
func _route(node_pos: Vector3, dest: Vector3, dest_out: bool, floor_i: int) -> Array:
    var hd := ROOM_D * 0.5
    var outside_now := node_pos.z > hd
    if floor_i != 0 or dest_out == outside_now:
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
    a["y"] = tgt.y
    ComTamChars.walk(rig, t, 8.0)
    if _step_toward(node, tgt, speed, delta):
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
                a["path"] = _route(node.position, _wait_point(floor_i, slot), floor_i == 0, floor_i)
            if _follow_path(a, node, rig, t, delta, 1.3):
                a["state"] = "queue"
                a["t"] = 0.0
        "queue":
            node.rotation.y = PI * 0.9 if floor_i > 0 else 0.35
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
                a["state"] = "eat"
                a["t"] = 0.0
                var seat2: Dictionary = a["seat"]
                var look: Vector3 = seat2["look"]
                node.rotation.y = atan2(look.x - node.position.x, look.z - node.position.z)
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
                ComTamChars.stand_up(rig)
                (meal["bowl"] as Node3D).visible = false
                (meal["sticks"] as Node3D).visible = false
                seat3["taken"] = false
                a["seat"] = null
                a["path"] = _route(node.position, _exit_point(floor_i, slot), floor_i == 0, floor_i)
                a["state"] = "leave"
        "leave":
            if _follow_path(a, node, rig, t, delta, 1.5):
                a["state"] = "enter"
                a["t"] = -randf() * 4.0
                a["path"] = []
                var sp2: Vector3 = a["spawn"]
                node.position = sp2
                a["y"] = sp2.y


## Ưu tiên bàn ngoài vỉa hè cho khách tầng trệt — quán cóc thì phải đông mặt tiền.
func _take_seat(floor_i: int):
    var indoor = null
    for s in _seats:
        if int(s["floor"]) != floor_i or bool(s["taken"]):
            continue
        if bool(s.get("out", false)):
            s["taken"] = true
            return s
        if indoor == null:
            indoor = s
    if indoor != null:
        (indoor as Dictionary)["taken"] = true
    return indoor


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
    var vh := maxf(get_viewport().get_visible_rect().size.y, 1.0)
    target_focus = clampf(target_focus + rel.y / vh * 1.9, 0.0, float(GameManager.FLOORS.size() - 1))
    yaw = clampf(yaw - rel.x * 0.004, YAW_HOME - YAW_RANGE, YAW_HOME + YAW_RANGE)


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
        return {"x0": -OUT_HW + 0.5, "x1": OUT_HW - 0.5, "z0": OUT_Z0, "z1": OUT_Z1}
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
    _ghost.position = Vector3(place_x, float(place_floor) * FLOOR_H + y, place_z)
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
    var can_out := allow != "in" and place_floor == 0
    var can_in := allow != "out"
    var hd := ROOM_D * 0.5
    var p_out = _ray_plane(from, dir, OUT_Y) if can_out else null
    var p_in = _ray_plane(from, dir, float(place_floor) * FLOOR_H) if can_in else null

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
    place_x = clampf(snappedf(hp.x, 0.1), float(rect["x0"]) - 0.1 + h.x, float(rect["x1"]) + 0.1 - h.x)
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
    var st: Dictionary = _station_nodes.get(id, {})

    match kind:
        "collect":
            var amount := float(GameManager.pending.get(id, 0.0))
            if amount < 1.0:
                return
            GameManager.collect(id)
            if not st.is_empty():
                spawn_float("+" + UIKit.money_short(amount) + " ₫",
                    (st["holder"] as Node3D).global_position + Vector3(0, 3.3, 0))
            collected.emit(amount)
        "boost":
            if GameManager.boost_station(id):
                if not st.is_empty():
                    st["punch"] = 1.0
                    spawn_float("+", (st["holder"] as Node3D).global_position + Vector3(0, 2.1, 0.4),
                        FLOOR_ACCENTS[int(st["floor"]) % FLOOR_ACCENTS.size()])
                boosted.emit(id)
            else:
                station_tapped.emit(id)
        "furni":
            furniture_tapped.emit(int(id))
        "floor":
            floor_tapped.emit(id)


func go_to_floor(index: int) -> void:
    target_focus = clampf(float(index), 0.0, float(GameManager.FLOORS.size() - 1))
    pan = Vector2.ZERO


func current_floor() -> int:
    return int(round(focus))
