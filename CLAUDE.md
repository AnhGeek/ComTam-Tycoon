# Cơm Tấm Tycoon — sổ tay cho Claude

Game idle/tycoon quán cơm tấm, Godot **4.7.2**, chơi trên điện thoại Android
(landscape). Toàn bộ 3D và UI dựng **bằng code**, không có asset ngoài — không
đi tìm file `.glb`/`.png`, không có cái nào cả.

Chữ hiển thị cho người chơi và **comment trong code đều viết tiếng Việt**, giọng
đời thường như đang kể chuyện quán xá. Giữ đúng giọng đó khi thêm code mới.

## Chạy & build

| Việc | Lệnh |
|---|---|
| Bắt lỗi cú pháp GDScript | `"$GODOT" --headless --path . --import` |
| Chạy thử trên PC | `"$GODOT" --path . --resolution 450x800 --quit-after 3000` |
| Build APK + cài lên máy | `./install.sh [IP] [--run]` |

`$GODOT` = `C:/Users/HoangAnh/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
(cái `.exe` ngoài cùng là tên **thư mục**). Luôn dùng bản `_console` để đọc được
stdout/stderr.

`--quit-after N` là số **khung hình**, ~60/giây. Chạy 3000 khung (~50 giây) là đủ
để khách vào quán, ngồi, được phục vụ, ăn xong (11 giây) rồi về — dùng nó để
chắc chắn không có lỗi runtime trong vòng đời của khách.

### `data/balance.json` — bảng số cân bằng game

Mọi con số cân bằng nằm ở đây, sửa xong chạy `./install.sh` là ra APK mới, **không
phải đụng vào code**: giá bán từng món trong menu, giá nâng cấp từng quầy, công thức nguyên liệu,
giá nguyên liệu, sức chứa từng món của hai cái kho, giá mở khu, lò than, lò giữ
nhiệt, lương nhân viên, giá trang
trí/bàn ghế, thưởng nhiệm vụ, và mấy hệ số chung (tiền vốn, độ dài một ngày, độ
kiên nhẫn của khách, hệ số nâng cấp mỗi cấp).

**Giá từng cấp:** mỗi thứ nâng cấp được (mọi quầy, lò than, lò giữ nhiệt) có mảng
`up_costs` đúng `chung.max_level` số (mặc định 25). Số thứ k là giá để **đạt cấp
k**, nên số đầu là 0 (cấp 1 có sẵn) và số cuối là giá lên cấp tối đa. Kịch cấp thì
nút trong game đổi thành "ĐÃ TỐI ĐA". `up_cost` và `chung.station_up_mult` chỉ còn
là đường lui khi mảng thiếu số. Giá mở khu (`floors.<id>.cost`) là khoản trả một
lần, không dính gì tới cấp.

**Công thức ghi số lẻ được:** `recipe` của quầy nhận số thập phân (nồi cơm ăn
`0.5` kg gạo và `0.01` bình gas mỗi phần). Kho thì **luôn là số nguyên**, nên chỗ
lẻ được cộng dồn trong `ing_debt` — đủ một đơn vị mới rút một đơn vị ra khỏi kho.
Phần lẻ còn nợ có lưu vào save, không thì tải lại game là được ăn không.

**Nhập nhanh:** nút "NHẬP NHANH CHO ĐẦY KHO" (`buy_all_low()`) nhập xoay vòng mỗi
lượt một lố, món cạn nhất đi trước, cho tới khi đầy hoặc hết tiền — món nào đã đầy
thì bỏ qua chứ không chặn mấy món còn thiếu. Mốc đầy là `stock_target()`, chính là
`item_capacity()` — trần riêng của từng món do kho của nó quyết định.

**Nấu nhanh là MUA đứt phần thời gian còn lại của mẻ**: trả tiền một cái là mẻ ra
ngay, không phải đợi. Giá tính ba tầng:

```
boost_cost(quầy) = stations.<quầy>.boost_cost        (giá lúc quầy còn cấp 1)
                 × chung.boost_cost_mult ^ (cấp - 1)  (mặc định 1.12)
                 × phần mẻ CÒN LẠI (1 - tiến độ)
```

Nhân với phần còn lại nên thúc sớm trả trọn, thúc lúc mẻ gần xong thì gần như
không mất gì — trả đúng khúc được rút ngắn. Giá cấp 1: nồi cơm 20.000 ₫ · bàn bì
chả 10.000 ₫ · trà đá 1.500 ₫ · lò than vỉa hè 50.000 ₫ (`grill.boost_cost`,
tính theo `grill_level`), chừng 30% giá trị một mẻ nên thúc vẫn lời.

`boost_cost = 0` nghĩa là **quầy đó không thúc được**, và bảng của nó cũng không
mọc ra nút nấu nhanh: **lò nướng thịt** để 0 vì nó chỉ giữ nhiệt cho sườn của lò
than, có nấu nướng gì đâu mà thúc. `boost_station()`/`boost_grill()` chỉ đẩy kim
đồng hồ tới `0.999` rồi để `_process`/`_tick_grill` kết mẻ theo đúng đường ra hàng
cũ — đừng chép lại đoạn trừ nguyên liệu ở chỗ khác.

`GameManager._load_balance()` đọc file này lúc khởi động rồi **ghi đè** lên số mặc
định khai báo trong `scripts/game_manager.gd`. Thiếu khoá nào thì khoá đó giữ số
mặc định, nên file JSON chỉ cần ghi phần muốn sửa. File hỏng cú pháp thì bỏ qua cả
file và ghi cảnh báo — `install.sh` bắt lỗi này trước khi build.

Vì vậy mấy bảng số trong `game_manager.gd` phải là `static var` chứ không được là
`const` (const thì không ghi đè được). Và `export_presets.cfg` có
`include_filter="data/*.json"` — JSON không phải "resource" của Godot nên thiếu
dòng đó là file không được đóng gói vào APK.

**Nút cộng tiền lúc test:** `chung.debug_tools` (mặc định `true`) bật khúc "Gỡ lỗi"
cuối trang Cài đặt — ba nút +1 triệu / +10 triệu / +100 triệu và một nút xoá sạch ví,
đều gọi `GameManager.debug_add_money()` (nhét thẳng vô ví, không đụng doanh thu hay
uy tín). Phát hành thật thì để `"debug_tools": false` là cả khúc đó biến mất.

### Dây chuyền hai tầng: quầy làm ra phần, menu bán ra tiền

Quầy **không bán thẳng cho khách**. Mỗi quầy chỉ làm ra một thứ *bán thành phẩm*
(khoá `out` trong `stations`), chất vào kho chung; `MENU` mới là danh sách món
bưng ra bàn và là chỗ duy nhất có giá bán.

| Quầy | Ăn vào | Làm ra |
|---|---|---|
| Nồi cơm tấm (`rice`) | gạo + gas | `com` — phần cơm |
| Bàn bì & chả (`prep`) | bì heo + chả trứng | `bicha` — phần bì chả |
| Quầy trà đá (`drink`) | đá bi + trà | `trada` — ly trà đá |
| Lò nướng thịt (`grill`) | — | không làm ra gì, chỉ **giữ nhiệt** `grilled` |
| Lò than vỉa hè | than + sườn sống | `grilled` — miếng sườn nướng |

Sáu món trong `MENU`: cơm tấm sườn (`com`+`grilled`) · cơm tấm bì chả
(`com`+`bicha`) · trà đá (`trada`) · cơm tấm thập cẩm và cơm hộp giao đi
(`grilled`+`bicha`) · set cơm tấm VIP (`grilled`+`bicha`+`trada`). Khoá `where`
nói món đó bán ở khu nào; `"ship"` nghĩa là chỉ shipper chở đi.

Vòng tiền, đúng theo thứ tự này:

1. Người bưng (hoặc shipper) chờ đủ `service_time` rồi gọi `take_order(where)`
   — hàm này bốc một món còn đủ hàng và **trừ ngay số nguyên** bán thành phẩm.
   Bếp chưa ghép nổi suất nào thì họ đứng chờ tiếp, không bưng khay không.
2. Khách **ăn xong** mới trả tiền: `sell_dish(did)` cộng trọn giá món vào ví,
   luôn là số nguyên đồng. Chữ bay lên đầu khách gộp cả hai: `"45.000 ₫ + 2 uy tín"`.
3. Chờ lâu quá bỏ về thì vẫn `-Y uy tín` như cũ, không mất tiền vì chưa thu.

Không còn chỗ nào bán theo phần lẻ: mọi nguyên liệu, mọi suất, mọi khoản tiền
đều là số nguyên (`_spend` cũng làm tròn).

### Mỗi khu một dãy quầy riêng

**Khu nào lo khu nấy — kho cũng vậy.** Cấp quầy, tiến độ mẻ, quản lý, **và cả
kho hàng** đều là của riêng từng khu: nâng nồi cơm khu máy lạnh không làm nồi cơm
vỉa hè chạy nhanh hơn, bếp khu nào ăn gạo khu đó và phần cơm nấu ra cũng nằm lại
khu đó. Khu nào cũng dựng đủ dãy quầy lẫn người đứng bếp của mình. Riêng **lò than
vỉa hè** (`_build_griller`) vẫn độc nhất một cái ngoài hiên khu trệt, nên ở khu
trên quầy `grill` (lò giữ nhiệt) có người đứng như quầy thường.

Cách ghi: mọi thứ tính theo quầy — `levels` · `progress` · `managers` · `pending` ·
`pending_portions` — dùng **khoá ghép `"<quầy>@<khu>"`**, ví dụ `"rice@aircon"`.

| Muốn gì | Gọi hàm |
|---|---|
| Khoá ghép của quầy `sid` ở khu `fid` | `station_key(sid, fid)` |
| Tên quầy (bỏ phần khu) | `station_base(id)` |
| Quầy đó đứng khu nào | `station_floor(id)` |
| Bảng số của quầy (cycle, batch, recipe…) | `station_def(id)` |
| Dãy quầy của một khu | `stations_on_floor(fid)` |
| Cả 4×3 cái quầy của quán | `all_station_ids()` |

`STATIONS[id]` chỉ còn là **bảng số theo tên quầy**, khoá `"floor"` trong đó là
tàn dư (ghi `"street"` cho cả bốn) — đừng bao giờ hỏi nó xem quầy nằm khu nào, hỏi
`station_floor()`. `station_level()` tự trả về 1 cho quầy của khu đã mở mà chưa
ghi cấp, nên mở khu (kể cả mở tắt trong code gỡ lỗi) là có ngay bốn quầy cấp 1.
Save đời cũ ghi khoá trần `"rice"` thì lúc load dồn về khu vỉa hè, mấy khu trên
bắt đầu lại từ cấp 1.

Bên `tycoon_world`, `_station_nodes` cũng khoá bằng khoá ghép nên quầy cùng tên ở
ba khu là ba mục riêng; chỗ nào cần **hình dạng** quầy (`match base:`, icon, dao
thớt) thì phải `station_base()` trước, chỗ nào hỏi cấp/nguyên liệu thì đưa thẳng
khoá ghép cho GameManager.

Bong bóng tiền trên quầy (`pending`, `collect()`, nút "THU … ₫") **không còn được
rót vào nữa** vì tiền chảy thẳng vô ví. Bộ khung vẫn nằm đó, quản lý quầy giờ chỉ
còn tác dụng cho thu nhập lúc vắng mặt.

### Kho theo khu — mọi thứ đi qua khoá khu

`stock` và `ing_debt` là **hai tầng**: `stock[floor_id][item_id]`. Không còn chỗ
nào đọc thẳng `GameManager.stock` nữa, hỏi qua mấy hàm này:

| Muốn gì | Gọi hàm |
|---|---|
| Khu `fid` có bao nhiêu món `id` | `stock_at(fid, id)` |
| Cả quán cộng lại (chỉ để hiện lên màn) | `stock_total(id)` |
| Cộng/trừ kho (số âm là trừ) | `add_stock(fid, id, n)` |
| Trần của món đó ở khu đó | `stock_cap(id, fid)` · `item_capacity(id, fid)` |
| Còn nhét thêm được bao nhiêu | `stock_room(id, fid)` |
| Trừ nguyên liệu (có cộng dồn phần lẻ) | `_use_ingredient(fid, ing, n)` |
| Nhập hàng về một khu | `buy_ingredient(id, packs, fid)` |
| Nhập đầy kho một khu / cả quán | `buy_all_low(fid)` · `buy_all_low_everywhere()` |
| Bốc một đơn ở `where`, trừ hàng kho `fid` | `take_order(where, fid)` |

**Bán thành phẩm cũng theo khu.** `com`/`bicha`/`trada` nấu ra ở khu nào thì nằm
lại khu đó, người bưng của khu đó mới lấy được; shipper cũng lấy hộp cơm ngay tại
khu mình đứng (`take_order("ship", fid)`).

**Sườn nướng là ngoại lệ.** Lò than chỉ có một cái ngoài vỉa hè (`grill_floor()`),
ăn than + sườn sống của **kho khu trệt**. Nướng xong thì `_tick_grill` **chia vòng
tròn** vào lò giữ nhiệt của mọi khu đang mở, mỗi lượt một miếng cho khu còn chỗ —
không vậy thì hai khu trên mất 4 trong 6 món của menu. Vì thế:

- `warmer_fill(fid)` / `warmer_full(fid)` hỏi **một khu**; `warmers_full()` (mọi
  khu đều chật) mới là cái làm lò than nghỉ tay.
- `warmer_level` vẫn nâng chung cả quán — nâng một lần là khay khu nào cũng rộng ra.

Save đời cũ ghi `stock`/`ing_debt` phẳng thì lúc load **dồn hết về khu vỉa hè**, y
như cách `staff` và `decor` đã làm; hai khu trên bắt đầu với kho trống.

### Quản lý tự đi chợ

Quầy nào thuê quản lý thì **nguyên liệu của quầy đó không được để cạn**: cứ
`chung.manager_buy_every` giây (mặc định 5), `_auto_restock()` đi một vòng, món nào
tụt xuống dưới `chung.manager_buy_at` (mặc định 25%) phần trần kho **của khu đó**
thì `_manager_buy()` nhập một phát cho **đầy trần** luôn. Ví không đủ thì nhập được
bao nhiêu hay bấy nhiêu; `chung.manager_buy_reserve` là khoản chừa lại không cho
quản lý đụng tới (mặc định 0 — quản lý tiêu tới đồng cuối cùng, cẩn thận lúc đang
để dành mở khu).

Quầy nào mua món nào thì `station_supplies(id)` quyết định: mặc định là đúng mấy
thứ mua ngoài chợ trong `recipe` của nó, riêng quầy `grill` **ở đúng khu có lò
than** thì mua thêm sườn sống + than. Nhờ mỗi nguyên liệu chỉ nằm trong công thức
của một tên quầy nên không có chuyện hai quầy giành nhau một món.

Ngoài chuyện đi chợ, quản lý vẫn là thứ **mở khoá thu nhập lúc vắng mặt** cho quầy
đó (`_apply_offline` bỏ qua quầy không ai trông), và khu nào có quản lý thì
`_build_manager` dựng một người mặc vest đứng trước quán.

### `install.sh`

Xuất APK ký **release** (bắt buộc: máy đang cài bản release, APK debug sẽ bị
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) rồi `adb install -r`.

```
./install.sh                # dùng IP nhớ trong .last-device
./install.sh 192.168.1.21   # chỉ định IP
./install.sh 192.168.1.21 --run
./install.sh --scan         # quên IP thì dò cả subnet
./install.sh --build-only
```

Keystore + mật khẩu nằm ngoài repo, ở
`C:/Users/HoangAnh/Documents/ComTamTycoon-keystore-backup/` (xem `RECOVERY.md`
trong đó). Godot đọc mật khẩu qua biến môi trường
`GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}` — **không bao giờ** ghi
mật khẩu vào `export_presets.cfg` vì file đó được commit.

### Điện thoại

Samsung A06 (`SM_A066B`, arm64), nối bằng **Wi-Fi ADB** — IP đổi mỗi lần đổi
mạng và rớt khi màn hình ngủ, cứ `adb connect <ip>:5555` lại (hoặc
`./install.sh --scan`). Màn hình 720x1600 nhưng game chạy ngang, nên
`screencap` trả về ảnh **1600x720** và `adb shell input tap X Y` nhận toạ độ
trong đúng khung xoay đó — đọc thẳng toạ độ từ ảnh chụp.

Xem tận mắt trên máy:
```
adb shell input tap X Y
adb shell "screencap -p > /sdcard/s.png"
MSYS_NO_PATHCONV=1 adb pull "/sdcard/s.png" <đích>    # thiếu env này Git Bash đổi /sdcard thành đường dẫn Windows
```

## Bẫy đã dẫm phải

- **Đừng nối thẳng `stock_changed` vào một hàm dựng lại cả danh sách.** Kho nhúc
  nhích liên tục (quầy ra mẻ, quản lý đi chợ) mà mỗi tiếng lại dựng lại nguyên
  trang thì màn đó giật; mua cả loạt trong một vòng lặp thì **treo hẳn game** —
  bấm "nhập đầy cả 3 khu" là hơn trăm lần dựng lại ngay giữa vòng. Hai lớp chặn:
  bên `GameManager` mấy hàm mua cả loạt (`buy_all_low`, `buy_all_low_everywhere`,
  `_auto_restock`) kẹp trong `_quiet_begin()`/`_quiet_end()` để gom tín hiệu phát
  đúng một lần (chỗ mua lẻ gọi `_emit_stock()` chứ không `stock_changed.emit()`);
  bên view thì chỉ ghi dấu `list_dirty` rồi dựng lại một lần trong `_process`.
- **Godot 4.7 coi "type inferred from a Variant value" là lỗi cứng**, không phải
  cảnh báo. Đừng dùng `:=` cho giá trị lấy từ Dictionary/Array (kể cả biến chạy
  trong `for x in [...]`) hay từ `abs()`. Ghi kiểu rõ ràng (`var v: Vector2 = ...`)
  hoặc dùng `absf`/`maxf`/`clampf`.
- **Viết file GDScript dài qua heredoc của bash hay hỏng** trong môi trường này.
  Dùng tool Write, hoặc viết script Python vá file rồi chạy.
- Export Android **bắt buộc** `textures/vram_compression/import_etc2_astc=true`
  trong `project.godot`, thiếu là nó từ chối export.
- Ký APK cần JDK; `java` không có trong PATH, nên `java_sdk_path` trong
  `editor_settings-4.7.tres` trỏ vào `C:/Program Files/Android/Android Studio/jbr`.
- **Người nhỏ hơn đồ đạc.** Nhân vật bị thu nhỏ (`CHAR_SCALE`) còn quầy/bàn thì cỡ
  thật, nên mặt quầy bếp (cao 1.07) ngang đầu người đứng bếp. Thêm nữa, máy quay
  chúi 42 độ nên **cả dải sau quầy bị chính cái quầy che kín** — đứng đó thì
  không ai thấy. Muốn khoe động tác của nhân vật thì kê bàn thấp (~0.72) ra phía
  trước quầy, như bàn thái bì & chả (`_build_chop_board`).
- Muốn kịch bản hoá thao tác UI để gỡ lỗi thì thêm autoload tạm
  `Probe="*res://scripts/_probe.gd"` và bơm sự kiện bằng `Input.parse_input_event()`,
  nhân toạ độ với `Vector2(get_window().size) / get_tree().root.get_visible_rect().size`.
  `get_tree().root.push_input()` bị nuốt im lặng, còn `--script` chạy không có
  autoload nên `GameManager` không phân giải được.

## Bố cục code

```
main.tscn / scripts/main.gd     khung 4 tab dọc bên trái: Quán · Nhiệm vụ · Mua sắm · Cài đặt
scripts/game_manager.gd         autoload GameManager — TOÀN BỘ luật chơi + save
scripts/tycoon_world.gd         cảnh 3D: dựng khu, bàn ghế, quầy, và vòng đời khách/nhân viên
scripts/com_tam_chars.gd        ComTamChars — người low-poly có xương, con chó, dĩa cơm, tư thế
scripts/ui_kit.gd               UIKit — màu, panel, nút, nhãn, `px()` cho tỉ lệ
scripts/ui_icons.gd             UIIcon.make(kind, size, color) — icon vẽ tay
scripts/drag_scroll.gd          vuốt để cuộn danh sách
views/restaurant_view.gd        màn chính: thanh trạng thái, danh sách quầy, các bảng chi tiết
views/{missions,shopping,settings}_view.gd
```

Luật chơi **chỉ nằm trong `GameManager`** (tiền, kho, cấp quầy, uy tín, khách/phút,
nhiệm vụ, offline earnings, `save_game()`/`load_game()` ra `user://com_tam_save.json`).
View và world chỉ đọc rồi vẽ. Thêm tính năng thì đặt số liệu vào GameManager trước.

### Dây chuyền sườn nướng

Hai cái "lò" là hai thứ khác nhau, đừng lẫn:

- **Lò nướng than** (ngoài hiên, `_build_griller` + `GameManager._tick_grill`) mới là
  chỗ nướng thật: ăn **than + sườn sống**, mỗi mẻ ra `grill_batch()` miếng. Nâng cấp
  ở đây = mỗi mẻ nhiều miếng hơn (`grill_level`).
- **Lò giữ nhiệt** (khay trên quầy, `_build_warmer`) **chỉ chứa** sườn đã nướng để
  lúc nào cũng có miếng sẵn phục vụ khách. Nâng cấp ở đây = trữ được nhiều miếng
  hơn (`warmer_level`, `warmer_capacity()`).

Hai luật quan trọng:

1. **Còn than là lửa còn** — `grill_lit()` chỉ hỏi than. Hết sườn sống thì cái vỉ
   trống trơn nhưng than vẫn đỏ, lửa vẫn cháy, khói vẫn bay. Chỉ `grill_running()`
   (đang nướng một mẻ) mới cần đủ cả than lẫn sườn.
2. **Sức chứa lò giữ nhiệt là trần của `stock["grilled"]`** — lò đầy thì
   `grill_running()` false, lò than ngoài hiên nghỉ tay.

Quầy `grill` trong danh sách quầy tên là **"Lò nướng thịt"** — nó đại diện cho cả
dây sườn nướng, nên khi hết than/sườn thì chính nó báo động (bốn quầy có thể báo
hết hàng: lò nướng thịt, nồi cơm tấm, bàn bì & chả, quầy trà đá). Bảng của quầy này
có ba lộ trình nâng cấp tách bạch: cấp quầy (cơm ra nhanh hơn), lò nướng than
(nhiều miếng mỗi mẻ), lò giữ nhiệt (nhiều chỗ chứa hơn). Số miếng thấy trong khay
(tối đa `WARM_SLOTS` ô) luôn khớp với số miếng thật trong kho.

### Mua sắm quản lý theo khu

Trang Mua sắm có hàng nút chọn khu nằm ngay dưới hàng tab (`shop_floor` trong
`views/shopping_view.gd`), dùng chung cho **mọi tab** — mua gì cũng là mua cho khu
đang chọn, kể cả nhập nguyên liệu, vì kho giờ tách riêng từng khu. Tab Nguyên liệu
có thêm nút "NHẬP ĐẦY KHO CẢ 3 KHU" cho đỡ phải bấm qua bấm lại.

Trong `GameManager`, `staff` và `decor` đều là `floor_id -> {id -> số lượng}`.
Tra cứu qua `staff_count(fid, id)` · `staff_total(id)` · `floor_crew(fid)` ·
`floor_salary(fid)` · `hire_cost(id, fid)`, thuê bằng `hire_staff(id, fid)`.
`STAFF[id]["max"]` và `["cost"]` tính cho **mỗi khu**, không phải cả quán.

**Chỉ còn hai loại nhân viên, mỗi khu nhiều nhất 2 người mỗi loại** — mà **1
người là có sẵn lúc mở khu**, nên chỉ thuê thêm được đúng 1 người nữa:

- `STAFF[id]["max"]` = **tổng** người của một khu (2), `["free"]` = số người đi
  kèm khi mở khu (1). Cả hai chỉnh được trong `balance.json`.
- `staff[fid][id]` chỉ ghi số **thuê thêm**. Người có sẵn không lưu vào save,
  `staff_free(fid, id)` suy thẳng từ "khu này mở chưa" — nhờ vậy game mới chơi
  và khu vừa mở là có người ngay, khỏi phải nhớ cập nhật chỗ nào.
- `staff_count(fid, id)` = có sẵn + thuê thêm, và **mọi chỗ tính tác dụng đều
  hỏi hàm này** (ghế, khách tới, `serve_ratio`, số người dựng trong cảnh 3D).
  Muốn biết riêng phần thuê thì hỏi `staff_hired(fid, id)`; `hire_left(fid, id)`
  cho biết còn thuê thêm được mấy người.
- **Lương chỉ trả cho người thuê thêm** (`floor_salary` dùng `staff_hired`) —
  người đi kèm khu làm không công, nên số người và tiền lương lệch nhau là đúng.

Cả hai loại đều chỉ lo cho khu mình, và thuê ai là thấy ngay người đó ngoài
quán — không có loại nào chỉ là con số:

- **Phục vụ** — mỗi người là **một người bưng cơm thật** đứng trước quầy khu đó
  (`_populate` dựng đúng `staff_count(fid, "waiter")` người, tên lấy lần lượt
  trong `SERVER_KEYS`), cộng 2 chỗ ngồi (`floor_seats(fid)`).
  `service_time(fid)` là quãng chờ của MỘT người bưng nên không hỏi tới nhân
  viên: đông người thì nhiều khay chạy song song, chứ người cũ không chạy nhanh
  hơn. Mỗi người đeo vòng chờ món của riêng mình trong `a["meter"]`.
- **Shipper** — kéo thêm 6% khách về khu (`floor_arrival_rate(fid)`), và ra
  đứng chờ hộp cơm ở quầy rồi chạy ra chạy vào suốt ngày (`_update_shipper`:
  `load → go → away → back`, dùng chung `_route`/`_follow_path`/`_spawn_point`
  với khách; lúc `away` thì tắt node cho nhẹ máy).

**Phụ bếp và thu ngân đã bỏ hẳn** (cả `STAFF` lẫn `staff.cook`/`staff.cashier`
trong `balance.json`): `station_cycle` giờ chỉ còn phụ thuộc cấp quầy, và
`revenue_multiplier()` biến mất luôn — tiền bán ra chỉ còn `giá × số phần`, ở cả
`_tick`, `_apply_offline` lẫn phần tính lãi mỗi giây. Save đời cũ có ghi hai loại
này thì lúc load tự rơi mất vì vòng load chỉ đọc các khoá còn trong `STAFF`.

`staff_total()` chỉ còn để hiện con số "cả quán có mấy người" trên trang Mua sắm.

Vì vậy mấy con số của quán đều có bản theo khu và bản cộng dồn:
`floor_seats/seats` · `floor_ambiance/ambiance` · `floor_arrival_rate/arrival_rate`.
Hàm cộng dồn chỉ để hiện lên HUD; phần tính tiền trong `_tick` và số khách dựng
trong cảnh 3D đều hỏi bản **theo khu**.

**Quản lý** thuê cho từng quầy (`hire_manager(sid)` · `has_manager(sid)`), mà quầy
nào cũng thuộc một khu nên `floor_managers(fid)` đếm được khu đó có ai trông.
Khu nào đã thuê quản lý thì `_build_manager` dựng một người mặc vest ra đứng phía
trước quán — **chỉ đứng im** nhìn quán (actor `mode = "boss"`, chạy `idle`), không
đi lại, không bưng bê. Nam mặc vest sơ mi cà vạt (`quan_nam`), nữ mặc vest với váy
bút chì (`quan_nu`); trong `ComTamChars.build()` là hai khoá `"suit"` và `"skirt"`
của preset — mặc váy thì ống chân đổi sang màu da.

Save đời cũ ghi `staff` phẳng thì lúc load dồn hết về khu đầu, y như cách trang
trí đã làm.

### Hai cái kho: kho lạnh và kho đồ khô

Mỗi nguyên liệu mua ngoài chợ đều thuộc về **một cái kho**, và cái kho đó chặn
trần số lượng trữ được:

| Kho | Khoá | Món | Vật mua |
|---|---|---|---|
| Kho lạnh | `fridge` | sườn heo · bì · chả · **đá bi** | Tủ lạnh |
| Kho đồ khô | `pantry` | gạo · trà · than · gas | Kệ đồ khô |

Hai kho chạy **y hệt nhau**, và **kho là của riêng từng khu**: mỗi khu tự mua
tủ/kệ của khu mình (tối đa `max` cái), tự nâng cấp, tự chứa hàng của mình. Nhập
gạo về vỉa hè thì bếp phòng máy lạnh vẫn đứng chờ gạo của nó.

Sức chứa tính riêng **cho từng món ở từng khu**:

```
item_capacity(món, khu) = cap_base[món]
                        + (tủ/kệ của KHU ĐÓ) × slot[món][cấp tủ đó]
```

`item_capacity_all(món)` mới là con số cộng cả ba khu, chỉ dùng để hiện lên màn
hình chứ không dùng để chặn trần.

Cả `cap_base` lẫn `slot` nằm trong `data/balance.json`, mỗi món một mảng
`MAX_LEVEL` số, nên **chỉnh được từng mức chứa của từng món ở từng cấp**. Bảng
thiếu số thì code suy ra theo công thức nhân dần (`store_slot`), không đứng im.

Mốc cấp 1 (chưa mua cái nào): sườn/bì/chả/đá bi 50 mỗi món · gạo 50 kg · trà 20
ấm · than 20 kg · **gas 1 bình**. Một bình gas nấu đúng **100 suất cơm** — nồi cơm
ăn `0.01` bình mỗi phần, chỗ lẻ được cộng dồn (xem `_use_ingredient`), nên kho đầy
cấp 1 vừa đủ 100 phần cơm cả gạo lẫn gas.

Trong `GameManager` mọi thứ đi qua bảng `STORAGE` và mấy hàm `store_*`:
`store_count/store_level/store_slot/store_cap_base` · `store_cost/store_upgrade_cost`
· `buy_store(kind, fid)` / `upgrade_store(kind, fid)` · `item_capacity(id, fid)` ·
`item_capacity_all(id)` · `storage_of(id)` · `is_stored(id)` · `is_cold(id)`.
Trạng thái nằm ở
`stores[kind][fid]` và `store_levels[kind][fid]`. `fridge_count/fridge_level/
buy_fridge/upgrade_fridge` chỉ còn là mấy cái tên cũ gọi vòng qua kho `"fridge"`
(cảnh 3D `_build_fridges` dùng tới). Kệ đồ khô **chưa có mô hình 3D**, mới chỉ có
trong màn Mua sắm.

`buy_ingredient()` tự cắt bớt số lượng cho vừa chỗ còn trống của món đó và chỉ
tính tiền phần nhét vô được; kho đầy thì trả `false`. `stock_target()` giờ chính
là `item_capacity()`, nên "NHẬP NHANH CHO ĐẦY KHO" nhập tới đúng trần từng món.

Màn Mua sắm có **năm tab**: Nguyên liệu · Nhân viên · Trang trí · **Kho lạnh** ·
**Kho khô**. Hai tab kho dùng chung một hàm dựng `_build_store(kind)` và dùng
chung hàng nút chọn khu với tab Nhân viên/Trang trí; `store_kind_of(tab)` cho
biết tab nào là kho nào. Tab Nguyên liệu không có nút chọn khu vì kho dùng chung,
mỗi thẻ nguyên liệu có nhãn nhỏ ghi nó nằm kho nào.

### `tycoon_world.gd` — vài quy ước

- Ba khu (`FLOORS`: vỉa hè · phòng máy lạnh · sân vườn) nằm cạnh nhau theo trục X,
  camera trượt ngang giữa chúng; `wing_x(i)` cho biết khu thứ i đứng ở đâu.
- `_seats` là mảng phẳng mọi chỗ ngồi của mọi khu. Mỗi chỗ mang sẵn: `pos`,
  `look` (tâm bàn), `style` (`stool`/`chair`), `y`, `table`, và `plate` +
  `plate_yaw` — chỗ đặt dĩa cơm trên mặt bàn trước mặt người đó.
- Vòng đời khách là máy trạng thái trong `_update_customer`:
  `enter → queue → walk_seat → wait_food → eat → leave`. Người phục vụ (Linh)
  bưng cơm ra qua `_serve_guest`, hết kiên nhẫn thì khách bỏ về và quán mất uy tín.
- `_box()` / `_cylinder()` là hai hàm dựng khối dùng khắp nơi; bên
  `ComTamChars` là `_bx()` / `_cyl()` / `_sph()` / `_mi()` / `mat()`.
- **Thụt lề khác nhau giữa hai file**: `tycoon_world.gd` (và các view) dùng
  **4 dấu cách**, `com_tam_chars.gd` dùng **tab**. Đừng trộn.
- Người đã thu nhỏ (`CHAR_SCALE`) nhưng ghế thì cỡ thật, nên lúc ngồi phải kênh
  người lên bằng `ComTamChars.seat_lift(style)`.

### UI

Máy cầm **ngang**, thanh điều hướng dựng **dọc bên trái** để không mất chiều cao.
Mọi kích thước đi qua `UIKit.px()` để co giãn theo màn hình — đừng viết số pixel
cứng. Một ngón = xoay/vuốt cảnh, hai ngón = kéo và thu phóng.

## Phát hành

**Không bao giờ tự tạo release trên GitHub.** Chỉ commit/push/tag/`gh release`
khi chủ dự án nói rõ là làm. Build và cài lên máy để thử thì cứ tự nhiên.

Khi được yêu cầu phát hành: bump **cả hai** `version/code` (số nguyên) và `version/name`
trong `export_presets.cfg`, rồi: commit → `git push origin master` → tag có chú
thích → push tag → `gh release create vX.Y.Z build/comtam-tycoon-X.Y.Z.apk -R AnhGeek/ComTam-Tycoon`
kèm ghi chú phát hành tiếng Việt. Cài đè để test thì không cần bump.
