# しりとり (Shiritori)

友達と同じ端末で交代しながら遊べる、しりとり iOS アプリです。SwiftUI 製。

## 特長

- 👥 **友達と対戦** … 同じ iPhone / iPad を回して 2〜6 人でプレイ（パス＆プレイ方式）
- 🔢 **文字数制限** … 最小文字数・最大文字数を自由に設定
- 📖 **単語の実在を自動判定** … 同梱のひらがな辞書（約 1,200 語）＋ iOS 標準の国語辞書で自動チェック
- 🧩 **しりとりのルールを自動判定**
  - 前の単語の最後の音から始まっているか
  - 「ん」で終わったら負け
  - 長音「ー」（例: コーヒー → ひ）・小書き文字（例: おちゃ → や）も正しく処理
  - すでに使った単語は使えない
- ⚙️ **こだわり設定**
  - 濁音・半濁音を区別しない（例: 「か」→「が」を許可）
  - 1 手ごとの制限時間（時間切れで負け）
  - 辞書にない単語も、参加者みんなが認めれば続行できる「承認」機能

## 遊び方

1. 設定画面でプレイヤー名・人数・ルールを決める
2. 「ゲームを始める」をタップ
3. 手番の人が **ひらがな** で単語を入力して送信
4. ルール違反の単語はその場で却下され、打ち直し
5. 「ん」で終わる・降参・時間切れになった人の負け

## ビルド方法

- 必要環境: **Xcode 16 以降**（iOS 17.0+）
- `Shiritori.xcodeproj` を開き、実機またはシミュレータで実行
- 実機で動かす場合は、ターゲットの *Signing & Capabilities* で自分の Apple Developer チームを選択してください（Bundle ID は `com.example.shiritori`。必要に応じて変更可）

> このプロジェクトは Xcode 16 の *file system synchronized group* を使っており、`Shiritori/` フォルダ内のファイルは自動的にターゲットへ含まれます。

## 単語判定について

単語の実在判定は次の 2 段構えです。

1. アプリに同梱した `Shiritori/Resources/words.txt`（クリーンなひらがな名詞）
2. iOS 標準の国語辞書（`UIReferenceLibraryViewController.dictionaryHasDefinition`）

同梱辞書に語を追加したいときは `words.txt` に 1 行 1 単語（ひらがな）で追記してください。`#` で始まる行はコメントです。端末に国語辞書がインストールされていない場合は 1 の同梱辞書のみで判定されるため、判定が厳しく感じるときは設定の「辞書に無くても参加者が認めればOK」をご利用ください。

## 構成

```
Shiritori/
├─ ShiritoriApp.swift        アプリのエントリポイント
├─ Models/
│  ├─ KanaUtils.swift        かなの正規化・しりとり判定ロジック
│  ├─ WordValidator.swift    単語の実在判定（同梱辞書＋標準辞書）
│  ├─ GameSettings.swift     ルール設定（永続化つき）
│  └─ ShiritoriGame.swift    ゲーム進行の管理（ObservableObject）
├─ Views/
│  ├─ RootView.swift         画面の切り替え
│  ├─ SetupView.swift        設定画面
│  ├─ GameView.swift         対戦画面
│  └─ ResultView.swift       結果画面
└─ Resources/
   └─ words.txt              同梱ひらがな辞書
```

## 今後の拡張アイデア

- Game Center を使ったオンライン対戦
- 単語の意味（辞書リンク）表示
- 使った単語のふりかえり・共有
