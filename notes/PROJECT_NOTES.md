# PROJECT_NOTES（Shiritori）

このファイルを**単一の正**として扱う。セッション開始時にまず読み、作業後に更新する。

最終更新: 2026-07-30

---

## 概要

友達と遊ぶ、しりとり iOS アプリ（SwiftUI）。
対戦は**パス＆プレイ（同一端末）**と**オンライン対戦（Game Center・2人・ターン制）**の2通り。
パス＆プレイでは単語の実在判定でのみ外部通信する。

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
    OnlineMatchState.swift  オンライン対戦で受け渡す状態＋オンライン用ルール調整
    OnlineMatchManager.swift Game Center（GKTurnBasedMatch）の管理
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
    TurnBasedMatchmakerView.swift  Game Center 標準マッチメイキング画面のラッパ
    Theme.swift             共通の見た目（背景・カード・ボタン・フォント）
  Resources/words.txt       同梱ひらがな辞書（約1,200語）
ShiritoriTests/             ユニットテスト（XCTest, ホスト付き）
  KanaUtilsTests.swift      かな正規化・接続判定
  GameSettingsTests.swift   設定の丸め込み・後方互換デコード
  OnlineMatchStateTests.swift  オンライン状態の受け渡し・手番制御
Info.plist                  実ファイル（AdMob のアプリID等）※同期グループ外
Shiritori.entitlements      Game Center の entitlement ※同期グループ外
Shiritori.xcodeproj         objectVersion 77（Xcode 16 以降）
.github/workflows/
  ci.yml                    PR / main push で iOS ビルド検証
  testflight.yml            手動実行（Actions → TestFlight → Run workflow）
```

---

## 主要な設計判断

- **対戦方式はパス＆プレイ（同一端末）＋オンライン対戦（Game Center・2人）。**
- **オンラインは `GKTurnBasedMatch`（非同期ターン制）を採用。** リアルタイム
  （`GKMatch`）ではなくこちらにした理由:
  - 対局データを Apple が預かるので**自前サーバーが不要**。
  - 相手が同時にオンラインでなくても成立する。**新規アプリで「自動マッチングしても
    誰もいない」問題を回避できる**のが決定的（対局が待機状態で残り、後から来た人と繋がる）。
  - 手番が回ると Game Center が通知を出す（APNs の自前実装が不要）。
  - 切断処理をほぼ書かなくてよい。
- **オンラインの状態受け渡しは `OnlineMatchState`。** 中断保存（`SavedGame`）の
  シリアライズ設計をそのまま流用できた（`Move` が既に `Codable` だった）。
- **履歴は再判定しない。** 判定は常に「その語を出した本人の端末」で行い、結果を履歴に
  焼き込む。だから端末間で辞書が違っても破綻しない。
- **オンラインでは一部ルールを落とす**（`onlineSanitized()`）。
  - 端末の国語辞書 → **不公平**（入れている辞書で結果が変わる）ので使わない。
  - 参加者承認 → 相手に口頭確認できないので使わない。
  - 秒単位の制限時間 → 非同期なので無意味。Game Center のターン制限（1週間）を使う。
  - Wikipedia 判定は**残す**（上記のとおり判定者が一貫しているため問題にならない）。
- **対局の受け取り口は `GKLocalPlayerListener` の1本に集約。**
  マッチメイキング画面の「対局が選ばれた」デリゲートは**非推奨**なので使わない。
- **単語の実在判定は4段構え。** ①同梱辞書 `words.txt` → ②端末の国語辞書
  （`UIReferenceLibraryViewController`）→ ③日本語 Wikipedia（タイトル完全一致）
  → ④参加者承認。①②で当たれば通信しないので、一般語は速い。
- **Wikipedia はタイトル完全一致で見る。** 全文検索は不可（後述の教訓）。
  読みのひらがな表記とカタカナ表記の両方を候補にして、カタカナのキャラ名・固有名詞を拾う。
- **入力はアプリ内キーボードが既定。** システムIMEだと予測変換・変換候補で次の手が
  相手に読まれてしまうため。フリック入力と50音タップを設定で選べる（既定フリック）。
- **かな判定ロジック**は `KanaUtils`。長音「ー」・小書き文字・濁音同一視・「ん」止まり・
  重複禁止に対応。
- **長音「ー」で終わる語は、直前のかな・その母音の両方で接続を許す。**
  例:「コーヒー」の次は「ひ」でも「い」でもOK（`connectingKanaOptions`）。
  「長音は母音とみなす」流派との齟齬をなくすため。表示バッジは代表として直前のかなを出す。
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
| オンライン対戦 | Game Center で2人・ターン制（非同期）。友達招待＋自動マッチング |
| 文字数ルール | 最小/最大の指定、または**ランダム文字数モード**（毎ターン2〜9文字ちょうど） |
| 実在判定 | 同梱辞書 → 端末辞書 → Wikipedia → 参加者承認 |
| 入力 | フリック入力 / 50音タップ（アプリ内・予測変換なし）、システムIMEも選択可 |
| ヒント | 電球ボタン。答えは出さず「◯文字で、終わりの音は『◯』」だけ。**1手番2回まで** |
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
- **シミュレータ機種名はハードコードしない** → `simctl` で利用可能な iPhone を動的に選び、
  その UDID を宛先にして `xcodebuild test` を実行（ビルド検証とユニットテストを兼ねる）。
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
| #10 | 起動クラッシュの修正 | ✅ **実機で起動・動作を確認済み(2026-07-28)** |

---

## 残タスク

- [x] build #10 の実機起動を確認 — 完了(2026-07-28)。#9 の起動クラッシュが解消し、
      問題なく動作することを確認。原因は AdMob のアプリID未設定で確定。
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
- [x] （任意）かな判定ロジックのユニットテストを追加し CI に組み込む — 完了(2026-07-28)。
      `ShiritoriTests`（XCTest, ホスト付き）を追加し、`KanaUtils` と `GameSettings` を検証。
      CI は `xcodebuild test` に変更（シミュレータは動的選択）。**この環境に Xcode が無く、
      pbxproj/CI 変更は未コンパイル**なので、実際の緑は PR の CI で確認すること。
- [ ] （任意）UI の実機調整（パステル背景の濃さ、ダークモードでの見え方）。
- [ ] （任意）ポイントの獲得量・アイコン価格のバランス調整、オリジナル画像アイコン。
- [ ] （任意）効果音 / 使った単語の共有 / 単語の意味リンク / iPad 表示最適化。
- [x] オンライン対戦の**第1段階**（Game Center・2人・ターン制）— 実装(2026-07-30)。
      `GKTurnBasedMatch` 方式。**この環境に Xcode が無いためコンパイル未検証**で、
      GameKit の API 利用と entitlement 追加は PR の CI で初めて検証される。
      **実機での対局確認も未実施**（下記の手作業が必要）。
- [ ] **オンライン対戦の実機確認**（ユーザーの手作業が必要）。
      - App Store Connect でこのアプリの **Game Center を有効化**する。
      - **サンドボックスの Game Center アカウント2つ**（実機2台、または実機＋別アカウント）が必要。
        1人1台だと対局の両側を確認できない。
      - 確認したいこと: サインイン → 招待で対局作成 → 相手に通知が届く → 交互に打てる →
        「ん」止まり/降参で決着 → Game Center の対局一覧に結果が残る。
- [ ] **オンライン対戦の第2段階以降**（第1段階の実機確認が終わってから）。
      - 自動マッチングは標準UIに含まれているので**すでに動く経路はある**が、
        プレイヤーが増えるまでは相手が見つからない。告知後に様子を見る。
      - 3人以上のオンライン対戦、リアルタイム対戦は未着手。
      - ResultView の「もう一度」がオンラインでは使えない（設定画面へ戻る動線のみ）。
        同じ相手と続けて遊ぶ「リマッチ」は未実装。

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
- **entitlements ファイルも同期グループの外（リポジトリ直下）に置く。**
  Info.plist と同じ理由（`Shiritori/` 配下だとリソースとして二重に取り込まれる）。
- **Game Center の entitlement を足すと署名の前提が変わる。** App ID 側でも Game Center を
  有効にする必要がある。TestFlight ワークフローは自動署名（`-allowProvisioningUpdates`）
  なので Xcode がプロファイルを作り直すが、**このリポジトリは署名で何度も詰まっている**ので
  entitlement を触った回は TestFlight の Archive ログを必ず確認する。
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
