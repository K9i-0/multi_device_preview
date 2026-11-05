# multi_device_preview — 設計方針とはまりどころ（OSS 化メモ）

Flutter アプリを、複数の端末サイズ・文字サイズで **1 つの macOS ウィンドウに横に並べて同時に動かし**、
1 台への操作を他の端末にも送る（同期操作）検証ツール。overflow やレイアウト崩れを一度にまとめて確かめるためのもの。
Marionette（AI エージェント）からも操作・撮影できる。

> 実機検証の代わりではない。ネイティブの UI・WebView・動画・ソフトウェアキーボードは対象外。

## 名前

- パッケージ名・リポジトリ名: **`multi_device_preview`**（2026-11-02 時点で pub.dev 未登録を確認済み）
- 公開 API・key の接頭辞・Marionette 拡張の名前空間もこれに揃える
  （例: `runMultiDevicePreview`、`multi_device_preview.screen.<n>`、`multiDevicePreview.saveScreenshot`）
- device_preview の派生（`device_preview_plus` / `device_preview_minus` 等）と同じ系統に見られやすいので、
  README の冒頭で「device_preview の外枠・プリセットを使う、別作者の独立したパッケージ」と明記する

---

## 1. 全体構成

- 1 プロセスの中で、対象アプリのルート Widget を **端末の数だけ並べて** 動かす。
  - 端末ごとに状態管理のコンテナ（例: Riverpod の `ProviderContainer`）を分ける。
  - 端末の画面サイズ・安全領域・文字サイズは `MediaQuery` の上書きで再現する。
    `MaterialApp`（`WidgetsApp`）は自前の MediaQuery を作らず祖先のものを使うので、上書きはアプリ全体に効く。
  - 外枠・ステータスバーの絵と機種のプリセットは [device_preview](https://pub.dev/packages/device_preview) の
    `DevicePreviewFrame` / `DevicePresets` を使う。**device_preview の binding（`DevicePreview.ensureInitialized`）は使わない**。
- 描画は全端末とも iOS として行う（`debugDefaultTargetPlatformOverride = TargetPlatform.iOS`）。
  Android のプリセットはサイズ・安全領域・外枠だけを変える。
- スクロールはさせず、一番背の高い端末が収まるよう全体を縮めて表示する（端末内の論理サイズは変わらない）。

### モジュールの分担

| モジュール | 役割 | 対象アプリへの依存 |
|---|---|---|
| `anchor` | 端末をまたいで「同じ要素」を対応付けるための目印を集める | なし |
| `position_mapping` | 操作元で押された位置を、別の端末の対応する位置へ写す | なし |
| `input_mirror` | ポインタ操作を他の端末へ順番待ちの列で送る | なし |
| `text_sync` | 入力欄の値と Enter での確定を揃える | なし |
| `input_gate` | 同期中、操作元以外への人間の直接の入力を止める | なし |
| `page` / `preset` / `debug_extensions` | 並べて表示する画面・機種と文字サイズの切り替え・Marionette 拡張 | ほぼなし |
| `controller` | 端末の枠・再起動・同期の ON / OFF | コンテナの入れ替え方法 |
| `app_instance` / `main` | 対象アプリの組み立て（override・初期化） | **完全に対象アプリ固有** |

中核（同期操作まわり）は対象アプリに依存しない。固有なのは「アプリをどう組み立てて差し込むか」だけ。

---

## 2. 同期操作の設計

### 2.1 操作元は 1 台だけ（InputGate）

- 端末ごとに別の操作ができると状態がずれていくので、**同期中に人間が操作できるのは左端の端末だけ**にする。
- 止めるのは **OS から届いた実際のポインタ入力を処理している間の hit test だけ**。次は通す:
  - Marionette の要素探索（`get_interactive_elements` の「見えているか」の判定など）
  - 同期で送る合成イベント
  - ツール自身の要素探索の hit test
- 「今は OS からの入力を処理中か」を見分けるため、バインディングの初期化後に入力処理へフックを 1 度仕込む。

### 2.2 要素の目印（Anchor）

Marionette の要素指定と同じものを目印にする:

- `ValueKey<String>`（ツール自身の key の接頭辞 `multi_device_preview.` は除く。端末ごとに値が違うため）
- `Semantics` の `identifier` → なければ `label`（テキストの無い画像バナー・アイコンボタンも対応付けられる）
- 画像の URL（`Image` / `ExtendedImage` の ImageProvider）
- テキスト（`Text` は `RichText` を build するので `RichText` だけ見ればよい）
- 入力欄（`EditableText`）

同じ目印が複数あるときは **ツリー順で何番目か（序数）** で対応付ける。
「見えているか」は要素の中心を hit test し、経路に目印の描画領域が含まれるかで判定する。
これで Navigator の下に隠れたページ・`IndexedStack` の非表示タブ・画面外やウィンドウ外の要素が除かれる。

### 2.3 位置の写し方（PositionMapping）

1. 押した位置の hit test 経路を深い順にたどり、最初のジェスチャーの受け手（GestureDetector / InkWell 等）を「押されたボタン」とする。
2. ボタンの中に目印があればボタンを「基準の箱」にする。なければ、目印を子孫に持つ最も深い RenderObject を基準の箱にする。
3. 箱の中の目印のうち、画面内で一意なもの（同じ目印が少ないもの）を選ぶ。
4. 写し先で同じ目印・同じ序数の要素を探し、そこから同じ段数だけ親をたどった箱を基準の箱の対応物とする。
5. 基準の箱の中での相対位置（0〜1）を、対応物の箱に当てはめる。

**前提**: 端末の幅が違っても同じ Widget のコードで組まれているので、要素の構造の対応から位置を求められる。
目印が見つからないときは画面全体での相対位置で写す。

### 2.4 「送らない」判断

- 目印で正確に対応付けられないタップ（基準の箱が画面の大部分を占める等）は **送らない**。
  箱の中の相対位置で写した先が、端末の高さの違いで別の要素（下部タブ等）になりうる。
  違う要素を押すと端末ごとに別の画面へ進んでしまうので、送らないほうがよい。
- スクロールは同じスクロール領域に当たればよいので、精度が低くても送る。
- 送れなかった端末には「同期ずれ」の印を出す。ずれたら「全端末を再起動」で揃え直す。

### 2.5 送り方（InputMirror）

- 押した瞬間に写し方を決め、押してから離すまでを 1 つのジェスチャーとして **端末ごとの順番待ちの列** に積む。
- 各端末は列を順に処理し、対応する要素が現れるまで（最大 5 秒。起動直後の読み込みを待てる長さ）待ってから送る。
  画面外にあれば見える位置までスクロールしてから、次のフレームで写し直して送る。
- 元のイベントの **時間間隔を保って** 送る（長押し・フリックの速度のため）。遅れて送り始めても溜まった分を同じ間隔で送る。
- タップ・長押し・スクロール（ドラッグ / ホイール / トラックパッド）を同じ仕組みで扱う。
  Marionette の `tap` / `swipe` も実機の入力と同じ経路（`GestureBinding`）に流れてくるので、そのまま同期される。
- 同期を途中で切っても、送り始めた操作は最後（指を離す等）まで送る。途中でやめると押されたままのポインタが残る。
- hover とデバイスの追加・削除は同期しない。

### 2.6 入力欄（TextSync）

- 入力欄はツリー順で何番目かで対応付け、**操作元（1 台目）の値を正** として他の端末を揃える。
- キーボード入力と Marionette の `enter_text`（フォーカスを移さずに値を書き換える）の両方を拾うため、
  フォーカスやコントローラの購読には頼らず **一定間隔で突き合わせる**。
- 反映は `EditableTextState.userUpdateTextEditingValue` で行い、キーボード入力と同じく `onChanged` を発火させる。
- 入力欄の数が 1 台目と違う端末（読み込み中・別の画面）は対応付けられないので揃えない。
- Enter での確定は done / go / search / send だけ送る。**next 等は送らない**
  （他の端末で実行すると次の入力欄へフォーカスが移り、操作元のフォーカスを奪う）。
- 値を先に揃え、操作元の確定処理が終わった後に他の端末でも確定する。
- 他の端末へ送ったタップでフォーカスが移ったら（入力欄のタップ等）、合成イベントに伴うフォーカス移動（microtask）が
  済んでから **操作元へフォーカスを戻す**。キーボード入力は操作元で受け、他の端末には TextSync で反映する。
- それとは別に、同期中は **キーボードフォーカスを常に操作元に置く**（端末ごとに `FocusScope` を挟み、
  `FocusManager` を購読して直す）。各アプリは起動時に最初の route へフォーカスを移すので、放っておくと
  最後に起動した端末がフォーカスを持ち、`Navigator` より上の `CallbackShortcuts`（デバッグメニューの Shift+D 等）が
  その端末にだけ効く。フォーカスが他の端末へ移ったとき・端末の外（ルートのスコープ等）へ落ちたときは、
  操作元のスコープへ戻す（スコープは最後にフォーカスしたノードへ渡す）。ツールのコントロールが取ったフォーカスはそのまま。
  同期をオフにしている間は各端末を直接操作するので直さない。

---

## 3. はまりどころ

### 3.1 Navigator / Overlay を端末の祖先に置けない

- アプリは `showDialog` 等で `Navigator.of(context, rootNavigator: true)` / `Overlay.of(context, rootOverlay: true)` を使う。
  これらは **一番外側のもの** を返すので、ツール側に Navigator / Overlay があると、端末内のダイアログがツールの画面全体に出てしまう。
- `LookupBoundary` は `View.of` まで遮ってしまうので使えない。
- 対処: ツールのルートは `MaterialApp` に `home` を渡さず `builder` で組み、Navigator を作らない。
  ツールのメニュー等に要る Overlay は **端末と重ねた別レイヤー** に置く（端末の祖先ではないので探索に掛からない。
  何も描いていない部分は hit test を通すので、下の端末を操作できる）。
- `showModalBottomSheet` も Navigator が要るので、ツールの設定シートは同じ見た目を自前で出す。

### 3.2 合成ポインタイベントの組み立て

- 合成イベントの device id は実機・Marionette（device id 1〜3）と重ならない下限以上にし、受け側で **再び同期しないよう見分ける**。
- トラックパッドの **PanZoom 系イベントの `copyWith` は pointer を引き継がない**（すべて 0 になる）。
  複数の端末へ送ると `GestureBinding` が同じ pointer の操作とみなし、2 台目以降を捨てる。
- ホイールの `PointerScrollEvent` の `copyWith` は操作元の `respond` を引き継いでしまう。
- → どちらも `copyWith` を使わず自前で組み立てる。
- 操作元のイベントの dispatch 中に `GestureBinding` へ再入しないよう、最初の送信も microtask 以降にする。

### 3.3 「押されたボタン」の誤認

- 端末全体を包む同期用の `Listener` や、画面の大部分を占める受け手（スクロール領域等）をボタンとみなすと、
  余白を押しただけでもその中の相対位置で写され、写し先で別のボタンが押される。
- → ボタンの探索は InputGate より内側（アプリ側）に限り、画面の大部分を占める受け手は除く。

### 3.4 端末の設定変更でアプリを作り直さない

- 機種・文字サイズを切り替えてもアプリの状態を保つため、アプリのツリーは builder の外で組み立てて使い回す。
- 親を再 build しないので、MediaQuery を上書きする Widget はプリセット・文字サイズの変更を **自分で購読** する。
- `DevicePreviewFrame` は画面の大きさで配置され、外枠は外側にはみ出して描かれる。外枠の分の余白を自分で確保する。

### 3.5 1 プロセスで複数インスタンス動かすことの制約（対象アプリ側への要求）

- **グローバルな `GlobalKey` やシングルトンがあると壊れる**。例: slang の `TranslationProvider` はプロセスで 1 つの
  GlobalKey を使うので、端末ごとには置けない → 全端末の共通の祖先に 1 つだけ置く。
- SharedPreferences と Keychain はプロセスで共有なので、**永続化された状態（ログイン・設定）は全端末で共有** される。
- 対象アプリの `main()` で状態管理のコンテナに渡す override が増えたら、ツール側の組み立てにも追従させる
  （追従しないと、override 前提のプロバイダが `UnimplementedError` を投げて起動しない）。
- 計測・クラッシュ収集・プッシュ通知などの SDK は起動しない（macOS 実装が無い / 検証には不要）。
  macOS 実装の無いプラグインの呼び出しは `MissingPluginException` になるので、
  fire-and-forget の呼び出しは `runZonedGuarded` で握りつぶす。

### 3.6 アセット・フォント（別アプリとして組む場合）

- 対象アプリを依存パッケージとして取り込むと、そのアセットは `packages/<name>/...` に置かれる。
  対象アプリのコードが package 指定なしの `assets/...` や接頭辞なしのフォント family 名で読んでいると **解決できない**。
- → ホストアプリの `assets/` を対象アプリの `assets/` へのシンボリックリンクにし、
  pubspec の `assets` / `fonts` 宣言をホスト側にも書く。両方の一致はテストで検査する。

### 3.7 macOS ビルド

- 対象アプリの依存プラグインの macOS 実装がビルドできないことがある。
  例: `flutter_inappwebview_macos` 1.2.0-beta.3 は `Package.swift` で macOS 10.14 を宣言しつつ 10.15+ の API を使っており、
  Xcode 26.4 以降の SPM ビルドでコンパイルエラーになる（upstream issue #2809 / 修正 PR #2891）。
  → パッチを当てた版を取り込んで `dependency_overrides` で差し替えた。
- entitlements: 開発者のマシンで使う検証ツールなので sandbox は無効にした（ローカルのモックサーバーへの接続や
  Keychain を、sandbox 用の追加設定なしで使うため）。`network.client` / `network.server` / `cs.allow-jit` を付ける。

### 3.8 debug / profile の違い

- `debugDefaultTargetPlatformOverride` は **debug でしか受け付けない**。profile で代入すると例外になり、以降の初期化が止まる。
  → `kDebugMode` のときだけ代入する。profile では macOS 向けの描画のままになり、hot reload もできないので、検証は debug で行う。
- Marionette は `!kReleaseMode`（debug / profile）で有効にする。

### 3.9 Marionette との組み合わせ

- `get_interactive_elements` で文字サイズ等を数値検証できるよう、`MarionetteConfiguration(compaction: CompactionMode.none)` にする。
- key・テキストの指定は最初に見つかった要素（= 左端の端末）に当たり、同期操作で他の端末にも送られる。
  端末ごとの画面に `multi_device_preview.screen.<n>` の key を付け、`ancestor_keys` で特定の端末だけを探す / 操作できるようにする。
- 4 台並べた画面は大きく、`take_screenshots` が MCP の応答の上限を超えて失敗することがある。
  → `RepaintBoundary` を取って PNG ファイルに書き出す拡張を用意した。
- **ウィンドウが他のウィンドウに隠れていると macOS が描画を止める**。操作は処理されるがスクショは古い画面のままになる。
  書き出しでは直前の操作の描画を待つが、待ち続けずにエラーで知らせる。
- スクショの画像の座標は論理座標と一致しない（Retina 等で拡大される）。座標で操作するときは `bounds` を使う。
  全体を縮めて表示しているので、`bounds` の x / y は縮めた後のウィンドウ上の位置、width / height は端末内の論理サイズになる。
- Marionette の `swipe` は touch のイベントなので、人間が macOS で使うトラックパッドの経路（PanZoom）は通らない。
  → PanZoom イベントを流す拡張を用意して、その経路の同期も確かめられるようにした
  （device / pointer は実機と重ならず、かつ合成イベントの判別の下限より小さくし、実機の入力として扱わせる）。
- Marionette から再現できず未確認のもの: 実キーボードの Enter による確定の同期、長押し、マウスホイールのスクロールの同期。

---

## 4. OSS 化の方針

### 4.1 パッケージの形

- 中核（anchor / position_mapping / input_mirror / text_sync / input_gate / page / preset / debug_extensions）を Flutter パッケージにする。
- 対象アプリの組み立ては利用者に任せる:

```dart
void main() async {
  // 共有する依存の初期化（対象アプリの main() 相当）
  runMultiDevicePreview(
    appBuilder: (context, slot) => ProviderScope(child: MyApp()),
    // 任意: 再起動・Marionette 拡張・描画の上書き など
  );
}
```

- 状態管理への依存は外す。コンテナの入れ替え（再起動）と、端末ごとのハンドル（カスタム拡張の送り先）は、
  コールバックやアダプターに抽象化する。
- `extended_image`（画像の目印）と `marionette_flutter`（拡張の登録）は任意の依存にする（アダプター / プラグイン）。

### 4.2 導入方法は 2 通り案内する

どちらの方法でも `runMultiDevicePreview(appBuilder: ...)` の API は同じ。違うのは置き場所と pubspec だけ。

| | A. アプリに別エントリーポイントを足す | B. 別のホストアプリを作る |
|---|---|---|
| 向いている構成 | シングルパッケージのリポジトリ | モノレポ / pub workspace |
| macOS ビルド | アプリの依存がそのまま macOS で通る | 通らない依存があり、上書きやパッチで逃がしたい |
| アプリへの影響 | `macos/` と dev_dependency が増える | アプリ本体は変わらない |
| アセット・フォント | そのまま使える | 再宣言が要る（init コマンドで自動化） |

- **A**: `multi_device_preview` は `dev_dependencies` に入れ、エントリーポイントは `lib/` の外（例: `multi_device_preview/main.dart`）に置いて
  リリースビルドに混ざらないようにする。起動は `flutter run -d macos -t multi_device_preview/main.dart`。
  entitlements はアプリの `macos/` に書くので、必要な設定を README に載せる。
- **B**: `dart run multi_device_preview:init` のようなコマンドでホストアプリを作る
  （`flutter create --platforms=macos`、対象アプリの pubspec からアセット・フォント宣言をコピー、シンボリックリンク、entitlements）。

### 4.3 README に書く「対象アプリへの要求」

- グローバルな `GlobalKey` / シングルトンを持たない（持つなら共通の祖先に 1 つだけ置ける形にする）
- 永続化された状態は全端末で共有される
- macOS 実装の無いプラグインは呼び出しが失敗する（握りつぶす・差し替える）
- ダイアログ等は `rootNavigator` / `rootOverlay` で出してよい（ツール側が Navigator / Overlay を持たないので端末内に出る）
- 同期の精度は key / Semantics の付き方に依存する（目印が無い大きな領域の中のタップは送られない）

### 4.4 既存ツールとの違い

- device_preview は 1 画面を切り替えて見るツール。
  multi_device_preview は **複数の端末を同時に並べて動かし、要素の対応付けで操作を同期する** のが違い。
- `multi_app_viewer`（0.0.1、2024-02 から更新なし）は 1 つのアプリを設定違いで並べ、主のインスタンスに合わせて
  一緒に操作する点で近い。README によれば同期はスクリプトや状態・イベントのブロードキャストによる。
  README で打ち出す違い:
  - アプリ側の組み込み無しで、生のポインタ入力・入力欄が他の端末へ同期される
  - AI エージェント（Marionette）から操作・撮影できる
- `flutter_device_emulator` / `pixel_preview` / `device_lab`（pub.dev）は 1 画面のプレビューで、同期操作は無い。
