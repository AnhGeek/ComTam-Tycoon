class_name ComTamChars
## Người low-poly có xương, dựng bằng code — tông màu tươi kiểu game idle hiện đại.
##
## Dùng:  var c := ComTamChars.build("hai");  add_child(c)
##        ComTamChars.walk(ComTamChars.rig_of(c), t)  /  idle  /  cook  /  sit
##
## Quy ước xoay (Godot, trục X): rotation.x DƯƠNG = xoay ra sau, ÂM = ra trước.
## Vì vậy đầu gối phải xoay DƯƠNG (gập về sau như người thật), còn khuỷu tay
## xoay ÂM (gập ra trước). Đảo dấu là chân sẽ gập ngược như chân chim.

# ---------- Màu da & tóc ----------
const SKIN_A := Color8(0xf2, 0xc6, 0xa0)
const SKIN_B := Color8(0xe0, 0xac, 0x82)
const SKIN_C := Color8(0xc9, 0x8e, 0x66)
const SKIN_D := Color8(0xf7, 0xd7, 0xb8)

const HAIR_BLACK := Color8(0x24, 0x22, 0x2b)
const HAIR_DARK := Color8(0x3b, 0x2c, 0x2a)
const HAIR_GREY := Color8(0xa8, 0xae, 0xb8)

# ---------- Màu quần áo: tươi, no màu, kiểu game mobile hiện đại ----------
const C_TEAL := Color8(0x14, 0xc4, 0xa9)
const C_MINT := Color8(0x7d, 0xe0, 0xc0)
const C_CORAL := Color8(0xff, 0x6f, 0x5c)
const C_AMBER := Color8(0xff, 0xb3, 0x2b)
const C_VIOLET := Color8(0x7c, 0x5c, 0xff)
const C_SKY := Color8(0x4c, 0x9a, 0xff)
const C_NAVY := Color8(0x2e, 0x3d, 0x6b)
const C_PINK := Color8(0xff, 0x7f, 0xb0)
const C_CREAM := Color8(0xf7, 0xf1, 0xe3)
const C_SLATE := Color8(0x5a, 0x6b, 0x8c)
const C_LIME := Color8(0x9a, 0xd8, 0x3a)
const C_DENIM := Color8(0x3f, 0x62, 0x88)

const SHOE_COL := Color8(0x3a, 0x33, 0x42)
const EYE_COL := Color8(0x2a, 0x24, 0x33)
const CHEF_WHITE := Color8(0xfa, 0xfb, 0xfc)
const STRAW := Color8(0xf0, 0xd7, 0x9b)
const HELMET_COL := Color8(0x33, 0x37, 0x44)

const PRESETS := {
	"hai": {"name": "Chú Hải", "role": "Thợ nướng", "skin": SKIN_C, "hair": HAIR_GREY, "top": CHEF_WHITE,
		"bottom": C_NAVY, "apron": C_CORAL, "cap": "chefcap", "build": "stocky", "mustache": true},
	"bay": {"name": "Cô Bảy", "role": "Bếp phụ", "skin": SKIN_B, "hair": HAIR_BLACK, "top": C_TEAL,
		"bottom": C_NAVY, "apron": C_CREAM, "hair_style": "bun", "build": "slim"},
	"minh": {"name": "Minh", "role": "Thu ngân", "skin": SKIN_A, "hair": HAIR_BLACK, "top": C_VIOLET,
		"bottom": C_NAVY, "cap": "cap", "build": "slim"},
	"linh": {"name": "Linh", "role": "Phục vụ", "skin": SKIN_D, "hair": HAIR_DARK, "top": C_CORAL,
		"bottom": C_NAVY, "apron": C_CREAM, "hair_style": "ponytail", "build": "slim"},
	"tu": {"name": "Bà Tư", "role": "Quản lý", "skin": SKIN_B, "hair": HAIR_GREY, "top": C_AMBER,
		"bottom": C_SLATE, "hair_style": "bun", "build": "stocky"},
	"office": {"name": "Khách văn phòng", "role": "Khách", "skin": SKIN_A, "hair": HAIR_BLACK, "top": C_SKY,
		"bottom": C_NAVY, "build": "slim", "bag": "satchel"},
	"auntie": {"name": "Cô Nhàn", "role": "Khách quen", "skin": SKIN_C, "hair": HAIR_GREY, "top": C_PINK,
		"bottom": C_SLATE, "hair_style": "bun", "hat": "conical", "build": "stocky"},
	"student": {"name": "Học sinh", "role": "Khách", "skin": SKIN_D, "hair": HAIR_BLACK, "top": C_LIME,
		"bottom": C_DENIM, "bag": "backpack", "build": "child"},
	"tourist": {"name": "Khách du lịch", "role": "Khách", "skin": SKIN_D, "hair": HAIR_DARK, "top": C_MINT,
		"bottom": C_CREAM, "hat": "bucket", "bag": "satchel", "build": "tall"},
	"xeom": {"name": "Chú xe ôm", "role": "Khách", "skin": SKIN_C, "hair": HAIR_DARK, "top": C_AMBER,
		"bottom": C_NAVY, "hat": "helmet", "build": "stocky"},
	"driver": {"name": "Anh giao hàng", "role": "Khách", "skin": SKIN_B, "hair": HAIR_BLACK, "top": C_TEAL,
		"bottom": C_NAVY, "hat": "helmet", "bag": "foodbox", "build": "slim"},
	"worker": {"name": "Khách lao động", "role": "Khách", "skin": SKIN_C, "hair": HAIR_BLACK, "top": C_VIOLET,
		"bottom": C_DENIM, "build": "stocky"},
}

const BUILDS := {
	"slim": {"h": 1.0, "w": 0.94, "belly": 0.0},
	"stocky": {"h": 0.97, "w": 1.12, "belly": 0.05},
	"tall": {"h": 1.07, "w": 0.96, "belly": 0.0},
	"child": {"h": 0.86, "w": 0.9, "belly": 0.0},
}

const CUSTOMER_KEYS := ["office", "auntie", "student", "tourist", "xeom", "driver", "worker"]

# ---------- Thông số dáng đi ----------
const HIP_SWING := 0.62        # biên độ đưa đùi trước/sau
const KNEE_SWING := 1.02       # độ gập gối lúc chân đang bước tới
const KNEE_STANCE := 0.14      # gập nhẹ lúc chân trụ, cho đỡ cứng
const ANKLE_LEVEL := 0.82      # mức bù cổ chân để bàn chân không chúi

# ---------- Ngồi ghế nhựa thấp kiểu quán vỉa hè ----------
## Ghế nhựa cao khoảng 26cm: hông gần sát đất nên đầu gối phải vổng LÊN CAO
## hơn hông, cẳng chân gần như dựng đứng, người chồm ra trước về phía bàn.
## Số liệu suy từ chiều dài xương: đùi 0.42, cẳng chân 0.40, hông đứng ở 0.82.
## Nhìn chúc từ trên xuống cả dãy nhà thì người cỡ thật trông to lộc ngộc so với
## gian phòng. Thu nhỏ nguyên bộ xương (giữ nguyên chi tiết, chỉ nhỏ đi) cho ra
## đúng tỉ lệ nhân vật tí hon kiểu idle tycoon.
const CHAR_SCALE := 0.72

const STOOL_SEAT := 0.26       # mặt ghế nhựa cách đất bao nhiêu mét
const CHAIR_SEAT := 0.48       # mặt ghế thường (dùng cho sit())
const STOOL_THIGH := -1.85     # đùi hất lên trước, quá phương ngang
const STOOL_SHIN := 0.66       # cẳng chân hơi ngả về sau, bàn chân nằm dưới gối
const STOOL_KNEE_OUT := 0.19   # hai gối dang ra hai bên

static var _mat_cache: Dictionary = {}


# ---------- Tài nguyên dùng chung ----------
static func mat(c: Color, rough: float = 0.72) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(false), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	_mat_cache[key] = m
	return m


static func _mi(mesh: Mesh, material: Material, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = Vector3(x, y, z)
	return m


static func _cyl(rt: float, rb: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _sph(r: float, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 7
	s.is_hemisphere = hemi
	return s


static func _bx(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


# ---------- Dựng nhân vật ----------
## Trả về Node3D; thông tin xương nằm trong meta "rig".
static func build(key: String) -> Node3D:
	var p: Dictionary = (PRESETS.get(key, PRESETS["office"]) as Dictionary).duplicate()
	var b: Dictionary = BUILDS.get(p.get("build", "slim"), BUILDS["slim"])
	var bh := float(b["h"])
	var bw := float(b["w"])
	var belly := float(b["belly"])

	var skin := mat(p["skin"], 0.68)
	var hair := mat(p["hair"], 0.8)
	var top := mat(p["top"])
	var bottom := mat(p["bottom"], 0.78)

	var group := Node3D.new()
	group.name = "Char" + key.capitalize()
	group.scale = Vector3.ONE * CHAR_SCALE
	var root := Node3D.new()
	root.name = "Root"
	group.add_child(root)

	# ---- chân: hông -> gối -> cổ chân (có cổ chân thì bàn chân mới không chúi) ----
	var hip_y := 0.82 * bh
	var legs: Array = []
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.115 * bw, hip_y, 0)
		hip.add_child(_mi(_cyl(0.105 * bw, 0.092 * bw, 0.42 * bh), bottom, 0, -0.21 * bh, 0))

		var knee := Node3D.new()
		knee.position = Vector3(0, -0.42 * bh, 0)
		knee.add_child(_mi(_cyl(0.088 * bw, 0.072 * bw, 0.4 * bh), bottom, 0, -0.2 * bh, 0))

		var ankle := Node3D.new()
		ankle.position = Vector3(0, -0.4 * bh, 0)
		ankle.add_child(_mi(_bx(0.14 * bw, 0.075, 0.27), mat(SHOE_COL, 0.6), 0, -0.02, 0.055))
		knee.add_child(ankle)

		hip.add_child(knee)
		root.add_child(hip)
		legs.append({"hip": hip, "knee": knee, "ankle": ankle})

	# ---- thân ----
	var torso := Node3D.new()
	torso.position = Vector3(0, hip_y, 0)
	root.add_child(torso)
	torso.add_child(_mi(_cyl(0.19 * bw, 0.17 * bw, 0.16 * bh), bottom, 0, 0.06 * bh, 0))
	var chest := _mi(_cyl(0.215 * bw, 0.185 * bw + belly, 0.44 * bh), top, 0, 0.36 * bh, 0)
	chest.scale = Vector3(1, 1, 0.78)
	torso.add_child(chest)
	var shoulders := _mi(_cyl(0.075, 0.075, 0.42 * bw), top, 0, 0.55 * bh, 0)
	shoulders.rotation.z = PI / 2.0
	torso.add_child(shoulders)
	torso.add_child(_mi(_cyl(0.055, 0.06, 0.09), skin, 0, 0.62 * bh, 0))

	if p.has("apron"):
		var ap_mat := mat(p["apron"], 0.85)
		torso.add_child(_mi(_bx(0.34 * bw, 0.5 * bh, 0.03), ap_mat, 0, 0.3 * bh, 0.155 * bw))
		for sx2 in [-0.09, 0.09]:
			var strap := _mi(_cyl(0.012, 0.012, 0.3, 6), ap_mat, sx2, 0.53 * bh, 0.12)
			strap.rotation.x = 0.1
			torso.add_child(strap)

	# ---- đầu ----
	var head := Node3D.new()
	head.position = Vector3(0, 0.7 * bh, 0)
	torso.add_child(head)
	var skull := _mi(_sph(0.125), skin)
	skull.scale = Vector3(1, 1.12, 0.95)
	head.add_child(skull)
	head.add_child(_mi(_bx(0.16, 0.09, 0.15), skin, 0, -0.1, 0.01))            # hàm
	head.add_child(_mi(_sph(0.028), skin, 0, -0.02, 0.115))                    # mũi
	for ex in [-0.118, 0.118]:
		head.add_child(_mi(_sph(0.028), skin, ex, -0.005, 0))                  # tai
	for ex2 in [-0.05, 0.05]:
		head.add_child(_mi(_sph(0.022), mat(EYE_COL, 0.35), ex2, 0.012, 0.104))# mắt
		head.add_child(_mi(_bx(0.045, 0.012, 0.02), hair, ex2, 0.052, 0.105))  # lông mày
	if bool(p.get("mustache", false)):
		head.add_child(_mi(_bx(0.075, 0.018, 0.02), hair, 0, -0.052, 0.104))

	# tóc
	var cap_hair := _mi(_sph(0.132, true), hair, 0, 0.012, -0.006)
	cap_hair.scale = Vector3(1, 1.06, 0.98)
	head.add_child(cap_hair)
	var style := str(p.get("hair_style", ""))
	if style == "bun":
		head.add_child(_mi(_sph(0.062), hair, 0, 0.075, -0.13))
	elif style == "ponytail":
		var tail := _mi(_cyl(0.045, 0.028, 0.3), hair, 0, -0.09, -0.14)
		tail.rotation.x = -0.35
		head.add_child(tail)

	# mũ nón
	var cap := str(p.get("cap", ""))
	if cap == "chefcap":
		head.add_child(_mi(_cyl(0.135, 0.135, 0.16, 14), mat(CHEF_WHITE, 0.9), 0, 0.15, 0))
		head.add_child(_mi(_sph(0.135, true), mat(CHEF_WHITE, 0.9), 0, 0.23, 0))
	elif cap == "cap":
		head.add_child(_mi(_cyl(0.135, 0.13, 0.08, 14), mat(p["top"], 0.8), 0, 0.115, 0))
		head.add_child(_mi(_bx(0.2, 0.02, 0.13), mat(p["top"], 0.8), 0, 0.085, 0.115))
	var hat := str(p.get("hat", ""))
	if hat == "conical":
		head.add_child(_mi(_cyl(0.02, 0.36, 0.26, 16), mat(STRAW, 0.9), 0, 0.2, 0))
	elif hat == "bucket":
		head.add_child(_mi(_cyl(0.13, 0.135, 0.11, 14), mat(C_MINT, 0.9), 0, 0.13, 0))
		head.add_child(_mi(_cyl(0.24, 0.24, 0.016, 16), mat(C_MINT, 0.9), 0, 0.08, 0))
	elif hat == "helmet":
		head.add_child(_mi(_sph(0.152, true), mat(HELMET_COL, 0.4), 0, 0.02, 0))
		head.add_child(_mi(_bx(0.24, 0.02, 0.1), mat(HELMET_COL, 0.4), 0, 0.0, 0.13))

	# ---- tay ----
	var arms: Array = []
	for sx3 in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx3 * 0.225 * bw, 0.53 * bh, 0)
		sh.add_child(_mi(_cyl(0.062, 0.055, 0.3 * bh), top, 0, -0.15 * bh, 0))
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.3 * bh, 0)
		elbow.add_child(_mi(_cyl(0.052, 0.045, 0.28 * bh), skin, 0, -0.14 * bh, 0))
		var hand := _mi(_sph(0.055), skin, 0, -0.29 * bh, 0)
		elbow.add_child(hand)
		sh.add_child(elbow)
		torso.add_child(sh)
		arms.append({"shoulder": sh, "elbow": elbow, "hand": hand})

	# ---- phụ kiện ----
	var bag := str(p.get("bag", ""))
	if bag == "backpack":
		torso.add_child(_mi(_bx(0.28, 0.34, 0.14), mat(C_CORAL, 0.8), 0, 0.36 * bh, -0.2))
	elif bag == "satchel":
		torso.add_child(_mi(_bx(0.24, 0.2, 0.08), mat(C_NAVY, 0.8), 0.17, 0.2 * bh, 0.06))
		var strap2 := _mi(_cyl(0.014, 0.014, 0.5, 6), mat(C_NAVY, 0.8), 0.02, 0.4 * bh, 0.02)
		strap2.rotation.z = -0.5
		torso.add_child(strap2)
	elif bag == "foodbox":
		torso.add_child(_mi(_bx(0.34, 0.34, 0.3), mat(C_TEAL, 0.8), 0, 0.42 * bh, -0.27))

	group.set_meta("rig", {
		"root": root, "torso": torso, "head": head,
		"legs": legs, "arms": arms, "build": b,
	})
	group.set_meta("preset", p)
	return group


static func rig_of(node: Node3D) -> Dictionary:
	return node.get_meta("rig", {})


static func name_of(node: Node3D) -> String:
	var p: Dictionary = node.get_meta("preset", {})
	return str(p.get("name", "Khách"))


static func role_of(node: Node3D) -> String:
	var p: Dictionary = node.get_meta("preset", {})
	return str(p.get("role", ""))


# ================= Hoạt cảnh =================

## Một chân trong chu kỳ bước. ph = 0 là lúc chân đang đá tới, qua dưới thân.
static func _walk_leg(leg: Dictionary, ph: float) -> void:
	var swing := maxf(0.0, cos(ph))       # pha đưa chân tới
	var stance := maxf(0.0, -cos(ph))     # pha chân trụ
	var hip_rot := -HIP_SWING * sin(ph)   # âm = đùi đưa ra trước
	var knee_rot := KNEE_SWING * swing + KNEE_STANCE * stance   # dương = gập về sau
	leg["hip"].rotation.x = hip_rot
	leg["knee"].rotation.x = knee_rot
	# cổ chân bù lại để bàn chân gần song song mặt đất
	leg["ankle"].rotation.x = -(hip_rot + knee_rot) * ANKLE_LEVEL


static func walk(rig: Dictionary, t: float, speed: float = 8.0) -> void:
	var ph := t * speed
	var legs: Array = rig["legs"]
	_walk_leg(legs[0], ph)
	_walk_leg(legs[1], ph + PI)

	# tay đánh ngược chiều chân
	var arms: Array = rig["arms"]
	var sw := sin(ph)
	arms[0]["shoulder"].rotation.x = 0.45 * sw
	arms[1]["shoulder"].rotation.x = -0.45 * sw
	arms[0]["elbow"].rotation.x = -0.32 - 0.3 * maxf(0.0, -sw)
	arms[1]["elbow"].rotation.x = -0.32 - 0.3 * maxf(0.0, sw)

	# thân nhún lên cao nhất khi chân trụ thẳng (2 lần mỗi chu kỳ)
	rig["root"].position.y = absf(cos(ph)) * 0.032
	rig["root"].rotation.z = sin(ph) * 0.03
	rig["torso"].rotation.y = sw * 0.09
	rig["torso"].rotation.x = 0.04
	rig["head"].rotation.y = -sw * 0.05
	rig["head"].rotation.x = 0.0


## Leo cầu thang: gối nhấc cao hẳn để bước lên mặt bậc, người hơi chồm tới,
## tay đánh gọn và bám hờ như đang vịn tay vịn. `up` = false thì là đi xuống.
static func _climb_leg(leg: Dictionary, ph: float) -> void:
	var lift := maxf(0.0, sin(ph))          # pha nhấc chân đặt lên bậc trên
	var hip_rot := -0.18 - 0.80 * lift
	var knee_rot := 0.24 + 1.05 * lift
	leg["hip"].rotation.x = hip_rot
	leg["knee"].rotation.x = knee_rot
	leg["ankle"].rotation.x = -(hip_rot + knee_rot) * ANKLE_LEVEL


static func climb(rig: Dictionary, t: float, up: bool = true) -> void:
	var ph := t * 5.4
	var legs: Array = rig["legs"]
	_climb_leg(legs[0], ph)
	_climb_leg(legs[1], ph + PI)

	var arms: Array = rig["arms"]
	var sw := sin(ph)
	arms[0]["shoulder"].rotation.x = 0.34 * sw - 0.20
	arms[1]["shoulder"].rotation.x = -0.34 * sw - 0.20
	arms[0]["elbow"].rotation.x = -0.55 - 0.2 * maxf(0.0, -sw)
	arms[1]["elbow"].rotation.x = -0.55 - 0.2 * maxf(0.0, sw)

	rig["root"].position.y = absf(cos(ph)) * 0.045
	rig["root"].rotation.z = sw * 0.02
	rig["torso"].rotation.x = 0.20 if up else -0.07
	rig["torso"].rotation.y = sw * 0.06
	rig["head"].rotation.x = -0.16 if up else 0.12
	rig["head"].rotation.y = 0.0


## Người đứng lò: chân trụ vững, một tay cầm kẹp lật sườn, thỉnh thoảng nhấc
## kẹp lên rồi hạ xuống, người hơi chồm về phía lò.
static func grill_flip(rig: Dictionary, t: float) -> void:
	_legs_rest(rig)
	var ph := t * 2.1
	var reach := 0.5 + 0.5 * sin(ph)          # nhịp đưa kẹp tới lui
	var lift := maxf(0.0, sin(ph * 2.0))      # cú nhấc miếng thịt lên

	var arms: Array = rig["arms"]
	# tay phải cầm kẹp lật thịt
	arms[1]["shoulder"].rotation.x = -0.95 - 0.25 * lift
	arms[1]["shoulder"].rotation.z = -0.16
	arms[1]["elbow"].rotation.x = -0.55 + 0.45 * reach
	# tay trái quạt than
	arms[0]["shoulder"].rotation.x = -0.55
	arms[0]["shoulder"].rotation.z = 0.22
	arms[0]["elbow"].rotation.x = -0.9 - 0.35 * sin(ph * 3.0)

	rig["root"].position.y = 0.0
	rig["root"].rotation.z = 0.0
	rig["torso"].rotation.x = 0.17
	rig["torso"].rotation.y = sin(ph) * 0.07
	rig["head"].rotation.x = -0.22
	rig["head"].rotation.y = 0.0


static func _legs_rest(rig: Dictionary) -> void:
	for l in rig["legs"]:
		l["hip"].rotation = Vector3.ZERO
		l["knee"].rotation.x = 0.0
		l["ankle"].rotation.x = 0.0


static func idle(rig: Dictionary, t: float) -> void:
	var a := sin(t * 1.5)
	_legs_rest(rig)
	var arms: Array = rig["arms"]
	arms[0]["shoulder"].rotation.x = a * 0.06
	arms[1]["shoulder"].rotation.x = -a * 0.06
	arms[0]["elbow"].rotation.x = -0.22
	arms[1]["elbow"].rotation.x = -0.22
	rig["root"].position.y = a * 0.008
	rig["root"].rotation.z = 0.0
	rig["torso"].rotation.y = 0.0
	rig["torso"].rotation.x = 0.0
	rig["head"].rotation.y = sin(t * 0.5) * 0.25
	rig["head"].rotation.x = 0.0


static func cook(rig: Dictionary, t: float) -> void:
	var a := sin(t * 5.0)
	_legs_rest(rig)
	var arms: Array = rig["arms"]
	arms[0]["shoulder"].rotation.x = -0.9 + a * 0.25
	arms[1]["shoulder"].rotation.x = -0.75 - a * 0.2
	arms[0]["elbow"].rotation.x = -0.9
	arms[1]["elbow"].rotation.x = -1.05 + a * 0.3
	rig["torso"].rotation.x = 0.12
	rig["torso"].rotation.y = 0.0
	rig["head"].rotation.x = 0.2
	rig["root"].position.y = 0.0
	rig["root"].rotation.z = 0.0


static func sit(rig: Dictionary, t: float) -> void:
	var b: Dictionary = rig["build"]
	rig["root"].position.y = -0.34 * float(b["h"])
	rig["root"].rotation.z = 0.0
	# đùi nằm ngang ra trước (âm), cẳng chân gập về sau xuống đất (dương)
	for l in rig["legs"]:
		l["hip"].rotation.x = -1.48
		l["knee"].rotation.x = 1.42
		l["ankle"].rotation.x = 0.06
	var a := sin(t * 3.4)
	var arms: Array = rig["arms"]
	arms[0]["shoulder"].rotation.x = -0.5 + a * 0.35
	arms[1]["shoulder"].rotation.x = -0.4
	arms[0]["elbow"].rotation.x = -1.3 - a * 0.4
	arms[1]["elbow"].rotation.x = -1.0
	rig["torso"].rotation.x = 0.16
	rig["torso"].rotation.y = 0.0
	rig["head"].rotation.x = 0.25 + a * 0.06


## Ngồi ghế nhựa thấp ngoài vỉa hè — dáng ngồi ăn cơm bụi Việt Nam.
##
## Khác hẳn ngồi ghế cao: mông chỉ cách đất 26cm nên đùi phải hất NGƯỢC lên
## (góc quá 90 độ), đầu gối vổng cao hơn hông, cẳng chân dựng gần thẳng đứng và
## bàn chân thu về ngay dưới gối. Lưng chồm ra trước vì bàn cũng thấp, một tay
## bưng chén sát ngực, tay kia và đũa đưa cơm lên miệng.
##
## `chat` = true: dáng ngồi nói chuyện, hai tay chống lên đầu gối, không ăn.
static func sit_stool(rig: Dictionary, t: float, chat: bool = false) -> void:
	var b: Dictionary = rig["build"]
	var bh := float(b["h"])
	rig["root"].position.y = -(0.82 - STOOL_SEAT) * bh
	rig["root"].rotation.z = 0.0

	var sway := sin(t * 1.1)
	var legs: Array = rig["legs"]
	for i in legs.size():
		var l: Dictionary = legs[i]
		var side := -1.0 if i == 0 else 1.0
		var thigh: float = STOOL_THIGH + sway * 0.03
		var shin: float = STOOL_SHIN
		l["hip"].rotation.x = thigh
		l["hip"].rotation.z = side * STOOL_KNEE_OUT      # gối dang sang hai bên
		l["knee"].rotation.x = shin - thigh              # gập sâu, gót thu vào trong
		l["ankle"].rotation.x = -shin                    # bàn chân đạp phẳng xuống đất

	var arms: Array = rig["arms"]
	if chat:
		# hai tay chống lên đầu gối, người đung đưa nói chuyện
		arms[0]["shoulder"].rotation.x = -0.62
		arms[1]["shoulder"].rotation.x = -0.62
		arms[0]["shoulder"].rotation.z = -0.24
		arms[1]["shoulder"].rotation.z = 0.24
		arms[0]["elbow"].rotation.x = -1.15
		arms[1]["elbow"].rotation.x = -1.15
		rig["torso"].rotation.x = 0.30 + sway * 0.04
		rig["torso"].rotation.y = sway * 0.12
		rig["head"].rotation.x = 0.06
		rig["head"].rotation.y = sway * 0.30
	else:
		# tay trái bưng chén sát ngực, tay phải và đũa đưa cơm lên miệng
		var bite := sin(t * 2.6)
		var lift: float = maxf(0.0, bite)
		arms[0]["shoulder"].rotation.x = -0.30
		arms[0]["shoulder"].rotation.z = -0.30
		arms[0]["elbow"].rotation.x = -2.05
		arms[1]["shoulder"].rotation.x = -0.34 - lift * 0.16
		arms[1]["shoulder"].rotation.z = 0.26
		arms[1]["elbow"].rotation.x = -1.55 - lift * 0.55
		rig["torso"].rotation.x = 0.34 - lift * 0.10   # chồm tới chén, ăn xong hơi ngửa ra
		rig["torso"].rotation.y = 0.0
		rig["head"].rotation.x = 0.30 - lift * 0.16
		rig["head"].rotation.y = 0.0


## Người đã thu nhỏ nhưng ghế thì vẫn cỡ thật, nên mông ngồi hụt xuống dưới mặt
## ghế. Trả về đoạn phải kênh cả người lên cho vừa đúng mặt ghế.
static func seat_lift(style: String) -> float:
	var seat: float = STOOL_SEAT if style == "stool" else CHAIR_SEAT
	return seat * (1.0 - CHAR_SCALE)


## Chén cơm + đũa cầm trên tay, mặc định ẩn. Gọi một lần lúc dựng nhân vật.
static func attach_meal(rig: Dictionary) -> Dictionary:
	var arms: Array = rig["arms"]
	var bowl := Node3D.new()
	bowl.position = Vector3(0, -0.055, 0.045)
	bowl.add_child(_mi(_cyl(0.072, 0.042, 0.058, 12), mat(Color8(0xfa, 0xfb, 0xfd), 0.4)))
	bowl.add_child(_mi(_sph(0.055, true), mat(Color8(0xff, 0xff, 0xff), 0.85), 0, 0.024, 0))
	arms[0]["hand"].add_child(bowl)

	var sticks := Node3D.new()
	sticks.position = Vector3(0, -0.06, 0.06)
	sticks.rotation = Vector3(-0.5, 0, 0)
	for sx in [-0.012, 0.012]:
		sticks.add_child(_mi(_bx(0.008, 0.008, 0.2), mat(Color8(0xd9, 0xb0, 0x76), 0.7), sx, 0, 0))
	arms[1]["hand"].add_child(sticks)

	bowl.visible = false
	sticks.visible = false
	return {"bowl": bowl, "sticks": sticks}


## Trả tư thế về đứng thẳng (sau khi rời ghế).
static func stand_up(rig: Dictionary) -> void:
	rig["root"].position.y = 0.0
	rig["root"].rotation.z = 0.0
	rig["torso"].rotation.x = 0.0
	rig["torso"].rotation.y = 0.0
	rig["head"].rotation.x = 0.0
	for a in rig["arms"]:
		a["shoulder"].rotation.z = 0.0
	_legs_rest(rig)


# ---------- Con chó của quán ----------
## Chó cỏ nằm vạ vật ở quán cơm là hình ảnh quá quen. Dựng bằng mấy khối đơn
## giản như người: bốn chân xoay được ở hông, đuôi ngoáy, đầu ngó nghiêng.
const DOG_COAT := Color8(0xc9, 0x8f, 0x5c)
const DOG_BELLY := Color8(0xf0, 0xdc, 0xc0)
const DOG_NOSE := Color8(0x33, 0x2c, 0x2c)


static func build_dog(coat: Color = DOG_COAT) -> Node3D:
	var fur := mat(coat, 0.85)
	var belly := mat(DOG_BELLY, 0.85)
	var dark := mat(DOG_NOSE, 0.6)

	var group := Node3D.new()
	group.name = "Dog"
	var root := Node3D.new()
	root.name = "Root"
	group.add_child(root)

	# thân nằm ngang
	var body := _mi(_cyl(0.125, 0.135, 0.44, 12), fur, 0, 0.34, 0)
	body.rotation.x = PI / 2.0
	root.add_child(body)
	root.add_child(_mi(_cyl(0.1, 0.1, 0.3, 10), belly, 0, 0.27, 0.02))

	# bốn chân: trước/sau, trái/phải
	var legs: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.085, 0.3, sz * 0.15)
			hip.add_child(_mi(_cyl(0.035, 0.03, 0.28), fur, 0, -0.14, 0))
			hip.add_child(_mi(_bx(0.075, 0.05, 0.11), dark, 0, -0.28, 0.02))
			root.add_child(hip)
			legs.append({"hip": hip, "front": sz > 0.0})

	# cổ + đầu ngóc lên phía trước
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.4, 0.2)
	root.add_child(neck)
	neck.add_child(_mi(_cyl(0.07, 0.085, 0.16), fur, 0, 0.06, 0.02))

	var head := Node3D.new()
	head.position = Vector3(0, 0.16, 0.03)
	neck.add_child(head)
	head.add_child(_mi(_sph(0.105), fur, 0, 0.02, 0))
	var snout := _mi(_cyl(0.05, 0.062, 0.13), fur, 0, -0.01, 0.11)
	snout.rotation.x = PI / 2.0
	head.add_child(snout)
	head.add_child(_mi(_sph(0.032), dark, 0, 0.0, 0.175))
	for ex in [-0.045, 0.045]:
		head.add_child(_mi(_sph(0.016), dark, ex, 0.05, 0.085))
		# tai cụp về sau
		var ear := _mi(_bx(0.045, 0.09, 0.02), fur, ex * 1.6, 0.09, -0.02)
		ear.rotation.x = -0.35
		head.add_child(ear)

	# đuôi vểnh
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.4, -0.2)
	root.add_child(tail)
	tail.rotation.x = -0.9
	tail.add_child(_mi(_cyl(0.02, 0.035, 0.22), fur, 0, 0.11, 0))

	group.set_meta("rig", {"root": root, "legs": legs, "head": head, "neck": neck, "tail": tail})
	return group


static func dog_rig_of(node: Node3D) -> Dictionary:
	return node.get_meta("rig", {}) as Dictionary


## Chạy lon ton: chân chéo nhau đánh cùng pha, thân nhún, đuôi ngoáy tít.
static func dog_walk(rig: Dictionary, t: float, speed: float = 7.0) -> void:
	var ph := t * speed
	for l in rig["legs"]:
		var leg: Dictionary = l
		# chân trước phải cùng pha với chân sau trái, đúng kiểu bốn chân đi
		var off: float = 0.0 if bool(leg["front"]) else PI
		(leg["hip"] as Node3D).rotation.x = sin(ph + off) * 0.62
	rig["root"].position.y = absf(cos(ph)) * 0.02
	rig["tail"].rotation.y = sin(ph * 1.6) * 0.5
	rig["neck"].rotation.x = -0.12
	rig["head"].rotation.y = 0.0


## Đứng hít hà: đầu ngó nghiêng, đuôi phe phẩy, người thở nhẹ.
static func dog_sniff(rig: Dictionary, t: float) -> void:
	for l in rig["legs"]:
		(l["hip"] as Node3D).rotation.x = 0.0
	var a := sin(t * 1.7)
	rig["root"].position.y = a * 0.006
	rig["tail"].rotation.y = sin(t * 3.2) * 0.7
	rig["neck"].rotation.x = 0.35 + a * 0.12
	rig["head"].rotation.y = sin(t * 0.8) * 0.5
