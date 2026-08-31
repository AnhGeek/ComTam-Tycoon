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
phải đụng vào code**: giá bán và giá nâng cấp từng quầy, công thức nguyên liệu,
giá nguyên liệu, giá mở khu, lò than, lò giữ nhiệt, lương nhân viên, giá trang
trí/bàn ghế, thưởng nhiệm vụ, và mấy hệ số chung (tiền vốn, độ dài một ngày, độ
kiên nhẫn của khách, hệ số nâng cấp mỗi cấp).

**Giá từng cấp:** mỗi thứ nâng cấp được (mọi quầy, lò than, lò giữ nhiệt) có mảng
`up_costs` đúng `chung.max_level` số (mặc định 25). Số thứ k là giá để **đạt cấp
k**, nên số đầu là 0 (cấp 1 có sẵn) và số cuối là giá lên cấp tối đa. Kịch cấp thì
nút trong game đổi thành "ĐÃ TỐI ĐA". `up_cost` và `chung.station_up_mult` chỉ còn
là đường lui khi mảng thiếu số. Giá mở khu (`floors.<id>.cost`) là khoản trả một
lần, không dính gì tới cấp.

**Nhập nhanh:** nút "NHẬP NHANH CHO ĐẦY KHO" (`buy_all_low()`) nhập xoay vòng mỗi
lượt một lố, món cạn nhất đi trước, cho tới khi đầy hoặc hết tiền — món nào đã đầy
thì bỏ qua chứ không chặn mấy món còn thiếu. Mốc đầy là `stock_target()`: đồ tươi
lấy theo `cold_capacity()`, đồ khô lấy `chung.dry_stock_target`.

`GameManager._load_balance()` đọc file này lúc khởi động rồi **ghi đè** lên số mặc
định khai báo trong `scripts/game_manager.gd`. Thiếu khoá nào thì khoá đó giữ số
mặc định, nên file JSON chỉ cần ghi phần muốn sửa. File hỏng cú pháp thì bỏ qua cả
file và ghi cảnh báo — `install.sh` bắt lỗi này trước khi build.

Vì vậy mấy bảng số trong `game_manager.gd` phải là `static var` chứ không được là
`const` (const thì không ghi đè được). Và `export_presets.cfg` có
`include_filter="data/*.json"` — JSON không phải "resource" của Godot nên thiếu
dòng đó là file không được đóng gói vào APK.

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
`views/shopping_view.gd`), dùng chung cho tab **Nhân viên** và **Trang trí** —
mua gì cũng là mua cho khu đang chọn. Tab **Nguyên liệu** không có nút chọn khu
vì kho hàng dùng chung cả 3 khu.

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

### Kho lạnh (tủ lạnh)

Bốn món tươi trong `COLD_ITEMS` (sườn, trứng, bì, chả) **có trần kho**, mấy thứ
khô (gạo, than, gas...) thì không. Trần đó là `cold_capacity()` =
`FRIDGE_CAP_BASE` cộng phần góp của mọi khu, mỗi khu góp
`số tủ × (FRIDGE_SLOT + (cấp − 1) × FRIDGE_SLOT_STEP)`.

Tủ lạnh theo đúng luật "mỗi khu lo phần khu mình": `fridges[fid]` là số tủ,
`fridge_levels[fid]` là cấp của khu đó, mua bằng `buy_fridge(fid)` (cái sau đắt
hơn cái trước theo `FRIDGE_COST_MULT`, nhiều nhất `FRIDGE_MAX` cái một khu) và
nâng bằng `upgrade_fridge(fid)` (25 cấp, giá từng cấp ở `fridge.up_costs` trong
`balance.json`). Nhưng **chỗ trữ thì góp chung**, vì kho nguyên liệu xưa giờ vẫn
là kho chung của cả quán.

`buy_ingredient()` tự cắt bớt số lượng cho vừa chỗ còn trống và chỉ tính tiền
phần nhét vô được; kho đầy thì trả `false`. Vách trái mỗi khu bày được **hai**
cái tủ (`_build_fridges`), cái thứ ba mua rồi vẫn tính chỗ trữ nhưng không dựng
ra cho đỡ chật. Tab **Kho lạnh** trong Mua sắm dùng chung nút chọn khu với hai
tab kia.

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
