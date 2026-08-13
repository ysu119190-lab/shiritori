# しりとり (Shiritori)

友達と同じ端末で交代しながら遊べる、しりとり iOS アプリです。SwiftUI 製。

## 特長

- 👥 **友達と対戦** … 同じ iPhone / iPad を回して 2〜6 人でプレイ（パス＆プレイ方式）
- 🤖 **1人でも遊べる** … CPU と 1 対 1（よわい / ふつう / つよいの 3 段階）。勝敗・連勝の記録つき
- 📡 **近くの人と対戦** … 同じ部屋にある 2 台を直接つないで 1 対 1（Wi-Fi / Bluetooth、サーバー不要）
- 🔢 **文字数制限** … 最小文字数・最大文字数を自由に設定
- 📖 **単語の実在を自動判定** … 同梱のひらがな辞書（約 46,000 語）＋ iOS 標準の国語辞書で自動チェック
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

## CI（自動ビルド）

`main` への Pull Request と push のたびに、GitHub Actions がアプリを自動ビルドして壊れていないか検証します（`.github/workflows/ci.yml`）。

- ランナー: `macos-15`（Xcode 16 系）
- 内容: `xcodebuild build` で iOS シミュレータ向けにビルド（コード署名なし）
- ビルドログは成否にかかわらず artifact として保存されます

### TestFlight（手動配信）

`.github/workflows/testflight.yml` を **手動実行**（Actions → TestFlight → Run workflow）すると、
アーカイブ→IPA書き出し→App Store Connect へのアップロードまで行います。

- Bundle ID: `io.github.ysu119190-lab.mojitori`
- ビルド番号は GitHub Actions の run number で単調増加
- ASCアップロード要件に合わせて Xcode 26 を明示選択
- **自動署名（ASC API キー方式）**：証明書に合うプロファイルを Xcode が自動生成するため、
  プロビジョニングプロファイルの手動作成は不要
- 実行には署名関連の Secrets 登録が必要（下記）

必要な Secrets（Settings → Secrets and variables → Actions）:

| Secret | 中身 |
|---|---|
| `DIST_CERT_P12_BASE64` | 配布証明書 `.p12` を base64 化 |
| `P12_PASSWORD` | `.p12` のパスワード |
| `ASC_API_KEY_P8_BASE64` | ASC API キー `.p8` を base64 化 |
| `ASC_KEY_ID` | API キーの Key ID |
| `ASC_ISSUER_ID` | API キーの Issuer ID |

## 単語判定について

単語の実在判定は次の順で行います。

1. アプリに同梱した辞書（オフライン・約 46,000 語）
   - `Shiritori/Resources/words.txt` … 厳選版（約 1,200 語）。**出題・ヒントにも使う**
   - `Shiritori/Resources/words-large.txt` … 検証用の拡張辞書（約 45,000 語）。
     mecab-ipadic（IPA辞書）の名詞（一般・サ変接続・形容動詞語幹・副詞可能）の読みから生成。
     **実在判定にのみ**使い、出題・ヒントには使わない
2. iOS 標準の国語辞書（`UIReferenceLibraryViewController.dictionaryHasDefinition`）
3. 日本語 Wikipedia のタイトル完全一致（キャラクター名などの固有名詞用フォールバック）

出題やヒントに使う語を追加したいときは `words.txt` に 1 行 1 単語（ひらがな）で追記してください。`#` で始まる行はコメントです。それでも判定が厳しく感じるときは設定の「辞書に無くても参加者が認めればOK」をご利用ください。

### 辞書データの出典

拡張辞書は [mecab-ipadic](https://github.com/taku910/mecab)（IPA辞書）の読みデータから生成しています。

> Copyright 2000, 2001, 2002, 2003 Nara Institute of Science and Technology. All Rights Reserved.

ライセンス全文はアプリに同梱の `Shiritori/Resources/ipadic-COPYING.txt` を参照してください。

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
