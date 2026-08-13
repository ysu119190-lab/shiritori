#!/usr/bin/env python3
"""利用できるシミュレータから1台を選び「UDID<TAB>名前」を出力する。

機種名をワークフローにハードコードすると、ランナーイメージの更新で
その機種が消えたときに壊れる。実際に存在する端末から動的に選ぶ。

使い方:
    xcrun simctl list devices available --json | ./pick_simulator.py iPhone "Pro Max"

第1引数: 名前に含まれる種別（iPhone / iPad）
第2引数: 優先したい名前の一部（省略可。該当が無ければ種別の中から選ぶ）

見つからないときは何も出力せず、終了コード 0 を返す（呼び出し側でスキップ判定する）。
"""
import json
import sys


def main() -> int:
    kind = sys.argv[1] if len(sys.argv) > 1 else "iPhone"
    prefer = sys.argv[2] if len(sys.argv) > 2 else ""

    try:
        devices = json.load(sys.stdin).get("devices", {})
    except json.JSONDecodeError:
        print("シミュレータ一覧を読み取れませんでした", file=sys.stderr)
        return 1

    candidates = [
        device
        for runtime in devices
        for device in devices[runtime]
        if device.get("isAvailable") and kind in device.get("name", "")
    ]
    if not candidates:
        return 0

    preferred = [d for d in candidates if prefer and prefer in d["name"]] or candidates
    # 名前順の最後は、だいたい新しい／大きい機種になる（16 > 15、Pro Max > Pro）。
    preferred.sort(key=lambda d: d["name"])
    chosen = preferred[-1]
    print(f"{chosen['udid']}\t{chosen['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
