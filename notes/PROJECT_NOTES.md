# PROJECT_NOTES（Shiritori）

このファイルを**単一の正**として扱う。セッション開始時にまず読み、作業後に更新する。

最終更新: 2026-07-28

---

## 概要

友達と同じ端末で交代しながら遊ぶ、しりとり iOS アプリ（SwiftUI）。
対戦はパス＆プレイ（同一端末）。単語の実在判定でのみ外部通信する。

配信: TestFlight（Bundle ID `io.github.ysu119190-lab.mojitori`、表示名「しりとり」）

### ファイル構成

```
Shiritori/
  ShiritoriApp.swift        エントリポイント
  Models/
    ShiritoriGame.swift     進行の中心（手番・判定・中断保存・ヒント）
    GameSettings.swift      設定（UserDefaults, 保存キー v2）
    KanaUtils.swift         かな正規化・接続判定・濁点/小書き循環表
    WordValidator.swift     同梱辞書＋端末辞書、お題/ヒント候補の抽出
    WebValidator.swift      日本語 Wikipedia でのタイトル完全一致判定
    SavedGame.swift         中断データの永続化
    PointsStore.swift       しりとりポイント＋アイコン所持
    AdManager.swift         AdMob インタースティシャル（＋AdConfig）
    GameRecord.swift        最長記録
    Haptics.swift           触覚フィードバック
  Views/
    RootView.swift          フェーズ切替＋スプラッシュ＋起動時広告
    SplashView.swift        起動モーション
    SetupView.swift         設定・再開・ポイント入口
    GameView.swift          対戦画面
    ResultView.swift        決着画面
    ShopView.swift          こうかん所（アイコン交換）
    KanaKeyboard.swift      50音タップ入力
    FlickKeyboard.swift     フリック入力
    Theme.swift             共通の見た目（背景・カード・ボタン・フォント）
  Resources/words.txt       同梱ひらがな辞書（約1,200語）
Info.plist                  実ファイル（AdMob のアプリID等）※同期グループ外
Shiritori.xcodeproj         objectVersion 77（Xcode 16 以降）
.github/workflows/
  ci.yml                    PR / main push で iOS ビルド検証
  testflight.yml            手動実行（Actions → TestFlight → Run workflow）
```

---

## 主要な設計判断

- **対戦方式はパス＆プレイ（同一端末）。** オンライン対戦はサーバー基盤/Game Center が
  必要で見送り。将来 Game Center や MultipeerConnectivity で拡張可能な構成にしてある。
- **単語の実在判定は4段構え。** ①同梱辞書 `words.txt` → ②端末の国語辞書
  （`UIReferenceLibraryViewController`）→ ③日本語 Wikipedia（タイトル完全一致）
  → ④参加者承認。①②で当たれば通信しないので、一般語は速い。
- **Wikipedia はタイトル完全一致で見る。** 全文検索は不可（後述の教訓）。
  読みのひらがな表記とカタカナ表記の両方を候補にして、カタカナのキャラ名・固有名詞を拾う。
- **入力はアプリ内キーボードが既定。** システムIMEだと予測変換・変換候補で次の手が
  相手に読まれてしまうため。フリック入力と50音タップを設定で選べる（既定フリック）。
- **かな判定ロジック**は `KanaUtils`。長音「ー」・小書き文字・濁音同一視・「ん」止まり・
  重複禁止に対応。
- **ゲーム開始時のお題はアプリが出題**（`isSeed`）。記録の語数 `chainCount` には数えない。
- **`PointsStore` は @MainActor にしない。** 非 MainActor の `ShiritoriGame` から
  加算するため。呼び出しは実際にはすべてメインスレッド上。
- **広告は「出せなければ出さない」。** アプリIDが無い / 未ロード / 画面遷移中は黙って
  スキップし、ゲームは絶対に止めない。

---

## 実装済みの機能

| 機能 | 概要 |
|---|---|
| 基本のしりとり | 2〜6人のパス＆プレイ。重複・「ん」止まり・接続を判定 |
| 文字数ルール | 最小/最大の指定、または**ランダム文字数モード**（毎ターン2〜9文字ちょうど） |
| 実在判定 | 同梱辞書 → 端末辞書 → Wikipedia → 参加者承認 |
| 入力 | フリック入力 / 50音タップ（アプリ内・予測変換なし）、システムIMEも選択可 |
| ヒント | 電球ボタン。答えは出さず「◯文字で、終わりの音は『◯』」だけ |
| 中断と再開 | 「中断して保存」→ 設定画面から「続きから再開する」 |
| しりとりポイント | 単語 +1 / 決着 +5 / 記録更新 +10。アイコン12種と交換（こうかん所） |
| 演出 | 起動スプラッシュ、単語受理時のキラキラ、触覚フィードバック |
| 制限時間 | 1手ごとの秒数指定（任意） |
| 広告 | 起動時・開始時・決着時のインタースティシャル（**60秒の頻度制限**） |

---

## 環境メモ

- この作業環境には **Swift/Xcode が無い**ため、ローカルでコンパイル検証できない。
  → CI（macOS ランナーでの実ビルド）で毎回検証する。
  **ただし CI が緑でも「実機で起動する」保証はない**（後述の教訓）。
- 実機実行時は Signing で Apple Developer チームの選択が必要。

---

## CI / TestFlight 運用

### CI（`ci.yml`）

- **PR 単位で起動**（`pull_request` → main）＋ **main への push 時**。
  ブランチ push だけでは起動しない。
- `concurrency` + `cancel-in-progress` で古い実行を自動キャンセル
  （macOS ランナーは無料枠を10倍消費するため）。
- **シミュレータ機種名はハードコードしない** → `generic/platform=iOS Simulator`。
- **Xcode バージョンは明示選択。**
- CI 失敗はログ本文でなく **run の URL** を共有して追う。

### TestFlight（`testflight.yml`）

- **main から手動実行**（Actions → TestFlight → Run workflow）。
- 署名は**自動署名**（ASC APIキー + `-allowProvisioningUpdates`）。
  ビルド番号は run number で単調増加、マーケティングバージョンは pbxproj の `MARKETING_VERSION`。
- 必要な Secrets: `DIST_CERT_P12_BASE64` / `P12_PASSWORD` /
  `ASC_API_KEY_P8_BASE64` / `ASC_KEY_ID` / `ASC_ISSUER_ID`。

### ビルド履歴（TestFlight）

| build | 内容 | 結果 |
|---|---|---|
| #2 | 初回アップロード成功（自動署名へ変更後） | ✅ |
| #3 | ランダム文字数モード・かなキーボード | ✅ |
| #4 | 起動/受理の演出、かな入力を既定オン | ✅ |
| #5 | （#6と同内容） | ❌ 証明書の上限 |
| #6 | Wikipedia 判定 | ✅ revoke 後に成功 |
| #7 | Wikipedia 完全一致修正・フリック入力 | ✅ |
| #8 | お題の自動出題・中断保存・UI刷新 | ✅ |
| #9 | 広告・ヒント・ポイント | ✅ アップロードは成功。**起動直後にクラッシュ** |
| #10 | 起動クラッシュの修正 | ✅ **実機での起動確認は未完了** |

---

## 残タスク

- [ ] **build #10 の実機起動を確認する**（最優先）。#9 の起動クラッシュが直ったかの検証。
      まだ落ちる場合はクラッシュログ（設定 → プライバシーとセキュリティ → 解析データ、
      または TestFlight のフィードバック）を見て原因を特定する。
- [ ] **広告を本番IDに差し替える**（リリース前）。作業は2箇所だけ:
      `AdConfig.productionInterstitialUnitID` と `Info.plist` の `GADApplicationIdentifier`。
      AdMob 側でアプリ登録と広告ユニット作成が必要（ユーザーの手作業）。
      あわせて `SKAdNetworkItems` に各広告ネットワークの識別子を追加すると計測精度が上がる
      （いまは Google の1件のみ）。
      注意: 開発中に本番IDを使うと無効トラフィック扱いでアカウント停止リスク。
- [ ] **証明書の増えすぎ対策**（再発防止）。自動署名は毎回 Apple Development 証明書を
      新規発行するため、放置するとまた上限に達する。定期的に revoke するか、
      配布証明書＋プロファイル明示指定の方式に寄せるか要検討
      （ただし過去に不一致で失敗した経緯あり。やるなら慎重に）。
- [ ] （任意）かな判定ロジックのユニットテストを追加し CI に組み込む。
- [ ] （任意）UI の実機調整（パステル背景の濃さ、ダークモードでの見え方）。
- [ ] （任意）ポイントの獲得量・アイコン価格のバランス調整、オリジナル画像アイコン。
- [ ] （任意）効果音 / 使った単語の共有 / 単語の意味リンク / iPad 表示最適化。
- [ ] （任意）オンライン対戦（Game Center or MultipeerConnectivity）。開発者登録は加入済み。

---

## 教訓メモ

### ビルド・リリース

- **CI が緑でも「実機で動く」保証はない。** build #9 は CI もアップロードも成功したが、
  起動直後にクラッシュした。CI が見ているのは「コンパイルとリンクが通るか」だけ。
  外部SDKを入れた回は、実機での起動確認までを1セットにする。
- **Info.plist の任意キーは `INFOPLIST_KEY_` で注入しない。** サードパーティ製のキー
  （`GADApplicationIdentifier` 等）は反映されないことがあり、これが #9 のクラッシュ原因。
  必要なら実ファイルの Info.plist を用意する（配列値もこちらでないと書けない）。
  実ファイルは**同期グループの外**（リポジトリ直下）に置くとリソース二重コピーを避けられる。
- **自動署名は証明書を使い切る。** Apple Development 証明書の発行上限に達すると
  `Choose a certificate to revoke.` で Archive が失敗する。Apple Developer の
  Certificates から古いものを revoke すれば復旧する。
- CI の手動署名は「プロファイルに含まれる証明書」と「.p12 の証明書」の不一致が起きやすい。
  自動署名なら回避できる。
- `.p12` は**レガシー形式**でエクスポートしないと macOS ランナーが読めない。
- マージ済み PR のブランチに積み増さない。追加作業は最新 main から作り直す。

### 実装

- **「実在判定」に全文検索を使わない。** Wikipedia を `list=search` で引くと本文まで
  部分一致してほぼ全ての語がヒットし、「全部OK」になってしまった。
  タイトル（＋リダイレクト）の完全一致で見る。
- **外部SDKの初期化は失敗し得る前提で書く。** アプリIDの有無を確認してから初期化し、
  ダメなら機能ごと無効にしてアプリは動かす。SDK は平気で例外を投げて落としてくる。
- **設定の既定値を変えるときは保存キーも上げる。** 旧既定値が UserDefaults に
  残っていると新しい既定が効かない（かなキーボードを既定オンにした際に v2 へ）。
- 新しい設定項目は `decodeIfPresent` で後方互換にする。
- 全画面 UI（広告など）の present は、前面の遷移が完全に終わってから行う。
- 本番の広告 ID を Debug ビルドに入れない（`#if DEBUG` でテスト ID に切替）。

### 運用

- 別リポジトリ（photouploader）はセッションのソースに追加されていないとアクセス不可。
- 新しい作業は新セッションで始め、最初にこのファイルを読ませて引き継ぐ。
