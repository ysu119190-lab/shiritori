# App Review への回答（Guideline 2.1 - Information Needed）

2026-08 の初回提出で、Guideline 2.1（情報不足）の指摘を受けたときの回答一式。
**App Store Connect → App Review Information → Notes** に貼り付ける。
審査は英語で行われるため、本文は英語。日本語の対訳は下部に置く。

> ⚠️ 指摘はバグではなく「審査メモの情報が足りない」というもの。
> 次回以降の提出でも、この内容を Notes に入れておけば同じ指摘は避けられる。

---

## 提出前にユーザーがやること

- [ ] **画面収録**（項目1）— これは実機でしか撮れない。下の「画面収録の撮り方」を参照
- [ ] **項目2の端末リスト**を実際にテストした内容へ差し替える（下書きは仮の値）
- [ ] 下の英文を Notes に貼る

---

## Notes に貼る英文（そのままコピー可）

```
Thank you for the review. Please find the requested information below.

--------------------------------------------------
1. SCREEN RECORDING
--------------------------------------------------
A screen recording captured on a physical device is attached to this
message, showing app launch and the typical user flow through the core
features (see item 4 for the flow).

Notes on the prompts shown in the recording:
- The app has NO account registration, login, or account deletion.
  No sign-in of any kind is required to use the app.
- The app has NO in-app purchases, subscriptions, or paid content.
  All features are free.
- The app has NO user-generated content that is shared publicly.
  Words typed by players are only shown to the players in the same
  match and are never stored on a server or shared with other users,
  so there is no need for content reporting or blocking mechanisms.
- The app does NOT use App Tracking Transparency and does not request
  IDFA. It does not request access to location, contacts, camera,
  photos, microphone, or any other sensitive data.
- The only system permission prompt is the Local Network permission,
  which appears ONLY when the user taps "Play with someone nearby"
  ("近くの人と対戦する"). It is required by MultipeerConnectivity to
  discover the other iPhone/iPad in the same room. This prompt is
  included in the recording.

--------------------------------------------------
2. DEVICES AND OS VERSIONS TESTED
--------------------------------------------------
[TODO: 実際にテストした端末に差し替えてください。例:]
- iPhone 15 Pro (physical device), iOS 18.5
- iPhone SE (3rd generation) (physical device), iOS 18.5
- iPad (10th generation) (physical device), iPadOS 18.5

All four game modes were tested on physical devices. The "Play with
someone nearby" mode was tested using two physical devices, and the
Game Center mode was tested using two devices with different Apple
Accounts.

--------------------------------------------------
3. APP FUNCTION AND TARGET AUDIENCE
--------------------------------------------------
"Shiritori" (しりとり) is a Japanese word game app.

About the game:
Shiritori is a traditional Japanese word-chain game. Each player says
a word that begins with the last syllable of the previous word. A
player loses if they say a word ending with the syllable "n" (ん),
repeat a word already used, or cannot continue.

The problem it solves:
When people play shiritori verbally, the game constantly stops because
of arguments: "Is that a real word?", "What syllable do I start from
again?", "Didn't we already use that?". This app removes those
interruptions by judging every rule automatically, so players can
simply enjoy the word game.

Core value:
- Automatic word validation using a built-in dictionary of about
  46,000 Japanese words (works offline).
- Automatic rule checking: syllable connection, the losing "n" ending,
  duplicate words, long vowels, small kana, and voiced-sound marks.
- Four ways to play: alone against the CPU, pass-and-play on one
  device, two devices connected directly nearby, and turn-based online
  play through Game Center.

Target audience:
Japanese-speaking users of all ages, including families with children.
All text in the game is written in hiragana (no kanji), so young
children can play. There is no violent, sexual, or otherwise mature
content. Age rating: 4+.

--------------------------------------------------
4. HOW TO SET UP AND ACCESS THE MAIN FEATURES
--------------------------------------------------
No login credentials, demo account, or sample files are required.
The app is fully functional immediately after launch.

There is a "How to play" ("あそびかた") screen inside the app,
reachable from the "?" button in the top-right corner of the first
screen. It explains all four modes in detail.

Recommended flow to review all core features:

(a) Play alone against the CPU  -- easiest to verify, single device
    1. Launch the app.
    2. On the first screen, tap "ひとりで" (Alone) in the
       "あそびかた" (How to play) section.
    3. Optionally choose CPU strength: よわい (easy) / ふつう
       (normal) / つよい (hard).
    4. Tap "ゲームを始める" (Start game) at the bottom.
    5. The app presents a starting word. Type a word beginning with
       the highlighted syllable using the in-app keyboard, then tap
       the send button. The CPU replies automatically.

(b) Pass-and-play on one device -- single device
    1. On the first screen, tap "みんなで" (Together).
    2. Set the number of players (2-6) and tap "ゲームを始める".
    3. Players take turns on the same device.

(c) Play with someone nearby -- requires TWO devices
    1. On both devices, make sure Wi-Fi and Bluetooth are on.
    2. On the first screen, tap "みんなで" then
       "近くの人と対戦する" (Play with someone nearby).
    3. On device A, tap "部屋をつくる" (Create a room).
    4. On device B, tap "部屋に入る" (Join a room).
       Allow the Local Network permission prompt when it appears.
    5. On device B, tap the name of device A when it appears.
    6. Once connected, on device A tap "対戦を始める" (Start match).

(d) Play with someone far away -- requires TWO devices with different
    Apple Accounts
    1. Sign in to Game Center in the iOS Settings app on both devices.
    2. On the first screen, tap "みんなで" then
       "はなれた人と対戦する" (Play with someone far away).
    3. Use the standard Game Center matchmaking screen to invite the
       other player or find an opponent.
    4. Players take turns. The match continues even if the app is
       closed; each player plays when it is their turn.

--------------------------------------------------
5. EXTERNAL SERVICES, TOOLS, AND PLATFORMS
--------------------------------------------------
- Google AdMob (Google Mobile Ads SDK)
  Purpose: displaying interstitial advertisements.
  This is the only third-party SDK in the app.

- Apple Game Center (GameKit)
  Purpose: turn-based online matches ("Play with someone far away").
  Optional. All other modes work without it.

- Apple MultipeerConnectivity (system framework)
  Purpose: direct device-to-device connection for the nearby mode.
  This is peer-to-peer over Wi-Fi/Bluetooth. No server is involved.

- Wikipedia public API (ja.wikipedia.org/w/api.php)
  Purpose: OPTIONAL secondary word validation. It is used only to
  check whether an article with that exact title exists, which lets
  players use proper nouns (such as character names) that are not in
  the built-in dictionary.
  Only the typed word (in hiragana) is sent. No personal information
  is transmitted, and no web page is displayed to the user. This can
  be turned off in the app's settings, and the app remains fully
  playable offline without it.

- Built-in dictionary data: mecab-ipadic (IPA dictionary)
  This is bundled data, not a network service. See item 7.

There is no authentication service, no payment processor, no AI
service, and no analytics service in the app. The app has no backend
server of its own and stores no user data remotely. All game data
(player names, settings, records, points) is stored only on the
device.

--------------------------------------------------
6. REGIONAL DIFFERENCES
--------------------------------------------------
The app functions consistently across all regions. There are no
region-specific features, content, or restrictions.

The app is provided in Japanese only, because it is a game based on
the Japanese syllabary. This is the same in every region.

The only variation is the advertisement content served by Google
AdMob, which is determined by AdMob and may differ by region. This
does not affect any app functionality.

--------------------------------------------------
7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
--------------------------------------------------
The app does not operate in a regulated industry. It is a word game
with no gambling, no financial services, no medical content, and no
age-restricted content.

Regarding third-party material, the app bundles a Japanese dictionary
generated from mecab-ipadic (the IPA dictionary), which is
redistributable under its license. The license explicitly permits
use, reproduction, and distribution:

  "Copyright 2000, 2001, 2002, 2003 Nara Institute of Science and
   Technology. All Rights Reserved.
   Use, reproduction, and distribution of this software is permitted.
   Any copy of this software, whether in its original form or
   modified, must include both the above copyright notice and the
   following paragraphs."

As required, the full license text is included in the app bundle at
Resources/ipadic-COPYING.txt and is also published in the project's
public repository:
https://github.com/ysu119190-lab/shiritori

No other third-party or protected material is used. All artwork, the
app icon, and all source code were created by the developer.

--------------------------------------------------
Please let us know if any further information is needed.
Thank you for your time.
```

---

## 画面収録の撮り方（項目1・ユーザー作業）

**実機で撮る必要があります**（シミュレータの録画は不可）。最新OSの実機で撮ってください。

### 録画の準備

1. iPhone の **設定 → コントロールセンター → 画面収録** を追加
2. 通知で中断されないよう**おやすみモード**にしておく
3. アプリを**一度削除して入れ直す**（初回の許可ダイアログを録画に含めるため）

### 録画する内容（3〜5分程度）

必ず**アプリの起動から**始めてください。

1. **ホーム画面からアプリを起動**（アイコンをタップするところから）
2. **ひとりでCPU対戦**
   - 「ひとりで」を選ぶ → 難易度を選ぶ → ゲーム開始
   - 単語を2〜3語入力して、CPUが返してくるところまで見せる
3. **「あそびかた」画面**を開いて、説明があることを見せる
4. **近くの人と対戦**（★ここが重要）
   - 「近くの人と対戦する」→「部屋をつくる」
   - **「ローカルネットワーク」の許可ダイアログが出るところを必ず録画に含める**
   - 「許可」を押す
   - （2台あれば接続まで見せられるとなお良い）
5. **みんなで（パス&プレイ）**で数手プレイ
6. 決着画面まで見せる

> Apple は「許可ダイアログが出る場面」を録画に含めるよう明示しています。
> ローカルネットワークの確認が出る場面は**必ず入れてください**。

### 提出方法

App Store Connect の返信画面で、動画ファイルを添付します。
長すぎる場合は、上の 1・2・4 を優先してください（特に 4）。

---

## 日本語の対訳（内容確認用・提出はしない）

| 項目 | 回答の要点 |
|---|---|
| 1. 画面収録 | 実機で撮影して添付。ログイン・課金・UGC・ATTは無し。許可ダイアログはローカルネットワークのみで、それは録画に含めると明記 |
| 2. テスト端末 | **要記入**。実機で4モードすべてを確認したこと、近距離は2台、Game Centerは別Apple Accountの2台で確認したことを書く |
| 3. 機能と対象 | しりとりの説明／「本当にある言葉？」で揉めて中断する問題を自動判定で解決／4つの対戦方式／全年齢・ひらがなのみで子どもも遊べる |
| 4. 使い方 | ログイン不要・デモアカウント不要。アプリ内に「あそびかた」画面あり。4モードの操作手順を具体的に記載 |
| 5. 外部サービス | AdMob（広告）／Game Center（オンライン）／MultipeerConnectivity（近距離・P2P）／Wikipedia API（任意の補助判定）／ipadic（同梱データ）。認証・決済・AI・解析サービスは無し。自前サーバー無し |
| 6. 地域差 | 全地域で同一。日本語のみ（かなのゲームのため）。広告内容がAdMob側で変わるだけで機能に影響なし |
| 7. 規制・第三者素材 | 規制業種ではない。ipadicは再配布可能なライセンスで、全文をアプリに同梱＋公開リポジトリに掲載。他の素材は自作 |

---

## 今後の提出でも同じ内容を入れる

この Notes の内容は**次回以降の提出でもそのまま使えます**。
App Store Connect の App Review Information → Notes に入れっぱなしにしておけば、
同じ指摘は繰り返されません（Apple も「Include this information in the Notes field
for future submissions」と書いています）。
