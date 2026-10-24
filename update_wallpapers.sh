#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIN_SRC="/mnt/c/Users/kevin/Downloads/TV_wallpaper"
THEME_DIR="$PROJECT_ROOT/themes/mytheme"
WP_DIR="$THEME_DIR/wallpapers"

echo "=========================================="
echo " CleanYourTV 桌布自動同步與部署程序"
echo "=========================================="

# 1. 檢查來源目錄是否存在且包含圖檔
if [ ! -d "$WIN_SRC" ] || [ -z "$(ls -A "$WIN_SRC" 2>/dev/null)" ]; then
  echo "錯誤: 來源目錄 $WIN_SRC 不存在或裡面沒有任何圖檔！"
  exit 1
fi

# 2. 檢查電視連線並自動取得 IP
echo "[1/6] 偵測電視連線狀態..."
TV_IP=$(adb devices | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}' | cut -d: -f1 | head -n1)

if [ -z "$TV_IP" ]; then
  echo "錯誤: 找不到已連線的電視 IP，請確認電視已開啟 ADB 網路除錯並連線！"
  adb devices
  exit 1
fi
echo "已鎖定電視 IP: $TV_IP"

# 3. 清理電視端與 WSL 本機舊圖檔
echo "[2/6] 清理舊圖檔..."
rm -rf "$WP_DIR"/*
adb shell "rm -rf /sdcard/theme/wallpapers/*"

# 4. 從 Windows 下載資料夾同步最新桌布
echo "[3/6] 從 Windows 下載資料夾同步最新桌布..."
mkdir -p "$WP_DIR"
cp -r "$WIN_SRC"/* "$WP_DIR"/
IMAGE_COUNT=$(ls -1 "$WP_DIR" | wc -l)
echo "已複製 $IMAGE_COUNT 張新桌布。"

# 5. 寫入標準偏好設定 (4 小時輪播、Dock 30% 透明度、30 分鐘待機)
echo "[4/6] 寫入偏好設定..."
cat << 'CONFIG_EOF' > "$THEME_DIR/config.json"
{
  "wallpaper": true,
  "wallpaper_rotation_minutes": 240,
  "wallpaper_order": "shuffle",
  "wallpaper_dim": 25,
  "wallpaper_true_color": false,
  "wallpaper_captions": false,
  "dock_opacity": 30,
  "home_idle_clock_minutes": 30
}
CONFIG_EOF

# 6. 呼叫官方 tools/theme.sh 部署至電視
echo "[5/6] 執行 tools/theme.sh 部署至電視..."
cd "$PROJECT_ROOT"
TV_HOST=$TV_IP ./tools/theme.sh themes/mytheme

# 7. Git 提交並同步至 GitHub
echo "[6/6] 提交變更至 Git 並推送到 GitHub..."
git add -A
git commit -m "Update wallpapers and config: 240m rotation, 30% dock opacity, 30m idle clock" || echo "無變更需要 commit"
git push origin $(git rev-parse --abbrev-ref HEAD)

echo "=========================================="
echo " 部署完成！"
echo "=========================================="
echo "--- 電視端目前生效設定 ---"
adb shell "cat /sdcard/theme/config.json"
