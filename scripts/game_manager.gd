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
## Xong một mẻ nướng: sân khấu 3D cho người đứng lò bưng thịt vào trong quán.
signal grill_batch_ready(count: int)

const SAVE_PATH := "user://com_tam_save.json"
const DAY_DURATION := 180.0   # giây cho mỗi "ngày" trong game

# ---------------- Dữ liệu tĩnh ----------------

const FLOORS := [
    {"id": "street", "name": "Quán vỉa hè", "note": "Ngõ chợ Bàn Cờ · Q.3", "cost": 0},
    {"id": "aircon", "name": "Phòng máy lạnh", "note": "Khách văn phòng, giá cao hơn", "cost": 2500000},
    {"id": "rooftop", "name": "Khu sân vườn", "note": "Bàn VIP, nướng than hoa", "cost": 12000000},
]

const INGREDIENTS := {
    "rice": {"name": "Gạo tấm", "unit": "kg", "price": 8000, "pack": 50},
    "pork": {"name": "Sườn heo", "unit": "miếng", "price": 15000, "pack": 50},
    "egg": {"name": "Trứng gà", "unit": "quả", "price": 4000, "pack": 100},
    "bi": {"name": "Bì heo", "unit": "phần", "price": 6000, "pack": 50},
    "cha": {"name": "Chả trứng", "unit": "miếng", "price": 10000, "pack": 50},
    "veg": {"name": "Đồ chua · rau", "unit": "hũ", "price": 3000, "pack": 50},
    "tea": {"name": "Trà · đá", "unit": "bình", "price": 5000, "pack": 50},
    "coal": {"name": "Than đá", "unit": "bao", "price": 24000, "pack": 20},
    ## Sườn nướng sẵn không mua được ngoài chợ: phải tự nướng ở lò than vỉa hè.
    "grilled": {"name": "Sườn nướng sẵn", "unit": "miếng", "price": 19000, "pack": 0,
        "shop": false},
}


## Chỉ những thứ bán ngoài chợ mới hiện trong màn Mua sắm.
static func shop_ingredients() -> Array:
    var out: Array = []
    for id in INGREDIENTS:
        if bool(INGREDIENTS[id].get("shop", true)):
            out.append(id)
    return out

## Mỗi quầy = một món; vị trí trong không gian 3D do TycoonWorld tự xếp theo khu.
const STATIONS := {
    "grill": {"floor": "street", "name": "Lò nướng sườn", "dish": "Cơm tấm sườn", "glyph": "▤",
        "recipe": {"rice": 1, "grilled": 1, "veg": 1}, "base_price": 45000, "cycle": 12.0,
        "batch": 2, "up_cost": 120000},
    "rice": {"floor": "street", "name": "Nồi cơm tấm", "dish": "Cơm tấm trứng", "glyph": "▦",
        "recipe": {"rice": 1, "egg": 2}, "base_price": 35000, "cycle": 10.0,
        "batch": 2, "up_cost": 90000},
    "prep": {"floor": "street", "name": "Bàn bì & chả", "dish": "Cơm tấm bì chả", "glyph": "▩",
        "recipe": {"rice": 1, "bi": 1, "cha": 1}, "base_price": 50000, "cycle": 15.0,
        "batch": 2, "up_cost": 160000},
    "drink": {"floor": "street", "name": "Quầy trà đá", "dish": "Trà đá · nước sâm", "glyph": "▥",
        "recipe": {"tea": 1}, "base_price": 10000, "cycle": 8.0,
        "batch": 3, "up_cost": 60000},

    "combo": {"floor": "aircon", "name": "Bàn cơm phần", "dish": "Cơm tấm thập cẩm", "glyph": "▣",
        "recipe": {"rice": 1, "pork": 1, "bi": 1, "cha": 1, "egg": 1}, "base_price": 85000, "cycle": 20.0,
        "batch": 2, "up_cost": 320000},
    "dessert": {"floor": "aircon", "name": "Quầy chè", "dish": "Chè · sương sáo", "glyph": "◍",
        "recipe": {"veg": 1, "tea": 1}, "base_price": 25000, "cycle": 12.0,
        "batch": 3, "up_cost": 210000},
    "office": {"floor": "aircon", "name": "Cơm hộp văn phòng", "dish": "Cơm hộp giao đi", "glyph": "▤",
        "recipe": {"rice": 1, "pork": 1, "veg": 1}, "base_price": 60000, "cycle": 16.0,
        "batch": 3, "up_cost": 400000},

    "bbq": {"floor": "rooftop", "name": "Lò than hoa", "dish": "Sườn nướng than", "glyph": "▤",
        "recipe": {"pork": 2, "veg": 1}, "base_price": 140000, "cycle": 22.0,
        "batch": 2, "up_cost": 900000},
    "vip": {"floor": "rooftop", "name": "Bàn VIP", "dish": "Set cơm tấm VIP", "glyph": "✦",
        "recipe": {"rice": 2, "pork": 1, "cha": 1, "egg": 1}, "base_price": 220000, "cycle": 30.0,
        "batch": 1, "up_cost": 1500000},
    "juice": {"floor": "rooftop", "name": "Quầy nước ép", "dish": "Nước ép trái cây", "glyph": "▥",
        "recipe": {"veg": 1, "tea": 1}, "base_price": 45000, "cycle": 12.0,
        "batch": 3, "up_cost": 600000},
}

## Lò than vỉa hè: nướng cả mẻ sườn cùng lúc, xong thì bưng vào quầy trong quán.
## Nâng cấp lò = mỗi mẻ nướng được nhiều miếng hơn.
const GRILL_BATCH_BASE := 10       # số miếng một mẻ lúc lò còn cấp 1
const GRILL_BATCH_STEP := 4        # mỗi cấp thêm chừng này miếng
const GRILL_CYCLE := 24.0          # giây cho trọn một mẻ
const GRILL_COAL := 1.0            # bao than cháy hết cho mỗi mẻ
const GRILL_UP_COST := 240000.0

## Quản lý: thuê cho từng quầy để tự động thu tiền.
const MANAGER_COST_MULT := 6.0

## Nhân viên chung của quán.
const STAFF := {
    "cook": {"name": "Phụ bếp", "desc": "-12% thời gian mỗi mẻ (cộng dồn)", "cost": 400000, "salary": 30000, "max": 5},
    "waiter": {"name": "Phục vụ", "desc": "+2 chỗ ngồi, khách chờ lâu hơn", "cost": 300000, "salary": 22000, "max": 5},
    "cashier": {"name": "Thu ngân", "desc": "+8% doanh thu mỗi người", "cost": 500000, "salary": 35000, "max": 4},
    "shipper": {"name": "Shipper", "desc": "+6% khách tới mỗi người", "cost": 350000, "salary": 25000, "max": 5},
}

const DECOR := {
    "plant": {"name": "Chậu cây xanh", "desc": "+2 điểm không khí", "cost": 120000, "amb": 2},
    "lantern": {"name": "Đèn lồng", "desc": "+3 điểm không khí", "cost": 200000, "amb": 3},
    "sign": {"name": "Bảng hiệu đèn LED", "desc": "+5 điểm không khí, khách tới nhanh", "cost": 450000, "amb": 5},
    "fan": {"name": "Quạt hơi nước", "desc": "+3 điểm không khí", "cost": 300000, "amb": 3},
    "table": {"name": "Bộ bàn ghế inox", "desc": "+2 chỗ ngồi", "cost": 380000, "seats": 2},
    "aquarium": {"name": "Bể cá cảnh", "desc": "+8 điểm không khí", "cost": 900000, "amb": 8},
}

## Bàn ghế mua rời rồi tự tay đặt vào quán.
## "zone": "in" = trong nhà · "out" = vỉa hè · "any" = đặt đâu cũng được.
## "w"/"d" là bề ngang · bề sâu chỗ chiếm (mét) dùng để kiểm tra chồng chỗ.
const FURNITURE := {
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
const OFFLINE_MAX_SECONDS := 14400.0
const OFFLINE_RATE := 0.5

## Nhiệm vụ: "kind" là tên chỉ số trong `stats`, đạt "target" thì nhận thưởng.
const MISSIONS := [
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

var stock: Dictionary = {}          # id -> số lượng
var prices: Dictionary = {}         # station_id -> giá bán
var levels: Dictionary = {}         # station_id -> cấp (0 = chưa mở)
var progress: Dictionary = {}       # station_id -> 0..1 tiến độ mẻ hiện tại
var pending: Dictionary = {}        # station_id -> tiền đang chờ thu
var pending_portions: Dictionary = {}  # station_id -> số phần chưa bán
var managers: Dictionary = {}       # station_id -> bool (tự thu)
var staff: Dictionary = {}          # staff_id -> số lượng
var decor: Dictionary = {}          # decor_id -> số lượng
var furniture: Dictionary = {}      # kind -> số bộ đã mua nhưng chưa đặt
var placed: Array = []              # bàn ghế đã đặt: {kind, floor, zone, x, z, rot}
var floors_unlocked: Dictionary = {}
var grill_level := 1                # cấp lò than vỉa hè
var grill_progress := 0.0           # mẻ đang nướng, 0..1

var stats: Dictionary = {}       # chỉ số cộng dồn cho nhiệm vụ
var claimed: Dictionary = {}     # mission_id -> đã nhận thưởng
var last_seen := 0.0             # unix time lần cuối thoát game

var served_today := 0
var earned_today := 0.0
var lost_today := 0
var logs: Array[String] = []


func _ready() -> void:
    _reset_defaults()
    if FileAccess.file_exists(SAVE_PATH):
        if load_game():
            _apply_offline(Time.get_unix_time_from_system() - last_seen)
    process_mode = Node.PROCESS_MODE_ALWAYS


func _reset_defaults() -> void:
    money = 3000000.0
    day = 1
    day_time = 0.0
    reputation = 50.0
    served_today = 0
    earned_today = 0.0
    lost_today = 0
    logs.clear()
    stock.clear()
    for id in INGREDIENTS:
        stock[id] = 150.0
    stock["coal"] = 40.0
    stock["grilled"] = 0.0      # sườn nướng sẵn phải tự nướng, không có sẵn trong kho
    prices.clear()
    levels.clear()
    progress.clear()
    pending.clear()
    pending_portions.clear()
    managers.clear()
    for id in STATIONS:
        prices[id] = int(STATIONS[id]["base_price"])
        levels[id] = 1 if STATIONS[id]["floor"] == "street" else 0
        progress[id] = 0.0
        pending[id] = 0.0
        pending_portions[id] = 0.0
        managers[id] = false
    staff.clear()
    for id in STAFF:
        staff[id] = 0
    decor.clear()
    for id in DECOR:
        decor[id] = 0
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
    grill_progress = 0.0
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


func stations_on_floor(fid: String) -> Array:
    var out: Array = []
    for id in STATIONS:
        if STATIONS[id]["floor"] == fid:
            out.append(id)
    return out


func station_level(id: String) -> int:
    return int(levels.get(id, 0))


func is_station_open(id: String) -> bool:
    return station_level(id) > 0 and is_floor_unlocked(str(STATIONS[id]["floor"]))


func station_upgrade_cost(id: String) -> int:
    var lv := station_level(id)
    return int(round(float(STATIONS[id]["up_cost"]) * pow(1.45, maxi(lv, 0))))


func manager_cost(id: String) -> int:
    return int(round(float(STATIONS[id]["up_cost"]) * MANAGER_COST_MULT))


func has_manager(id: String) -> bool:
    return bool(managers.get(id, false))


## Thời gian một mẻ, đã tính cấp quầy và phụ bếp.
func station_cycle(id: String) -> float:
    var lv := maxi(station_level(id), 1)
    var t := float(STATIONS[id]["cycle"]) / (1.0 + 0.05 * (lv - 1))
    t *= pow(0.88, float(staff.get("cook", 0)))
    return maxf(t, 0.6)


## Số phần làm ra mỗi mẻ.
func station_batch(id: String) -> int:
    var lv := maxi(station_level(id), 1)
    return int(STATIONS[id]["batch"]) + int(floor((lv - 1) / 4.0))


## Một mẻ nướng được bao nhiêu miếng sườn.
func grill_batch() -> int:
    return GRILL_BATCH_BASE + (grill_level - 1) * GRILL_BATCH_STEP


func grill_upgrade_cost() -> float:
    return GRILL_UP_COST * pow(1.8, float(grill_level - 1))


## Lò có đang đỏ lửa không: phải còn sườn sống cho cả mẻ và còn than.
func grill_running() -> bool:
    return float(stock.get("pork", 0.0)) >= float(grill_batch()) \
        and float(stock.get("coal", 0.0)) >= GRILL_COAL


func upgrade_grill() -> bool:
    var cost := grill_upgrade_cost()
    if not _spend(cost):
        return false
    grill_level += 1
    _bump("upgrades")
    state_changed.emit()
    _log("Nâng lò than lên cấp %d — mỗi mẻ %d miếng" % [grill_level, grill_batch()])
    return true


func station_price(id: String) -> float:
    return float(prices.get(id, STATIONS[id]["base_price"]))


func station_cost_per_portion(id: String) -> float:
    var total := 0.0
    var recipe: Dictionary = STATIONS[id]["recipe"]
    for ing in recipe:
        total += float(INGREDIENTS[ing]["price"]) * float(recipe[ing])
    return total


func suggested_price(id: String) -> int:
    return int(ceil(station_cost_per_portion(id) * 2.2 / 1000.0) * 1000.0)


## Hệ số khách theo giá: giá càng cao càng ít khách.
func price_appeal(id: String) -> float:
    var ratio := station_price(id) / maxf(float(STATIONS[id]["base_price"]), 1.0)
    return clampf(1.6 - 0.6 * ratio, 0.15, 1.4)


func revenue_multiplier() -> float:
    return 1.0 + 0.08 * float(staff.get("cashier", 0))


func ambiance() -> int:
    var total := furniture_ambiance()
    for id in DECOR:
        if DECOR[id].has("amb"):
            total += int(decor.get(id, 0)) * int(DECOR[id]["amb"])
    return total


## Số chỗ ngồi do bàn ghế tự đặt mang lại.
func furniture_seats() -> int:
    var s := 0
    for it in placed:
        var kind := str((it as Dictionary).get("kind", ""))
        if FURNITURE.has(kind):
            s += int(FURNITURE[kind]["seats"])
    return s


func furniture_ambiance() -> int:
    var a := 0
    for it in placed:
        var kind := str((it as Dictionary).get("kind", ""))
        if FURNITURE.has(kind):
            a += int(FURNITURE[kind].get("amb", 0))
    return a


func seats() -> int:
    var s := 4 + int(staff.get("waiter", 0)) * 2 + furniture_seats()
    for id in DECOR:
        if DECOR[id].has("seats"):
            s += int(decor.get(id, 0)) * int(DECOR[id]["seats"])
    for f in FLOORS:
        if f["cost"] > 0 and is_floor_unlocked(str(f["id"])):
            s += 4
    return s


## Số khách tới mỗi phút (dùng cho cả phần hiển thị 3D).
func arrival_rate() -> float:
    var base := 8.0
    base *= 1.0 + reputation / 100.0
    base *= 1.0 + float(ambiance()) * 0.015
    base *= 1.0 + 0.06 * float(staff.get("shipper", 0))
    var appeal := 0.0
    var n := 0
    for id in STATIONS:
        if is_station_open(id):
            appeal += price_appeal(id)
            n += 1
    if n > 0:
        base *= appeal / float(n)
    return maxf(base, 0.5)


func total_pending() -> float:
    var t := 0.0
    for id in pending:
        t += float(pending[id])
    return t


func daily_salary() -> float:
    var total := 0.0
    for id in STAFF:
        total += float(staff.get(id, 0)) * float(STAFF[id]["salary"])
    return total


func has_ingredients(id: String, times: int = 1) -> bool:
    var recipe: Dictionary = STATIONS[id]["recipe"]
    for ing in recipe:
        if float(stock.get(ing, 0.0)) < float(recipe[ing]) * times:
            return false
    return true


func missing_ingredients() -> Array:
    var out: Array = []
    for ing in shop_ingredients():
        if float(stock.get(ing, 0.0)) <= 0.0:
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

    for id in STATIONS:
        if not is_station_open(id):
            continue
        var batch := station_batch(id)
        # Chỉ chạy khi còn nguyên liệu
        if progress[id] <= 0.0 and not has_ingredients(id, 1):
            continue
        progress[id] = float(progress[id]) + d / station_cycle(id)
        if float(progress[id]) >= 1.0:
            progress[id] = 0.0
            var made := 0
            for i in batch:
                if not has_ingredients(id, 1):
                    break
                var recipe: Dictionary = STATIONS[id]["recipe"]
                for ing in recipe:
                    stock[ing] = float(stock[ing]) - float(recipe[ing])
                made += 1
            if made > 0:
                pending_portions[id] = float(pending_portions[id]) + made
                dirty_stock = true
            else:
                _log("Hết nguyên liệu cho " + str(STATIONS[id]["name"]))

    # Bán phần ăn cho khách: mỗi giây bán được một lượng theo lượng khách tới.
    var per_sec := arrival_rate() / 60.0
    for id in STATIONS:
        if not is_station_open(id) or float(pending_portions[id]) <= 0.0:
            continue
        var share := per_sec * price_appeal(id) * d
        var sold := minf(float(pending_portions[id]), share)
        if sold <= 0.0:
            continue
        pending_portions[id] = float(pending_portions[id]) - sold
        var gain := sold * station_price(id) * revenue_multiplier()
        pending[id] = float(pending[id]) + gain
        served_today += int(sold)
        stats["served"] = float(stats.get("served", 0.0)) + sold
        stats["earned"] = float(stats.get("earned", 0.0)) + gain
        if has_manager(id):
            _collect_station(id)
            dirty_money = true
        bubble_changed.emit(id)

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
    for id in STATIONS:
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
    if not missing_ingredients().is_empty():
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
    var batch := grill_batch()
    stock["pork"] = float(stock.get("pork", 0.0)) - float(batch)
    stock["coal"] = float(stock.get("coal", 0.0)) - GRILL_COAL
    stock["grilled"] = float(stock.get("grilled", 0.0)) + float(batch)
    grill_batch_ready.emit(batch)
    _log("Nướng xong %d miếng sườn, bưng vào quầy" % batch)
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


# ---------------- Chạm để nấu nhanh ----------------

## Người chơi chạm vào quầy: đẩy nhanh mẻ đang nấu (phần chơi chủ động).
func boost_station(id: String) -> bool:
    if not is_station_open(id) or not has_ingredients(id, 1):
        return false
    progress[id] = minf(float(progress[id]) + 0.14, 0.999)
    _bump("boosts")
    return true


# ---------------- Thu nhập khi vắng mặt ----------------

## Tính tiền kiếm được trong lúc người chơi không mở game.
func _apply_offline(seconds: float) -> void:
    if seconds < 60.0:
        return
    var span := minf(seconds, OFFLINE_MAX_SECONDS)
    var total := 0.0
    var portions := 0
    for id in STATIONS:
        if not is_station_open(id) or not has_manager(id):
            continue
        var cycles := span / station_cycle(id) * OFFLINE_RATE
        var made := int(cycles * station_batch(id))
        # giới hạn theo nguyên liệu còn trong kho
        var recipe: Dictionary = STATIONS[id]["recipe"]
        for ing in recipe:
            var can := int(float(stock.get(ing, 0.0)) / maxf(float(recipe[ing]), 1.0))
            made = mini(made, can)
        if made <= 0:
            continue
        for ing in recipe:
            stock[ing] = maxf(0.0, float(stock[ing]) - float(recipe[ing]) * made)
        total += float(made) * station_price(id) * revenue_multiplier()
        portions += made
    if total <= 0.0:
        return
    money += total
    _bump("served", float(portions))
    _bump("earned", total)
    money_changed.emit()
    stock_changed.emit()
    offline_earned.emit({"amount": total, "seconds": span, "portions": portions})


# ---------------- Mua sắm ----------------

func can_afford(cost: float) -> bool:
    return money >= cost


func _spend(cost: float) -> bool:
    if money < cost:
        return false
    money -= cost
    money_changed.emit()
    return true


func buy_ingredient(id: String, packs: int = 1) -> bool:
    var qty := int(INGREDIENTS[id]["pack"]) * packs
    var cost := float(INGREDIENTS[id]["price"]) * qty
    if not _spend(cost):
        return false
    stock[id] = float(stock.get(id, 0.0)) + qty
    stock_changed.emit()
    _log("Nhập %d %s %s" % [qty, str(INGREDIENTS[id]["unit"]), str(INGREDIENTS[id]["name"]).to_lower()])
    return true


func buy_all_low(threshold: float = 10.0) -> int:
    var count := 0
    for id in shop_ingredients():
        if float(stock.get(id, 0.0)) < threshold:
            if buy_ingredient(id):
                count += 1
    return count


func hire_staff(id: String) -> bool:
    if int(staff.get(id, 0)) >= int(STAFF[id]["max"]):
        return false
    var cost := float(STAFF[id]["cost"]) * (int(staff.get(id, 0)) + 1)
    if not _spend(cost):
        return false
    staff[id] = int(staff.get(id, 0)) + 1
    _bump("staff")
    state_changed.emit()
    _log("Thuê thêm " + str(STAFF[id]["name"]).to_lower())
    return true


func buy_decor(id: String) -> bool:
    if not _spend(float(DECOR[id]["cost"])):
        return false
    decor[id] = int(decor.get(id, 0)) + 1
    _bump("decor")
    reputation = minf(100.0, reputation + 1.0)
    state_changed.emit()
    _log("Mua " + str(DECOR[id]["name"]).to_lower())
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
    if not is_floor_unlocked(str(STATIONS[id]["floor"])):
        return false
    if not _spend(station_upgrade_cost(id)):
        return false
    levels[id] = station_level(id) + 1
    _bump("upgrades")
    state_changed.emit()
    _log("%s lên cấp %d" % [str(STATIONS[id]["name"]), station_level(id)])
    return true


func hire_manager(id: String) -> bool:
    if has_manager(id) or not is_station_open(id):
        return false
    if not _spend(manager_cost(id)):
        return false
    managers[id] = true
    _bump("managers")
    state_changed.emit()
    _log("Thuê quản lý cho " + str(STATIONS[id]["name"]).to_lower())
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


func set_price(id: String, value: float) -> void:
    var floor_price := station_cost_per_portion(id) * 1.05
    prices[id] = int(clampf(value, floor_price, float(STATIONS[id]["base_price"]) * 4.0))
    state_changed.emit()


func suggest_all_prices() -> void:
    for id in STATIONS:
        prices[id] = suggested_price(id)
    state_changed.emit()


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
        "grill_level": grill_level,
        "furniture": furniture, "placed": placed,
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
    money = float(data.get("money", money))
    day = int(data.get("day", day))
    day_time = float(data.get("day_time", 0.0))
    reputation = float(data.get("reputation", reputation))
    auto_open = bool(data.get("auto_open", true))
    var d_stock = data.get("stock", {})
    if typeof(d_stock) == TYPE_DICTIONARY:
        for id in INGREDIENTS:
            stock[id] = float(d_stock.get(id, stock.get(id, 0.0)))
    var d_prices = data.get("prices", {})
    var d_levels = data.get("levels", {})
    var d_pending = data.get("pending", {})
    var d_portions = data.get("pending_portions", {})
    var d_mgr = data.get("managers", {})
    for id in STATIONS:
        if typeof(d_prices) == TYPE_DICTIONARY:
            prices[id] = int(d_prices.get(id, prices[id]))
        if typeof(d_levels) == TYPE_DICTIONARY:
            levels[id] = int(d_levels.get(id, levels[id]))
        if typeof(d_pending) == TYPE_DICTIONARY:
            pending[id] = float(d_pending.get(id, 0.0))
        if typeof(d_portions) == TYPE_DICTIONARY:
            pending_portions[id] = float(d_portions.get(id, 0.0))
        if typeof(d_mgr) == TYPE_DICTIONARY:
            managers[id] = bool(d_mgr.get(id, false))
    var d_staff = data.get("staff", {})
    if typeof(d_staff) == TYPE_DICTIONARY:
        for id in STAFF:
            staff[id] = int(d_staff.get(id, 0))
    var d_decor = data.get("decor", {})
    if typeof(d_decor) == TYPE_DICTIONARY:
        for id in DECOR:
            decor[id] = int(d_decor.get(id, 0))
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
    var d_floors = data.get("floors", {})
    if typeof(d_floors) == TYPE_DICTIONARY:
        for fl in FLOORS:
            floors_unlocked[fl["id"]] = bool(d_floors.get(fl["id"], fl["cost"] == 0))
    var d_stats = data.get("stats", {})
    if typeof(d_stats) == TYPE_DICTIONARY:
        for k in stats:
            stats[k] = float(d_stats.get(k, stats[k]))
    var d_claimed = data.get("claimed", {})
    if typeof(d_claimed) == TYPE_DICTIONARY:
        for m in MISSIONS:
            claimed[m["id"]] = bool(d_claimed.get(m["id"], false))
    last_seen = float(data.get("last_seen", Time.get_unix_time_from_system()))
    money_changed.emit()
    stock_changed.emit()
    state_changed.emit()
    return true
