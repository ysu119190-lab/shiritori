# PROJECT_NOTES（Shiritori）

このファイルを**単一の正**として扱う。セッション開始時にまず読み、作業後に更新する。

## 概要

友達と同じ端末で交代しながら遊ぶ、しりとり iOS アプリ（SwiftUI）。
オンライン通信はなし（パス＆プレイ方式）。

- `Shiritori/` — アプリ本体（Xcode 16 の file system synchronized group を利用）
- `Shiritori.xcodeproj` — プロジェクト（objectVersion 77 = Xcode 16 必須）
- `Shiritori/Resources/words.txt` — 同梱ひらがな辞書（約1,200語）
- `.github/workflows/ci.yml` — PR/main push で iOS ビルド検証

## 主要な設計判断

- **対戦方式はパス＆プレイ（同一端末）。** オンライン対戦はサーバー基盤/Game Center
  が必要で、この環境ではビルド・実機テスト不可のため見送り。将来 Game Center や
  MultipeerConnectivity で拡張可能な構成にしてある。
- **単語の実在判定は2段構え。** ①同梱辞書 `words.txt`（クリーンな名詞）②iOS標準の
  国語辞書 `UIReferenceLibraryViewController.dictionaryHasDefinition`。
  辞書外でも参加者承認で続行できる「承認」機能あり。
- **かな判定ロジック**は `KanaUtils`。長音「ー」・小書き文字・濁音同一視・「ん」止まり・
  重複禁止に対応。ロジックは Python 移植で全ケース検証済み（Swift 実機ビルドは未確認）。

## 環境メモ

- この作業環境には **Swift/Xcode が無い**ため、ローカルでコンパイル検証できない。
  → だからこそ CI（macOS ランナーでの実ビルド）で毎回検証する方針。
- 実機実行時は Signing でユーザー自身の Apple Developer チーム選択が必要
  （Bundle ID: `com.example.shiritori`）。

## CI 運用（PhotoUploader ルール準拠）

- **PR 単位で起動**（`pull_request` → main）＋ **main への push 時**。
  ブランチ push だけでは起動しない。
- `concurrency` + `cancel-in-progress` で古い実行を自動キャンセル
  （macOS ランナーは無料枠を10倍消費するため）。
- **シミュレータ機種名はハードコードしない** → `generic/platform=iOS Simulator` で
  機種非依存にビルド。
- **Xcode バージョンは明示選択**（利用可能な最新の Xcode 16 系を動的選択）。
- CI 失敗はログ本文でなく **run の URL** を共有して追う。

## タスク

- [x] しりとりアプリ本体を実装 — 完了(2026-07-23)。PR #1 でマージ済み。
- [x] UI/機能強化（辞書1,199語・触覚・最長記録・対戦画面刷新） — 完了(2026-07-23)。PR #1。
- [x] CI（GitHub Actions で iOS ビルド検証）を追加 — 完了(2026-07-23)。
      Xcode 明示選択・機種非依存・PR単位＋自動キャンセルでルール準拠。
- [x] CI を実際の PR で緑にする — 完了(2026-07-23)。PR #2 で Build (iOS) success を確認しマージ。
      → アプリが実機ビルドできることを確認済み。
- [x] TestFlight 配信の準備 — 完了(2026-07-23)。
      Bundle ID を `io.github.ysu119190-lab.mojitori` に設定、1024px アイコン実体化、
      `testflight.yml`（手動実行）を作成。
- [ ] TestFlight 初回アップロードを通す — 進行中(2026-07-25)。
      症状: 手動署名でプロファイルが .p12 の証明書を含まず Archive 失敗
      （"Provisioning profile ... doesn't include signing certificate ..."）。
      対応: ワークフローを**自動署名（ASC APIキー + -allowProvisioningUpdates）**に変更し、
      証明書に合うプロファイルを Xcode 側で自動生成する方式へ。プロファイル用 Secret は不要化。
      教訓: CI の手動署名は「プロファイルに含まれる証明書」と「.p12 の証明書」を一致させる
      必要があり、不一致が起きやすい。自動署名なら回避できる。
- [x] ランダム文字数モードを追加 — 完了(2026-07-26)。ラリーごとに 1〜9 文字のお題を
      ランダムに決め、「ちょうどN文字」の単語だけ受理する。設定でトグル（オン時は
      最小・最大の設定は無視）。`ShiritoriGame.requiredLength` を手番ごとに roll。
- [x] 予測変換対策：アプリ内かなキーボードを追加 — 完了(2026-07-26)。
      システムIMEを使わず 50音タップで入力するので変換候補が一切出ない。
      設定でトグル。`Shiritori/Views/KanaKeyboard.swift`。濁点/半濁点/小書きは
      「小゛゜」キーで直前の文字を循環切替。
- [x] フィードバック対応（演出・かな入力・バッジ） — 完了(2026-07-26)。
      ① 起動スプラッシュ（タイトルが弾んで出るモーション）を追加。
      ② 単語受理時にキラキラ＋チェックマークの演出と履歴行のポップを追加。
      ③ アプリ内かなキーボードを既定オンに変更（保存キーを v2 に上げて旧既定オフを引き継がない）。
      ④ ランダム文字数バッジの「123」アイコンを外してテキストのみに。
- [x] ウェブ（Wikipedia）判定を追加 — 完了(2026-07-26)。同梱辞書・端末辞書で見つからない
      語を日本語 Wikipedia で全文検索し、記事があれば実在扱い（キャラクター名・固有名詞OK）。
      `WebValidator.swift`（URLSession + ja.wikipedia の api.php）。既定オン、設定でトグル。
      submit を「ローカル未ヒット→ .needsExistenceConfirmation を返す」に変更し、View 側で
      ウェブ判定→参加者承認の順に解決。履歴に「ウェブ」バッジ、確認中はスピナー表示。
      注意: このアプリで初めて外部通信（HTTPS）が発生。App Store のプライバシー表記に留意。
- [x] Wikipedia判定の誤検出を修正 — 完了(2026-07-26)。全文検索(list=search)だと
      ほぼ全ての語がヒットして「全部OK」になっていた（症状）。原因は全文検索が本文まで
      部分一致するため。対応: 記事タイトルの完全一致(action=query&titles=…&redirects=1)に変更。
      読みのひらがな＋カタカナ変換の両方を候補にして、カタカナ表記のキャラ名・固有名詞を拾う。
      教訓: 「実在判定」に全文検索は不可。タイトル/リダイレクトの完全一致で見る。
- [x] フリック入力キーボードを追加 — 完了(2026-07-26)。50音タップが使いづらいとの声。
      `FlickKeyboard.swift`（中央=あ段、左右上下=い/え/う/お段、iOS標準配置）。設定に
      「キーボードの種類（フリック / 50音タップ）」を追加、既定フリック。「小゛゜」表は
      `KanaUtils.modifierCycle` に共有化。
- [x] フィードバック対応（お題・中断保存・UI） — 完了(2026-07-26)。
      ① ランダム文字数の下限を 1→2 に（1文字は続けられず詰むため）。
      ② ゲーム開始時の最初の単語をアプリが出題（`WordValidator.randomStartWord`、
         「ん」止まり・つなげない語は除外）。Move に `isSeed` を追加し、記録の語数
         `chainCount` はお題を数えない。
      ③ 中断して保存／続きから再開を追加（`SavedGame.swift`、UserDefaults）。対戦画面の
         一時停止ボタン →「中断して保存 / 保存せずに終了 / 続ける」。設定画面の先頭に
         「続きから再開する」。開始・決着時は保存データを破棄。
      ④ UI をパステル調に刷新（`Theme.swift`：共通背景 AppBackground・カード・丸ボタン、
         丸ゴシック体）。スプラッシュ背景を不透明にして設定画面が透けないよう修正。
- [x] 全画面広告（AdMob）を追加 — 完了(2026-07-26)。起動時・ゲーム開始時・決着時の3箇所。
      `AdManager.swift`（インタースティシャルの先読み＋表示）。**頻度制限60秒**で連続表示を防ぐ。
      SDK は SPM（`swift-package-manager-google-mobile-ads` 12.x）を pbxproj に手書き追加。
      アプリIDは `INFOPLIST_KEY_GADApplicationIdentifier` で注入（物理 Info.plist は作らず維持）。
      **現状は Google 公式のテストID**。実IDに差し替えるのは `AdConfig` の1箇所だけ。
      注意: 開発中に本番IDを使うと無効トラフィックでアカウント停止リスク。実IDはリリース直前に。
- [x] ヒント機能を追加 — 完了(2026-07-26)。入力バーの電球ボタン。答えは出さず
      「◯文字で、終わりの音は『◯』」だけ教える難しめの内容（ランダム文字数モードでは
      文字数は既知なので終わりの音のみ）。`WordValidator.hintWord` で同梱辞書から候補を探す。
- [x] しりとりポイント／アイコン交換を追加 — 完了(2026-07-26)。`PointsStore.swift`（UserDefaults）。
      単語1つ +1、決着 +5、記録更新 +10。設定画面から「こうかん所」（`ShopView`）へ入り、
      SF Symbols のアイコン12種をポイントで交換してプレイヤーごとに設定できる。
      アイコンは設定画面のプレイヤー欄と対戦履歴に反映。
      メモ: `PointsStore` は `ShiritoriGame`（非 MainActor）から加算するため @MainActor にしない。
- [ ] 広告の本番ID差し替え（`AdConfig.productionInterstitialUnitID` と
      `INFOPLIST_KEY_GADApplicationIdentifier`）。あわせて SKAdNetworkItems を入れるなら
      物理 Info.plist 化が必要（配列は INFOPLIST_KEY_ では書けない）。
- [ ] （任意）かな判定ロジックのユニットテストを追加し CI に組み込む。
- [ ] （任意）効果音 / 使った単語の共有 / 単語の意味リンク / iPad 表示最適化。
- [ ] （任意）オンライン対戦（Game Center or MultipeerConnectivity）。開発者登録は加入済み。

## 教訓メモ

- マージ済み PR のブランチに積み増さない。追加作業は最新 main から作り直す
  （今回 CI 作業でも main→branch を再作成しリベースで CLAUDE.md を取り込んだ）。
- 別リポジトリ（photouploader）はセッションのソースに追加されていないとアクセス不可。
  参照が必要なら先にセッションへ追加（要承認）。
