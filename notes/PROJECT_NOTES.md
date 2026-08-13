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
    CPUOpponent.swift       CPUの手の選択（難易度別・乱数注入でテスト可能）
    SoloStats.swift         1人プレイの戦績（勝敗・連勝・最高連勝）
    NearbySession.swift     近距離通信（MultipeerConnectivity）の薄いラッパー
    PeerMessage.swift       端末間メッセージと GameSnapshot（Codable）
    GameCenterManager.swift Game Center 認証＋ターン制対戦の受け渡し
    OnlineMatchState.swift  matchData として持ち回るゲーム状態（Codable）
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
    NearbyLobbyView.swift   近くの端末と待ち合わせて接続する画面
    GameCenterMatchmakerView.swift  対戦相手さがし画面のブリッジ
  Resources/words.txt       厳選辞書（約1,200語・出題/ヒント/判定）
  Resources/words-large.txt 検証用拡張辞書（約45,000語・判定のみ。ipadic由来）
  Resources/ipadic-COPYING.txt  拡張辞書のライセンス（同梱必須）
ShiritoriTests/             ユニットテスト（XCTest, ホスト付き）
  KanaUtilsTests.swift      かな正規化・接続判定
  GameSettingsTests.swift   設定の丸め込み・後方互換デコード
  WordValidatorTests.swift  同梱辞書の実在判定（オフライン）
  CPUOpponentTests.swift    CPUの手の選択（乱数固定で決定的に検証）
  SoloStatsTests.swift      戦績・連勝の記録（専用UserDefaultsスイート）
  PeerMessageTests.swift    通信メッセージ/スナップショットの往復
  OnlineMatchStateTests.swift  オンライン対戦データの往復・プレイヤー登録
Info.plist                  実ファイル（AdMob のアプリID・ローカルネットワーク権限等）※同期グループ外
Shiritori.entitlements      Game Center の entitlement ※App ID 側の有効化も必要
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
- **長音「ー」で終わる語は、直前のかな・その母音の両方で接続を許す。**
  例:「コーヒー」の次は「ひ」でも「い」でもOK（`connectingKanaOptions`）。
  「長音は母音とみなす」流派との齟齬をなくすため。表示バッジは代表として直前のかなを出す。
- **ゲーム開始時のお題はアプリが出題**（`isSeed`）。記録の語数 `chainCount` には数えない。
- **`PointsStore` は @MainActor にしない。** 非 MainActor の `ShiritoriGame` から
  加算するため。呼び出しは実際にはすべてメインスレッド上。
- **近距離対戦はホスト権威にする。** ホストが `ShiritoriGame` を動かし、状態スナップショットを
  配る。ゲストは入力を送るだけで自分では判定しない（両端末で判定すると食い違うため）。
  ゲストの時計は表示のみで、決着を宣言するのはホスト。
- **オンライン対戦は状態を持ち回る方式。** ホスト権威ではなく、手番の端末だけが
  `OnlineMatchState` を書き換えて次の人へ渡す。同時に書き換わらないので競合しない。
  プレイヤーは「手番が回ってきた人から順に登録」して、参加の順番に依存しないようにする。
- **通信対戦では実在判定を同梱辞書だけにする。** ウェブ判定や参加者承認は非同期の
  往復が増えて待ちが読めないため、46,000語のオフライン辞書で即断する。
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
| ヒント | 電球ボタン。答えは出さず「◯文字で、終わりの音は『◯』」だけ。**1手番2回まで** |
| 中断と再開 | 「中断して保存」→ 設定画面から「続きから再開する」 |
| しりとりポイント | 単語 +1 / 決着 +5 / 記録更新 +10。アイコン12種と交換（こうかん所） |
| 演出 | 起動スプラッシュ、単語受理時のキラキラ、触覚フィードバック |
| 制限時間 | 1手ごとの秒数指定（任意） |
| 1人プレイ | CPU対戦（よわい/ふつう/つよい）。勝敗・連勝を記録、勝利でボーナスポイント |
| 近くの人と対戦 | MultipeerConnectivity で2台を直結。**ホスト権威**（判定はホストのみ） |
| はなれた人と対戦 | Game Center のターン制。状態を matchData で持ち回る（打つ側が判定） |
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
- [x] **広告を本番IDに差し替える** — 完了(2026-08-10)。AdMob アプリ登録（ユーザー）後、
      `Info.plist` の `GADApplicationIdentifier` と `AdConfig.productionInterstitialUnitID`
      を本番IDに設定。Debug ビルドは従来どおりテストID（`#if DEBUG`）。
      バナー用ユニットIDも発行済み（AdManager.swift のコメントに記録・未実装）。
      注意: 本番IDのビルドで広告を自分で何度もタップしない（無効トラフィック対策）。
- [ ] （任意）`SKAdNetworkItems` に各広告ネットワークの識別子を追加すると計測精度が上がる
      （いまは Google の1件のみ）。
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

## 課題記録: ネット判定（Wikipedia）の精度が悪い (2026-08-10)

- 症状: 普通の名詞（えんとつ・はなたば等）が「辞書に見つかりません」になりがち。
- 原因: Wikipediaは百科事典で記事タイトルが漢字表記のため、読み（かな）の
  タイトル完全一致では一般名詞がほぼ引けない（かなタイトルの有無が不規則）。
  クエリ調整では直らない構造的問題。あいまい検索にすると誤受理が増える。
- 対応: mecab-ipadic の名詞（一般・サ変接続・形容動詞語幹・副詞可能）から
  読みを抽出した検証用拡張辞書 words-large.txt（約45,000語・0.62MB）を同梱。
  実在判定は 厳選words.txt → 拡張words-large.txt → 端末辞書 → Wikipedia の順。
  出題・ヒントは従来どおり厳選辞書のみ（難語を出さないため）。
  ライセンス: ipadic-COPYING.txt を同梱し README に出典明記。
- 教訓: 「読みで引ける辞書」が必要な機能に百科事典を使わない。
  この環境から ja.wikipedia.org は遮断されておりライブ検証不可（分析はコード＋仕様ベース）。
