#!/usr/bin/env bash
# Build APK ký release rồi cài thẳng lên điện thoại qua Wi-Fi ADB.
#
#   ./install.sh                  # dùng IP đã lưu (hoặc máy đang cắm dây)
#   ./install.sh 192.168.1.21     # chỉ định IP
#   ./install.sh 192.168.1.21 --run   # cài xong mở game luôn
#   ./install.sh --scan           # dò cả subnet tìm điện thoại
#   ./install.sh --build-only     # chỉ xuất APK, không cài
#
# IP dùng lần cuối được nhớ trong .last-device, lần sau chạy không cần gõ lại.
set -euo pipefail
cd "$(dirname "$0")"

GODOT="C:/Users/HoangAnh/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
KEYSTORE_DIR="C:/Users/HoangAnh/Documents/ComTamTycoon-keystore-backup"
APK="build/comtam-tycoon.apk"
PKG="com.hoanganh.comtamtycoon"
LAST_DEVICE=".last-device"

ip=""
do_run=0
do_scan=0
build_only=0
for arg in "$@"; do
	case "$arg" in
		--run) do_run=1 ;;
		--scan) do_scan=1 ;;
		--build-only) build_only=1 ;;
		-*) echo "Không hiểu tham số: $arg" >&2; exit 2 ;;
		*) ip="$arg" ;;
	esac
done

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 1. Xuất APK ký release ----------
say "Xuất APK (release-signed)"
[ -f "$KEYSTORE_DIR/comtamtycoon-release.jks" ] || die "Không thấy keystore trong $KEYSTORE_DIR"
if [ -f "$KEYSTORE_DIR/.pw" ]; then
	pw="$(tr -d '\r\n' < "$KEYSTORE_DIR/.pw")"
else
	# .pw có thể chưa được tạo lại sau khi khôi phục backup — xem RECOVERY.md
	pw="li4Bw28AYPxXEieWRUqBP9JvTWKnBO5t"
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE_DIR/comtamtycoon-release.jks"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="comtamtycoon"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$pw"

mkdir -p build
"$GODOT" --headless --path . --export-release "Android" "$APK" 2>&1 | tail -4
[ -f "$APK" ] || die "Export thất bại, không thấy $APK"
printf 'APK: %s (%s)\n' "$APK" "$(du -h "$APK" | cut -f1)"

if [ "$build_only" = 1 ]; then
	say "Xong (chỉ build)."
	exit 0
fi

# ---------- 2. Bắt liên lạc với điện thoại ----------
connected() { adb devices | grep -qE '\bdevice$'; }

try_connect() {
	adb connect "$1:5555" >/dev/null 2>&1 || true
	sleep 1
	connected
}

# Dò cả subnet tìm máy nào mở cổng 5555 (IP điện thoại đổi mỗi lần đổi Wi-Fi).
scan_subnet() {
	local base
	base="$(ipconfig 2>/dev/null | grep -oE '192\.168\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f1-3)"
	base="${base:-192.168.1}"
	say "Dò $base.2-254 tìm cổng ADB 5555"
	powershell -NoProfile -Command "
		\$t=@(); 2..254 | ForEach-Object {
			\$c=New-Object Net.Sockets.TcpClient
			\$t += [pscustomobject]@{ip=\"$base.\$_\";c=\$c;task=\$c.ConnectAsync(\"$base.\$_\",5555)} }
		Start-Sleep -Milliseconds 2500
		foreach(\$x in \$t){ if(\$x.task.Status -eq 'RanToCompletion' -and \$x.c.Connected){ \$x.ip }; \$x.c.Close() }
	" | tr -d '\r'
}

say "Kết nối điện thoại"
if [ "$do_scan" = 1 ]; then
	ip=""
elif [ -z "$ip" ] && [ -f "$LAST_DEVICE" ]; then
	ip="$(tr -d '\r\n' < "$LAST_DEVICE")"
	echo "Dùng IP đã lưu: $ip"
fi

if [ -n "$ip" ]; then
	try_connect "$ip" || { echo "IP $ip không bắt được, chuyển sang dò mạng."; ip=""; }
fi

if [ -z "$ip" ] && ! connected; then
	for found in $(scan_subnet); do
		echo "Thấy $found"
		if try_connect "$found"; then ip="$found"; break; fi
	done
fi

connected || die "Không thấy điện thoại. Bật lại Wi-Fi debugging (hoặc cắm dây USB) rồi chạy lại."
[ -n "$ip" ] && printf '%s' "$ip" > "$LAST_DEVICE"
adb devices -l | grep -E '\bdevice\b' | sed 's/^/  /'

# ---------- 3. Cài ----------
say "Cài $APK"
if ! adb install -r "$APK"; then
	die "Cài hỏng. Nếu là INSTALL_FAILED_UPDATE_INCOMPATIBLE thì bản trên máy ký bằng key khác — gỡ app rồi cài lại: adb uninstall $PKG"
fi

if [ "$do_run" = 1 ]; then
	say "Mở game"
	adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
fi

say "Xong."
