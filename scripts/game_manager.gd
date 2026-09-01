extends Node
## Autoload: toàn bộ dữ liệu + vòng lặp mô phỏng của quán cơm tấm.
##
## Lối chơi kiểu idle tycoon (như Idle Bank Tycoon): mỗi QUẦY chạy một mẻ,
## tốn nguyên liệu, làm ra các PHẦN cơm. Phần cơm bán cho khách -> tiền gom vào
## "bong bóng" trên quầy, chạm để thu. Thuê quản lý thì tự thu.

signal money_changed
signal stock_changed
signal state_changed          # nâng cấp / thuê người / mở khu / đổi giá
signal log_added(text: String)
signal bubble_changed(station_id: String)
signal day_ended(summary: Dictionary)
signal offline_earned(data: Dictionary)   # thu nhập khi vắng mặt
signal missions_changed
## Uy tín thay đổi. Tách khỏi `state_changed` là có lý do: `state_changed` khiến
## TycoonWorld DỰNG LẠI toàn bộ quán, mà khách bỏ về thì xảy ra liên tục.
signal reputation_changed
## Xong một mẻ nướng: sân khấu 3D cho người đứng lò bưng thịt vào trong quán.
signal grill_batch_ready(count: int)

const SAVE_PATH := "user://com_tam_save.json"
const BALANCE_PATH := "res://data/balance.json"   # bảng số chỉnh tay, xem _load_balance()
static var DAY_DURATION := 180.0   # giây cho mỗi "ngày" trong game

# ---------------- Dữ liệu tĩnh ----------------

static var FLOORS := [
	{"id": "street", "name": "Quán vỉa hè", "note": "Ngõ chợ Bàn Cờ · Q.3", "cost": 0},
	{"id": "aircon", "name": "Phòng máy lạnh", "note": "Khách văn phòng, giá cao hơn", "cost": 2500000},
	{"id": "rooftop", "name": "Khu sân vườn", "note": "Bàn VIP, nướng than hoa", "cost": 12000000},
]

static var INGREDIENTS := {
	"rice": {"name": "Gạo tấm", "unit": "kg", "price": 8000, "pack": 50},
	"pork": {"name": "Sườn heo", "unit": "miếng", "price": 15000, "pack": 50},
	"bi": {"name": "Bì heo", "unit": "phần", "price": 6000, "pack": 50},
	"cha": {"name": "Chả trứng", "unit": "miếng", "price": 10000, "pack": 50},
	"tea": {"name": "Trà", "unit": "ấm", "price": 800, "pack": 100},
	"ice": {"name": "Đá bi lạnh", "unit": "ly", "price": 700, "pack": 100},
	"coal": {"name": "Than đá", "unit": "bao", "price": 24000, "pack": 20},
	"gas": {"name": "Gas", "unit": "suất", "price": 2000, "pack": 100},
	## Bốn thứ dưới đây là BÁN THÀNH PHẨM: chợ không bán, quầy trong quán tự làm
	## ra rồi menu mới lấy chúng ghép thành món bưng cho khách. Giá ghi ở đây chỉ
	## để tính vốn một suất, không phải giá mua.
	"com": {"name": "Phần cơm tấm", "unit": "phần", "price": 10000, "pack": 0,
		"shop": false},
	"bicha": {"name": "Phần bì chả", "unit": "phần", "price": 16000, "pack": 0,
		"shop": false},
	"trada": {"name": "Ly trà đá", "unit": "ly", "price": 1500, "pack": 0,
		"shop": false},
	"grilled": {"name": "Sườn nướng sẵn", "unit": "miếng", "price": 17000, "pack": 0,
		"shop": false},
}

## Bán thành phẩm quầy tự làm ra — không mua được, chỉ nấu ra hoặc nướng ra.
static var MADE_ITEMS := ["com", "bicha", "trada", "grilled"]


## Chỉ những thứ bán ngoài chợ mới hiện trong màn Mua sắm.
static func shop_ingredients() -> Array:
	var out: Array = []
	for id in INGREDIENTS:
		if bool(INGREDIENTS[id].get("shop", true)):
			out.append(id)
	return out

## Quầy KHÔNG bán thẳng cho khách nữa: mỗi quầy chỉ làm ra một thứ bán thành
## phẩm ("out") chất sẵn trong kho, rồi MENU bên dưới mới ghép chúng thành món
## bưng ra bàn. Cả bốn quầy đều là bếp chung của quán nên đứng ở khu vỉa hè;
## khách khu nào cũng ăn cơm nấu từ cái bếp đó.
##   "out"  = thứ quầy làm ra, rỗng nghĩa là quầy không nấu (lò giữ nhiệt)
##   "keep" = quầy trữ sẵn được mấy phần, mỗi cấp nới thêm "keep_step"
##   "base_price" chỉ để tính lãi hiện trên bảng nâng cấp, không phải giá bán.
static var STATIONS := {
	"grill": {"floor": "street", "name": "Lò nướng thịt", "dish": "Sườn nướng sẵn", "glyph": "▤",
		# quầy này không nấu gì hết: nó là cái lò giữ nhiệt, chỉ CHỨA sườn do lò
		# than ngoài vỉa hè nướng ra. Công thức {grilled: 1} để lại là để người
		# đứng quầy biết lúc nào hết hàng mà nghỉ tay, và để màn hình báo động.
		# "boost_cost" = 0: quầy này KHÔNG thúc được, nó có nấu nướng gì đâu.
		"out": "", "recipe": {"grilled": 1}, "base_price": 25000, "cycle": 12.0,
		"batch": 2, "keep": 0, "keep_step": 0, "up_cost": 120000, "boost_cost": 0},
	"rice": {"floor": "street", "name": "Nồi cơm tấm", "dish": "Phần cơm tấm", "glyph": "▦",
		"out": "com", "recipe": {"rice": 1, "gas": 1}, "base_price": 20000, "cycle": 10.0,
		"batch": 2, "keep": 40, "keep_step": 8, "up_cost": 90000, "boost_cost": 20000},
	"prep": {"floor": "street", "name": "Bàn bì & chả", "dish": "Phần bì chả", "glyph": "▩",
		# đúng như cái tên: bàn này thái BÌ và CHẢ, hết một trong hai là đứng tay
		"out": "bicha", "recipe": {"bi": 1, "cha": 1}, "base_price": 30000, "cycle": 15.0,
		"batch": 2, "keep": 40, "keep_step": 8, "up_cost": 160000, "boost_cost": 10000},
	"drink": {"floor": "street", "name": "Quầy trà đá", "dish": "Ly trà đá", "glyph": "▥",
		"out": "trada", "recipe": {"ice": 1, "tea": 1}, "base_price": 5000, "cycle": 8.0,
		"batch": 3, "keep": 60, "keep_step": 12, "up_cost": 60000, "boost_cost": 1500},
}

## MENU — mấy món THẬT SỰ bán ra tiền. Khách ngồi bàn gọi một món hợp với khu
## mình đang ngồi, người phục vụ trừ đúng số nguyên bán thành phẩm trong kho rồi
## bưng ra; ăn xong khách mới trả tiền.
##   "needs"  = bán thành phẩm tốn cho MỘT suất, luôn là số nguyên
##   "where"  = khu nào có khách gọi món này; "ship" nghĩa là chỉ shipper giao đi
##   "weight" = mười người vào quán thì mấy người gọi món này. Trà đá để thấp vì
##              ít ai vào quán cơm chỉ uống mỗi ly trà đá.
static var MENU := {
	"com_suon": {"name": "Cơm tấm sườn", "desc": "1 phần cơm + 1 miếng sườn nướng",
		"price": 45000, "weight": 1.0, "needs": {"com": 1, "grilled": 1},
		"where": ["street", "aircon", "rooftop"]},
	"com_bi_cha": {"name": "Cơm tấm bì chả", "desc": "1 phần cơm + 1 phần bì chả",
		"price": 40000, "weight": 1.0, "needs": {"com": 1, "bicha": 1},
		"where": ["street", "aircon", "rooftop"]},
	"tra_da": {"name": "Trà đá", "desc": "1 ly trà đá",
		"price": 5000, "weight": 0.25, "needs": {"trada": 1},
		"where": ["street", "aircon", "rooftop"]},
	"thap_cam": {"name": "Cơm tấm thập cẩm", "desc": "1 miếng sườn + 1 phần bì chả",
		"price": 65000, "weight": 1.0, "needs": {"grilled": 1, "bicha": 1},
		"where": ["aircon", "rooftop"]},
	"com_hop": {"name": "Cơm hộp giao đi", "desc": "1 miếng sườn + 1 phần bì chả, shipper chở đi",
		"price": 60000, "weight": 1.0, "needs": {"grilled": 1, "bicha": 1},
		"where": ["ship"]},
	"set_vip": {"name": "Set cơm tấm VIP", "desc": "1 miếng sườn + 1 phần bì chả + 1 ly trà đá",
		"price": 90000, "weight": 1.0, "needs": {"grilled": 1, "bicha": 1, "trada": 1},
		"where": ["rooftop"]},
}


## Lò than vỉa hè: nướng cả mẻ sườn cùng lúc, xong thì bưng vào quầy trong quán.
## Nâng cấp lò = mỗi mẻ nướng được nhiều miếng hơn.
static var GRILL_BATCH_BASE := 10   # số miếng một mẻ lúc lò còn cấp 1
static var GRILL_BATCH_STEP := 4   # mỗi cấp thêm chừng này miếng
static var GRILL_CYCLE := 24.0   # giây cho trọn một mẻ
static var GRILL_COAL := 1.0   # bao than cháy hết cho mỗi mẻ
static var GRILL_UP_COST := 240000.0
## Tiền thúc cho xong mẻ sườn đang nướng, tính lúc lò còn cấp 1
static var GRILL_BOOST_COST := 50000.0

## Lò giữ nhiệt trong quầy: sườn nướng xong ngoài hiên bưng vào đây nằm chờ khách,
## nên nó quyết định quán trữ sẵn được bao nhiêu miếng. Lò đầy thì lò than ngoài
## hiên nghỉ tay — muốn nướng tiếp thì phải bán bớt hoặc nâng lò cho rộng chỗ.
static var WARMER_BASE := 14   # sức chứa lúc lò còn cấp 1
static var WARMER_STEP := 8   # mỗi cấp thêm chừng này chỗ
static var WARMER_UP_COST := 200000.0

## HAI CÁI KHO của quán. Món nào cũng thuộc về một kho và bị kho đó chặn trần:
##   kho lạnh  — sườn, bì, chả, đá bi
##   kho đồ khô — gạo, trà, than, gas
## Mỗi KHU tự mua tủ (kệ) của khu mình rồi nâng cấp riêng, nhưng chỗ trữ thì góp
## chung vào một cái kho của quán, vì kho nguyên liệu xưa giờ vẫn dùng chung.
##
## Sức chứa MỖI MÓN tính như sau:
##   cap_base[món]  = trữ được chừng đó khi chưa mua cái tủ/kệ nào
##   slot[món][k-1] = một cái tủ/kệ CẤP k trữ thêm chừng đó cho món đó
##   tổng = cap_base + Σ (mọi tủ của mọi khu) slot[món][cấp tủ đó]
## Hai bảng này nằm trong data/balance.json, mỗi món một mảng MAX_LEVEL số nên
## chỉnh được từng mức chứa của từng món ở từng cấp.
static var STORAGE := {
	"fridge": {
		"name": "Kho lạnh", "unit_name": "Tủ lạnh", "short": "tủ",
		"desc": "Đồ tươi phải bỏ tủ lạnh: để ngoài là hư.",
		"items": ["pork", "bi", "cha", "ice"],
		"cost": 600000.0, "cost_mult": 1.7, "max": 3,
		"up_cost": 180000.0, "up_mult": 1.55, "up_costs": [],
		"cap_base": {"pork": 50, "bi": 50, "cha": 50, "ice": 50},
		"slot": {},
	},
	"pantry": {
		"name": "Kho đồ khô", "unit_name": "Kệ đồ khô", "short": "kệ",
		"desc": "Gạo, trà, than, gas — chất được bao nhiêu là do cái kệ.",
		"items": ["rice", "tea", "coal", "gas"],
		"cost": 400000.0, "cost_mult": 1.7, "max": 3,
		"up_cost": 140000.0, "up_mult": 1.55, "up_costs": [],
		"cap_base": {"rice": 50, "tea": 20, "coal": 20, "gas": 1},
		"slot": {},
	},
}

## Đồ tươi = mấy món nằm trong kho lạnh. Giữ lại cái tên cũ vì nhiều chỗ gọi tới.
static var COLD_ITEMS := ["pork", "bi", "cha", "ice"]

## Quản lý: thuê cho từng quầy để tự động thu tiền.
static var MANAGER_COST_MULT := 6.0

## Nâng cấp: mỗi cấp quầy đắt thêm bao nhiêu lần, nấu nhanh thêm bao nhiêu, và
## mấy cấp thì được thêm một phần mỗi mẻ. Chỉnh trong data/balance.json.
static var STATION_UP_MULT := 1.45
static var LEVEL_SPEED_GAIN := 0.05
static var LEVEL_BATCH_EVERY := 4
static var GRILL_UP_MULT := 1.8
static var WARMER_UP_MULT := 1.75

## Nấu nhanh đắt thêm bao nhiêu lần mỗi cấp. Quầy càng cao cấp thì một mẻ càng
## nhiều phần và càng mau, nên tiền thúc cũng phải đi lên theo.
static var BOOST_COST_MULT := 1.12

## Tiền vốn lúc mở quán mới.
static var START_MONEY := 3000000.0

## Cấp tối đa của mọi thứ nâng cấp được (quầy, lò than, lò giữ nhiệt). Giá từng
## cấp nằm trong data/balance.json: mảng `up_costs` có đúng MAX_LEVEL số, số thứ k
## là giá để ĐẠT cấp k — nên số đầu tiên là 0 vì cấp 1 có sẵn lúc mở quầy.
## (Giá mở khu mới nằm riêng ở mục `floors`, không dính gì tới cấp.)
static var MAX_LEVEL := 25
static var GRILL_UP_COSTS: Array = []
static var WARMER_UP_COSTS: Array = []

## Nhân viên thuê RIÊNG cho từng khu: "cost" là giá người đầu tiên của một khu,
## "max" là số người tối đa mỗi khu (không phải cả quán) — mỗi khu chỉ chứa được
## hai người mỗi loại, quán nhỏ mà nhét đông quá thì đứng chật cả lối đi. Hai
## loại này ai cũng chỉ làm cho khu mình, và thuê ai là thấy ngay người đó
## ngoài quán chứ không phải chỉ là con số.
static var STAFF := {
	"waiter": {"name": "Phục vụ", "desc": "Thêm một người bưng cơm và +2 chỗ ngồi cho khu này", "cost": 300000, "salary": 22000, "max": 2, "free": 1},
	"shipper": {"name": "Shipper", "desc": "+6% khách tới khu này, chạy giao cơm suốt ngày", "cost": 350000, "salary": 25000, "max": 2, "free": 1},
}

static var DECOR := {
	"plant": {"name": "Chậu cây xanh", "desc": "+2 điểm không khí", "cost": 120000, "amb": 2},
	"lantern": {"name": "Đèn lồng", "desc": "+3 điểm không khí", "cost": 200000, "amb": 3},
	"sign": {"name": "Bảng hiệu đèn LED", "desc": "+5 điểm không khí, khách tới nhanh", "cost": 450000, "amb": 5},
	"fan": {"name": "Quạt máy đứng", "desc": "+3 điểm không khí, quạt đảo mát cả quán", "cost": 300000, "amb": 3},
	"table": {"name": "Bộ bàn ghế inox", "desc": "+2 chỗ ngồi", "cost": 380000, "seats": 2},
	"aquarium": {"name": "Bể cá cảnh", "desc": "+8 điểm không khí", "cost": 900000, "amb": 8},
	## Chó cỏ chạy lăng quăng trong quán: không giúp bán được thêm phần cơm nào,
	## chỉ để quán có hồn — nên điểm không khí vừa phải mà giá thì rẻ.
	"dog": {"name": "Chó cỏ giữ quán", "desc": "+4 điểm không khí, chạy lăng quăng",
		"cost": 260000, "amb": 4},
}

## Bàn ghế mua rời rồi tự tay đặt vào quán.
## "zone": "in" = trong nhà · "out" = vỉa hè · "any" = đặt đâu cũng được.
## "w"/"d" là bề ngang · bề sâu chỗ chiếm (mét) dùng để kiểm tra chồng chỗ.
static var FURNITURE := {
	"stool_set": {"name": "Bàn nhựa vỉa hè", "desc": "Bàn thấp + 4 ghế nhựa, kiểu quán cóc",
		"cost": 180000, "seats": 4, "amb": 1, "zone": "any", "w": 1.55, "d": 1.55},
	"table_steel": {"name": "Bàn inox 4 ghế", "desc": "Bàn inox chắc chắn, kê trong quán",
		"cost": 420000, "seats": 4, "amb": 2, "zone": "any", "w": 1.75, "d": 1.75},
	"table_wood": {"name": "Bàn gỗ 6 ghế", "desc": "Bàn dài cho nhóm đông",
		"cost": 1350000, "seats": 6, "amb": 4, "zone": "in", "w": 2.7, "d": 1.6},
	"parasol": {"name": "Dù che vỉa hè", "desc": "Che nắng cho bàn ngoài đường",
		"cost": 260000, "seats": 0, "amb": 3, "zone": "out", "w": 1.9, "d": 1.9},
}

## Thu nhập khi vắng mặt: chỉ quầy có quản lý mới chạy, hiệu suất 50%, tối đa 4 giờ.
static var OFFLINE_MAX_SECONDS := 14400.0
static var OFFLINE_RATE := 0.5

## Quản lý tự đi chợ. Món nào tụt xuống dưới MGR_BUY_AT phần trần kho của khu thì
## nhập một phát cho đầy trần luôn; cứ MGR_BUY_EVERY giây ngó kho một lần; và
## chừa lại MGR_BUY_RESERVE đồng trong ví cho người chơi (mặc định không chừa).
static var MGR_BUY_AT := 0.25
static var MGR_BUY_EVERY := 5.0
static var MGR_BUY_RESERVE := 0.0
# Bật mấy nút cộng tiền ở trang Cài đặt để test cho nhanh.
# Tắt bằng cách để "debug_tools": false trong chung của data/balance.json.
static var DEBUG_TOOLS := true

## Nhiệm vụ: "kind" là tên chỉ số trong `stats`, đạt "target" thì nhận thưởng.
static var MISSIONS := [
	{"id": "serve50", "name": "Bán 50 phần cơm", "kind": "served", "target": 50, "reward": 200000},
	{"id": "up5", "name": "Nâng cấp quầy 5 lần", "kind": "upgrades", "target": 5, "reward": 350000},
	{"id": "staff3", "name": "Thuê 3 nhân viên", "kind": "staff", "target": 3, "reward": 400000},
	{"id": "boost100", "name": "Chạm quầy 100 lần cho nhanh", "kind": "boosts", "target": 100, "reward": 250000},
	{"id": "mgr1", "name": "Thuê 1 quản lý quầy", "kind": "managers", "target": 1, "reward": 500000},
	{"id": "decor3", "name": "Mua 3 món trang trí", "kind": "decor", "target": 3, "reward": 300000},
	{"id": "earn5m", "name": "Kiếm tổng 5 triệu đồng", "kind": "earned", "target": 5000000, "reward": 800000},
	{"id": "floor2", "name": "Mở phòng máy lạnh", "kind": "floors", "target": 2, "reward": 1000000},
	{"id": "serve300", "name": "Bán 300 phần cơm", "kind": "served", "target": 300, "reward": 2000000},
	{"id": "rep80", "name": "Đạt uy tín 80", "kind": "reputation", "target": 80, "reward": 1500000},
	{"id": "floor3", "name": "Mở khu sân vườn", "kind": "floors", "target": 3, "reward": 5000000},
]

# ---------------- Trạng thái ----------------

var money := 3000000.0
var day := 1
var day_time := 0.0
var reputation := 50.0
var auto_open := true          # quán tự chạy ngày mới

## KHO TÁCH RIÊNG TỪNG KHU. Kho lạnh, kho đồ khô và cả rổ bán thành phẩm giờ là
## của riêng mỗi khu: bếp khu nào ăn nguyên liệu khu đó, phần làm ra nằm lại khu
## đó, người bưng của khu đó mới lấy được.
##   stock[floor_id][item_id] = khu đó đang có bao nhiêu món đó
## Ngoại lệ duy nhất là sườn nướng: lò than chỉ có một cái ngoài vỉa hè, nướng
## xong thì chia vào lò giữ nhiệt của mấy khu đang mở (xem _tick_grill).
var stock: Dictionary = {}          # floor_id -> {item_id -> số lượng}
var prices: Dictionary = {}         # station_id -> giá bán
var levels: Dictionary = {}         # station_id -> cấp (0 = chưa mở)
var progress: Dictionary = {}       # station_id -> 0..1 tiến độ mẻ hiện tại
var pending: Dictionary = {}        # station_id -> tiền đang chờ thu
var pending_portions: Dictionary = {}  # station_id -> số phần chưa bán
var managers: Dictionary = {}       # station_id -> bool (tự thu)
## Nhân viên cũng tính RIÊNG cho từng khu như trang trí: thuê phục vụ cho vỉa hè
## thì phòng máy lạnh vẫn phải tự lo người của nó.
##   staff[floor_id][staff_id] = số người khu đó THUÊ THÊM (người có sẵn lúc mở
##   khu không ghi vào đây, xem staff_free)
var staff: Dictionary = {}          # floor_id -> {staff_id -> số lượng}
## Trang trí giờ tính RIÊNG cho từng khu: mỗi gian hàng tự lo mặt tiền của nó,
## mua chậu cây cho vỉa hè thì phòng máy lạnh vẫn trống trơn.
##   decor[floor_id][decor_id] = số món khu đó đang có
var decor: Dictionary = {}          # floor_id -> {decor_id -> số lượng}
## Tủ lạnh và kệ đồ khô đều tính riêng từng khu, nên gom chung một chỗ:
##   stores[kind][floor_id]       = khu đó có mấy cái
##   store_levels[kind][floor_id] = cấp của mấy cái đó (1..MAX_LEVEL)
## `kind` là khoá trong STORAGE: "fridge" (tủ lạnh) hoặc "pantry" (kệ đồ khô).
var stores: Dictionary = {}
var store_levels: Dictionary = {}
var furniture: Dictionary = {}      # kind -> số bộ đã mua nhưng chưa đặt
var placed: Array = []              # bàn ghế đã đặt: {kind, floor, zone, x, z, rot}
var floors_unlocked: Dictionary = {}
var grill_level := 1                # cấp lò than vỉa hè
var warmer_level := 1               # cấp lò giữ nhiệt trong quầy
var grill_progress := 0.0           # mẻ đang nướng, 0..1

## Chỗ lẻ của công thức chưa đủ để rút khỏi kho. Công thức ghi được số lẻ (0.5 kg
## gạo một dĩa chẳng hạn) nhưng KHO thì luôn là số nguyên, nên phần lẻ nằm chờ ở
## đây: cứ đủ một đơn vị mới trừ kho một đơn vị.
## Kho tách theo khu nên chỗ nợ lẻ cũng tách theo khu.
##   ing_debt[floor_id][ingredient_id] = phần lẻ còn nợ, luôn trong khoảng 0..1
var ing_debt: Dictionary = {}       # floor_id -> {ingredient_id -> phần lẻ}

## Đếm ngược tới lượt quản lý đi chợ kế tiếp (xem _auto_restock).
var _restock_timer := 0.0

## Đang mua cả loạt hay không (nhập nhanh, quản lý đi chợ). Mua một lố mà phát
## một tín hiệu thì mấy màn nghe nó dựng lại danh sách cả trăm lần ngay giữa
## vòng lặp — bấm một cái là game đứng hình. Nên gom lại, xong xuôi mới phát
## đúng một tiếng. Đếm chứ không phải cờ, để mấy vòng lồng nhau khỏi giẫm chân.
var _stock_quiet := 0

var stats: Dictionary = {}       # chỉ số cộng dồn cho nhiệm vụ
var claimed: Dictionary = {}     # mission_id -> đã nhận thưởng
var last_seen := 0.0             # unix time lần cuối thoát game

var served_today := 0
var earned_today := 0.0
var lost_today := 0
var logs: Array[String] = []


func _ready() -> void:
	_load_balance()
	_reset_defaults()
	if FileAccess.file_exists(SAVE_PATH):
		if load_game():
			_apply_offline(Time.get_unix_time_from_system() - last_seen)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Đọc bảng số ở `data/balance.json` rồi ghi đè lên số mặc định trong file này.
##
## Ý tưởng: mọi con số cân bằng game (giá bán, giá nâng cấp, tiền lương, sức chứa,
## thưởng nhiệm vụ...) đều sửa được ngoài file JSON, sửa xong chạy `install.sh` là
## ra APK mới, khỏi đụng vào code. Thiếu khoá nào thì khoá đó giữ số mặc định, nên
## file JSON có thể chỉ ghi vài dòng cần sửa. File hỏng cú pháp thì bỏ qua cả file
## và ghi cảnh báo, game vẫn chạy bằng số mặc định.
func _load_balance() -> void:
	if not FileAccess.file_exists(BALANCE_PATH):
		return
	var f := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("data/balance.json sai cú pháp — dùng số mặc định")
		return
	var d: Dictionary = raw

	_merge_rows(d.get("stations", {}), STATIONS,
		{"name": TYPE_STRING, "dish": TYPE_STRING, "out": TYPE_STRING,
		"base_price": TYPE_FLOAT, "cycle": TYPE_FLOAT, "batch": TYPE_INT,
		"keep": TYPE_INT, "keep_step": TYPE_INT, "up_cost": TYPE_FLOAT,
		"boost_cost": TYPE_FLOAT,
		"recipe": TYPE_DICTIONARY, "up_costs": TYPE_ARRAY})
	_merge_rows(d.get("menu", {}), MENU,
		{"name": TYPE_STRING, "desc": TYPE_STRING, "price": TYPE_INT,
		"weight": TYPE_FLOAT, "needs": TYPE_DICTIONARY, "where": TYPE_ARRAY})
	_merge_rows(d.get("ingredients", {}), INGREDIENTS,
		{"name": TYPE_STRING, "unit": TYPE_STRING, "price": TYPE_FLOAT, "pack": TYPE_INT})
	_merge_rows(d.get("staff", {}), STAFF,
		{"cost": TYPE_FLOAT, "salary": TYPE_FLOAT, "max": TYPE_INT, "free": TYPE_INT})
	_merge_rows(d.get("decor", {}), DECOR,
		{"cost": TYPE_FLOAT, "amb": TYPE_INT, "seats": TYPE_INT})
	_merge_rows(d.get("furniture", {}), FURNITURE,
		{"cost": TYPE_FLOAT, "seats": TYPE_INT, "amb": TYPE_INT})

	# khu và nhiệm vụ là mảng, phải dò theo "id"
	var fl = d.get("floors", {})
	if typeof(fl) == TYPE_DICTIONARY:
		for row in FLOORS:
			var src = fl.get(str(row["id"]))
			if typeof(src) == TYPE_DICTIONARY and (src as Dictionary).has("cost"):
				row["cost"] = float((src as Dictionary)["cost"])
	var ms = d.get("missions", {})
	if typeof(ms) == TYPE_DICTIONARY:
		for row in MISSIONS:
			var src2 = ms.get(str(row["id"]))
			if typeof(src2) != TYPE_DICTIONARY:
				continue
			var sd: Dictionary = src2
			if sd.has("target"):
				row["target"] = float(sd["target"])
			if sd.has("reward"):
				row["reward"] = float(sd["reward"])

	var g = d.get("grill", {})
	if typeof(g) == TYPE_DICTIONARY:
		var gd: Dictionary = g
		GRILL_BATCH_BASE = int(gd.get("batch_base", GRILL_BATCH_BASE))
		GRILL_BATCH_STEP = int(gd.get("batch_step", GRILL_BATCH_STEP))
		GRILL_CYCLE = float(gd.get("cycle", GRILL_CYCLE))
		GRILL_COAL = float(gd.get("coal_per_batch", GRILL_COAL))
		GRILL_UP_COST = float(gd.get("up_cost", GRILL_UP_COST))
		GRILL_UP_MULT = float(gd.get("up_mult", GRILL_UP_MULT))
		GRILL_BOOST_COST = float(gd.get("boost_cost", GRILL_BOOST_COST))
		if typeof(gd.get("up_costs")) == TYPE_ARRAY:
			GRILL_UP_COSTS = (gd["up_costs"] as Array).duplicate()

	var w = d.get("warmer", {})
	if typeof(w) == TYPE_DICTIONARY:
		var wd: Dictionary = w
		WARMER_BASE = int(wd.get("base", WARMER_BASE))
		WARMER_STEP = int(wd.get("step", WARMER_STEP))
		WARMER_UP_COST = float(wd.get("up_cost", WARMER_UP_COST))
		WARMER_UP_MULT = float(wd.get("up_mult", WARMER_UP_MULT))
		if typeof(wd.get("up_costs")) == TYPE_ARRAY:
			WARMER_UP_COSTS = (wd["up_costs"] as Array).duplicate()

	# Hai cái kho: "fridge" và "pantry" là hai mục cùng tên trong balance.json.
	for kind in STORAGE:
		var src = d.get(str(kind))
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = src
		var row: Dictionary = STORAGE[kind]
		for key in ["cost", "cost_mult", "up_cost", "up_mult"]:
			if sd.has(key):
				row[key] = float(sd[key])
		if sd.has("max"):
			row["max"] = maxi(1, int(sd["max"]))
		if typeof(sd.get("up_costs")) == TYPE_ARRAY:
			row["up_costs"] = (sd["up_costs"] as Array).duplicate()
		# danh sách món của kho: đổi được, nhưng phải là món có thật
		if typeof(sd.get("items")) == TYPE_ARRAY:
			var keep: Array = []
			for it in sd["items"]:
				if INGREDIENTS.has(str(it)):
					keep.append(str(it))
			if not keep.is_empty():
				row["items"] = keep
		if typeof(sd.get("cap_base")) == TYPE_DICTIONARY:
			row["cap_base"] = (sd["cap_base"] as Dictionary).duplicate()
		if typeof(sd.get("slot")) == TYPE_DICTIONARY:
			row["slot"] = (sd["slot"] as Dictionary).duplicate()
	COLD_ITEMS = (STORAGE["fridge"]["items"] as Array).duplicate()

	var m = d.get("chung", d.get("misc", {}))
	if typeof(m) == TYPE_DICTIONARY:
		var md: Dictionary = m
		START_MONEY = float(md.get("start_money", START_MONEY))
		MAX_LEVEL = maxi(1, int(md.get("max_level", MAX_LEVEL)))
		DAY_DURATION = float(md.get("day_duration", DAY_DURATION))
		CUSTOMER_PATIENCE = float(md.get("customer_patience", CUSTOMER_PATIENCE))
		MANAGER_COST_MULT = float(md.get("manager_cost_mult", MANAGER_COST_MULT))
		STATION_UP_MULT = float(md.get("station_up_mult", STATION_UP_MULT))
		BOOST_COST_MULT = float(md.get("boost_cost_mult", BOOST_COST_MULT))
		LEVEL_SPEED_GAIN = float(md.get("level_speed_gain", LEVEL_SPEED_GAIN))
		LEVEL_BATCH_EVERY = int(md.get("level_batch_every", LEVEL_BATCH_EVERY))
		OFFLINE_MAX_SECONDS = float(md.get("offline_max_seconds", OFFLINE_MAX_SECONDS))
		OFFLINE_RATE = float(md.get("offline_rate", OFFLINE_RATE))
		MGR_BUY_AT = clampf(float(md.get("manager_buy_at", MGR_BUY_AT)), 0.0, 1.0)
		MGR_BUY_EVERY = maxf(float(md.get("manager_buy_every", MGR_BUY_EVERY)), 0.5)
		MGR_BUY_RESERVE = maxf(float(md.get("manager_buy_reserve", MGR_BUY_RESERVE)), 0.0)
		DEBUG_TOOLS = bool(md.get("debug_tools", DEBUG_TOOLS))


## Chép những khoá cho phép sửa từ bảng JSON sang bảng số của game, ép đúng kiểu
## (JSON đọc số nào cũng ra float, để nguyên là chỗ nào cần số nguyên sẽ lệch).
func _merge_rows(src, dst: Dictionary, fields: Dictionary) -> void:
	if typeof(src) != TYPE_DICTIONARY:
		return
	var rows: Dictionary = src
	for id in rows:
		if not dst.has(id) or typeof(rows[id]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rows[id]
		for key in fields:
			if not row.has(key):
				continue
			match int(fields[key]):
				TYPE_INT:
					dst[id][key] = int(row[key])
				TYPE_FLOAT:
					dst[id][key] = float(row[key])
				TYPE_DICTIONARY:
					if typeof(row[key]) == TYPE_DICTIONARY:
						dst[id][key] = (row[key] as Dictionary).duplicate()
				TYPE_ARRAY:
					if typeof(row[key]) == TYPE_ARRAY:
						dst[id][key] = (row[key] as Array).duplicate()
				_:
					dst[id][key] = str(row[key])


func _reset_defaults() -> void:
	money = START_MONEY
	day = 1
	day_time = 0.0
	reputation = 50.0
	served_today = 0
	earned_today = 0.0
	lost_today = 0
	logs.clear()
	stock.clear()
	# Mỗi khu một cái kho riêng. Số thật điền lại ở cuối hàm, lúc đã dựng xong
	# tủ kệ nên mới biết trần từng món của từng khu.
	for f in FLOORS:
		var blank: Dictionary = {}
		for id in INGREDIENTS:
			blank[id] = 0.0
		stock[str(f["id"])] = blank
	prices.clear()
	levels.clear()
	progress.clear()
	pending.clear()
	pending_portions.clear()
	managers.clear()
	for id in MENU:
		prices[id] = int(MENU[id]["price"])
	# mỗi khu một bộ quầy riêng; khu chưa mở thì quầy của khu đó còn cấp 0
	for id in all_station_ids():
		levels[id] = 1 if is_floor_unlocked(station_floor(id)) else 0
		progress[id] = 0.0
		pending[id] = 0.0
		pending_portions[id] = 0.0
		managers[id] = false
	staff.clear()
	for f in FLOORS:
		var crew: Dictionary = {}
		for id in STAFF:
			crew[id] = 0
		staff[str(f["id"])] = crew
	decor.clear()
	for f in FLOORS:
		var row: Dictionary = {}
		for id in DECOR:
			row[id] = 0
		decor[str(f["id"])] = row
	stores.clear()
	store_levels.clear()
	for kind in STORAGE:
		var cnt: Dictionary = {}
		var lvs: Dictionary = {}
		for f in FLOORS:
			cnt[str(f["id"])] = 0
			lvs[str(f["id"])] = 1
		stores[str(kind)] = cnt
		store_levels[str(kind)] = lvs
	furniture.clear()
	for id in FURNITURE:
		furniture[id] = 0
	# quán mở màn đã có sẵn hai bộ bàn nhựa ngoài vỉa hè
	placed = [
		{"kind": "stool_set", "floor": 0, "zone": "out", "x": -2.0, "z": 3.9, "rot": 0},
		{"kind": "stool_set", "floor": 0, "zone": "out", "x": 2.0, "z": 3.9, "rot": 0},
	]
	floors_unlocked.clear()
	for f in FLOORS:
		floors_unlocked[f["id"]] = f["cost"] == 0
	grill_level = 1
	warmer_level = 1
	grill_progress = 0.0
	ing_debt.clear()
	_restock_timer = 0.0
	# Kho đã dựng xong ở trên nên giờ mới biết trần từng món của từng khu: khu
	# nào đã mở thì mở quán ra là đầy ắp đồ mua ngoài chợ, còn bán thành phẩm
	# thì phải tự nấu tự nướng. Khu chưa mở thì kho trống trơn.
	for f in FLOORS:
		var fid := str(f["id"])
		var room: Dictionary = {}
		for id in INGREDIENTS:
			room[id] = float(item_capacity(str(id), fid)) if is_stored(str(id)) else 0.0
		for id in MADE_ITEMS:
			room[id] = 0.0
		stock[fid] = room
		ing_debt[fid] = {}
	stats = {"served": 0.0, "earned": 0.0, "upgrades": 0.0, "staff": 0.0,
		"managers": 0.0, "decor": 0.0, "floors": 1.0, "boosts": 0.0, "reputation": 50.0}
	claimed.clear()
	last_seen = Time.get_unix_time_from_system()


# ---------------- Truy vấn ----------------

func floor_data(fid: String) -> Dictionary:
	for f in FLOORS:
		if f["id"] == fid:
			return f
	return FLOORS[0]


func floor_index(fid: String) -> int:
	for i in FLOORS.size():
		if FLOORS[i]["id"] == fid:
			return i
	return 0


func is_floor_unlocked(fid: String) -> bool:
	return bool(floors_unlocked.get(fid, false))


## MỖI KHU MỘT DÃY QUẦY RIÊNG. Kho nguyên liệu và kho bán thành phẩm vẫn dùng
## chung cả quán, nhưng cấp quầy, tiến độ mẻ và quản lý là của riêng từng khu —
## nâng nồi cơm khu máy lạnh không làm nồi cơm vỉa hè chạy nhanh hơn.
##
## Cách ghi: mọi thứ tính theo quầy (`levels`, `progress`, `managers`, `pending`,
## `pending_portions`) dùng KHOÁ GHÉP `"<quầy>@<khu>"`, ví dụ `"rice@aircon"`.
## Tra bảng số của quầy thì đi qua `station_def(id)`, hỏi nó đứng khu nào thì
## `station_floor(id)`. Khoá trần kiểu `"rice"` (save đời cũ) vẫn đọc được: coi
## như quầy đó nằm ngoài vỉa hè.
const STATION_SEP := "@"


## Khoá ghép của quầy `sid` ở khu `fid`.
func station_key(sid: String, fid: String) -> String:
	return sid + STATION_SEP + fid


## Tên quầy trong bảng `STATIONS`, bỏ phần khu đi.
func station_base(id: String) -> String:
	var i := id.find(STATION_SEP)
	return id.substr(0, i) if i >= 0 else id


## Quầy này đứng ở khu nào.
func station_floor(id: String) -> String:
	var i := id.find(STATION_SEP)
	if i >= 0:
		return id.substr(i + 1)
	return str(STATIONS[id]["floor"]) if STATIONS.has(id) else str(FLOORS[0]["id"])


## Bảng số của quầy: nhịp mẻ, số phần, công thức, giá nâng cấp…
func station_def(id: String) -> Dictionary:
	return STATIONS[station_base(id)]


## Mọi cái quầy của cả quán: bốn quầy nhân ba khu, kể cả khu chưa mở.
func all_station_ids() -> Array:
	var out: Array = []
	for f in FLOORS:
		for sid in STATIONS:
			out.append(station_key(str(sid), str(f["id"])))
	return out


## Dãy quầy của riêng một khu. Khu chưa mở thì chưa có cái quầy nào.
func stations_on_floor(fid: String) -> Array:
	if not is_floor_unlocked(fid):
		return []
	var out: Array = []
	for id in STATIONS:
		out.append(station_key(str(id), fid))
	return out


## Cấp của một cái quầy. Mở khu là bốn quầy khu đó có sẵn cấp 1, nên khoá nào
## chưa ghi gì mà khu đã mở thì cứ tính cấp 1 — save đời cũ hay chỗ nào mở khu
## tắt cũng rơi vào đây, khỏi phải nhớ đi ghi cấp cho từng quầy.
func station_level(id: String) -> int:
	var lv := int(levels.get(id, 0))
	if lv <= 0 and is_floor_unlocked(station_floor(id)):
		return 1
	return lv


func is_station_open(id: String) -> bool:
	return is_floor_unlocked(station_floor(id))


## Giá để nâng quầy lên cấp kế tiếp. Ưu tiên tra bảng `up_costs` trong
## balance.json; bảng thiếu số thì mới tính theo công thức nhân dần.
func station_upgrade_cost(id: String) -> int:
	var lv := station_level(id)
	if lv >= MAX_LEVEL:
		return 0
	var listed := _cost_at(station_def(id).get("up_costs"), lv)
	if listed >= 0.0:
		return int(round(listed))
	return int(round(float(station_def(id)["up_cost"]) * pow(STATION_UP_MULT, maxi(lv, 0))))


## Quầy đã kịch cấp chưa.
func station_at_max(id: String) -> bool:
	return station_level(id) >= MAX_LEVEL


## Đọc giá cấp `lv` trong một bảng giá. Trả -1 nếu bảng không có số đó.
func _cost_at(table, lv: int) -> float:
	if typeof(table) != TYPE_ARRAY:
		return -1.0
	var rows: Array = table
	if lv < 0 or lv >= rows.size():
		return -1.0
	return float(rows[lv])


func manager_cost(id: String) -> int:
	return int(round(float(station_def(id)["up_cost"]) * MANAGER_COST_MULT))


func has_manager(id: String) -> bool:
	return bool(managers.get(id, false))


## Khu này đang thuê mấy người quản lý — quản lý thuê cho từng quầy, mà quầy nào
## cũng thuộc về một khu, nên đếm được ngay ai đang trông coi khu nào.
func floor_managers(fid: String) -> int:
	var n := 0
	for id in stations_on_floor(fid):
		if has_manager(str(id)):
			n += 1
	return n


## Thời gian một mẻ, đã tính cấp quầy.
func station_cycle(id: String) -> float:
	var lv := maxi(station_level(id), 1)
	var t := float(station_def(id)["cycle"]) / (1.0 + LEVEL_SPEED_GAIN * (lv - 1))
	return maxf(t, 0.6)


## Số phần làm ra mỗi mẻ.
func station_batch(id: String) -> int:
	var lv := maxi(station_level(id), 1)
	return int(station_def(id)["batch"]) + int(floor(float(lv - 1) / float(maxi(LEVEL_BATCH_EVERY, 1))))


## Một mẻ nướng được bao nhiêu miếng sườn.
func grill_batch() -> int:
	return GRILL_BATCH_BASE + (grill_level - 1) * GRILL_BATCH_STEP


func grill_upgrade_cost() -> float:
	if grill_at_max():
		return 0.0
	var listed := _cost_at(GRILL_UP_COSTS, grill_level)
	if listed >= 0.0:
		return listed
	return GRILL_UP_COST * pow(GRILL_UP_MULT, float(grill_level - 1))


func grill_at_max() -> bool:
	return grill_level >= MAX_LEVEL


## Còn than là lò còn đỏ lửa, dù chưa có miếng sườn nào trên vỉ. Hết sườn chỉ là
## không có gì để nướng, không phải lò tắt.
func grill_lit() -> bool:
	return stock_at(grill_floor(), "coal") >= GRILL_COAL


## Lò than vỉa hè chỉ có một cái, nằm ngoài hiên khu trệt — than với sườn sống
## của nó lấy ở kho khu đó.
func grill_floor() -> String:
	return str(FLOORS[0]["id"])


## Lò có đang nướng mẻ nào không: phải còn sườn sống cho cả mẻ và còn than.
func grill_running() -> bool:
	# lò giữ nhiệt còn chỗ mới nướng tiếp: nướng ra mà không chỗ để thì phí công
	return stock_at(grill_floor(), "pork") >= float(grill_batch()) \
		and stock_at(grill_floor(), "coal") >= GRILL_COAL \
		and not warmers_full()


## Lò giữ nhiệt trong quầy trữ sẵn được bao nhiêu miếng sườn.
func warmer_capacity() -> int:
	return WARMER_BASE + (warmer_level - 1) * WARMER_STEP


func warmer_upgrade_cost() -> float:
	if warmer_at_max():
		return 0.0
	var listed := _cost_at(WARMER_UP_COSTS, warmer_level)
	if listed >= 0.0:
		return listed
	return WARMER_UP_COST * pow(WARMER_UP_MULT, float(warmer_level - 1))


func warmer_at_max() -> bool:
	return warmer_level >= MAX_LEVEL


## Lò giữ nhiệt của MỘT khu đang đầy tới đâu, 0..1 — dùng cho thanh mức và cho
## số miếng bày trong khay của khu đó. Khu nào cũng có khay riêng, nhưng cấp lò
## thì nâng chung cho cả quán.
func warmer_fill(fid: String) -> float:
	return clampf(stock_at(fid, "grilled") / float(warmer_capacity()), 0.0, 1.0)


func warmer_full(fid: String) -> bool:
	return stock_at(fid, "grilled") >= float(warmer_capacity())


## Mọi khu đang mở đều hết chỗ chứa sườn — lúc đó lò than mới nghỉ tay.
func warmers_full() -> bool:
	for f in FLOORS:
		var fid := str(f["id"])
		if is_floor_unlocked(fid) and not warmer_full(fid):
			return false
	return true


## ---------------- Hai cái kho của quán ----------------

## Món này nằm trong kho nào — "fridge", "pantry", hoặc rỗng nếu không kho nào
## quản (bán thành phẩm tự làm thì lò giữ nhiệt / kho quầy lo, không tính ở đây).
static func storage_of(id: String) -> String:
	for kind in STORAGE:
		if (STORAGE[kind]["items"] as Array).has(id):
			return str(kind)
	return ""


## Món này có bị kho chặn trần không.
static func is_stored(id: String) -> bool:
	return not storage_of(id).is_empty()


## Món này có phải đồ tươi phải bỏ tủ lạnh không.
static func is_cold(id: String) -> bool:
	return storage_of(id) == "fridge"


## Một cái tủ/kệ CẤP `lv` trữ thêm bao nhiêu món `id`. Tra bảng `slot` trong
## balance.json trước — mảng đó có MAX_LEVEL số nên chỉnh được từng cấp; bảng
## thiếu số thì mới suy ra theo công thức nhân dần.
func store_slot(kind: String, id: String, lv: int) -> int:
	var slots = STORAGE[kind].get("slot", {})
	if typeof(slots) == TYPE_DICTIONARY and (slots as Dictionary).has(id):
		var rows = (slots as Dictionary)[id]
		if typeof(rows) == TYPE_ARRAY:
			var arr: Array = rows
			if lv >= 1 and lv <= arr.size():
				return int(arr[lv - 1])
			if not arr.is_empty():
				# quá cuối bảng thì bám theo số cuối, nhân dần cho khỏi đứng im
				return int(round(float(arr[arr.size() - 1])
					* pow(1.28, float(lv - arr.size()))))
	var base := float(store_cap_base(kind, id)) * 0.6
	return int(round(base * pow(1.28, float(maxi(lv, 1) - 1))))


## Chưa mua cái tủ/kệ nào thì quán vẫn để tạm được chừng này món `id`.
func store_cap_base(kind: String, id: String) -> int:
	var base = STORAGE[kind].get("cap_base", {})
	if typeof(base) == TYPE_DICTIONARY:
		return int((base as Dictionary).get(id, 0))
	return 0


## Cả quán trữ được bao nhiêu món `id`: phần có sẵn cộng mọi cái tủ/kệ của mọi khu.
## Khu `fid` trữ được bao nhiêu món `id`: nền của khu cộng với mấy cái tủ/kệ khu
## đó đã mua. Kho tách theo khu nên khu nào cũng có nền riêng, còn khu chưa mở
## thì chưa có lấy một chỗ.
func item_capacity(id: String, fid: String) -> int:
	var kind := storage_of(id)
	if kind.is_empty() or not is_floor_unlocked(fid):
		return 0
	var here := store_count(kind, fid) * store_slot(kind, id, store_level(kind, fid))
	return store_cap_base(kind, id) + here


## Cả quán cộng lại trữ được bao nhiêu món đó — chỉ để khoe con số tổng.
func item_capacity_all(id: String) -> int:
	var cap := 0
	for f in FLOORS:
		cap += item_capacity(id, str(f["id"]))
	return cap


## Khu `fid` góp bao nhiêu chỗ cho món `id`.
func store_floor_capacity(kind: String, fid: String, id: String) -> int:
	return store_count(kind, fid) * store_slot(kind, id, store_level(kind, fid))


func store_count(kind: String, fid: String) -> int:
	var row = stores.get(kind, {})
	return int(row.get(fid, 0)) if typeof(row) == TYPE_DICTIONARY else 0


func store_level(kind: String, fid: String) -> int:
	var row = store_levels.get(kind, {})
	if typeof(row) != TYPE_DICTIONARY:
		return 1
	return clampi(int(row.get(fid, 1)), 1, MAX_LEVEL)


func store_max(kind: String) -> int:
	return maxi(1, int(STORAGE[kind].get("max", 3)))


func store_at_max(kind: String, fid: String) -> bool:
	return store_count(kind, fid) >= store_max(kind)


func store_level_at_max(kind: String, fid: String) -> bool:
	return store_level(kind, fid) >= MAX_LEVEL


## Giá cái tủ/kệ tiếp theo của khu này — khu đó đã có mấy cái thì cái sau đắt hơn.
func store_cost(kind: String, fid: String) -> float:
	return float(STORAGE[kind]["cost"]) 		* pow(float(STORAGE[kind]["cost_mult"]), float(store_count(kind, fid)))


func store_upgrade_cost(kind: String, fid: String) -> float:
	if store_level_at_max(kind, fid):
		return 0.0
	var listed := _cost_at(STORAGE[kind].get("up_costs"), store_level(kind, fid))
	if listed >= 0.0:
		return listed
	return float(STORAGE[kind]["up_cost"]) 		* pow(float(STORAGE[kind]["up_mult"]), float(store_level(kind, fid) - 1))


## Mua thêm một cái tủ/kệ cho khu `fid`. Khu chưa mở thì chưa kê được.
func buy_store(kind: String, fid: String) -> bool:
	if not is_floor_unlocked(fid) or store_at_max(kind, fid):
		return false
	if not _spend(store_cost(kind, fid)):
		return false
	if typeof(stores.get(kind, null)) != TYPE_DICTIONARY:
		stores[kind] = {}
	(stores[kind] as Dictionary)[fid] = store_count(kind, fid) + 1
	_bump("decor")
	state_changed.emit()
	_log("Kê thêm %s cho %s" % [str(STORAGE[kind]["unit_name"]).to_lower(),
		str(floor_data(fid)["name"]).to_lower()])
	return true


## Nâng cấp tủ/kệ của khu `fid`: mọi cái của khu đó cùng rộng ra một nấc.
func upgrade_store(kind: String, fid: String) -> bool:
	if store_count(kind, fid) <= 0 or store_level_at_max(kind, fid):
		return false
	if not _spend(store_upgrade_cost(kind, fid)):
		return false
	if typeof(store_levels.get(kind, null)) != TYPE_DICTIONARY:
		store_levels[kind] = {}
	(store_levels[kind] as Dictionary)[fid] = store_level(kind, fid) + 1
	_bump("upgrades")
	state_changed.emit()
	_log("Nâng %s %s lên cấp %d" % [str(STORAGE[kind]["unit_name"]).to_lower(),
		str(floor_data(fid)["name"]).to_lower(), store_level(kind, fid)])
	return true


## Khu `fid` đang có bao nhiêu món `id`.
func stock_at(fid: String, id: String) -> float:
	var room = stock.get(fid, null)
	if typeof(room) != TYPE_DICTIONARY:
		return 0.0
	return float((room as Dictionary).get(id, 0.0))


## Cả quán cộng lại có bao nhiêu món đó — chỉ dùng cho chỗ hiển thị chung.
func stock_total(id: String) -> float:
	var n := 0.0
	for f in FLOORS:
		n += stock_at(str(f["id"]), id)
	return n


## Cộng món `id` vào kho khu `fid` (`n` âm là trừ ra), không cho tụt xuống dưới 0.
func add_stock(fid: String, id: String, n: float) -> void:
	if typeof(stock.get(fid, null)) != TYPE_DICTIONARY:
		stock[fid] = {}
	var room: Dictionary = stock[fid]
	room[id] = maxf(0.0, float(room.get(id, 0.0)) + n)


## Trần kho của một món ở một khu. Sườn nướng thì lò giữ nhiệt của khu đó chặn,
## bán thành phẩm khác do kho quầy lo (xem station_keep), còn lại chất thoải mái.
func stock_cap(id: String, fid: String) -> float:
	if id == "grilled":
		return float(warmer_capacity())
	return float(item_capacity(id, fid)) if is_stored(id) else INF


## Khu `fid` còn nhét thêm được bao nhiêu món `id` nữa.
func stock_room(id: String, fid: String) -> float:
	return maxf(0.0, stock_cap(id, fid) - stock_at(fid, id))


## Mấy cái tên cũ, giữ lại cho chỗ khác khỏi phải sửa: tủ lạnh chính là kho "fridge".
func fridge_count(fid: String) -> int:
	return store_count("fridge", fid)


func fridge_level(fid: String) -> int:
	return store_level("fridge", fid)


func buy_fridge(fid: String) -> bool:
	return buy_store("fridge", fid)


func upgrade_fridge(fid: String) -> bool:
	return upgrade_store("fridge", fid)


func upgrade_warmer() -> bool:
	if warmer_at_max():
		return false
	var cost := warmer_upgrade_cost()
	if not _spend(cost):
		return false
	warmer_level += 1
	_bump("upgrades")
	state_changed.emit()
	_log("Nâng lò giữ nhiệt lên cấp %d — chứa được %d miếng" % [warmer_level, warmer_capacity()])
	return true


func upgrade_grill() -> bool:
	if grill_at_max():
		return false
	var cost := grill_upgrade_cost()
	if not _spend(cost):
		return false
	grill_level += 1
	_bump("upgrades")
	state_changed.emit()
	_log("Nâng lò than lên cấp %d — mỗi mẻ %d miếng" % [grill_level, grill_batch()])
	return true


## Giá trị một phần bán thành phẩm quầy này làm ra. Không phải giá bán cho khách
## (giá bán nằm ở MENU) — nó chỉ để bảng nâng cấp khoe "lãi mỗi phần".
func station_price(id: String) -> float:
	return float(station_def(id)["base_price"])


## Vốn nguyên liệu cho MỘT phần quầy này làm ra.
func station_cost_per_portion(id: String) -> float:
	var total := 0.0
	var recipe: Dictionary = station_def(id)["recipe"]
	for ing in recipe:
		total += float(INGREDIENTS[ing]["price"]) * float(recipe[ing])
	return total


## Quầy trữ sẵn được mấy phần. Lò nướng thịt mượn luôn sức chứa của lò giữ nhiệt,
## mấy quầy còn lại thì nới thêm một nấc mỗi cấp.
func station_keep(id: String) -> int:
	if str(station_def(id).get("out", "")).is_empty():
		return warmer_capacity()
	var lv := maxi(station_level(id), 1)
	return int(station_def(id).get("keep", 40)) 		+ (lv - 1) * int(station_def(id).get("keep_step", 0))


## Quầy đã chất đầy kho của nó chưa — đầy thì người đứng quầy nghỉ tay.
func station_full(id: String) -> bool:
	var out := str(station_def(id).get("out", ""))
	if out.is_empty():
		return true
	return stock_at(station_floor(id), out) >= float(station_keep(id))


# ---------------- Menu: mấy món thật sự bán ra tiền ----------------

## Giá bán một suất, luôn là số nguyên đồng.
func dish_price(did: String) -> int:
	return int(prices.get(did, MENU[did]["price"]))


## Vốn một suất: cộng giá mấy phần bán thành phẩm ghép vào nó.
func dish_cost(did: String) -> float:
	var total := 0.0
	var needs: Dictionary = MENU[did]["needs"]
	for it in needs:
		total += float(INGREDIENTS[it]["price"]) * float(needs[it])
	return total


func dish_suggested_price(did: String) -> int:
	return int(ceil(dish_cost(did) * 2.2 / 1000.0) * 1000.0)


## Hệ số khách theo giá: bán mắc hơn giá gốc thì ít người gọi món đó.
func dish_appeal(did: String) -> float:
	var ratio := float(dish_price(did)) / maxf(float(MENU[did]["price"]), 1.0)
	return clampf(1.6 - 0.6 * ratio, 0.15, 1.4)


## Món này hay được gọi tới đâu: độ phổ biến của món nhân với mức hút khách theo
## giá. Bán mắc lên thì phần khách gọi món đó rơi bớt sang món khác.
func dish_draw(did: String) -> float:
	return maxf(float(MENU[did].get("weight", 1.0)), 0.0) * dish_appeal(did)


## Món này bán ở đâu: tên khu, hoặc "ship" nếu chỉ shipper chở đi.
func dish_sold_at(did: String, where: String) -> bool:
	var list = MENU[did].get("where", [])
	return typeof(list) == TYPE_ARRAY and (list as Array).has(where)


## Món này đã bán được chưa: chỉ cần một khu bán nó đã mở cửa (món giao đi thì
## lúc nào cũng bán được, shipper chạy từ vỉa hè).
func dish_open(did: String) -> bool:
	var list = MENU[did].get("where", [])
	if typeof(list) != TYPE_ARRAY:
		return false
	for w in list:
		if str(w) == "ship" or is_floor_unlocked(str(w)):
			return true
	return false


## Bếp khu `fid` có đủ hàng ghép ra suất này không — dùng cho chỗ hiển thị.
func dish_ready(did: String, fid: String) -> bool:
	var needs: Dictionary = MENU[did]["needs"]
	for it in needs:
		if stock_at(fid, str(it)) < float(needs[it]):
			return false
	return true


## Món này khu nào cũng chưa ghép nổi một suất — dùng cho mấy chỗ báo hết hàng
## chung cho cả quán.
func dish_ready_anywhere(did: String) -> bool:
	for f in FLOORS:
		var fid := str(f["id"])
		if is_floor_unlocked(fid) and dish_ready(did, fid):
			return true
	return false


## Mấy món đang bưng ra được ở `where` ("street"/"aircon"/"rooftop"/"ship"), lấy
## hàng từ kho khu `fid`. Người bưng khu nào thì `fid` là khu đó; shipper cũng
## vậy, hộp cơm giao đi lấy ngay tại khu shipper đứng chờ.
func menu_ready(where: String, fid: String) -> Array:
	var out: Array = []
	for did in MENU:
		if dish_sold_at(str(did), where) and dish_ready(str(did), fid):
			out.append(str(did))
	return out


## Nhận một đơn: bốc một món còn hàng ở `where` rồi TRỪ NGAY bán thành phẩm
## (toàn số nguyên). Trả về id món, hoặc chuỗi rỗng nếu bếp không còn gì để bưng.
## Món mắc thì ít người gọi hơn — đó là chỗ giá bán ăn vào lượng khách.
func take_order(where: String, fid: String) -> String:
	var picks: Array = menu_ready(where, fid)
	if picks.is_empty():
		return ""
	var total := 0.0
	for did in picks:
		total += dish_draw(str(did))
	var roll := randf() * total
	var chosen := str(picks[picks.size() - 1])
	for did in picks:
		roll -= dish_draw(str(did))
		if roll <= 0.0:
			chosen = str(did)
			break
	var needs: Dictionary = MENU[chosen]["needs"]
	for it in needs:
		add_stock(fid, str(it), -float(int(needs[it])))
	stock_changed.emit()
	return chosen


## Khách ăn xong (hoặc shipper giao xong) mới trả tiền — và trả trọn số nguyên
## đồng, không có đồng lẻ nào. Trả về số tiền vừa thu.
func sell_dish(did: String) -> int:
	if not MENU.has(did):
		return 0
	var pay := dish_price(did)
	money += float(pay)
	earned_today += float(pay)
	served_today += 1
	_bump("served")
	_bump("earned", float(pay))
	money_changed.emit()
	return pay


## Hệ số khách của một QUẦY: trung bình mức hút khách của mấy món dùng tới thứ
## quầy đó làm ra. Bảng nâng cấp trong quán đọc con số này.
func price_appeal(id: String) -> float:
	var out := str(station_def(id).get("out", ""))
	if out.is_empty():
		out = "grilled"
	var total := 0.0
	var n := 0
	for did in MENU:
		var needs: Dictionary = MENU[did]["needs"]
		if not needs.has(out):
			continue
		total += dish_appeal(str(did))
		n += 1
	return total / float(n) if n > 0 else 1.0


## Mở một khu là có sẵn ngần này người mỗi loại, không phải trả lương: một phục
## vụ và một shipper đi kèm theo khu. Khu chưa mở thì chẳng có ai.
func staff_free(fid: String, id: String) -> int:
	if not is_floor_unlocked(fid):
		return 0
	return int(STAFF[id].get("free", 0))


## Khu `fid` đã THUÊ THÊM mấy người loại `id` (không tính người có sẵn).
func staff_hired(fid: String, id: String) -> int:
	var crew = staff.get(fid, {})
	if typeof(crew) != TYPE_DICTIONARY:
		return 0
	return int(crew.get(id, 0))


## Khu `fid` có tất cả mấy người loại `id`: người có sẵn cộng người thuê thêm.
## Mọi chỗ tính tác dụng của nhân viên đều hỏi hàm này, nên người có sẵn cũng
## làm việc y như người mới thuê.
func staff_count(fid: String, id: String) -> int:
	return staff_free(fid, id) + staff_hired(fid, id)


## Khu `fid` còn thuê thêm được mấy người loại `id`.
func hire_left(fid: String, id: String) -> int:
	return maxi(staff_max(id) - staff_count(fid, id), 0)


## Cả quán cộng lại có mấy người loại `id`, tính cả người có sẵn của từng khu.
func staff_total(id: String) -> int:
	var n := 0
	for f in FLOORS:
		n += staff_count(str(f["id"]), id)
	return n


## Mỗi khu nhiều nhất chừng này người mỗi loại — ĐÃ TÍNH luôn người có sẵn lúc
## mở khu, nên "max 2 · free 1" nghĩa là chỉ thuê thêm được đúng một người.
func staff_max(id: String) -> int:
	return int(STAFF[id]["max"])


## Khu `fid` đang có bao nhiêu người, gộp mọi loại.
func floor_crew(fid: String) -> int:
	var n := 0
	for id in STAFF:
		n += staff_count(fid, id)
	return n


## Khu `fid` đang có mấy món trang trí loại `id`.
func decor_count(fid: String, id: String) -> int:
	var row = decor.get(fid, {})
	if typeof(row) != TYPE_DICTIONARY:
		return 0
	return int(row.get(id, 0))


## Cả quán cộng lại có mấy món loại `id` (dùng cho mấy con số chung).
func decor_total(id: String) -> int:
	var n := 0
	for fid in decor:
		n += decor_count(str(fid), id)
	return n


## Điểm không khí của RIÊNG một khu: trang trí bày ở khu đó cộng bàn ghế đã kê
## trong khu đó — khu nào chăm chút thì khu đó đông, không xài ké của khu khác.
func floor_ambiance(fid: String) -> int:
	var total := furniture_ambiance(floor_index(fid))
	for id in DECOR:
		if DECOR[id].has("amb"):
			total += decor_count(fid, id) * int(DECOR[id]["amb"])
	return total


## Không khí cả quán, cộng dồn ba khu (chỉ để hiện lên bảng thống kê).
func ambiance() -> int:
	var total := 0
	for f in FLOORS:
		total += floor_ambiance(str(f["id"]))
	return total


## Số chỗ ngồi do bàn ghế tự đặt mang lại. `fi` = -1 là tính cả quán, còn lại
## thì chỉ đếm bàn ghế kê trong khu thứ `fi`.
func furniture_seats(fi: int = -1) -> int:
	var s := 0
	for it in placed:
		var row: Dictionary = it
		var kind := str(row.get("kind", ""))
		if FURNITURE.has(kind) and (fi < 0 or int(row.get("floor", 0)) == fi):
			s += int(FURNITURE[kind]["seats"])
	return s


func furniture_ambiance(fi: int = -1) -> int:
	var a := 0
	for it in placed:
		var row: Dictionary = it
		var kind := str(row.get("kind", ""))
		if FURNITURE.has(kind) and (fi < 0 or int(row.get("floor", 0)) == fi):
			a += int(FURNITURE[kind].get("amb", 0))
	return a


## Chỗ ngồi của RIÊNG một khu: bốn ghế có sẵn, cộng phục vụ thuê cho khu này,
## cộng bàn ghế và trang trí bày trong khu này. Khu chưa mở thì không ghế nào.
func floor_seats(fid: String) -> int:
	if not is_floor_unlocked(fid):
		return 0
	var s := 4 + staff_count(fid, "waiter") * 2 + furniture_seats(floor_index(fid))
	for id in DECOR:
		if DECOR[id].has("seats"):
			s += decor_count(fid, id) * int(DECOR[id]["seats"])
	return s


## Chỗ ngồi cả quán, cộng dồn ba khu.
func seats() -> int:
	var s := 0
	for f in FLOORS:
		s += floor_seats(str(f["id"]))
	return s


## Số khách tới RIÊNG một khu mỗi phút (dùng cho cả phần hiển thị 3D). Uy tín là
## của chung cả quán, còn không khí, shipper và giá bán thì tính đúng khu đó —
## thuê shipper cho khu nào thì khách kéo về khu đó.
func floor_arrival_rate(fid: String) -> float:
	if not is_floor_unlocked(fid):
		return 0.0
	var base := 8.0
	base *= 1.0 + reputation / 100.0
	base *= 1.0 + float(floor_ambiance(fid)) * 0.015
	base *= 1.0 + 0.06 * float(staff_count(fid, "shipper"))
	# bán mắc thì khách thưa: lấy trung bình mức hút khách của mấy món khu này bán
	var appeal := 0.0
	var n := 0
	for did in MENU:
		if not dish_sold_at(str(did), fid):
			continue
		appeal += dish_appeal(str(did))
		n += 1
	if n > 0:
		base *= appeal / float(n)
	return maxf(base, 0.5)


## Khách tới cả quán mỗi phút, cộng dồn mọi khu đã mở.
func arrival_rate() -> float:
	var total := 0.0
	for f in FLOORS:
		total += floor_arrival_rate(str(f["id"]))
	return total


func total_pending() -> float:
	var t := 0.0
	for id in pending:
		t += float(pending[id])
	return t


## Ước lượng tiền vào mỗi giây khi quán chạy đều: dùng cho dòng "₫/s" trên HUD
## và trong bảng nâng cấp. Chỉ tính quầy đã mở và còn nguyên liệu để chạy.
func income_per_second(station_id: String = "") -> float:
	var total := 0.0
	for id in all_station_ids():
		if station_id != "" and id != station_id:
			continue
		if not is_station_open(str(id)):
			continue
		if str(station_def(str(id)).get("out", "")).is_empty():
			continue          # lò giữ nhiệt không nấu ra gì, không tính vào ₫/s
		var lai := station_price(str(id)) - station_cost_per_portion(str(id))
		total += lai * float(station_batch(str(id))) / maxf(station_cycle(str(id)), 0.1)
	return total


## ---------------- Khách ngồi bàn chờ được phục vụ ----------------

## Khách ngồi xuống là bắt đầu đếm giờ. Hết chừng này giây mà chưa ai bưng cơm
## ra thì họ bỏ về. Tạm để chung một mức cho mọi loại khách; sau này muốn khách
## sang chảnh mất kiên nhẫn nhanh hơn thì tách theo từng loại.
static var CUSTOMER_PATIENCE := 28.0

## Bỏ về thì quán mất bao nhiêu uy tín, tuỳ loại khách: khách quen dễ tính mất
## ít, khách văn phòng hay khách du lịch còn đi kể với người khác nên mất nhiều.
const CUSTOMER_ANGER := {
	"office": 3, "auntie": 3, "student": 1, "tourist": 2,
	"xeom": 2, "driver": 1, "worker": 2,
}
## Thỉnh thoảng vớ phải người khó tính: một phần năm số lần là mất nặng hơn hẳn.
const ANGER_SPIKE_CHANCE := 0.2
const ANGER_MAX := 5


## Khách ĂN XONG rồi vui vẻ đứng dậy ra về: quán được thêm 1-2 điểm uy tín.
## Tính lúc ăn xong chứ không tính lúc mới bưng ra: bưng ra mà người ta chưa ăn
## thì đã tốt đẹp gì đâu. Không có phần thưởng này thì cơ chế bỏ về chỉ có một
## chiều đi xuống, uy tín nằm bẹp ở 0.
const HAPPY_REWARD_MIN := 1
const HAPPY_REWARD_MAX := 2


## Trả về số uy tín vừa được cộng.
func customer_finished() -> int:
	var gain := randi_range(HAPPY_REWARD_MIN, HAPPY_REWARD_MAX)
	reputation = minf(100.0, reputation + float(gain))
	reputation_changed.emit()
	return gain


## Một người khách bỏ về vì chờ lâu. Trả về số uy tín vừa mất.
func customer_gave_up(kind: String) -> int:
	var penalty := int(CUSTOMER_ANGER.get(kind, 2))
	if randf() < ANGER_SPIKE_CHANCE:
		penalty = randi_range(4, ANGER_MAX)
	penalty = clampi(penalty, 1, ANGER_MAX)
	reputation = maxf(0.0, reputation - float(penalty))
	lost_today += 1
	_log("Khách bỏ về vì chờ lâu · uy tín -%d" % penalty)
	# KHÔNG dùng state_changed ở đây: nó dựng lại cả quán, khách đang ngồi bị xoá
	# sạch và người phục vụ mất luôn đĩa đang bưng.
	reputation_changed.emit()
	return penalty


## Sức làm của cả một khu: cộng năng suất (phần/giây) của MỌI quầy đang mở trong
## khu đó. Quầy càng lên cấp, mẻ càng nhiều và càng nhanh, nên tổng này càng lớn.
func service_rate(fid: String) -> float:
	var total := 0.0
	for id in stations_on_floor(fid):
		var sid := str(id)
		if not is_station_open(sid):
			continue
		total += float(station_batch(sid)) / maxf(station_cycle(sid), 0.1)
	return total


## Bao lâu thì người phục vụ bưng được một đĩa: nghịch đảo của tổng năng suất
## trên. Kẹp lại cho khỏi nhanh quá (nhìn giật) hay chậm quá (tưởng đứng hình).
const SERVICE_BASE := 4.0          # nhịp chờ khi cả khu mới chỉ có một quầy cấp 1

## Đây là quãng chờ của MỘT người bưng. Thuê thêm phục vụ thì khu có thêm người
## bưng chứ người cũ không chạy nhanh hơn, nên chỗ này không hỏi tới nhân viên.
func service_time(fid: String) -> float:
	var rate := service_rate(fid)
	if rate <= 0.001:
		return 12.0
	return clampf(SERVICE_BASE / rate, 1.0, 12.0)


## Uy tín chia thành các bậc 25 điểm: ngôi sao trên HUD hiện bậc, thanh tím bên
## cạnh hiện phần đã đi được trong bậc hiện tại.
const REP_PER_LEVEL := 25.0


func rep_level() -> int:
	return int(floor(reputation / REP_PER_LEVEL)) + 1


func rep_progress() -> float:
	return fmod(maxf(reputation, 0.0), REP_PER_LEVEL) / REP_PER_LEVEL


func daily_salary() -> float:
	var total := 0.0
	for f in FLOORS:
		total += floor_salary(str(f["id"]))
	return total


## Lương một khu phải trả mỗi ngày.
func floor_salary(fid: String) -> float:
	var total := 0.0
	for id in STAFF:
		total += float(staff_hired(fid, id)) * float(STAFF[id]["salary"])
	return total


## Trừ `amount` nguyên liệu `ing` ra khỏi kho. Công thức ghi số lẻ được, nhưng
## kho thì luôn là số nguyên: chỗ lẻ cộng dồn vào `ing_debt`, đủ một đơn vị mới
## rút một đơn vị ra. Ghi 0.5 kg gạo một dĩa thì cứ hai dĩa mới vơi một ký.
func _use_ingredient(fid: String, ing: String, amount: float) -> void:
	if amount <= 0.0:
		return
	if typeof(ing_debt.get(fid, null)) != TYPE_DICTIONARY:
		ing_debt[fid] = {}
	var owed_row: Dictionary = ing_debt[fid]
	var owed := float(owed_row.get(ing, 0.0)) + amount
	var take := floorf(owed)
	owed_row[ing] = owed - take
	if take > 0.0:
		add_stock(fid, ing, -take)


## Quầy này còn đủ nguyên liệu trong kho KHU CỦA NÓ để chạy `times` phần không.
func has_ingredients(id: String, times: int = 1) -> bool:
	var fid := station_floor(id)
	var recipe: Dictionary = station_def(id)["recipe"]
	for ing in recipe:
		if stock_at(fid, str(ing)) < float(recipe[ing]) * times:
			return false
	return true


## Có khu nào đang cạn sạch món gì không — mất uy tín cuối ngày vì chuyện này.
func any_missing_ingredients() -> bool:
	for f in FLOORS:
		var fid := str(f["id"])
		if is_floor_unlocked(fid) and not missing_ingredients(fid).is_empty():
			return true
	return false


## Khu này đang cạn sạch mấy món nào.
func missing_ingredients(fid: String) -> Array:
	var out: Array = []
	for ing in shop_ingredients():
		if stock_at(fid, str(ing)) <= 0.0:
			out.append(ing)
	return out


# ---------------- Vòng lặp mô phỏng ----------------

func _process(delta: float) -> void:
	var d := delta
	day_time += d
	if day_time >= DAY_DURATION:
		_end_day()

	var dirty_money := false
	var dirty_stock := false

	if _tick_grill(d):
		dirty_stock = true

	# Quản lý không đi chợ mỗi khung hình — cứ vài giây ngó kho một lần cho đỡ
	# nặng máy và cho nhật ký khỏi ngập chữ "nhập hàng".
	_restock_timer += d
	if _restock_timer >= MGR_BUY_EVERY:
		_restock_timer = 0.0
		_auto_restock()

	# Khu nào cũng có dãy quầy của mình, mỗi cái chạy mẻ riêng theo cấp riêng, và
	# giờ thì ăn nguyên liệu kho khu mình rồi chất phần làm ra cũng vào kho khu
	# mình luôn — bếp khu này hết gạo thì khu kia vẫn nấu ngon lành.
	for id in all_station_ids():
		if not is_station_open(id):
			continue
		var fid := station_floor(id)
		# Lò nướng thịt không nấu gì: nó chỉ giữ nhiệt cho sườn của lò than.
		var out := str(station_def(id).get("out", ""))
		if out.is_empty():
			continue
		# Quầy chất đầy kho rồi thì đứng nghỉ, nấu ra nữa cũng không có chỗ để.
		if station_full(id):
			progress[id] = 0.0
			pending_portions[id] = stock_at(fid, out)
			continue
		var batch := station_batch(id)
		# Chỉ chạy khi còn nguyên liệu
		if progress[id] <= 0.0 and not has_ingredients(id, 1):
			pending_portions[id] = stock_at(fid, out)
			continue
		progress[id] = float(progress[id]) + d / station_cycle(id)
		if float(progress[id]) >= 1.0:
			progress[id] = 0.0
			# Mẻ chỉ ra tới lúc kho quầy đầy, và mỗi phần trừ đúng số ghi trong công
			# thức — số lẻ thì cộng dồn cho tới lúc đủ một đơn vị (xem _use_ingredient).
			var room := station_keep(id) - int(stock_at(fid, out))
			var made := 0
			for i in mini(batch, maxi(room, 0)):
				if not has_ingredients(id, 1):
					break
				var recipe: Dictionary = station_def(id)["recipe"]
				for ing in recipe:
					_use_ingredient(fid, str(ing), float(recipe[ing]))
				made += 1
			if made > 0:
				add_stock(fid, out, float(made))
				dirty_stock = true
			else:
				_log("Hết nguyên liệu cho %s %s" % [str(station_def(id)["name"]).to_lower(), str(floor_data(fid)["name"]).to_lower()])
		pending_portions[id] = stock_at(fid, out)

	# Lò nướng thịt là cái lò giữ nhiệt: con số "phần chờ" của nó là số miếng sườn
	# đang nằm trong khay của chính khu đó.
	for f in FLOORS:
		var wf := str(f["id"])
		pending_portions[station_key("grill", wf)] = stock_at(wf, "grilled")

	if dirty_stock:
		stock_changed.emit()
	if dirty_money:
		money_changed.emit()


func _collect_station(id: String) -> void:
	var amount := float(pending.get(id, 0.0))
	if amount <= 0.0:
		return
	pending[id] = 0.0
	money += amount
	earned_today += amount


## Người chơi chạm vào bong bóng tiền trên quầy.
func collect(id: String) -> float:
	var amount := float(pending.get(id, 0.0))
	if amount <= 0.0:
		return 0.0
	_collect_station(id)
	money_changed.emit()
	bubble_changed.emit(id)
	return amount


func collect_all() -> float:
	var total := 0.0
	for id in all_station_ids():
		var a := float(pending.get(id, 0.0))
		if a > 0.0:
			total += a
			_collect_station(id)
			bubble_changed.emit(id)
	if total > 0.0:
		money_changed.emit()
	return total


func _end_day() -> void:
	day_time = 0.0
	var salary := daily_salary()
	money -= salary
	var summary := {
		"day": day, "served": served_today, "earned": earned_today,
		"salary": salary, "profit": earned_today - salary,
	}
	# Uy tín theo lượng khách phục vụ trong ngày
	if served_today > 40:
		reputation = minf(100.0, reputation + 3.0)
	elif served_today < 12:
		reputation = maxf(0.0, reputation - 4.0)
	if any_missing_ingredients():
		reputation = maxf(0.0, reputation - 2.0)
	day += 1
	served_today = 0
	earned_today = 0.0
	lost_today = 0
	_log("Hết ngày %d · trả lương %s ₫" % [int(summary["day"]), UIKit.money(salary)])
	day_ended.emit(summary)
	money_changed.emit()
	state_changed.emit()
	save_game()


## Lò than vỉa hè chạy độc lập với các quầy: đủ sườn sống và còn than thì đỏ lửa,
## hết một mẻ thì cả mẻ thành "sườn nướng sẵn" cho quầy trong quán dùng.
func _tick_grill(d: float) -> bool:
	if not grill_running():
		return false
	grill_progress += d / GRILL_CYCLE
	if grill_progress < 1.0:
		return false
	grill_progress = 0.0
	var gf := grill_floor()
	var batch := grill_batch()
	add_stock(gf, "pork", -float(batch))
	add_stock(gf, "coal", -GRILL_COAL)
	# Lò than chỉ có một cái ngoài vỉa hè mà khu nào cũng cần sườn, nên nướng
	# xong thì chia vòng tròn vào lò giữ nhiệt của mấy khu đang mở: mỗi lượt một
	# miếng cho khu còn chỗ. Hết chỗ cả quán thì phần dư đành bỏ lại trên vỉ.
	var takers: Array = []
	for f in FLOORS:
		if is_floor_unlocked(str(f["id"])):
			takers.append(str(f["id"]))
	var kept := 0
	while kept < batch:
		var moved := false
		for t in takers:
			if kept >= batch:
				break
			if warmer_full(str(t)):
				continue
			add_stock(str(t), "grilled", 1.0)
			kept += 1
			moved = true
		if not moved:
			break
	grill_batch_ready.emit(kept)
	_log("Nướng xong %d miếng sườn, chia vào lò giữ nhiệt các khu" % kept)
	return true


# ---------------- Nhiệm vụ ----------------

func _bump(kind: String, amount: float = 1.0) -> void:
	stats[kind] = float(stats.get(kind, 0.0)) + amount
	missions_changed.emit()


func mission_progress(m: Dictionary) -> float:
	if str(m["kind"]) == "reputation":
		return reputation
	return float(stats.get(str(m["kind"]), 0.0))


func mission_done(m: Dictionary) -> bool:
	return mission_progress(m) >= float(m["target"])


func mission_claimed(id: String) -> bool:
	return bool(claimed.get(id, false))


## Số nhiệm vụ đã xong mà chưa bấm nhận — dùng cho chấm đỏ trên thanh điều hướng.
func missions_ready() -> int:
	var n := 0
	for m in MISSIONS:
		if mission_done(m) and not mission_claimed(str(m["id"])):
			n += 1
	return n


func claim_mission(id: String) -> float:
	for m in MISSIONS:
		if str(m["id"]) != id:
			continue
		if not mission_done(m) or mission_claimed(id):
			return 0.0
		claimed[id] = true
		var reward := float(m["reward"])
		money += reward
		money_changed.emit()
		missions_changed.emit()
		_log("Nhận thưởng nhiệm vụ: %s ₫" % UIKit.money(reward))
		return reward
	return 0.0


# ---------------- Nấu nhanh: trả tiền cho xong mẻ ----------------

## Nấu nhanh là MUA đứt phần thời gian còn lại của mẻ đang nấu: trả tiền một cái
## là mẻ ra ngay, không phải ngồi đợi. Giá tính ba tầng:
##
##   giá gốc (`boost_cost` của quầy trong balance.json)
##   × BOOST_COST_MULT^(cấp - 1)   — quầy cao cấp mẻ to hơn nên thúc đắt hơn
##   × phần mẻ CÒN LẠI             — thúc sớm trả trọn, thúc lúc gần xong gần như
##                                   không mất gì, vì có rút ngắn được bao nhiêu đâu
##
## `boost_cost` bằng 0 nghĩa là quầy đó không thúc được — lò nướng thịt chỉ giữ
## nhiệt cho sườn của lò than, nó có nấu nướng gì đâu mà thúc.
func boost_cost(id: String) -> int:
	var base := float(station_def(id).get("boost_cost", 0.0))
	if base <= 0.0 or str(station_def(id).get("out", "")).is_empty():
		return 0
	var lv := maxi(station_level(id), 1)
	var left := clampf(1.0 - float(progress.get(id, 0.0)), 0.0, 1.0)
	return int(round(base * pow(BOOST_COST_MULT, float(lv - 1)) * left))


## Bấm được nút nấu nhanh hay không: quầy phải đang mở, thúc được, còn nguyên
## liệu, kho chưa đầy và trong ví đủ tiền.
func can_boost(id: String) -> bool:
	if not is_station_open(id) or boost_cost(id) <= 0:
		return false
	if station_full(id) or not has_ingredients(id, 1):
		return false
	return can_afford(float(boost_cost(id)))


## Trả tiền xong thì chỉ việc đẩy kim đồng hồ tới sát vạch: khung hình kế tiếp
## `_process` kết mẻ theo đúng đường ra hàng cũ (trần kho, phần lẻ nguyên liệu,
## báo hết hàng) — đừng chép lại đoạn đó ở đây.
func boost_station(id: String) -> bool:
	if not can_boost(id):
		return false
	if not _spend(float(boost_cost(id))):
		return false
	progress[id] = 0.999
	_bump("boosts")
	return true


## Tiền thúc cho xong mẻ sườn ngoài lò than, tính y hệt quầy trong quán.
func grill_boost_cost() -> int:
	var left := clampf(1.0 - grill_progress, 0.0, 1.0)
	return int(round(GRILL_BOOST_COST * pow(BOOST_COST_MULT, float(grill_level - 1)) * left))


func can_boost_grill() -> bool:
	# `grill_running` đã hỏi đủ ba chuyện: còn than, còn sườn sống, lò giữ nhiệt
	# còn chỗ. Thiếu thứ nào thì có thúc cũng chẳng ra miếng nào.
	return grill_running() and can_afford(float(grill_boost_cost()))


func boost_grill() -> bool:
	if not can_boost_grill():
		return false
	if not _spend(float(grill_boost_cost())):
		return false
	grill_progress = 0.999
	_bump("boosts")
	return true


# ---------------- Quản lý tự đi chợ ----------------

## Quầy này phải lo nhập mấy món nào. Bình thường là đúng mấy thứ trong công thức
## của nó, mà chỉ tính món mua ngoài chợ được (bán thành phẩm thì tự nấu).
func station_supplies(id: String) -> Array:
	var out: Array = []
	var recipe: Dictionary = station_def(id)["recipe"]
	for ing in recipe:
		if INGREDIENTS.has(ing) and bool(INGREDIENTS[ing].get("shop", true)):
			out.append(str(ing))
	# Quầy "Lò nướng thịt" đại diện cho cả dây sườn nướng, mà than với sườn sống
	# thì đốt ngoài lò than vỉa hè — nên chỉ quản lý ở đúng khu có lò mới đi chợ
	# mua hai món đó, quản lý khu trên chỉ trông cái khay giữ nhiệt.
	if station_base(id) == "grill" and station_floor(id) == grill_floor():
		out.append("pork")
		out.append("coal")
	return out


## Quản lý tự đi chợ: quầy nào có người trông thì nguyên liệu của quầy đó không
## được để cạn. Thấy tụt xuống dưới ngưỡng là nhập một phát cho ĐẦY trần kho của
## khu đó, miễn là ví đủ tiền; thiếu tiền thì nhập được bao nhiêu hay bấy nhiêu,
## cạn túi hẳn thì thôi, cứ để quầy báo hết hàng như thường.
func _auto_restock() -> void:
	_quiet_begin()
	for f in FLOORS:
		var fid := str(f["id"])
		if not is_floor_unlocked(fid):
			continue
		for sid in stations_on_floor(fid):
			if not has_manager(str(sid)):
				continue
			for ing in station_supplies(str(sid)):
				_manager_buy(fid, str(ing))
	_quiet_end()


func _manager_buy(fid: String, ing: String) -> void:
	var cap := float(item_capacity(ing, fid))
	if cap <= 0.0:
		return
	var have := stock_at(fid, ing)
	if have > cap * MGR_BUY_AT:
		return
	var need := int(cap - have)
	if need <= 0:
		return
	var price := maxf(float(INGREDIENTS[ing]["price"]), 1.0)
	# Chừa lại một khoản trong ví cho người chơi còn tiền nâng cấp, mở khu —
	# chỉnh bằng chung.manager_buy_reserve trong balance.json (mặc định 0).
	var purse := maxf(money - MGR_BUY_RESERVE, 0.0)
	var qty: int = need
	if price * float(need) > purse:
		qty = int(purse / price)
	if qty <= 0:
		return
	if not _spend(price * float(qty)):
		return
	add_stock(fid, ing, float(qty))
	_emit_stock()
	_log("Quản lý %s nhập %d %s %s" % [str(floor_data(fid)["name"]).to_lower(), qty, str(INGREDIENTS[ing]["unit"]), str(INGREDIENTS[ing]["name"]).to_lower()])


# ---------------- Thu nhập khi vắng mặt ----------------

## Tính tiền kiếm được trong lúc người chơi không mở game.
## Tính tiền kiếm được trong lúc người chơi không mở game. Vẫn theo đúng luật
## lúc đang chơi: quầy nấu ra bán thành phẩm, menu ghép lại thành suất, bán được
## suất nào thì thu trọn tiền suất đó — không có nửa suất.
func _apply_offline(seconds: float) -> void:
	if seconds < 60.0:
		return
	# Chỉ chạy khi có người trông quầy, y như trước.
	var watched := false
	for id in all_station_ids():
		if is_station_open(str(id)) and has_manager(str(id)):
			watched = true
			break
	if not watched:
		return
	var span := minf(seconds, OFFLINE_MAX_SECONDS)
	# Bếp nấu được bao nhiêu phần mỗi loại trong quãng vắng mặt đó — kho tách theo
	# khu nên quầy nào cũng chỉ đụng tới nguyên liệu của khu mình.
	for id in all_station_ids():
		if not is_station_open(str(id)) or not has_manager(str(id)):
			continue
		var out := str(station_def(str(id)).get("out", ""))
		if out.is_empty():
			continue
		var sfid := station_floor(str(id))
		var made := int(span / station_cycle(str(id)) * OFFLINE_RATE * float(station_batch(str(id))))
		var recipe: Dictionary = station_def(str(id))["recipe"]
		for ing in recipe:
			var per := float(recipe[ing])
			if per > 0.0:
				made = mini(made, int(stock_at(sfid, str(ing)) / per))
		if made <= 0:
			continue
		for ing in recipe:
			_use_ingredient(sfid, str(ing), float(recipe[ing]) * float(made))
		add_stock(sfid, out, float(made))
	# Khách ghé trong quãng đó ăn hết chừng nào thì thu chừng đó. Mỗi khu bán món
	# của khu mình bằng hàng của khu mình; khu nào có shipper thì thêm một dòng
	# hộp cơm giao đi, cũng lấy hàng ngay tại khu đó.
	var guests := int(span * arrival_rate() / 60.0 * OFFLINE_RATE)
	var total := 0
	var portions := 0
	var wheres: Array = []
	for f in FLOORS:
		var ofid := str(f["id"])
		if not is_floor_unlocked(ofid):
			continue
		wheres.append({"where": ofid, "fid": ofid})
		if staff_count(ofid, "shipper") > 0:
			wheres.append({"where": "ship", "fid": ofid})
	if wheres.is_empty():
		return
	var dry := 0
	for i in guests:
		var slot: Dictionary = wheres[i % wheres.size()]
		var did := take_order(str(slot["where"]), str(slot["fid"]))
		if did.is_empty():
			# cả bếp lẫn menu đều sạch trơn thì có chờ thêm cũng vậy, nghỉ sớm
			dry += 1
			if dry >= wheres.size():
				break
			continue
		dry = 0
		total += dish_price(did)
		portions += 1
	if total <= 0:
		return
	money += float(total)
	served_today += portions
	_bump("served", float(portions))
	_bump("earned", float(total))
	money_changed.emit()
	stock_changed.emit()
	offline_earned.emit({"amount": float(total), "seconds": span, "portions": portions})


# ---------------- Mua sắm ----------------

func can_afford(cost: float) -> bool:
	return money >= cost


func debug_add_money(amount: float) -> void:
	# Cửa sau lúc test: nhét thẳng tiền vào ví, không đụng tới doanh thu hay uy tín.
	money = maxf(0.0, money + float(round(amount)))
	money_changed.emit()
	_log("Gỡ lỗi: cộng %s ₫" % UIKit.money(amount))


func _spend(cost: float) -> bool:
	# Mọi khoản chi chốt về số nguyên đồng: trong game không có tiền lẻ.
	var due := float(round(cost))
	if money < due:
		return false
	money -= due
	money_changed.emit()
	return true


## Nhập hàng về kho của MỘT khu. Kho tách theo khu rồi nên mua gì cũng phải nói
## rõ mua cho khu nào; bỏ trống thì mặc định là khu vỉa hè.
func buy_ingredient(id: String, packs: int = 1, fid: String = "") -> bool:
	if fid.is_empty():
		fid = str(FLOORS[0]["id"])
	if not is_floor_unlocked(fid):
		return false
	var qty := int(INGREDIENTS[id]["pack"]) * packs
	# Món nào cũng có trần kho: kho chật thì cắt bớt cho vừa, tiền cũng chỉ trả
	# đúng phần nhét vô được — nhập dư rồi đổ đi thì phí của.
	if is_stored(id):
		qty = mini(qty, int(stock_room(id, fid)))
		if qty <= 0:
			return false
	var cost := float(INGREDIENTS[id]["price"]) * qty
	if not _spend(cost):
		return false
	add_stock(fid, id, float(qty))
	_emit_stock()
	_log("Nhập %d %s %s cho %s" % [qty, str(INGREDIENTS[id]["unit"]), str(INGREDIENTS[id]["name"]).to_lower(), str(floor_data(fid)["name"]).to_lower()])
	return true


## Nhập nhanh nên nhập tới đâu: đầy đúng trần kho của món đó ở khu đó.
func stock_target(id: String, fid: String) -> float:
	return float(item_capacity(id, fid)) if is_stored(id) else 0.0


## Đi một vòng chợ nhập cho đầy kho. Món nào đã đầy thì bỏ qua chứ không làm
## kẹt mấy món còn thiếu — trước đây chỉ nhập đúng một lố cho món dưới mốc, nên
## kho lạnh rộng ra là bấm hoài vẫn thấy thiếu.
## Nhập xoay vòng mỗi lượt một lố, món cạn nhất đi trước, để tiền chia đều cho
## mọi món chứ không dồn hết vào món đầu tiên. Hết tiền thì dừng.
## Trả về số loại thực sự nhập được.
func buy_all_low(fid: String) -> int:
	if not is_floor_unlocked(fid):
		return 0
	_quiet_begin()
	var order: Array = shop_ingredients()
	order.sort_custom(func(a, b) -> bool:
		var ra: float = stock_at(fid, str(a)) / maxf(stock_target(str(a), fid), 1.0)
		var rb: float = stock_at(fid, str(b)) / maxf(stock_target(str(b), fid), 1.0)
		return ra < rb)

	var bought: Dictionary = {}
	var again := true
	while again:
		again = false
		for id in order:
			var sid := str(id)
			var pack := int(INGREDIENTS[sid]["pack"])
			if pack <= 0:
				continue
			if stock_at(fid, sid) >= stock_target(sid, fid):
				continue
			if money < float(INGREDIENTS[sid]["price"]) * float(pack):
				continue
			if not buy_ingredient(sid, 1, fid):
				continue
			bought[sid] = true
			again = true
	_quiet_end()
	return bought.size()


## Nhập một lượt cho cả ba khu, khỏi phải bấm qua bấm lại từng khu.
func buy_all_low_everywhere() -> int:
	_quiet_begin()
	var n := 0
	for f in FLOORS:
		n += buy_all_low(str(f["id"]))
	_quiet_end()
	return n


## Thuê thêm một người cho khu `fid` — khu nào trả lương khu nấy, khu chưa mở
## thì chưa thuê được ai. Người thứ hai trong cùng khu đắt gấp đôi người đầu.
func hire_staff(id: String, fid: String = "") -> bool:
	if fid.is_empty():
		fid = str(FLOORS[0]["id"])
	if not is_floor_unlocked(fid):
		return false
	if staff_count(fid, id) >= staff_max(id):
		return false
	var have := staff_hired(fid, id)
	var cost := hire_cost(id, fid)
	if not _spend(cost):
		return false
	if typeof(staff.get(fid, null)) != TYPE_DICTIONARY:
		staff[fid] = {}
	(staff[fid] as Dictionary)[id] = have + 1
	_bump("staff")
	state_changed.emit()
	_log("Thuê thêm " + str(STAFF[id]["name"]).to_lower() + " cho "
		+ str(floor_data(fid)["name"]).to_lower())
	return true


## Giá thuê người tiếp theo loại `id` cho khu `fid`.
func hire_cost(id: String, fid: String) -> float:
	return float(STAFF[id]["cost"]) * (staff_hired(fid, id) + 1)


## Mua một món trang trí và đặt luôn vào khu `fid` — khu nào tiền khu nấy,
## khu chưa mở thì chưa bày biện gì được.
func buy_decor(id: String, fid: String = "") -> bool:
	if fid.is_empty():
		fid = str(FLOORS[0]["id"])
	if not is_floor_unlocked(fid):
		return false
	if not _spend(float(DECOR[id]["cost"])):
		return false
	if typeof(decor.get(fid, null)) != TYPE_DICTIONARY:
		decor[fid] = {}
	(decor[fid] as Dictionary)[id] = decor_count(fid, id) + 1
	_bump("decor")
	reputation = minf(100.0, reputation + 1.0)
	state_changed.emit()
	_log("Mua " + str(DECOR[id]["name"]).to_lower() + " cho " + str(floor_data(fid)["name"]).to_lower())
	return true


# ---------------- Bàn ghế: mua rồi tự đặt ----------------

## Số bộ đã mua nhưng chưa đặt xuống.
func furniture_stock(kind: String) -> int:
	return int(furniture.get(kind, 0))


func furniture_pending() -> int:
	var n := 0
	for k in furniture:
		n += int(furniture[k])
	return n


func buy_furniture(kind: String) -> bool:
	if not FURNITURE.has(kind):
		return false
	if not _spend(float(FURNITURE[kind]["cost"])):
		return false
	furniture[kind] = furniture_stock(kind) + 1
	_bump("decor")
	state_changed.emit()
	_log("Mua " + str(FURNITURE[kind]["name"]).to_lower())
	return true


## Đặt một bộ trong kho xuống vị trí đã chọn. Trả về chỉ số trong `placed`.
func place_furniture(kind: String, floor_i: int, zone: String, x: float, z: float, rot: int) -> int:
	if furniture_stock(kind) <= 0:
		return -1
	furniture[kind] = furniture_stock(kind) - 1
	placed.append({"kind": kind, "floor": floor_i, "zone": zone,
		"x": snappedf(x, 0.05), "z": snappedf(z, 0.05), "rot": rot})
	reputation = minf(100.0, reputation + 0.5)
	state_changed.emit()
	_log("Kê " + str(FURNITURE[kind]["name"]).to_lower() + (" ngoài vỉa hè" if zone == "out" else " trong quán"))
	return placed.size() - 1


func move_furniture(index: int, floor_i: int, zone: String, x: float, z: float, rot: int) -> bool:
	if index < 0 or index >= placed.size():
		return false
	var it: Dictionary = placed[index]
	it["floor"] = floor_i
	it["zone"] = zone
	it["x"] = snappedf(x, 0.05)
	it["z"] = snappedf(z, 0.05)
	it["rot"] = rot
	state_changed.emit()
	return true


## Cất bàn về kho (không mất tiền, đặt lại lúc nào cũng được).
func store_furniture(index: int) -> bool:
	if index < 0 or index >= placed.size():
		return false
	var it: Dictionary = placed[index]
	var kind := str(it.get("kind", ""))
	placed.remove_at(index)
	furniture[kind] = furniture_stock(kind) + 1
	state_changed.emit()
	return true


## Bán lại bàn đã đặt, thu về một nửa giá.
func sell_furniture(index: int) -> float:
	if index < 0 or index >= placed.size():
		return 0.0
	var it: Dictionary = placed[index]
	var kind := str(it.get("kind", ""))
	var back := float(FURNITURE.get(kind, {}).get("cost", 0)) * 0.5
	placed.remove_at(index)
	money += back
	money_changed.emit()
	state_changed.emit()
	_log("Bán lại " + str(FURNITURE.get(kind, {}).get("name", "bàn")).to_lower())
	return back


func upgrade_station(id: String) -> bool:
	if not is_floor_unlocked(station_floor(id)) or station_at_max(id):
		return false
	if not _spend(station_upgrade_cost(id)):
		return false
	levels[id] = station_level(id) + 1
	_bump("upgrades")
	state_changed.emit()
	_log("%s %s lên cấp %d" % [str(station_def(id)["name"]),
		str(floor_data(station_floor(id))["name"]).to_lower(), station_level(id)])
	return true


func hire_manager(id: String) -> bool:
	if has_manager(id) or not is_station_open(id):
		return false
	if not _spend(manager_cost(id)):
		return false
	managers[id] = true
	_bump("managers")
	state_changed.emit()
	_log("Thuê quản lý cho %s %s" % [str(station_def(id)["name"]).to_lower(),
		str(floor_data(station_floor(id))["name"]).to_lower()])
	return true


func unlock_floor(fid: String) -> bool:
	if is_floor_unlocked(fid):
		return false
	var f := floor_data(fid)
	if not _spend(float(f["cost"])):
		return false
	floors_unlocked[fid] = true
	for id in stations_on_floor(fid):
		if station_level(id) <= 0:
			levels[id] = 1
	_bump("floors")
	reputation = minf(100.0, reputation + 5.0)
	state_changed.emit()
	_log("Mở " + str(f["name"]).to_lower())
	return true


## Đặt giá bán một món trong menu. Chốt lại thành số nguyên nghìn cho khỏi có
## đồng lẻ, và không cho bán dưới vốn.
func set_price(did: String, value: float) -> void:
	if not MENU.has(did):
		return
	var floor_price := dish_cost(did) * 1.05
	var top := float(MENU[did]["price"]) * 4.0
	prices[did] = int(round(clampf(value, floor_price, top) / 1000.0)) * 1000
	if float(prices[did]) < floor_price:
		prices[did] = int(ceil(floor_price / 1000.0)) * 1000
	state_changed.emit()


func suggest_all_prices() -> void:
	for did in MENU:
		prices[did] = dish_suggested_price(str(did))
	state_changed.emit()


## Báo "kho vừa đổi" — trừ lúc đang mua cả loạt thì im, để _quiet_end() phát một
## lần cho cả loạt.
func _emit_stock() -> void:
	if _stock_quiet <= 0:
		stock_changed.emit()


func _quiet_begin() -> void:
	_stock_quiet += 1


func _quiet_end() -> void:
	_stock_quiet = maxi(_stock_quiet - 1, 0)
	if _stock_quiet == 0:
		stock_changed.emit()


func _log(msg: String) -> void:
	logs.append(msg)
	if logs.size() > 40:
		logs.remove_at(0)
	log_added.emit(msg)


# ---------------- Lưu / tải ----------------

func reset_game() -> void:
	_reset_defaults()
	money_changed.emit()
	stock_changed.emit()
	state_changed.emit()
	save_game()


func save_game() -> void:
	var data := {
		"money": money, "day": day, "day_time": day_time, "reputation": reputation,
		"stock": stock, "prices": prices, "levels": levels, "pending": pending,
		"pending_portions": pending_portions, "managers": managers,
		"staff": staff, "decor": decor, "floors": floors_unlocked,
		"stores": stores, "store_levels": store_levels,
		"grill_level": grill_level, "warmer_level": warmer_level,
		"furniture": furniture, "placed": placed,
		"ing_debt": ing_debt,
		"auto_open": auto_open, "stats": stats, "claimed": claimed,
		"last_seen": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	money = float(round(float(data.get("money", money))))
	day = int(data.get("day", day))
	day_time = float(data.get("day_time", 0.0))
	reputation = float(data.get("reputation", reputation))
	auto_open = bool(data.get("auto_open", true))
	# Save đời cũ ghi phẳng {món: số lượng} vì hồi đó cả quán chung một cái kho.
	# Gặp kiểu đó thì dồn hết về khu đầu, coi như hàng đang chất ngoài vỉa hè —
	# không mất món nào, mấy khu trên bắt đầu với kho trống.
	var d_stock = data.get("stock", {})
	if typeof(d_stock) == TYPE_DICTIONARY:
		var flat_stock := false
		for sk in d_stock:
			if typeof(d_stock[sk]) != TYPE_DICTIONARY:
				flat_stock = true
				break
		for sf in FLOORS:
			var sfid := str(sf["id"])
			var ssrc: Dictionary = {}
			if flat_stock:
				ssrc = d_stock if sfid == str(FLOORS[0]["id"]) else {}
			elif typeof(d_stock.get(sfid, null)) == TYPE_DICTIONARY:
				ssrc = d_stock[sfid]
			var sroom: Dictionary = {}
			for id in INGREDIENTS:
				# kho luôn là số nguyên: save đời cũ có phần lẻ thì gọt đi
				sroom[id] = float(int(float(ssrc.get(id, 0.0))))
			stock[sfid] = sroom
	var d_prices = data.get("prices", {})
	if typeof(d_prices) == TYPE_DICTIONARY:
		for did in MENU:
			prices[did] = int(d_prices.get(did, prices[did]))
	var d_levels = data.get("levels", {})
	var d_pending = data.get("pending", {})
	var d_portions = data.get("pending_portions", {})
	var d_mgr = data.get("managers", {})
	# Save đời cũ ghi khoá trần ("rice") vì hồi đó bốn quầy là bếp chung cả quán.
	# Gặp kiểu đó thì coi như đó là dãy quầy ngoài vỉa hè, mấy khu trên bắt đầu
	# lại từ cấp 1 — không ai mất cấp đã nâng.
	var first_fid := str(FLOORS[0]["id"])
	for id in all_station_ids():
		var legacy: String = station_base(id) if station_floor(id) == first_fid else id
		if typeof(d_levels) == TYPE_DICTIONARY:
			levels[id] = int(d_levels.get(id, d_levels.get(legacy, levels.get(id, 0))))
		if typeof(d_pending) == TYPE_DICTIONARY:
			pending[id] = float(d_pending.get(id, d_pending.get(legacy, 0.0)))
		if typeof(d_portions) == TYPE_DICTIONARY:
			pending_portions[id] = float(d_portions.get(id, d_portions.get(legacy, 0.0)))
		if typeof(d_mgr) == TYPE_DICTIONARY:
			managers[id] = bool(d_mgr.get(id, d_mgr.get(legacy, false)))
	var d_staff = data.get("staff", {})
	if typeof(d_staff) == TYPE_DICTIONARY:
		# Save đời cũ ghi phẳng {staff_id: số lượng} vì hồi đó nhân viên dùng chung
		# cả quán. Gặp kiểu đó thì dồn hết về khu đầu, coi như mọi người đang đứng
		# ngoài vỉa hè — không ai bị đuổi việc.
		var flat_staff := false
		for sk in d_staff:
			if typeof(d_staff[sk]) != TYPE_DICTIONARY:
				flat_staff = true
				break
		for sf in FLOORS:
			var sfid := str(sf["id"])
			var ssrc: Dictionary = {}
			if flat_staff:
				ssrc = d_staff if sfid == str(FLOORS[0]["id"]) else {}
			elif typeof(d_staff.get(sfid, null)) == TYPE_DICTIONARY:
				ssrc = d_staff[sfid]
			var crew: Dictionary = {}
			for sid in STAFF:
				# save đời cũ thuê được nhiều hơn: cắt cho vừa phần thuê thêm còn lại
				var room := maxi(staff_max(str(sid)) - int(STAFF[sid].get("free", 0)), 0)
				crew[sid] = mini(int(ssrc.get(sid, 0)), room)
			staff[sfid] = crew
	var d_decor = data.get("decor", {})
	if typeof(d_decor) == TYPE_DICTIONARY:
		# Save đời cũ ghi phẳng {decor_id: số lượng} vì hồi đó trang trí dùng chung
		# cả quán. Gặp kiểu đó thì dồn hết về khu đầu tiên, coi như đồ đang bày ở
		# vỉa hè — không ai mất món nào.
		var flat := false
		for k in d_decor:
			if typeof(d_decor[k]) != TYPE_DICTIONARY:
				flat = true
			break
		for fl in FLOORS:
			var fid := str(fl["id"])
			var src: Dictionary = {}
			if flat:
				src = d_decor if fid == str(FLOORS[0]["id"]) else {}
			elif typeof(d_decor.get(fid, null)) == TYPE_DICTIONARY:
				src = d_decor[fid]
			var row: Dictionary = {}
			for id in DECOR:
				row[id] = int(src.get(id, 0))
			decor[fid] = row
	# Save đời cũ chỉ có tủ lạnh, ghi phẳng ở "fridges"/"fridge_levels"; đọc lại
	# thì coi như đó là kho "fridge", còn kho đồ khô thì khu nào cũng chưa có kệ.
	var d_stores = data.get("stores", {})
	var d_slevel = data.get("store_levels", {})
	for kind in STORAGE:
		var k := str(kind)
		var src = (d_stores as Dictionary).get(k, {}) if typeof(d_stores) == TYPE_DICTIONARY else {}
		var srcl = (d_slevel as Dictionary).get(k, {}) if typeof(d_slevel) == TYPE_DICTIONARY else {}
		if k == "fridge":
			if typeof(src) != TYPE_DICTIONARY or (src as Dictionary).is_empty():
				src = data.get("fridges", {})
			if typeof(srcl) != TYPE_DICTIONARY or (srcl as Dictionary).is_empty():
				srcl = data.get("fridge_levels", {})
		var cnt: Dictionary = {}
		var lvs: Dictionary = {}
		for fr_f in FLOORS:
			var fr_id := str(fr_f["id"])
			var n := 0
			if typeof(src) == TYPE_DICTIONARY:
				n = int((src as Dictionary).get(fr_id, 0))
			cnt[fr_id] = clampi(n, 0, store_max(k))
			var lv := 1
			if typeof(srcl) == TYPE_DICTIONARY:
				lv = int((srcl as Dictionary).get(fr_id, 1))
			lvs[fr_id] = clampi(lv, 1, MAX_LEVEL)
		stores[k] = cnt
		store_levels[k] = lvs

	var d_furni = data.get("furniture", {})
	if typeof(d_furni) == TYPE_DICTIONARY:
		for id in FURNITURE:
			furniture[id] = int(d_furni.get(id, 0))
	var d_placed = data.get("placed", null)
	if typeof(d_placed) == TYPE_ARRAY:
		placed.clear()
		for raw in d_placed:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var kind := str(raw.get("kind", ""))
			if not FURNITURE.has(kind):
				continue
			placed.append({"kind": kind, "floor": int(raw.get("floor", 0)),
				"zone": str(raw.get("zone", "in")), "x": float(raw.get("x", 0.0)),
				"z": float(raw.get("z", 0.0)), "rot": int(raw.get("rot", 0))})
	grill_level = maxi(1, int(data.get("grill_level", 1)))
	warmer_level = maxi(1, int(data.get("warmer_level", 1)))
	# Ván cũ lưu trước khi lò giữ nhiệt có sức chứa thì sườn nướng có thể đang
	# nhiều hơn cả cái lò: gạt phần dư đi một lần cho khớp luật mới.
	if not data.has("warmer_level"):
		for wf in FLOORS:
			var wfid := str(wf["id"])
			add_stock(wfid, "grilled", minf(0.0, float(warmer_capacity()) - stock_at(wfid, "grilled")))
	var d_floors = data.get("floors", {})
	if typeof(d_floors) == TYPE_DICTIONARY:
		for fl in FLOORS:
			floors_unlocked[fl["id"]] = bool(d_floors.get(fl["id"], fl["cost"] == 0))
	# chỗ lẻ của công thức: không nhớ lại thì tải game xong là được ăn không phần lẻ
	var d_debt = data.get("ing_debt", {})
	if typeof(d_debt) == TYPE_DICTIONARY:
		ing_debt.clear()
		var flat_debt := false
		for dk in d_debt:
			if typeof(d_debt[dk]) != TYPE_DICTIONARY:
				flat_debt = true
				break
		for df in FLOORS:
			var dfid := str(df["id"])
			var dsrc: Dictionary = {}
			if flat_debt:
				dsrc = d_debt if dfid == str(FLOORS[0]["id"]) else {}
			elif typeof(d_debt.get(dfid, null)) == TYPE_DICTIONARY:
				dsrc = d_debt[dfid]
			var drow: Dictionary = {}
			for id in INGREDIENTS:
				var owed := float(dsrc.get(id, 0.0))
				if owed > 0.0:
					drow[id] = clampf(owed, 0.0, 1.0)
			ing_debt[dfid] = drow
	var d_stats = data.get("stats", {})
	if typeof(d_stats) == TYPE_DICTIONARY:
		for k in stats:
			stats[k] = float(d_stats.get(k, stats[k]))
	var d_claimed = data.get("claimed", {})
	if typeof(d_claimed) == TYPE_DICTIONARY:
		for m in MISSIONS:
			claimed[m["id"]] = bool(d_claimed.get(m["id"], false))
	# Ván cũ lưu hồi kho còn vô hạn thì có món đang nhiều hơn cả cái kho: gạt phần
	# dư cho khớp luật mới, coi như để lâu quá phải bỏ.
	for cf in FLOORS:
		var cfid := str(cf["id"])
		for cid in INGREDIENTS:
			var cap := INF
			if is_stored(str(cid)):
				cap = float(item_capacity(str(cid), cfid))
			elif str(cid) == "grilled":
				cap = float(warmer_capacity())
			if stock_at(cfid, str(cid)) > cap:
				add_stock(cfid, str(cid), cap - stock_at(cfid, str(cid)))
	last_seen = float(data.get("last_seen", Time.get_unix_time_from_system()))
	money_changed.emit()
	stock_changed.emit()
	state_changed.emit()
	return true
