#!/usr/bin/env bash
# App Store 用のスクリーンショットをシミュレータで撮る。
# store-screenshots.yml から呼ばれる。ローカルでも実行できる。
#
# 前提: RUNNER_TEMP/dd に Debug ビルド済みの Shiritori.app があること。
# 環境変数:
#   TARGET       … iphone / ipad / both（既定 both）
#   RUNNER_TEMP  … 作業ディレクトリ（未設定なら mktemp）
set -euo pipefail

RUNNER_TEMP="${RUNNER_TEMP:-$(mktemp -d)}"
TARGET="${TARGET:-both}"

APP="$RUNNER_TEMP/dd/Build/Products/Debug-iphonesimulator/Shiritori.app"
if [ ! -d "$APP" ]; then
  echo "::error::アプリが見つかりません: $APP"
  exit 1
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
OUT="$RUNNER_TEMP/screenshots"
mkdir -p "$OUT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 撮る画面（ScreenshotScene の名前と一致させる）。
SCENES=(setup game keyboard nearby solo help result)

# 条件に合うシミュレータを1台選ぶ（機種名はハードコードしない）。
pick_device() {
  xcrun simctl list devices available --json \
    | python3 "$SCRIPT_DIR/pick_simulator.py" "$1" "$2"
}

capture_on() {
  local kind="$1" prefer="$2" label="$3"
  local line udid name

  line=$(pick_device "$kind" "$prefer")
  if [ -z "$line" ]; then
    echo "::warning::$kind のシミュレータが見つかりません。スキップします。"
    return 0
  fi
  udid=$(printf '%s' "$line" | cut -f1)
  name=$(printf '%s' "$line" | cut -f2)

  echo "::group::$label — $name"

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  # 時刻・電波・バッテリーをストア向けの見た目に固定する。
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 \
    --wifiMode active --wifiBars 3 || true

  xcrun simctl install "$udid" "$APP"

  local dir="$OUT/$label"
  mkdir -p "$dir"

  local n=1 idx
  for scene in "${SCENES[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshotScene "$scene" >/dev/null
    # 画面の描画とシートのアニメーションが終わるのを待つ。
    sleep 4
    printf -v idx "%02d" "$n"
    xcrun simctl io "$udid" screenshot --type=png "$dir/${idx}-${scene}.png"
    n=$((n + 1))
  done

  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl shutdown "$udid" || true
  echo "::endgroup::"
}

if [ "$TARGET" = "iphone" ] || [ "$TARGET" = "both" ]; then
  # App Store の 6.9 インチ枠に合う大きい iPhone を優先する。
  capture_on "iPhone" "Pro Max" "iphone"
fi
if [ "$TARGET" = "ipad" ] || [ "$TARGET" = "both" ]; then
  capture_on "iPad" "iPad Pro" "ipad"
fi

# 撮れた画像とサイズの一覧を出す（App Store の要求サイズと突き合わせるため）。
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
{
  echo "## 撮影したスクリーンショット"
  echo ""
  echo "| ファイル | サイズ |"
  echo "|---|---|"
  find "$OUT" -name '*.png' | sort | while read -r file; do
    size=$(sips -g pixelWidth -g pixelHeight "$file" \
      | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w" x "h}')
    echo "| ${file#"$OUT"/} | $size |"
  done
  echo ""
  echo "App Store の要求サイズ: iPhone 6.9インチ = 1320 x 2868 / iPad 13インチ = 2064 x 2752"
} >> "$summary"

echo "スクリーンショットの保存先: $OUT"
