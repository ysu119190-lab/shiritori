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
- [ ] CI を実際の PR で緑にする — **要ユーザー**：この branch から main への PR 作成後、
      初回 run を確認。赤なら run URL を見て修正する。
- [ ] （任意）かな判定ロジックのユニットテストを追加し CI に組み込む。
- [ ] （任意）効果音 / 使った単語の共有 / 単語の意味リンク / iPad 表示最適化。
- [ ] （任意）オンライン対戦（Game Center or MultipeerConnectivity）。開発者登録は加入済み。

## 教訓メモ

- マージ済み PR のブランチに積み増さない。追加作業は最新 main から作り直す
  （今回 CI 作業でも main→branch を再作成しリベースで CLAUDE.md を取り込んだ）。
- 別リポジトリ（photouploader）はセッションのソースに追加されていないとアクセス不可。
  参照が必要なら先にセッションへ追加（要承認）。
