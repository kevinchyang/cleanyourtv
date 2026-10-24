#!/usr/bin/env bash

TV_IP="${TV_HOST:-192.168.200.12}"
PORT="5555"
TARGET="$TV_IP:$PORT"

echo "==========================================="
echo "   Sony KD-65X8500F 系統最佳化狀態檢查"
echo "==========================================="

# 1. 檢查 ADB 連線
echo -n "[1/5] 檢查 ADB 連線 ($TARGET)... "
adb connect "$TARGET" > /dev/null 2>&1
DEVICE_STATE=$(adb devices | grep "$TARGET" | awk '{print $2}')

if [ "$DEVICE_STATE" == "device" ]; then
    echo "連線正常"
else
    echo "連線失敗 (目前狀態: $DEVICE_STATE)"
    echo "請確認電視開機並連接 Wi-Fi，且 ADB 網路偵錯已開啟。"
    exit 1
fi

# 2. 檢查已停用的垃圾服務狀態
echo ""
echo "[2/5] 檢查已停用套件狀態 (預期皆為 disabled-user)："
DEBLOAT_PACKAGES=(
    "com.sony.dtv.b2b.hotelmode"
    "com.sony.dtv.b2b.rs232csupport"
    "com.sony.dtv.b2b.vendorprotocol"
    "com.sony.dtv.sonyselect"
    "com.sony.dtv.smarthelp"
    "com.sony.dtv.interactivetvutil"
    "com.google.android.tvrecommendations"
    "com.google.android.play.games"
)

for pkg in "${DEBLOAT_PACKAGES[@]}"; do
    STATUS=$(adb shell pm list packages -d | grep "^package:$pkg$")
    if [ -n "$STATUS" ]; then
        printf "  - %-40s [OK] 已停用\n" "$pkg"
    else
        IS_INSTALLED=$(adb shell pm list packages | grep "^package:$pkg$")
        if [ -n "$IS_INSTALLED" ]; then
            printf "  - %-40s [WARN] 依然在啟用狀態 (重啟被復原)\n" "$pkg"
        else
            printf "  - %-40s [INFO] 電視未安裝此套件\n" "$pkg"
        fi
    fi
done

# 3. 檢查 HomeKeyService 攔截服務狀態
echo ""
echo "[3/5] 檢查 Apple TV Launcher 及按鍵攔截服務："
CURRENT_HOME=$(adb shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME | grep "name=" | head -n1 | sed 's/.*name=//; s/ .*//')
echo "  - 當前系統預設 Home: $CURRENT_HOME"

ACCESSIBILITY_SERVICES=$(adb shell settings get secure enabled_accessibility_services)
if [[ "$ACCESSIBILITY_SERVICES" == *"com.gathin.tvhome"* ]]; then
    echo "  - HomeKeyService 攔截服務: [OK] 啟用中"
else
    echo "  - HomeKeyService 攔截服務: [WARN] 未啟用或已被關閉"
fi

# 4. 檢查動畫縮放速度
echo ""
echo "[4/5] 檢查視窗與轉場動畫比例 (預期為 0.5)："
SCALE_WIN=$(adb shell settings get global window_animation_scale | tr -d '\r')
SCALE_TRANS=$(adb shell settings get global transition_animation_scale | tr -d '\r')
SCALE_ANIM=$(adb shell settings get global animator_duration_scale | tr -d '\r')

echo "  - 視窗動畫比例 (window_animation_scale):     $SCALE_WIN"
echo "  - 轉場動畫比例 (transition_animation_scale): $SCALE_TRANS"
echo "  - 動畫秒數比例 (animator_duration_scale):   $SCALE_ANIM"

# 5. 檢查背景快取處理程序限制
echo ""
echo "[5/5] 檢查背景快取處理程序上限："
CACHED_SETTING=$(adb shell settings get global activity_manager_constants | tr -d '\r')
if [[ "$CACHED_SETTING" == *"max_cached_processes=2"* ]]; then
    echo "  - 背景快取上限: [OK] max_cached_processes=2 (設定維持中)"
else
    echo "  - 背景快取上限: [INFO] 系統已還原為原廠預設 (內容: ${CACHED_SETTING:-預設})"
fi

echo ""
echo "==========================================="
echo "檢查完畢。"
