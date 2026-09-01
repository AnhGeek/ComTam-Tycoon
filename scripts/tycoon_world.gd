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
const WARM_SLOTS := 18             # số ô sườn bày được trong lò giữ nhiệt
const COOK_STAND := 0.35           # bục gỗ kê chân người đứng bếp sau quầy

const SERVICE_SEGMENTS := 12       # số vạch trên vòng "đang ra món"

# Nhịp coi nồi: canh nồi một hồi rồi mở nắp ra đảo, đảo xong đậy lại. Để ngắn
# thôi — liếc vào quán lúc nào cũng phải có người đang mở nắp thì mới đã mắt.
const POT_CYCLE := 11.0            # trọn một vòng canh nồi (giây)
const POT_WATCH := 5.0             # đứng canh chừng này giây rồi mới mở nắp
const POT_SWING := 0.7             # nhấc nắp lên (và hạ xuống) mất chừng này
# Nồi cơm cao gần bằng người, đứng bục thường thì cái nồi che kín tới tận cổ.
# Ai coi nồi cao thì kê bục cao hơn hẳn cho lộ nửa người trên ra khỏi nồi.
const POT_STAND := 0.68
## Người phục vụ của một khu, lấy lần lượt theo danh sách này cho đỡ giống hệt nhau
const SERVER_KEYS := ["linh", "hanh", "phuc"]
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
const C_BI := Color8(0xe8, 0xd8, 0xbe)             # bì heo thái sợi
const C_CHA := Color8(0xd9, 0xa5, 0x4e)            # chả trứng hấp
const C_CHA_TOP := Color8(0xe8, 0xc0, 0x54)        # mặt chả quét lòng đỏ
const C_CHE_BEAN := Color8(0xe8, 0xc7, 0x5a)       # chè đậu xanh
const C_CHE_JELLY := Color8(0x3a, 0x34, 0x3c)      # sương sáo
const C_COCONUT := Color8(0xf7, 0xf2, 0xe6)        # nước cốt dừa
const C_BOX := Color8(0xf4, 0xf6, 0xf8)            # hộp xốp cơm mang đi
const C_ORANGE := Color8(0xf2, 0x8c, 0x28)         # cam vắt nước
const C_RICE := Color8(0xfa, 0xf6, 0xea)           # cơm tấm chín trong nồi
# Nồi cơm gas công nghiệp: thân sơn xám nhám, nắp và vành inox, đế đen.
const C_COOKER_BODY := Color8(0xa8, 0xaf, 0xb9)
const C_COOKER_SHADE := Color8(0x7e, 0x86, 0x94)
const C_COOKER_STEEL := Color8(0xf1, 0xf4, 0xf9)
const C_COOKER_BASE := Color8(0x5d, 0x64, 0x71)
const C_COOKER_KNOB := Color8(0x33, 0x38, 0x42)
const C_COOKER_SWITCH := Color8(0xd8, 0x3a, 0x33)
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
var _meters: Array = []            # mọi vòng đếm giờ đang có trong cảnh
var _grill: Dictionary = {}        # các bộ phận của lò than để cập nhật mỗi khung hình
var _decor_bits: Array = []        # quạt + bảng hiệu LED: mấy món trang trí biết cựa quậy
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

# ---------- Vật cản đặc: người không đi xuyên qua ----------
## Khoảng chừa quanh người lúc lái tránh đồ đạc — coi như nửa bề ngang thân. Người
## đã thu nhỏ (CHAR_SCALE) nên vai chỉ rộng chừng này; để rộng hơn thì họ đi vòng
## quá xa, trông như sợ cái bàn. Đây CHỈ là số để lái, không phải va chạm cứng.
const BODY_R := 0.24
## Lối đi hẹp hơn chừng này thì bịt luôn (xem `_seal_solids`). Thân người rộng
## 0.48, nên 0.78 là chừa mỗi bên một tấc rưỡi — vừa đủ để đi lọt mà trông vẫn
## tự nhiên. Để sát nút (0.58) thì sinh ra mấy cái khe nửa vời: lọt thì có lọt,
## nhưng người cứ lấn cấn ở cửa khe, nhìn y như kẹt — khe giữa đầu tường trái với
## xe lò than và khe giữa hai cái tủ lạnh đều đúng kiểu đó.
const WALK_W := 0.78
## Khu -> [{c: tâm, h: nửa chiều}] mọi khối đặc trong khu đó, tính theo mặt bằng
## (bỏ qua cao độ: bàn, quầy, lò, tường — thứ nào người cũng phải đi vòng).
var _solids: Dictionary = {}


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


## Khối cầu (nửa quả cam, nắp chuông...) — anh em với `_box` và `_cylinder`.
func _mesh_sphere(parent: Node3D, r: float, c: Color, x: float, y: float, z: float,
        rough: float = 0.72) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = r
    mesh.height = r * 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = ComTamChars.mat(c, rough)
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
    _solids.clear()
    _meters.clear()
    _grill.clear()
    _decor_bits.clear()

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


## Chỗ đứng của quầy thứ `i` trong khu có tất cả `n` quầy: dàn đều dọc tường
## sau, quầy đầu và quầy cuối luôn nằm ở hai mép ±2.7 (đủ hẹp để không bị cắt ở
## mép màn hình). Khu chỉ có 3 quầy thì ba cái giãn rộng ra chiếm hết mặt quầy,
## chứ không dồn về một bên bỏ trống một góc.
##
## Ô của quầy tính theo TỔNG số quầy của khu, không phải số quầy đã mở — mở thêm
## quầy thì mấy quầy cũ vẫn đứng nguyên chỗ, không xê dịch cả dãy.
func _station_slot(i: int, n: int = 4) -> Vector3:
    var z := -ROOM_D * 0.5 + 1.15
    if n <= 1:
        return Vector3(0, 0, z)
    return Vector3(-2.7 + 5.4 * float(i) / float(n - 1), 0, z)


## Ghi một khối đặc của khu `index`: tâm (x, z) và nửa chiều ngang / nửa chiều sâu.
## Chỉ ghi phần THÂN đồ vật, đừng ghi luôn vòng ghế quanh bàn — ghi cả ghế thì
## khách không bao giờ chen vào ngồi được chỗ của mình.
func _solid(index: int, x: float, z: float, hx: float, hz: float) -> void:
    if not _solids.has(index):
        _solids[index] = []
    (_solids[index] as Array).append({"c": Vector2(x, z), "h": Vector2(hx, hz)})


## Bịt mấy cái KHE CHẾT trong khu: hai thứ kê gần nhau chừa ra một kẽ hẹp hơn bề
## ngang người thì ai lỡ lọt vào đó là nằm luôn trong ấy, không cách nào lách ra.
## Góc phải quầy là chỗ dính nhiều nhất: hồ cá cách mặt quầy hai tấc bảy, chậu
## cây cách hồ cá một tấc hai, cả hai lại cách mép phải quán hơn hai tấc.
##
## Cách chữa: nới cái NHỎ hơn cho dính hẳn vào cái lớn, coi hai thứ là một khối
## liền — người đi vòng ngoài chứ không ai chui vào kẽ nữa. Chạy hai lượt để thứ
## vừa nới xong còn bịt tiếp được kẽ giữa nó với thứ thứ ba (quầy → hồ cá → chậu
## cây → mép quán là đúng một dây bốn thứ như vậy).
##
## Nới rồi thì bàn ghế người chơi kê sát tường cũng liền luôn vào tường, nên
## không cần đi bịt tay từng chỗ mỗi lần thêm đồ mới.
func _seal_solids(index: int) -> void:
    var list: Array = _solids.get(index, [])
    for _pass in 2:
        for a in list:
            var sa: Dictionary = a
            for b in list:
                var sb: Dictionary = b
                if sa == sb:
                    continue
                var ha: Vector2 = sa["h"]
                var hb: Vector2 = sb["h"]
                # chỉ cái nhỏ mới bị nới; nới cái quầy hay bức tường thì nó phình
                # ra nuốt luôn nửa gian nhà
                if ha.x * ha.y > hb.x * hb.y:
                    continue
                var ca: Vector2 = sa["c"]
                var d: Vector2 = (sb["c"] as Vector2) - ca
                for axis in 2:
                    var ax: float = d.x if axis == 0 else d.y
                    var ov: float = d.y if axis == 0 else d.x
                    var ha_ax: float = ha.x if axis == 0 else ha.y
                    var hb_ax: float = hb.x if axis == 0 else hb.y
                    var ha_ov: float = ha.y if axis == 0 else ha.x
                    var hb_ov: float = hb.y if axis == 0 else hb.x
                    # hai cái phải nhìn thẳng vào mặt nhau theo trục kia mới là khe
                    if absf(ov) >= ha_ov + hb_ov:
                        continue
                    var gap := absf(ax) - ha_ax - hb_ax
                    if gap <= 0.0 or gap >= WALK_W:
                        continue
                    var grow := gap * 0.5
                    var dir := 1.0 if ax >= 0.0 else -1.0
                    if axis == 0:
                        ha.x += grow
                        ca.x += grow * dir
                    else:
                        ha.y += grow
                        ca.y += grow * dir
                    sa["h"] = ha
                    sa["c"] = ca


func _build_floor(node: Node3D, fid: String, index: int) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    var accent: Color = FLOOR_ACCENTS[index % FLOOR_ACCENTS.size()]
    _blockers[index] = []
    _solids[index] = []
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

    # Hai bức tường là khối đặc: dựng dày hẳn ra phía sau lưng để ai đi nhanh
    # cũng không lọt qua kẽ tường trong một khung hình.
    _solid(index, 0, -hd - 0.4, hw + 0.4, 0.5)
    _solid(index, -hw - 0.4, 0, 0.5, hd)
    # Mép phải không có tường thật (để trống cho thấy lòng quán), nhưng bước qua
    # đó là hụt chân xuống khoảng trống giữa hai khu — chặn lại y như tường. Chỉ
    # chặn trong lòng quán thôi, vỉa hè phía trước vẫn đi lại thoải mái.
    _solid(index, hw + 0.4, 0, 0.5, hd)

    # quầy bếp dọc tường sau
    _box(node, ROOM_W - 0.5, 0.95, 1.0, C_WOOD, 0, 0.48, -hd + 1.15)
    _box(node, ROOM_W - 0.5, 0.16, 1.02, accent, 0, 0.9, -hd + 1.15, 0.5)
    _box(node, ROOM_W - 0.3, 0.1, 1.16, C_WALL, 0, 1.02, -hd + 1.15, 0.55)
    # cả dãy quầy bếp (và mọi thứ bày trên đó) là một khối liền, không ai chui qua
    _solid(index, 0, -hd + 1.15, (ROOM_W - 0.5) * 0.5, 0.58)

    # vỉa hè trước quán chạy suốt cả dãy; riêng khu trệt mới có lò than + bảng hiệu
    _build_terrace(node, accent, index == 0)
    if index == 0:
        _solid(index, GRILL_POS.x, GRILL_POS.z, 0.84, 0.34)      # xe lò than
        _solid(index, -hw - 0.75, hd + 1.7, 0.24, 0.24)          # cột bảng hiệu
    _solid(index, hw - 0.05, hd + 0.95, 0.38, 0.38)              # lu nước đầu hè

    # Quầy hàng. Bốn cái quầy là bếp CHUNG của cả quán (chung kho, chung tiến độ),
    # nhưng khu nào cũng phải có dãy quầy của mình — không thì mặt quầy trống trơn
    # mà người bưng thì đứng lấy đĩa giữa không khí. Nên dựng đủ ở mọi khu, chỉ có
    # lò than vỉa hè là độc nhất một cái ngoài hiên khu trệt.
    var sids := GameManager.stations_on_floor(fid)
    for i in sids.size():
        _build_station(node, str(sids[i]), _station_slot(i, sids.size()), index)

    # Bàn ăn có sẵn của quán. Kê lùi xuống phía trước và dồn vào giữa để chừa hai
    # lối đi thật: một lối chạy dọc trước mặt quầy bếp, một lối rộng bên phải nối
    # thẳng từ cửa ra vỉa hè vào trong. Bàn phải trước kê sát góc, lối vào chỉ còn
    # bốn tấc — người bưng cơm với khách chen nhau ở đó là kẹt cứng.
    var spots: Array = [Vector2(-2.15, 0.85), Vector2(1.05, 0.85)]
    _tables[index] = []
    for i in spots.size():
        _build_table(node, spots[i], index)

    _build_decor(node, fid, index, accent)
    _build_fridges(node, fid, index, accent)
    _build_placed(node, index)
    _seal_solids(index)
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
## dần theo tiến độ mẻ nướng.
##
## Hai chuyện khác nhau: CÒN THAN thì than vẫn đỏ, lửa vẫn liếm, khói vẫn bay —
## hết sườn sống chỉ làm cái vỉ trống trơn chứ không dập được bếp. Hết than mới
## là lò tắt: than xám lại, tắt lửa, tắt khói.
func _update_grill(dt: float) -> void:
    if _grill.is_empty() or not is_instance_valid(_grill["node"] as Node3D):
        return
    var lit := GameManager.grill_lit()
    var on := GameManager.grill_running()
    var prog := clampf(GameManager.grill_progress, 0.0, 1.0)
    var beat := 0.5 + 0.5 * sin(_time * 3.1)

    for e in _grill["embers"]:
        var m := (e as MeshInstance3D).material_override as StandardMaterial3D
        if m == null:
            continue
        m.emission_energy_multiplier = (1.1 + beat * 1.3) if lit else 0.0
        m.albedo_color = C_EMBER if lit else C_ASH

    for f in _grill["flames"]:
        var fl: MeshInstance3D = f["node"]
        fl.visible = lit
        if not lit:
            continue
        var wob := 0.45 + 0.75 * absf(sin(_time * float(f["speed"]) + float(f["phase"])))
        var sc: float = float(f["scale"])
        fl.scale = Vector3(sc * (0.8 + wob * 0.35), sc * wob * 1.35, sc * (0.8 + wob * 0.35))
        fl.position.y = float(f["y0"]) + wob * 0.06
        fl.rotation.z = sin(_time * 3.0 + float(f["phase"])) * 0.22

    var glow = _grill.get("glow")
    if glow != null and is_instance_valid(glow):
        var lamp: OmniLight3D = glow
        lamp.visible = lit
        lamp.light_energy = 1.1 + beat * 1.1

    for smk in _grill["smoke"]:
        var n: Node3D = smk["node"]
        n.visible = lit
        if not lit:
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

    # vỉ chỉ có thịt khi đang nướng thật: bưng mẻ đi giao hay hết sườn sống thì
    # vỉ trống trơn, dù than bên dưới vẫn đang đỏ rực
    var away := bool(_grill.get("away", false)) or not on
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
    # Lu nước nép hẳn ra mép hè bên phải: đứng chỗ cũ thì nó chặn ngay cửa ra
    # vào, khách với người bưng cơm phải lách qua cái lu mới ra được vỉa hè.
    _cylinder(t, 0.34, 0.36, 0.5, C_STEEL_LIGHT, hw - 0.05, 0.33, hd + 0.95, 14)
    _cylinder(t, 0.36, 0.36, 0.08, C_STEEL, hw - 0.05, 0.62, hd + 0.95, 14)
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


## Nửa chiều ngang/sâu của riêng CÁI BÀN (hoặc chân dù), không tính vòng ghế.
## Đây là khối người phải đi vòng; ghế thì phải chừa ra, không thì khách đứng
## ngoài không lách vào ngồi được. Xoay ngang thì đổi chỗ hai chiều.
func _solid_half(kind: String, rot: int) -> Vector2:
    var h := Vector2.ZERO
    match kind:
        "stool_set":
            h = Vector2(0.5, 0.5)
        "table_steel":
            h = Vector2(0.65, 0.65)
        "table_wood":
            h = Vector2(1.17, 0.52)
        "parasol":
            h = Vector2(0.26, 0.26)      # chỉ cái đế, tán dù thì đi lọt bên dưới
    return Vector2(h.y, h.x) if rot % 2 == 1 else h


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
        var sh := _solid_half(kind, int(it.get("rot", 0)))
        if sh.x > 0.0:
            _solid(index, holder.position.x, holder.position.z, sh.x, sh.y)
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
    # chỉ mặt bàn là khối đặc, bốn cái ghế quanh nó thì chừa ra cho khách ngồi
    _solid(index, spot.x, spot.y, 0.6, 0.6)
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


## Trang trí của MỘT khu. Mỗi gian hàng tự lo mặt tiền của nó: chậu cây mua cho
## vỉa hè thì phòng máy lạnh vẫn trống trơn, nên ở đây chỉ đếm đồ của đúng khu
## `fid` chứ không đếm chung cả quán.
func _build_decor(node: Node3D, fid: String, index: int, accent: Color) -> void:
    var hw := ROOM_W * 0.5
    var hd := ROOM_D * 0.5
    # chậu cây nép vách phải: vách trái để dành cho dãy tủ lạnh
    if GameManager.decor_count(fid, "plant") > 0:
        _cylinder(node, 0.22, 0.26, 0.36, C_WOOD_DARK, hw - 0.55, 0.18, -hd + 2.8, 10)
        _cylinder(node, 0.05, 0.26, 0.9, C_PLANT, hw - 0.55, 0.78, -hd + 2.8, 8)
        _solid(index, hw - 0.55, -hd + 2.8, 0.28, 0.28)
    if GameManager.decor_count(fid, "aquarium") > 0:
        _box(node, 1.0, 0.6, 0.4, C_WOOD_DARK, hw - 0.75, 0.3, -hd + 2.2)
        _box(node, 0.9, 0.55, 0.34, Color8(0x8f, 0xbc, 0xd8), hw - 0.75, 0.86, -hd + 2.2, 0.3)
        _solid(index, hw - 0.75, -hd + 2.2, 0.5, 0.2)
    # Quạt: mua mấy cái thì kê mấy góc, nhiều nhất hai cái cho khỏi rối mắt.
    var fans := mini(GameManager.decor_count(fid, "fan"), 2)
    for i in fans:
        # kê hai góc TRƯỚC của quán: góc sau bị chính cái quầy bếp che kín, đứng
        # đó thì có quay cả ngày cũng chẳng ai thấy
        var fx: float = -hw + 0.55 if i == 0 else hw - 0.55
        var fz: float = hd - 0.45 if i == 0 else hd - 1.5
        # quạt thổi vào lòng quán: cái bên trái hướng ra giữa, cái bên phải quay lại
        _build_fan(node, index, fx, fz, 1.3 if i == 0 else -1.3, accent)
    var lanterns := mini(GameManager.decor_count(fid, "lantern"), 4)
    for i in lanterns:
        _cylinder(node, 0.14, 0.14, 0.34, Color8(0xc4, 0x6b, 0x4a), -1.7 + i * 1.15, FLOOR_H - 0.75, hd - 0.7, 10)
    # Chó cỏ: khu nào mua thì khu đó có chó chạy loăng quăng. Nhiều nhất hai con
    # mỗi khu, đông quá thì rối mắt mà máy yếu cũng nặng thêm.
    var dogs := mini(GameManager.decor_count(fid, "dog"), 2)
    for i in dogs:
        var dog := ComTamChars.build_dog()
        var spot := _dog_target(index)
        dog.position = spot
        node.add_child(dog)
        _actors.append({"node": dog, "rig": ComTamChars.dog_rig_of(dog), "mode": "dog",
            "floor": index, "state": "sniff", "t": randf() * 2.0, "target": spot,
            "phase": randf() * 3.0})
    if GameManager.decor_count(fid, "sign") > 0:
        _build_led_sign(node, index, accent)


## Quạt đứng: đế tròn, cột inox, cái đầu quạt gồm lồng bảo vệ + ba cánh.
##
## Hai chuyển động tách làm hai khớp lồng nhau, đúng như quạt thật:
##   - `head` xoay quanh trục Y — cái đầu quạt đảo qua đảo lại
##   - `spin` xoay quanh trục Z — ba cánh quay tít bên trong lồng
## Cả hai do `_update_decor` lo. `yaw0` là hướng quạt thổi lúc đầu đứng giữa,
## nó đảo qua đảo lại quanh hướng đó.
func _build_fan(node: Node3D, index: int, x: float, z: float, yaw0: float, accent: Color) -> void:
    var col := Color8(0xe8, 0xee, 0xf8)          # vỏ quạt nhựa trắng ngà
    var dark := C_STEEL_DARK

    # đế + cột
    _cylinder(node, 0.3, 0.32, 0.06, dark, x, 0.03, z, 14)
    _cylinder(node, 0.05, 0.07, 1.5, C_STEEL_LIGHT, x, 0.78, z, 8)
    _solid(index, x, z, 0.16, 0.16)

    # khớp đảo: mọi thứ từ đây trở lên quay theo cái đầu quạt
    var head := Node3D.new()
    head.name = "FanHead"
    head.position = Vector3(x, 1.56, z)
    head.rotation.y = yaw0
    node.add_child(head)

    # cụm mô-tơ phía sau; đầu quạt thổi về hướng +Z của khớp
    _cylinder(head, 0.11, 0.13, 0.26, col, 0, 0, -0.16, 12).rotation.x = PI * 0.5
    _box(head, 0.09, 0.07, 0.05, accent, 0, -0.03, -0.3, 0.4)

    # lồng quạt: hai vành thép, để hở cho thấy cánh quay bên trong
    var ring := TorusMesh.new()
    ring.inner_radius = 0.33
    ring.outer_radius = 0.36
    ring.rings = 20
    ring.ring_segments = 6
    for rz in [0.02, 0.13]:
        var rim := MeshInstance3D.new()
        rim.mesh = ring
        rim.material_override = ComTamChars.mat(C_STEEL_LIGHT, 0.4)
        rim.position = Vector3(0, 0, float(rz))
        rim.rotation.x = PI * 0.5
        head.add_child(rim)
    # mấy nan lồng chắn phía trước
    for i in 4:
        var bar := _box(head, 0.02, 0.68, 0.02, C_STEEL_LIGHT, 0, 0, 0.13, 0.4)
        bar.rotation.z = float(i) * PI / 4.0

    # ba cánh quạt quay quanh trục Z
    var spin := Node3D.new()
    spin.name = "FanBlades"
    spin.position = Vector3(0, 0, 0.06)
    head.add_child(spin)
    _cylinder(spin, 0.07, 0.07, 0.06, dark, 0, 0, 0, 10).rotation.x = PI * 0.5
    for i in 3:
        var arm := Node3D.new()
        arm.rotation.z = float(i) * TAU / 3.0
        spin.add_child(arm)
        var blade := _box(arm, 0.3, 0.17, 0.012, col, 0.17, 0, 0, 0.35)
        blade.rotation.x = 0.35        # cánh hơi vênh cho ra dáng ăn gió

    _decor_bits.append({"kind": "fan", "head": head, "spin": spin,
        "yaw0": yaw0, "floor": index, "phase": randf() * TAU})


## Bảng hiệu đèn LED treo trên tường sau: nền tối, chữ "CƠM TẤM" phát sáng, viền
## là một dãy bóng LED chạy vòng quanh. Bảng hiệu mà đứng im thì chán, nên chỗ
## này chỉ gom sẵn mấy vật liệu phát sáng lại; phần nhấp nháy nằm ở
## `_update_decor`, chỉnh độ sáng mỗi khung hình.
func _build_led_sign(node: Node3D, index: int, accent: Color) -> void:
    var hd := ROOM_D * 0.5
    var sg := Node3D.new()
    sg.name = "LedSign"
    # treo dưới bảng tên khu một khoảng, không thì hai cái chữ chồng lên nhau
    sg.position = Vector3(0, 1.44, -hd + 0.2)
    node.add_child(sg)

    # khung + nền bảng
    _box(sg, 2.46, 0.68, 0.05, C_STEEL_DARK, 0, 0, 0, 0.5)
    _box(sg, 2.3, 0.54, 0.06, Color8(0x14, 0x18, 0x28), 0, 0, 0.02, 0.6)

    # chữ neon giữa bảng + gạch chân sáng
    var neon := Color8(0xff, 0x5f, 0xa8)
    var txt := _label3d(sg, "CƠM TẤM", 46, neon, 0, 0.06, 0.07, false)
    var bar := _box(sg, 1.5, 0.035, 0.02, accent, 0, -0.15, 0.07, 0.2)
    _emissive(bar, accent, 2.2)

    # dãy bóng LED chạy vòng quanh viền bảng
    var bulbs: Array = []
    var pts: Array = []
    for i in 9:
        var bx := -1.12 + float(i) * 0.28
        pts.append(Vector2(bx, 0.29))
        pts.append(Vector2(bx, -0.29))
    for p in pts:
        var pv: Vector2 = p
        var b := _cylinder(sg, 0.035, 0.035, 0.03, C_GOLD, pv.x, pv.y, 0.06, 8)
        b.rotation.x = PI * 0.5
        var bm := StandardMaterial3D.new()
        bm.albedo_color = C_GOLD
        bm.emission_enabled = true
        bm.emission = C_GOLD
        bm.emission_energy_multiplier = 2.0
        b.material_override = bm
        bulbs.append(bm)

    _decor_bits.append({"kind": "sign", "node": sg, "text": txt,
        "bar": bar.material_override, "bulbs": bulbs, "neon": neon,
        "floor": index, "phase": float(index) * 0.6})


## Dãy tủ lạnh của khu: kê dọc vách trái, mua mấy cái thì đứng mấy cái. Kho
## nguyên liệu vẫn dùng chung cả quán, nhưng tủ thì khu nào mua khu đó kê — nhìn
## vào là biết khu này đã lo được chỗ trữ đồ tươi tới đâu.
##
## Vách trái chỉ nhét vừa hai cái mà không che mất quầy bếp, nên cái thứ ba mua
## rồi thì vẫn tính chỗ trữ, chỉ là không bày ra cho đỡ chật.
func _build_fridges(node: Node3D, fid: String, index: int, accent: Color) -> void:
    var hw := ROOM_W * 0.5
    var shown := mini(GameManager.fridge_count(fid), 2)
    for i in shown:
        _build_fridge(node, index, -hw + 0.45, -0.55 + float(i) * 1.6, accent)


## Một cái tủ lạnh hai cửa: thân inox, hai cánh có tay nắm dọc, viền màu khu ở
## nóc. Quay mặt vào lòng quán (nhìn về +X) vì nó dựa lưng vào vách trái.
func _build_fridge(node: Node3D, index: int, x: float, z: float, accent: Color) -> void:
    var body := Color8(0xe6, 0xeb, 0xf4)
    var door := Color8(0xd3, 0xdb, 0xea)
    var dark := C_STEEL_DARK

    var fr := Node3D.new()
    fr.name = "Fridge"
    fr.position = Vector3(x, 0, z)
    fr.rotation.y = PI * 0.5          # mặt tủ quay ra giữa quán
    node.add_child(fr)

    # thân tủ + chân đế
    _box(fr, 0.78, 0.06, 0.66, dark, 0, 0.03, 0, 0.5)
    _box(fr, 0.8, 1.62, 0.68, body, 0, 0.87, 0, 0.45)
    _box(fr, 0.84, 0.07, 0.72, accent, 0, 1.71, 0, 0.4)      # viền màu khu trên nóc

    # hai cánh cửa: cánh trên ngăn đá, cánh dưới ngăn mát
    _box(fr, 0.74, 0.52, 0.04, door, 0, 1.42, 0.35, 0.4)
    _box(fr, 0.74, 1.0, 0.04, door, 0, 0.66, 0.35, 0.4)
    # khe hở giữa hai cánh cho ra dáng tủ hai ngăn
    _box(fr, 0.76, 0.03, 0.05, dark, 0, 1.14, 0.35, 0.5)
    # tay nắm dọc, cả hai cùng nằm mé trái cánh
    for hy in [1.42, 0.8]:
        _box(fr, 0.05, 0.34, 0.05, C_STEEL_LIGHT, -0.28, hy, 0.39, 0.35)
    # cái nhãn nhỏ trên cánh dưới cho đỡ trơ
    _box(fr, 0.2, 0.09, 0.02, accent, 0.2, 0.28, 0.38, 0.4)

    _solid(index, x, z, 0.4, 0.42)


## Nhịp sống của mấy món trang trí: quạt đảo qua đảo lại còn cánh thì quay tít,
## bảng hiệu LED thở nhè nhẹ rồi chớp một cái, viền chạy đèn vòng quanh.
func _update_decor(delta: float) -> void:
    for raw in _decor_bits:
        var d: Dictionary = raw
        # khu ở xa tầm nhìn thì thôi khỏi tính, để dành sức cho máy yếu
        if absf(float(d["floor"]) - focus) > ACTOR_LOD_RANGE:
            continue
        var ph := float(d["phase"])
        if str(d["kind"]) == "fan":
            var head: Node3D = d["head"]
            # đảo qua đảo lại chừng ±40 độ quanh hướng ban đầu, chậm rãi như quạt thật
            head.rotation.y = float(d["yaw0"]) + sin(_time * 0.55 + ph) * 0.7
            var spin: Node3D = d["spin"]
            spin.rotation.z -= delta * 16.0
        else:
            var t := _time * 2.4 + ph
            # chữ neon thở nhè nhẹ, cứ một lúc lại chớp tối một nhịp như đèn thật
            var beat := 0.72 + 0.28 * sin(t)
            if fmod(t, TAU * 3.0) < 0.35:
                beat = 0.22
            var txt: Label3D = d["text"]
            var neon: Color = d["neon"]
            txt.modulate = Color(neon.r * beat, neon.g * beat, neon.b * beat, 1.0)
            var bmat: StandardMaterial3D = d["bar"]
            bmat.emission_energy_multiplier = 0.6 + beat * 2.2
            # viền chạy đèn: bóng nào tới lượt thì sáng rực, còn lại lim dim
            var bulbs: Array = d["bulbs"]
            for i in bulbs.size():
                var m: StandardMaterial3D = bulbs[i]
                var wave := sin(_time * 5.0 - float(i) * 0.7 + ph)
                m.emission_energy_multiplier = 0.35 + maxf(0.0, wave) * 3.2


# ---------- Quầy hàng ----------

## Nồi cơm gas cỡ lớn kiểu quán ăn: đế đen có bảng công tắc đỏ và van gas, thân
## drum sơn xám hơi loe lên, vành inox, nắp inox nhiều tầng với quai chữ nhật, hai
## móc gài hai bên. Nắp gom vào một khớp riêng để người coi nồi nhấc lên hạ
## xuống được. Trả về {"steam": hơi nước, "lid": khớp nắp, "y0"/"z0": chỗ nắp nằm
## lúc đậy kín} cho `_update_stations` và `_set_pot_lid` xài.
func _build_rice_cooker(holder: Node3D, open: bool, trim: Color) -> Dictionary:
    # khoá thì cả cái nồi xám xịt như mọi thứ chưa mở
    var body: Color = C_COOKER_BODY if open else C_LOCK
    var shade: Color = C_COOKER_SHADE if open else C_LOCK
    var steel: Color = C_COOKER_STEEL if open else C_LOCK
    var base: Color = C_COOKER_BASE if open else C_LOCK
    var dark: Color = C_COOKER_KNOB if open else C_LOCK

    # ---- đế bếp gas: khối đen bè ra, nồi ngồi lên trên
    _cylinder(holder, 0.30, 0.32, 0.08, base, 0, 1.04, 0, 16)
    _cylinder(holder, 0.33, 0.33, 0.025, shade, 0, 1.088, 0, 16)
    # bảng điều khiển hai công tắc đỏ, quay ra phía khách
    _box(holder, 0.18, 0.075, 0.05, dark, 0, 1.045, 0.29)
    for sx in [-0.04, 0.04]:
        _box(holder, 0.055, 0.048, 0.02, C_COOKER_SWITCH if open else C_LOCK, sx, 1.045, 0.317, 0.45)
    # van gas chìa sang bên phải: tay vặn rồi tới ống dẫn
    var knob := _cylinder(holder, 0.048, 0.048, 0.05, trim, 0.315, 1.04, 0.1, 10)
    knob.rotation.z = PI * 0.5
    var pipe := _cylinder(holder, 0.024, 0.024, 0.17, dark, 0.42, 1.04, 0.1, 8)
    pipe.rotation.z = PI * 0.5

    # ---- thân nồi: gần như thẳng đứng, chỉ hơi phình lên trên như nồi thật
    _cylinder(holder, 0.34, 0.30, 0.07, body, 0, 1.13, 0, 18)
    _cylinder(holder, 0.35, 0.34, 0.30, body, 0, 1.315, 0, 18)
    _cylinder(holder, 0.355, 0.352, 0.028, shade, 0, 1.452, 0, 18)

    # ---- vành inox loe ra khỏi thân (vành thuộc về nồi, không nhấc theo nắp)
    _cylinder(holder, 0.39, 0.383, 0.03, steel, 0, 1.481, 0, 20)

    # ---- cơm chín đầy ắp trong lòng nồi: bình thường nắp đậy kín chẳng thấy gì,
    # chỉ lúc người coi nồi nhấc nắp lên mới lộ ra
    if open:
        _cylinder(holder, 0.335, 0.315, 0.05, C_RICE, 0, 1.468, 0, 18)

    # ---- nắp phẳng xếp tầng (không phải mái vòm), gom hết vào một khớp để
    # `_set_pot_lid` nhấc lên nghiêng ra lúc đảo cơm
    var lid := Node3D.new()
    lid.name = "Lid"
    lid.position = Vector3(0, 1.5, 0)
    holder.add_child(lid)
    _cylinder(lid, 0.355, 0.355, 0.038, steel, 0, 0.015, 0, 20)
    _cylinder(lid, 0.295, 0.295, 0.03, steel, 0, 0.049, 0, 20)
    _cylinder(lid, 0.19, 0.19, 0.022, steel, 0, 0.075, 0, 16)

    # quai nắp: khung chữ nhật rỗng ruột nằm ngửa trên nắp, kê trên hai chân
    for hx in [-0.115, 0.115]:
        _box(lid, 0.04, 0.045, 0.05, dark, hx, 0.105, 0)
        _box(lid, 0.038, 0.032, 0.15, dark, hx, 0.138, 0)
    for hz in [-0.056, 0.056]:
        _box(lid, 0.27, 0.032, 0.038, dark, 0, 0.138, hz)

    # ---- hai móc gài kẹp nắp xuống thân, bấu vào vành inox
    for lx in [-1.0, 1.0]:
        _box(holder, 0.045, 0.17, 0.055, shade, lx * 0.378, 1.42, 0)
        _box(holder, 0.09, 0.03, 0.06, shade, lx * 0.372, 1.502, 0)
        _box(holder, 0.055, 0.05, 0.07, dark, lx * 0.362, 1.335, 0, 0.5)

    # ---- hơi cơm phì ra quanh mép nắp lúc nồi đang chạy
    var pot := {"lid": lid, "x0": 0.0, "y0": 1.5, "z0": 0.0, "steam": [],
        "slide": 0.42, "lift": 0.14, "drop": 0.38, "tilt": 1.15, "stand": POT_STAND}
    if not open:
        return pot
    var steam: Array = []
    for i in 3:
        var sm := StandardMaterial3D.new()
        sm.albedo_color = Color(0.95, 0.97, 1.0, 0.32)
        sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var sp := _cylinder(holder, 0.06, 0.06, 0.06, Color.WHITE,
            randf_range(-0.2, 0.2), 1.68 + float(i) * 0.28, randf_range(-0.14, 0.14), 8)
        sp.material_override = sm
        steam.append({"node": sp, "y0": 1.68})
    pot["steam"] = steam
    return pot


## Lò giữ nhiệt đặt trên quầy: sườn nướng ngoài hiên bưng vào đây nằm chờ khách.
##
## Máy quay của game nhìn chúi xuống 42 độ, nên tủ kính đứng thì chỉ thấy cái nóc.
## Vì vậy lò làm kiểu KHAY HỞ NÓC: khay inox nông, sườn nằm phơi ra trong khay,
## phía sau là vách và mái che có đèn sưởi hắt xuống. Nhìn từ trên xuống là đếm
## được đúng số miếng đang có — mỗi miếng thấy được là một miếng có thật trong kho.
## Trả về mảng các miếng để `_update_stations` bật/tắt theo số sườn còn lại.
func _build_warmer(holder: Node3D, open: bool, body_col: Color, trim: Color) -> Array:
    # khay inox nông đặt trên mặt quầy
    _box(holder, 1.02, 0.14, 0.64, C_STEEL_LIGHT, 0, 1.07, 0, 0.4)
    _box(holder, 0.94, 0.1, 0.56, body_col if open else C_LOCK, 0, 1.1, 0, 0.5)
    _box(holder, 1.06, 0.04, 0.68, trim, 0, 1.0, 0, 0.5)

    # vách sau + hai vách hông + mái che: phần "lò" chụp lên nửa sau của khay
    _box(holder, 1.02, 0.36, 0.06, body_col, 0, 1.32, -0.29)
    for dx in [-0.48, 0.48]:
        _box(holder, 0.06, 0.36, 0.34, body_col, dx, 1.32, -0.15)
    _box(holder, 1.06, 0.06, 0.42, body_col, 0, 1.5, -0.13)
    _box(holder, 1.08, 0.04, 0.44, trim, 0, 1.535, -0.13, 0.5)

    var slots: Array = []
    if not open:
        return slots

    # đèn sưởi vàng cam gắn dưới mái, hắt xuống khay sườn
    var lamp := _box(holder, 0.86, 0.03, 0.26, C_HOT, 0, 1.455, -0.13, 0.3)
    var lm := StandardMaterial3D.new()
    lm.albedo_color = C_HOT
    lm.emission_enabled = true
    lm.emission = C_HOT
    lm.emission_energy_multiplier = 1.4
    lamp.material_override = lm

    # sườn xếp hai hàng trong khay, hàng sau nằm dưới mái cho ấm
    var per_row := int(WARM_SLOTS / 2)
    for row in 2:
        var rz := -0.14 + float(row) * 0.26
        for i in per_row:
            var x := -0.4 + float(i) * (0.8 / float(per_row - 1))
            var slab := _box(holder, 0.08, 0.035, 0.22, C_MEAT_DONE, x, 1.155, rz, 0.55)
            slab.rotation.y = 0.05 * (1.0 if i % 2 == 0 else -1.0)
            slab.visible = false
            slots.append(slab)
    return slots


## Chỗ thái bì & chả: cái thớt nằm ngay trên mặt quầy bếp, cùng một dãy với nồi
## cơm tấm và lò giữ nhiệt — người thái đứng sau quầy thái xuống đó. Trên thớt có
## mớ bì heo thái sợi và miếng chả trứng; hết thứ nào thì phần đó biến khỏi thớt,
## nhìn cái thớt là biết bàn còn làm được hay không.
func _build_chop_board(holder: Node3D) -> Dictionary:
    var z := -0.25
    # thớt gỗ dày đặt trên mặt quầy (mặt quầy cao 1.07)
    _box(holder, 0.5, 0.05, 0.3, C_WOOD, 0, 1.095, z, 0.8)
    _box(holder, 0.52, 0.025, 0.32, C_WOOD_DARK, 0, 1.072, z, 0.85)

    # bì heo: mấy sợi mảnh xếp chồng bên trái thớt
    var bi := Node3D.new()
    holder.add_child(bi)
    for i in 7:
        var b := _box(bi, 0.085, 0.012, 0.012, C_BI, -0.13 + randf_range(-0.02, 0.02),
            1.126 + float(i) * 0.008, z - 0.06 + float(i) * 0.014, 0.85)
        b.rotation.y = randf_range(-0.5, 0.5)

    # chả trứng: một miếng vuông vàng nâu và mấy lát đã xắn ra
    var cha := Node3D.new()
    holder.add_child(cha)
    _box(cha, 0.1, 0.045, 0.1, C_CHA, 0.14, 1.142, z - 0.05, 0.7)
    _box(cha, 0.1, 0.008, 0.1, C_CHA_TOP, 0.14, 1.168, z - 0.05, 0.7)
    for i in 3:
        _box(cha, 0.026, 0.04, 0.085, C_CHA, 0.075 + float(i) * 0.03, 1.14, z + 0.07, 0.7)
    return {"bi": bi, "cha": cha}


## Quầy chè (khu máy lạnh): ba nồi inox chè khác nhau trên bệ, kèm chồng ly thuỷ
## tinh và cái vá múc. Quầy chưa mở thì xám ngoét như mọi thứ chưa mở.
##
## Nồi giữa là nồi có nắp mở được: người coi nồi bên khu máy lạnh cũng lâu lâu
## nhấc nắp lên đảo một vòng rồi đậy lại, y như người coi nồi cơm ngoài vỉa hè.
func _build_che_counter(holder: Node3D, open: bool, trim: Color) -> Dictionary:
    var steel: Color = C_STEEL_LIGHT if open else C_LOCK
    _box(holder, 0.92, 0.16, 0.6, trim, 0, 1.15, 0, 0.55)
    var fills := [C_CHE_BEAN, C_CHE_JELLY, C_COCONUT]
    var pot: Dictionary = {}
    for i in 3:
        var x := -0.29 + float(i) * 0.29
        _cylinder(holder, 0.13, 0.12, 0.18, steel, x, 1.32, 0.1, 14)
        if open:
            _cylinder(holder, 0.115, 0.115, 0.02, fills[i], x, 1.41, 0.1, 14)
        # nắp inox có núm, riêng nồi giữa thì nhấc lên hạ xuống được
        var lid := Node3D.new()
        lid.name = "Lid%d" % i
        lid.position = Vector3(x, 1.43, 0.1)
        holder.add_child(lid)
        _cylinder(lid, 0.135, 0.132, 0.018, steel, 0, 0.009, 0, 14)
        _cylinder(lid, 0.026, 0.026, 0.03, steel, 0, 0.033, 0, 8)
        if i == 1:
            # nồi chè kê sát nhau, nắp gạt ngắn thôi rồi gác nghiêng lên
            # chính miệng nồi của nó, không thì đụng nồi bên cạnh
            pot = {"lid": lid, "x0": x, "y0": 1.43, "z0": 0.1, "steam": [],
                "slide": 0.17, "lift": 0.1, "drop": 0.1, "tilt": 1.0}
        # cái vá gác miệng nồi
        var ladle := _cylinder(holder, 0.012, 0.012, 0.18, steel, x + 0.09, 1.46, 0.1, 6)
        ladle.rotation.x = 0.5
    # chồng ly thuỷ tinh để bên phải
    for i in 4:
        _cylinder(holder, 0.045, 0.04, 0.06, C_PLATE if open else C_LOCK,
            0.38, 1.26 + float(i) * 0.055, 0.24, 10)
    return pot if open else {}


## Quầy cơm hộp văn phòng: chồng hộp xốp mang đi, một hộp mở nắp đang xới cơm,
## với xấp túi ni lông vắt bên cạnh.
func _build_takeaway(holder: Node3D, open: bool, trim: Color) -> void:
    var box_c: Color = C_BOX if open else C_LOCK
    _box(holder, 0.9, 0.14, 0.6, trim, 0, 1.14, 0, 0.55)
    # ba chồng hộp cao thấp khác nhau cho khỏi đều tăm tắp
    var stacks := [3, 4, 2]
    for i in stacks.size():
        var x := -0.3 + float(i) * 0.24
        for k in int(stacks[i]):
            var by := 1.24 + float(k) * 0.062
            _box(holder, 0.2, 0.052, 0.15, box_c, x, by, 0.06, 0.6)
            _box(holder, 0.205, 0.008, 0.155, C_STEEL_LIGHT if open else C_LOCK, x, by + 0.03, 0.06, 0.5)
    if open:
        # hộp đang xới dở: nắp dựng nghiêng, trong lòng có cơm và miếng sườn
        _box(holder, 0.22, 0.05, 0.16, box_c, 0.3, 1.235, 0.3, 0.6)
        _box(holder, 0.18, 0.03, 0.12, Color8(0xfa, 0xf6, 0xea), 0.3, 1.27, 0.3, 0.85)
        _box(holder, 0.09, 0.025, 0.07, C_MEAT_DONE, 0.33, 1.29, 0.3, 0.55)
        var lid := _box(holder, 0.22, 0.015, 0.16, box_c, 0.3, 1.32, 0.4, 0.6)
        lid.rotation.x = -1.1


## Bàn cơm phần: khay inox dài chia ô, mỗi ô một thứ — cơm, sườn, đồ chua, rau.
func _build_tray_line(holder: Node3D, open: bool, trim: Color) -> void:
    var steel: Color = C_STEEL_LIGHT if open else C_LOCK
    _box(holder, 0.94, 0.14, 0.62, trim, 0, 1.14, 0, 0.55)
    _box(holder, 0.9, 0.1, 0.44, steel, 0, 1.26, 0.08, 0.4)
    if not open:
        return
    var foods := [Color8(0xfa, 0xf6, 0xea), C_MEAT_DONE, C_CHA, C_PLANT]
    for i in foods.size():
        var x := -0.31 + float(i) * 0.21
        _box(holder, 0.17, 0.05, 0.36, Color8(0xd6, 0xdd, 0xe8), x, 1.29, 0.08, 0.35)
        _box(holder, 0.15, 0.035, 0.32, foods[i], x, 1.315, 0.08, 0.7)
    # cái kẹp gắp để đầu khay
    _cylinder(holder, 0.012, 0.012, 0.16, steel, 0.41, 1.33, 0.12, 6).rotation.z = 0.6


## Bàn VIP: mặt gỗ sẫm nẹp vàng, có nắp chuông đậy đĩa và bộ đũa để sẵn.
func _build_vip_table(holder: Node3D, open: bool, trim: Color) -> void:
    var gold: Color = C_GOLD if open else C_LOCK
    var steel: Color = C_STEEL_LIGHT if open else C_LOCK
    _box(holder, 0.9, 0.2, 0.62, C_WOOD_DARK if open else C_LOCK, 0, 1.17, 0, 0.7)
    _box(holder, 0.95, 0.035, 0.66, gold, 0, 1.29, 0, 0.45)
    _box(holder, 0.95, 0.02, 0.66, trim, 0, 1.06, 0, 0.5)
    if not open:
        return
    # nắp chuông inox úp đĩa, có núm vàng
    _cylinder(holder, 0.2, 0.2, 0.02, C_PLATE, -0.18, 1.32, 0.08, 16)
    var dome := _mesh_sphere(holder, 0.19, steel, -0.18, 1.33, 0.08)
    dome.scale = Vector3(1.0, 0.72, 1.0)
    _cylinder(holder, 0.03, 0.03, 0.05, gold, -0.18, 1.47, 0.08, 8)
    # đĩa bày sẵn và đôi đũa gác
    _cylinder(holder, 0.16, 0.16, 0.025, C_PLATE, 0.22, 1.32, 0.08, 14)
    _cylinder(holder, 0.13, 0.13, 0.012, gold, 0.22, 1.34, 0.08, 14)
    for sx in [-0.012, 0.012]:
        _box(holder, 0.008, 0.008, 0.22, C_WOOD, 0.22 + sx, 1.35, 0.1, 0.7)


## Quầy nước ép: cái máy ép inox có phễu, rổ cam và mấy ly nước đã vắt sẵn.
func _build_juice_bar(holder: Node3D, open: bool, trim: Color) -> void:
    var steel: Color = C_STEEL_LIGHT if open else C_LOCK
    _box(holder, 0.9, 0.14, 0.6, trim, 0, 1.14, 0, 0.55)
    # thân máy ép + phễu trên nóc + vòi rót
    _box(holder, 0.26, 0.34, 0.24, steel, -0.26, 1.38, 0.08)
    _cylinder(holder, 0.13, 0.06, 0.12, steel, -0.26, 1.6, 0.08, 12)
    var spout := _cylinder(holder, 0.03, 0.03, 0.1, C_STEEL_DARK if open else C_LOCK,
        -0.26, 1.24, 0.22, 8)
    spout.rotation.x = PI * 0.5
    if not open:
        return
    # rổ cam bên cạnh
    _cylinder(holder, 0.17, 0.15, 0.09, C_WOOD, 0.14, 1.26, 0.08, 12)
    for i in 5:
        var ang := TAU * float(i) / 5.0
        _mesh_sphere(holder, 0.055, C_ORANGE, 0.14 + cos(ang) * 0.07, 1.33,
            0.08 + sin(ang) * 0.06)
    # hai ly nước cam đã vắt
    for i in 2:
        var x := 0.36
        _cylinder(holder, 0.05, 0.045, 0.13, C_PLATE, x, 1.28, 0.02 + float(i) * 0.16, 10)
        _cylinder(holder, 0.045, 0.045, 0.09, C_ORANGE, x, 1.27, 0.02 + float(i) * 0.16, 10)


## `sid` là khoá ghép "quầy@khu": hình dạng thì tra theo TÊN QUẦY, còn cấp và
## tiến độ thì hỏi thẳng bằng khoá ghép nên mỗi khu một đằng.
func _build_station(parent: Node3D, sid: String, pos: Vector3, floor_index: int) -> void:
    var base := GameManager.station_base(sid)
    var open := GameManager.is_station_open(sid)
    var accent: Color = FLOOR_ACCENTS[floor_index % FLOOR_ACCENTS.size()]

    var holder := Node3D.new()
    holder.name = "St_" + base
    holder.position = pos
    parent.add_child(holder)

    var body_col := C_STEEL_DARK if open else C_LOCK
    var trim := accent if open else C_LOCK
    var smoke: Array = []
    var warm: Array = []
    var chop: Dictionary = {}
    var pot: Dictionary = {}

    match base:
        "grill":
            # quầy trong quán KHÔNG nướng: nó là lò giữ nhiệt, giữ ấm sườn đã nướng
            warm = _build_warmer(holder, open, body_col, trim)
        "bbq":
            # lò than hoa trên sân vườn thì nướng thật, sườn sống bỏ thẳng lên vỉ
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
                    var sp := _cylinder(holder, 0.12, 0.12, 0.12, Color.WHITE,
                        randf_range(-0.35, 0.35), 1.6 + randf() * 1.0, 0, 8)
                    sp.material_override = sm
                    smoke.append({"node": sp, "y0": sp.position.y})
        "rice":
            pot = _build_rice_cooker(holder, open, trim)
            smoke = pot["steam"]
        "dessert":
            pot = _build_che_counter(holder, open, trim)
        "office":
            _build_takeaway(holder, open, trim)
        "juice":
            _build_juice_bar(holder, open, trim)
        "prep":
            # Bàn bì & chả KHÔNG còn là cái bục trên mặt quầy nữa: bản thân cái bàn
            # thái kê phía trước chính là quầy này. Mặt quầy chỗ đó để trống, chỉ
            # còn chồng đĩa chờ ra món.
            _cylinder(holder, 0.14, 0.14, 0.05, C_PLATE, -0.24, 1.1, -0.1, 12)
            _cylinder(holder, 0.14, 0.14, 0.04, C_PLATE, -0.24, 1.14, -0.1, 12)
            if open:
                chop = _build_chop_board(holder)
        "combo":
            _build_tray_line(holder, open, trim)
        "vip":
            _build_vip_table(holder, open, trim)
        "drink":
            _box(holder, 0.7, 1.5, 0.58, Color8(0xf3, 0xf5, 0xfa), 0, 0.75, -0.1)
            _box(holder, 0.74, 0.12, 0.62, trim, 0, 1.45, -0.1, 0.5)
            _box(holder, 0.58, 1.0, 0.06, Color8(0xa8, 0xd8, 0xf0), 0, 1.0, 0.2, 0.25)
        _:
            _box(holder, 0.9, 0.5, 0.7, body_col, 0, 1.25, 0)

    # Trên đầu quầy giờ để trống hẳn: không thanh tiến độ, không nhãn tên, không
    # bảng tiền vàng che mất người đứng bếp. Tiến độ từng quầy đã có ở dải quầy
    # bên phải màn hình, còn tiền thì bấm nút THU (hoặc thuê quản lý) là gom hết.
    _touch_area(holder, "boost", sid, Vector3(0, 1.05, 0), Vector3(1.2, 1.9, 1.15))

    # Khoá ở đây là khoá ghép "quầy@khu" của GameManager, nên quầy cùng tên ở ba
    # khu vẫn là ba mục riêng, không cái nào đè cái nào.
    _station_nodes[sid] = {
        "holder": holder, "smoke": smoke, "warm": warm, "chop": chop, "pot": pot,
        "floor": floor_index, "punch": 0.0,
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


## Quản lý của khu: khu nào đã thuê quản lý cho ít nhất một quầy thì dựng một
## người mặc vest ra đứng phía trước quán, gần lối ra vỉa hè cho dễ thấy mặt.
## Quản lý không bưng bê gì hết — chỉ đứng im trông chừng, nên không có đường đi,
## không có việc, chỉ thở nhè nhẹ theo `idle`.
func _build_manager(node: Node3D, fid: String, index: int) -> void:
    if GameManager.floor_managers(fid) <= 0:
        return
    var boss := ComTamChars.build("quan_nam" if index % 2 == 0 else "quan_nu")
    boss.position = Vector3(-0.9, 0.0, ROOM_D * 0.5 - 0.55)
    boss.rotation.y = 0.25          # quay mặt ra đường, hơi nghiêng về phía máy quay
    node.add_child(boss)
    _actors.append({"node": boss, "rig": ComTamChars.rig_of(boss), "mode": "boss",
        "floor": index, "phase": randf() * 3.0})


func _populate(node: Node3D, fid: String, index: int) -> void:
    var hd := ROOM_D * 0.5
    # Khu nào cũng có dãy quầy của mình, nên khu nào cũng có người đứng bếp.
    var sids: Array = GameManager.stations_on_floor(fid)
    # nhớ luôn quầy đó nằm ở ô thứ mấy, để người đứng đúng sau quầy của mình
    var open_here: Array = []
    for i in sids.size():
        var sid := str(sids[i])
        if GameManager.is_station_open(sid):
            open_here.append({"sid": sid, "slot": i})

    # người đứng lò than ngoài vỉa hè (chỉ tầng trệt, quầy nướng nằm ngoài đó)
    var has_grill := false
    for e in open_here:
        var ent: Dictionary = e
        if GameManager.station_base(str(ent["sid"])) == "grill":
            has_grill = true
    if index == 0 and has_grill:
        _build_griller(node)

    # đầu bếp đứng sau quầy
    var cook_keys := ["hai", "bay", "tu", "minh"]
    var made := 0
    for e in open_here:
        var ent: Dictionary = e
        if made >= 4:
            break
        var sid_here := str(ent["sid"])
        var base_here := GameManager.station_base(sid_here)
        # người của lò nướng đã ra ngoài đứng lò than rồi, khỏi dựng lại
        if index == 0 and base_here == "grill":
            continue
        var sp := _station_slot(int(ent["slot"]), sids.size())
        var ch := ComTamChars.build(cook_keys[made % cook_keys.size()])
        made += 1
        # bục kê chân: quầy nào có nồi cao thì kê cao hơn cho khỏi bị nồi che
        var pot_here := _pot_of(sid_here)
        var stand: float = float(pot_here.get("stand", COOK_STAND))
        # Khoảng hẹp sau quầy bị chính cái quầy che kín ở góc máy 42 độ, đứng đó
        # thì không ai thấy. Riêng người thái bì & chả cho ra đứng phía mặt tiền
        # quầy, quay mặt vào trong — đúng kiểu quán cơm tấm bày thớt ra trước cho
        # khách nhìn, mà cũng là chỗ duy nhất thấy được tay dao.
        # Ai đứng bếp cũng đứng SÁT LƯNG QUẦY, quay mặt ra phía khách, và kê chân
        # lên một cái bục gỗ: người trong game chỉ cao 1,31 mà mặt quầy đã 1,07,
        # không kê lên thì cái quầy che kín tới tận cổ mà tay cũng không với tới
        # mặt quầy. Bục nằm khuất sau quầy nên người chơi chỉ thấy họ cao vừa phải.
        ch.position = Vector3(sp.x, stand, sp.z - 0.6)
        ch.rotation.y = 0.0
        _box(node, 0.7, stand, 0.5, C_WOOD_DARK, sp.x, stand * 0.5, sp.z - 0.6)
        node.add_child(ch)
        var crig := ComTamChars.rig_of(ch)
        # người đứng bàn bì & chả cầm sẵn con dao bầu để thái
        var knife = ComTamChars.attach_knife(crig) if base_here == "prep" else null
        # quầy nào có nồi đậy nắp thì người đứng đó cầm sẵn cái vá xới, tới lúc
        # mở nắp ra đảo mới lòi vá ra tay
        var paddle = ComTamChars.attach_paddle(crig) if not pot_here.is_empty() else null
        _actors.append({"node": ch, "rig": crig, "mode": "cook", "station": sid_here,
            "knife": knife, "paddle": paddle, "floor": index, "phase": randf() * 3.0})

    # quản lý khu: thuê rồi thì có người đứng trông, chỉ đứng im nhìn quán
    _build_manager(node, fid, index)

    # Người phục vụ: mở khu là có sẵn một người, thuê thêm được đúng một người
    # nữa — `staff_count` đã gộp cả hai nên có mấy người thì dựng bấy nhiêu. Ai
    # cũng tự lấy đĩa ở quầy, tự bưng ra bàn, tự quay về chỗ mình, nên đông người
    # thì nhiều khay chạy song song, cơm ra bàn mau hơn.
    var accent: Color = FLOOR_ACCENTS[index % FLOOR_ACCENTS.size()]
    var crew := GameManager.staff_count(fid, "waiter")
    for i in crew:
        var sv := ComTamChars.build(str(SERVER_KEYS[i % SERVER_KEYS.size()]))
        # dàn hàng ngang trước quầy, mỗi người một chỗ đứng riêng cho khỏi chồng nhau
        var pickup := Vector3((float(i) - float(crew - 1) * 0.5) * 0.9, 0, -hd + 2.15)
        sv.position = pickup
        node.add_child(sv)
        var rig := ComTamChars.rig_of(sv)
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
        # mỗi người một vòng chờ món trên đầu, ai cầm đĩa trước thì vòng người đó tắt
        _actors.append({"node": sv, "rig": rig, "mode": "server", "floor": index,
            "state": "wait", "t": -float(i) * 0.9, "dish": dish, "tray": tray,
            "pickup": pickup, "target": pickup, "y": 0.0, "phase": randf() * 3.0,
            "meter": _make_meter(sv, 2.25, 0.27, C_OK, accent)})

    # Shipper: mở khu cũng có sẵn một người, thuê thêm được một người nữa. Ai
    # cũng ôm thùng cơm đứng chờ ở quầy rồi phóng ra đường giao, giao xong lại
    # lộn về lấy chuyến khác.
    for i in GameManager.staff_count(fid, "shipper"):
        var sh := ComTamChars.build("driver")
        var post := Vector3(2.5 - float(i) * 0.62, 0, -hd + 1.55)
        sh.position = post
        node.add_child(sh)
        _actors.append({"node": sh, "rig": ComTamChars.rig_of(sh), "mode": "shipper",
            "floor": index, "state": "load", "t": -float(i) * 1.6, "post": post,
            "path": [], "y": 0.0, "slot": i, "phase": randf() * 3.0})

    # khách: tầng trệt thì đi dọc vỉa hè tới, tầng trên vào từ cầu thang
    var seats_here := 0
    for s in _seats:
        if int(s["floor"]) == index:
            seats_here += 1
    # Càng nhiều chỗ ngồi thì quán càng đông: khách bám theo số ghế thật của tầng
    # (kể cả bàn người chơi mới kê), chặn trên 12 người/tầng cho máy yếu thở được.
    var count := clampi(int(round(float(seats_here) * 0.7)), 4, MAX_CUSTOMERS)
    count = mini(count, maxi(4, int(GameManager.floor_arrival_rate(fid))))
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
    _update_decor(delta)
    _update_actors(delta)
    _update_floats(delta)


func _update_stations() -> void:
    var dt := get_process_delta_time()
    for sid in _station_nodes:
        _update_station(_station_nodes[sid], dt)


## Một cái quầy của một khu: nhún khi được thúc, ẩn hiện đồ trên thớt,
## bày lại số miếng sườn trong lò giữ nhiệt và cho khói bay lên.
func _update_station(st: Dictionary, dt: float) -> void:
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

    # Kho tách theo khu rồi, nên đồ bày trên quầy phải hỏi kho của đúng khu đó.
    var st_fid := str(GameManager.FLOORS[int(st.get("floor", 0))]["id"])

    # bàn bì & chả: hết thứ nào thì thứ đó biến khỏi thớt
    var chop: Dictionary = st.get("chop", {})
    if not chop.is_empty():
        (chop["bi"] as Node3D).visible = GameManager.stock_at(st_fid, "bi") >= 1.0
        (chop["cha"] as Node3D).visible = GameManager.stock_at(st_fid, "cha") >= 1.0

    # lò giữ nhiệt: số miếng sườn bày trong lò đúng bằng số miếng đang có,
    # lò rộng hơn sức bày thì mỗi miếng đại diện cho vài miếng trong kho
    var warm: Array = st.get("warm", [])
    if not warm.is_empty():
        var cap := GameManager.warmer_capacity()
        var shown := mini(cap, WARM_SLOTS)
        var have := int(GameManager.stock_at(st_fid, "grilled"))
        var lit := 0
        if cap > 0:
            lit = int(ceil(float(have) * float(shown) / float(cap)))
        lit = clampi(lit, 0, warm.size())
        for i in warm.size():
            var slab: MeshInstance3D = warm[i]
            var want := i < lit
            if slab.visible != want:
                slab.visible = want

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


## Đoạn thẳng p->q có xiên qua hình chữ nhật (tâm c, nửa chiều h) không? Trả về
## quãng đường tới chỗ đụng (0 = đụng ngay dưới chân, 1 = tận đích), -1 là không
## đụng. Cắt lát theo từng trục, kiểu quen thuộc của mọi phép cắt hình hộp.
func _seg_hits_box(p: Vector2, q: Vector2, c: Vector2, h: Vector2) -> float:
    var d := q - p
    var t0 := 0.0
    var t1 := 1.0
    for axis in 2:
        var dv: float = d.x if axis == 0 else d.y
        var pv: float = p.x if axis == 0 else p.y
        var cv: float = c.x if axis == 0 else c.y
        var hv: float = h.x if axis == 0 else h.y
        if absf(dv) < 0.00001:
            if absf(pv - cv) > hv:
                return -1.0
            continue
        var ta := (cv - hv - pv) / dv
        var tb := (cv + hv - pv) / dv
        if ta > tb:
            var sw := ta
            ta = tb
            tb = sw
        t0 = maxf(t0, ta)
        t1 = minf(t1, tb)
        if t0 > t1:
            return -1.0
    return t0


## Trước mặt còn quang không: bắn một tia dài `reach` theo hướng `dir`, đụng khối
## nào trong danh sách là tắc.
func _way_clear(list: Array, p: Vector2, dir: Vector2, reach: float) -> bool:
    var q := p + dir * reach
    for s in list:
        var sd: Dictionary = s
        var c: Vector2 = sd["c"]
        var h: Vector2 = sd["h"]
        if _seg_hits_box(p, q, c, h) >= 0.0:
            return false
    return true


## Chỗ cần NGẮM cho bước tới.
##
## Cứ nhắm thẳng đích; trước mặt vướng thì QUẠT thử sang hai bên từng nấc 22 độ,
## lấy hướng lệch ít nhất mà trước mặt còn quang. Đã lệch bên nào thì bước sau
## ưu tiên bên đó, tới chừng nào đi thẳng lại được mới thôi — không nhớ bên thì
## tới mép bàn là người lắc qua lắc lại rồi đứng luôn ở đó.
##
## Quạt cả nắm hướng như vầy hơn hẳn cách ngắm vào góc từng cái bàn: chỗ nào đồ
## đạc xúm lại một cụm (quầy + hồ cá + chậu cây + bàn) thì ngắm vào góc cái này
## lại chui vào lòng cái kia, còn tia quạt thì soi một lượt hết cả cụm.
func _steer(a: Dictionary, node: Node3D, target: Vector3) -> Vector3:
    var all: Array = _solids.get(int(a.get("floor", 0)), [])
    if all.is_empty():
        return target
    var pad := Vector2(BODY_R, BODY_R) * 1.05
    var p := Vector2(node.position.x, node.position.z)
    var d := Vector2(target.x, target.z)
    # Đang đứng lọt trong lòng khối nào thì ngắm từ chỗ ĐÃ RA NGOÀI khối đó — chứ
    # đứng trong lòng cái quầy mà đòi vòng qua nó thì ngắm ra sau lưng quầy, có
    # khi ngắm thẳng vào tường. Chỗ chờ hàng của shipper nằm lọt trong lòng quầy
    # bếp nên lần nào cũng dính. Chỉ dời điểm ngắm thôi, người vẫn đứng nguyên.
    for s in all:
        var si: Dictionary = s
        var ci: Vector2 = si["c"]
        var hi: Vector2 = (si["h"] as Vector2) + pad
        var ex := hi.x - absf(p.x - ci.x)
        var ez := hi.y - absf(p.y - ci.y)
        if ex <= 0.0 or ez <= 0.0:
            continue
        if ex < ez:
            p.x = ci.x + (hi.x + 0.02) * (1.0 if p.x >= ci.x else -1.0)
        else:
            p.y = ci.y + (hi.y + 0.02) * (1.0 if p.y >= ci.y else -1.0)

    var to := d - p
    var dist := to.length()
    if dist < 0.01:
        return target
    var dir := to / dist
    var reach := minf(0.95, dist)

    # chỉ mấy khối quanh đây mới đáng soi, khối tận đầu kia khu thì bỏ
    var near_list: Array = []
    for s in all:
        var sd: Dictionary = s
        var c: Vector2 = sd["c"]
        var h: Vector2 = (sd["h"] as Vector2) + pad
        if absf(p.x - c.x) > h.x + reach or absf(p.y - c.y) > h.y + reach:
            continue
        # Đích nằm sát khối (cái ghế kê quanh bàn) thì kệ khối đó, cứ đi vào — đo
        # trên khối THẬT chứ không đo trên khối đã nới thêm bề ngang người, y như
        # `_avoid_solids`. Đo trên khối đã nới thì cái ghế ngoài vỉa hè hụt đúng
        # 5 milimét, thế là khách lượn quanh bàn cả buổi không ngồi xuống được.
        var hr: Vector2 = sd["h"]
        var near := Vector2(clampf(d.x, c.x - hr.x, c.x + hr.x), clampf(d.y, c.y - hr.y, c.y + hr.y))
        if near.distance_to(d) < BODY_R + 0.08:
            continue
        near_list.append({"c": c, "h": h})

    if near_list.is_empty() or _way_clear(near_list, p, dir, reach):
        # qua hẳn cái bàn đó rồi: quên bên vừa lệch đi, gặp cái sau tính lại
        a.erase("_turn")
        return target

    # Quạt hai vòng: vòng đầu nhìn xa cho biết đường, không ra hướng nào thì vòng
    # sau nhìn gần lại. Chỗ hẹp mà cứ đòi nhìn xa gần một mét thì hướng nào cũng
    # thấy vướng — như cái khe chín tấc giữa bàn phải với hồ cá, đủ rộng để lách
    # qua mà nhìn xa thì tưởng bít.
    # Thứ tự thử: ĐANG lệch bên nào thì vét hết bên đó trước, bên đó bít hẳn mới
    # chịu đổi bên. Chưa lệch bên nào thì mới so bên nào lệch ít hơn.
    #
    # Chỗ này quan trọng: cứ mỗi khung hình lại bốc theo góc lệch nhỏ nhất thì
    # nhích sang trái một cái, bên phải liền hoá ra gần hơn, nhích lại sang phải
    # — người rung tại chỗ suốt buổi. Bám một bên cho tới khi qua hẳn mới là đi.
    var turn: float = float(a.get("_turn", 0.0))
    var order: Array = []
    if turn != 0.0:
        for i in range(1, 8):
            order.append(Vector2(float(i), turn))
        for i in range(1, 8):
            order.append(Vector2(float(i), -turn))
    else:
        for i in range(1, 8):
            order.append(Vector2(float(i), 1.0))
            order.append(Vector2(float(i), -1.0))
    for far in [reach, reach * 0.45]:
        var r: float = far
        for o in order:
            var oc: Vector2 = o
            var nd := dir.rotated(oc.x * PI / 8.0 * oc.y)
            if _way_clear(near_list, p, nd, r):
                a["_turn"] = oc.y
                return Vector3(p.x + nd.x * r, target.y, p.y + nd.y * r)
    # bốn phía đều bít thì thôi, cứ nhắm thẳng mà đi xuyên qua — thà quẹt qua cái
    # bàn một cái còn hơn đứng chết dí ở đó
    return target


## Nhích một bước về phía `target`, có né đồ đạc nếu truyền vào `a` (người này
## thuộc khu nào thì né đồ khu đó). Trả về true khi đã tới nơi.
##
## KHÔNG có va chạm cứng: không ai bị đẩy ra, không ai bị chặn đứng. Người chỉ
## LÁI để tránh bàn ghế (`_steer`), lỡ có quẹt vào mép bàn một cái thì thôi, chứ
## không bao giờ bị kẹt cứng — đứng chết một chỗ khó coi hơn nhiều so với cạ vai
## vào cái bàn.
func _step_toward(node: Node3D, target: Vector3, speed: float, delta: float,
        a: Dictionary = {}) -> bool:
    var d := Vector2(target.x - node.position.x, target.z - node.position.z)
    var dist := d.length()
    if dist < 0.09:
        return true
    var from := Vector2(node.position.x, node.position.z)
    var step := speed * delta
    # đi thẳng tới đích, trừ khi giữa đường có cái bàn: lúc đó ngắm vòng qua góc
    var aim := d
    if not a.is_empty():
        var look := _steer(a, node, target)
        aim = Vector2(look.x - from.x, look.z - from.y)
        if aim.length() < 0.001:
            aim = d
    aim = aim.normalized()
    node.position.x += aim.x * step
    node.position.z += aim.y * step
    # quay mặt theo hướng ĐI THẬT, để lúc trượt dọc mép bàn thì người cũng xoay
    # theo mép bàn chứ không đi ngang như cua
    var mv := Vector2(node.position.x, node.position.z) - from
    if mv.length() > 0.0008:
        node.rotation.y = atan2(mv.x, mv.y)
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
                _update_cook(a, rig, t)
            "boss":
                ComTamChars.idle(rig, t)
            "shipper":
                _update_shipper(a, node, rig, t, delta)
            "server":
                _update_server(a, node, rig, t, delta)
            "dog":
                _update_dog(a, node, rig, t, delta)
            "customer":
                _update_customer(a, node, rig, t, delta)
            "griller":
                _update_griller(a, node, rig, t, delta)


## Cái nồi đậy nắp của một quầy, rỗng nếu quầy đó chẳng có nồi nào.
func _pot_of(sid: String) -> Dictionary:
    if not _station_nodes.has(sid):
        return {}
    var st: Dictionary = _station_nodes[sid]
    return st.get("pot", {})


## Nắp nồi mở NGANG, đúng kiểu bưng nắp ra rồi dựng nghiêng bên cạnh nồi:
## k = 0 là đậy kín, k = 1 là nắp đã nằm hẳn bên trái, tựa vào hông nồi.
##
## Đường đi ba nhịp cho khỏi cà vào vành: nhấc bổng lên trước, rồi mới đưa
## ngang sang trái, vừa đi vừa nghiêng và hạ xuống mặt quầy. Gạt sang trái để
## chừa bên phải cho tay cầm vá đảo.
func _set_pot_lid(pot: Dictionary, k: float) -> void:
    if pot.is_empty():
        return
    var lid = pot.get("lid")
    if lid == null or not is_instance_valid(lid as Node):
        return
    var node := lid as Node3D
    var e := clampf(k, 0.0, 1.0)
    var up := sin(clampf(e / 0.35, 0.0, 1.0) * PI * 0.5)
    var away := clampf((e - 0.25) / 0.75, 0.0, 1.0)
    away = away * away * (3.0 - 2.0 * away)
    node.position.x = float(pot["x0"]) - float(pot["slide"]) * away
    node.position.y = float(pot["y0"]) + float(pot["lift"]) * up \
        - float(pot["drop"]) * away
    node.position.z = float(pot["z0"])
    node.rotation.x = 0.0
    node.rotation.z = float(pot["tilt"]) * away


## Người đứng bếp, ba kiểu đứng tuỳ quầy:
##
## - Bàn bì & chả thì đứng THÁI: dao nhấc lên bổ xuống đều đều.
## - Quầy có nồi đậy nắp (nồi cơm tấm vỉa hè, nồi chè khu máy lạnh) thì đứng
##   CANH NỒI: canh một hồi rồi mở nắp ra, cầm vá đảo một vòng cho cơm tơi, xong
##   đậy nắp lại — cứ thế lặp lại mỗi POT_CYCLE giây.
## - Còn lại thì làm tay chân lặt vặt như cũ.
##
## Còn nguyên liệu thì tay mới làm. Quầy nào hết hàng là người đứng quầy đó bỏ
## dao bỏ vá xuống, đậy nắp nồi lại, đứng thở — nhìn vào là biết quầy đang kẹt.
func _update_cook(a: Dictionary, rig: Dictionary, t: float) -> void:
    var sid := str(a.get("station", ""))
    var knife = a.get("knife")
    var paddle = a.get("paddle")
    var pot := _pot_of(sid)
    var busy := sid != "" and GameManager.is_station_open(sid) \
        and GameManager.has_ingredients(sid, 1)
    var stirring := false

    if not busy:
        ComTamChars.idle(rig, t)
        _set_pot_lid(pot, 0.0)
    elif GameManager.station_base(sid) == "prep":
        ComTamChars.chop(rig, t)
    elif not pot.is_empty():
        # mỗi người lệch pha một chút cho khỏi cả quán cùng mở nắp một lượt
        var k := fmod(t + float(a["phase"]) * 4.6, POT_CYCLE)
        var lift := 0.0
        if k < POT_WATCH:
            ComTamChars.cook(rig, t)
        elif k < POT_WATCH + POT_SWING:
            lift = (k - POT_WATCH) / POT_SWING
            ComTamChars.lift_lid(rig, lift)
        elif k < POT_CYCLE - POT_SWING:
            lift = 1.0
            stirring = true
            ComTamChars.stir_pot(rig, t)
        else:
            lift = (POT_CYCLE - k) / POT_SWING
            ComTamChars.lift_lid(rig, lift)
        _set_pot_lid(pot, lift)
    else:
        ComTamChars.cook(rig, t)

    if knife != null and is_instance_valid(knife as Node):
        (knife as Node3D).visible = busy
    # cái vá chỉ lòi ra đúng lúc đang đảo nồi, còn lại thì cất đi
    if paddle != null and is_instance_valid(paddle as Node):
        (paddle as Node3D).visible = stirring


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
            _set_meter(a.get("meter"), float(a["t"]) / wait_for, true)
            if float(a["t"]) < wait_for:
                return
            # Có đĩa rồi: tìm người ĐANG NGỒI BÀN chờ ăn, ai chờ lâu nhất đi trước.
            # Không có ai chờ thì cứ ôm đĩa đứng đó, không bưng ra bàn trống nữa.
            var guest = _pick_hungry(int(a["floor"]))
            if guest == null:
                a["t"] = wait_for
                return
            # Tới lúc này mới GỌI MÓN: trừ đúng số nguyên phần cơm, phần bì chả,
            # ly trà đá, miếng sườn trong kho. Bếp chưa ghép nổi suất nào thì
            # đứng chờ tiếp chứ không bưng khay không ra bàn.
            var order := GameManager.take_order(fid, fid)
            if order.is_empty():
                a["t"] = wait_for
                return
            a["order"] = order
            var g: Dictionary = guest
            g["booked"] = true
            a["guest"] = g
            a["target"] = _guest_spot(g)
            a["state"] = "deliver"
            a["t"] = 0.0
            # bưng được đĩa rồi thì tắt vòng, đi giao đã
            _set_meter(a.get("meter"), 0.0, false)
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
            if _step_toward(node, stop, 2.05, delta, a):
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
                _serve_guest(a["guest"], str(a.get("order", "")))
                a["guest"] = null
                a["order"] = ""
            if float(a["t"]) > 1.1:
                a["state"] = "return"
                a["t"] = 0.0
        "return":
            rig["torso"].rotation.x = 0.0
            a["y"] = 0.0
            if _step_toward(node, a["pickup"], 2.25, delta, a):
                a["state"] = "wait"
                a["t"] = 0.0
            else:
                ComTamChars.walk(rig, t, 8.0)

    dish.visible = carrying
    node.position.y = move_toward(node.position.y, float(a.get("y", 0.0)), delta * 1.8)
    _carry_pose(rig)
    _level_tray(a["tray"])


## Shipper: đứng ở quầy chờ đóng hộp -> phóng ra đường giao -> khuất mắt một lát
## -> quay đầu vô quán lấy chuyến kế. Cứ thế cả ngày, nên nhìn vào quán lúc nào
## cũng có người ra người vào. Shipper không đụng gì tới khách ngồi bàn: khách
## của họ ở ngoài đường, mình chỉ thấy phần chạy đi chạy về.
func _update_shipper(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    a["t"] = float(a["t"]) + delta
    var floor_i := int(a["floor"])
    var slot := int(a["slot"])
    if float(a["t"]) < 0.0:
        ComTamChars.idle(rig, t)
        return
    node.position.y = move_toward(node.position.y, float(a.get("y", 0.0)), delta * 1.8)

    match str(a["state"]):
        "load":
            # đứng quay vào quầy chờ người ta xếp hộp lên thùng
            ComTamChars.idle(rig, t)
            node.rotation.y = PI
            var fid := str(GameManager.FLOORS[floor_i]["id"])
            if float(a["t"]) > clampf(GameManager.service_time(fid) * 1.6, 2.5, 8.0):
                # Chỉ chạy khi trong tay đã có hộp cơm thật: bếp hết hàng thì
                # shipper đứng đợi ở quầy chứ không phóng đi tay không.
                var order := GameManager.take_order("ship", fid)
                if order.is_empty():
                    a["t"] = 0.0
                    return
                a["order"] = order
                a["path"] = _route(node.position, _exit_point(floor_i, slot + 1), true, floor_i)
                a["state"] = "go"
                a["t"] = 0.0
        "go":
            if _follow_path(a, node, rig, t, delta, 1.75):
                # ra khỏi khung hình rồi thì tắt đi cho đỡ nặng máy
                node.visible = false
                a["state"] = "away"
                a["t"] = 0.0
                a["rest"] = 4.0 + randf() * 2.5      # quãng đi giao, mỗi chuyến một khác
        "away":
            if float(a["t"]) > float(a.get("rest", 5.0)):
                var sp: Vector3 = _spawn_point(floor_i, slot)
                node.position = sp
                node.visible = true
                a["y"] = sp.y
                a["path"] = _route(sp, Vector3(a["post"]), false, floor_i)
                a["state"] = "back"
                a["t"] = 0.0
        "back":
            if _follow_path(a, node, rig, t, delta, 1.75):
                # về tới quầy, giao xong chuyến đó: giờ mới có tiền hộp cơm
                var pay := GameManager.sell_dish(str(a.get("order", "")))
                a["order"] = ""
                if pay > 0:
                    spawn_float("%s ₫" % UIKit.money(pay),
                        node.global_position + Vector3(0, 1.9, 0), C_GOLD)
                a["state"] = "load"
                a["t"] = 0.0


## Một chỗ bất kỳ trong lòng quán để con chó lững thững đi tới.
func _dog_target(floor_i: int) -> Vector3:
    for _try in 8:
        # ba lần thì một lần nó lượn ra vỉa hè: chó cỏ giữ quán có bao giờ chịu
        # nằm yên trong nhà đâu
        var out := randf() < 0.38
        var r: Rect2 = _dog_out_bounds() if out else _dog_bounds()
        var p := Vector3(randf_range(r.position.x, r.end.x), OUT_Y if out else 0.0,
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


## Khoảnh vỉa hè trước quán mà con chó được phép lượn ra: chừa mép bó vỉa để nó
## đừng đứng dưới lòng đường, và chừa chỗ cái lò than cho khỏi lửa.
func _dog_out_bounds() -> Rect2:
    var hw := OUT_HW - 0.7
    var z0 := OUT_Z0 + 0.3
    var z1 := OUT_Z1 - 0.6
    return Rect2(-hw, z0, hw * 2.0, z1 - z0)


## Chó: đi tới một chỗ, đứng hít hà một lát, rồi lại chọn chỗ khác.
func _update_dog(a: Dictionary, node: Node3D, rig: Dictionary, t: float, delta: float) -> void:
    a["t"] = float(a["t"]) + delta
    # Con chó được đi cả trong quán lẫn ngoài vỉa hè, nhưng không được ra khỏi
    # hai khoảnh đó: đang đứng bên nào thì chốt theo khoảnh bên ấy, nên nó không
    # xuyên tường mà cũng không lang thang xuống lòng đường.
    var hd := ROOM_D * 0.5
    var outside := node.position.z > hd - 0.3
    var pen: Rect2 = _dog_out_bounds().grow(0.2) if outside else _dog_bounds().grow(0.15)
    if outside:
        # nới mép gần vào tới bậc thềm mà vẫn giữ nguyên mép xa, không thì cái
        # khoảnh bị co lại và con chó bị chặn ngay giữa vỉa hè
        var far := pen.end.y
        pen.position.y = minf(pen.position.y, hd - 0.35)
        pen.size.y = far - pen.position.y
    else:
        pen.size.y = maxf(pen.size.y, (hd - 0.25) - pen.position.y)
    node.position.x = clampf(node.position.x, pen.position.x, pen.end.x)
    node.position.z = clampf(node.position.z, pen.position.y, pen.end.y)
    # bậc thềm xuống vỉa hè: hạ dần chứ không nhảy cóc
    var want_y: float = OUT_Y if node.position.z > hd + 0.15 else 0.0
    node.position.y = move_toward(node.position.y, want_y, delta * 1.6)
    match str(a["state"]):
        "walk":
            ComTamChars.dog_walk(rig, t, 7.0)
            if _step_toward(node, a["target"], 0.85, delta, a) or float(a["t"]) > 12.0:
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
func _serve_guest(guest, order: String = "") -> void:
    if not _guest_waiting(guest):
        return
    var g: Dictionary = guest
    # nhớ luôn khách này ăn món gì: ăn xong mới tính tiền đúng món đó
    g["order"] = order
    g["state"] = "eat"
    g["t"] = 0.0
    g["booked"] = false
    _show_plate(g, true)
    _set_meter(g.get("meter"), 0.0, false)


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
    var done := _step_toward(node, tgt, speed * (0.72 if climbing else 1.0), delta, a)
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
                # Ăn xong mới trả tiền — và trả trọn số nguyên đồng đúng giá món
                # đã gọi. Quán vừa được tiền vừa được tiếng thơm, nên chữ bay lên
                # gộp cả hai: "45.000 ₫ + 2 uy tín".
                var pay := GameManager.sell_dish(str(a.get("order", "")))
                var gained := GameManager.customer_finished()
                a["order"] = ""
                var toast := "+%d uy tín" % gained
                if pay > 0:
                    toast = "%s ₫ + %d uy tín" % [UIKit.money(pay), gained]
                spawn_float(toast,
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
