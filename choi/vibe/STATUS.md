# STATUS.md — 学習状態・プリファレンスの保存取得規約と自己改造指針

## 0. 本書の性格

本書は、`*.enhack.app` ドメインに配置される学習アプリが、**ログイン済みの
利用者の学習状態とプリファレンスを enHack サーバー(Maker API)に保存し、
取得する**ための共通規約と、そのための自己改造の行動指針である。読者は
アプリの開発者(生成 AI を含む)を想定する。DATA.md(教材データ読み込み
規約)・LOGIN.md(ログイン状態の確認規約)の続編であり、起動規約(同一
ドメイン配置・ルートからのパス指定)は DATA.md §2 を、ログイン判定は
LOGIN.md をそのまま前提とする。

- 本書が宣言するのは**器**である: 保存単位と識別、ハッシュの算出規則、
  API と応答規約、読み出し・書き込みの手順、エラーの扱い
- **中身の意味論はスコープ外である**: 何を学習状態として記録するか、
  ペイロード JSON の構造、形式バージョンの値、記録するタイミングは、
  すべてアプリの側が決める。サーバーはペイロードを解釈しない(§2.4)
- 本書の API は、LOGIN.md の判定で**ログイン済みのときにだけ**呼び出す。
  未ログイン時の扱い(メッセージ提示・遷移禁止)は LOGIN.md §4 に従う
- ログイン画面への誘導は LOGIN.md §0 のとおりスコープ外
- 学習状態の**端末側の永続化(localStorage・IndexedDB 等)は要求しない**。
  サーバーが唯一の永続先であり、アプリはセッション中はメモリ上の状態で
  動作する(§4・§5)
- 複数タブ・複数端末からの同時利用の調停は要求しない(後着優先 §2.4)

## 1. 保存単位と識別

### 1.1 8種類の保存単位

認証ユーザーごとに、次の8種類の JSON を独立して保存できる。**完全な識別
情報**ごとに最新の1件だけが保持される(履歴は持たない)。認証ユーザーは
セッションから確定するため、識別情報に利用者 ID は含めない。

| `target_type` | 完全な識別情報 | 用途 |
|---|---|---|
| `user` | (なし) | プリファレンス |
| `course` | `course_id` | コースの学習状態 |
| `unit` | `unit_id` | ユニットの学習状態 |
| `part` | `part_id` | パートの学習状態 |
| `deck` | `deck_id` | デッキの学習状態 |
| `card` | `deck_id` + `card_hash` | カードの学習状態 |
| `sentence` | `deck_id` + `card_hash` + `sentence_hash` | センテンスの学習状態 |
| `sentence_method` | `deck_id` + `card_hash` + `sentence_hash` + `method` | センテンス×学習方法の学習状態 |

- 8種類すべてを使う必要はない。アプリは使う保存単位だけに書き込む
- `method`(学習方法識別子)は `[a-z0-9_]{1,64}`。値はアプリが定める
  (例: `word_order`、`pronunciation`)。同じセンテンスへの学習方法別の
  書き込みは互いに独立する

### 1.2 恒久識別子(コース〜デッキ)

- コース・ユニット・パート・デッキは、教材サーバーが管理する**恒久識別子**で
  識別する。教材内容の編集・差分更新を跨いで不変であり、**教材サーバー全体で
  一意**で、単独で対象を同定できる
- アプリが持つ値をそのまま使う: `unit_id` は DATA.md §2 の起動パラメータ、
  `deck_id` は DATA.md §3.2 手順3(`deck/detail`)に渡した ID、`part_id` は
  デッキ(`data.deck`)の `part_id`(パートを使わない教材では null。その
  場合 `part` 単位は使わない)、`course_id` はユニット詳細(DATA.md §3.2
  手順1 `unit/detail`)の `data.unit.course_id`(コースに帰属しないユニット
  では null。その場合 `course` 単位は使わない)
- 上の2フィールド(`data.deck.part_id`・`data.unit.course_id`)は、DATA.md
  §3.3 が教材として列挙していないため、DATA.md §4 の「列挙されていない
  フィールドは読み飛ばす」の対象に見える。**本書は識別のためにこの2フィールドを
  読むことを明示的に認める**。いずれも null がありうるため、キーの存在
  チェックと null チェックを介して読む(DATA.md §4 と同じ)
- 識別子は大文字の UUID 表記で返る(例: `FEB49F42-9A05-11F1-B061-10DC160DA7B8`)。
  アプリは受け取った値を大文字小文字を変えずにそのまま送り、そのまま比較する
- **上位階層の識別子を併せて送らない**。たとえば `target_type=part` に
  `unit_id` を添えると `INVALID` になる。所属関係はサーバーが保持する

### 1.3 コンテンツハッシュ(カード・センテンス)

カードとセンテンスはサーバー上に実体を持たない。**アプリが教材内容から
算出する SHA-256 ハッシュ**で識別する(算出規則 v1)。サーバーはハッシュを
不透明な識別子として保持するだけで、算出・検証はしない。

**センテンスの正規化**(英文 `en` および話者 `person` に、記載順に適用):

1. Unicode NFKC で正規化する
2. BOM(U+FEFF)、ゼロ幅スペース(U+200B)、ソフトハイフン(U+00AD)を除去する
3. 左右のシングルクォーテーション(U+2018、U+2019)を ASCII アポストロフィ
   (U+0027)へ変換する
4. スラッシュ(U+002F)を ASCII スペース(U+0020)へ変換する
5. Unicode の `White_Space` プロパティに該当する文字を ASCII スペースへ変換する
6. ASCII 英大文字 `A`〜`Z` を `a`〜`z` へ変換する
7. 連続する ASCII スペースを1個へ圧縮する
8. 先頭および末尾の ASCII スペースを除去する

句読点・ハイフン・ダイアクリティカルマーク・短縮形と展開形の違い・語順は
維持する(変換しない)。

**センテンスハッシュ** = 正規化後の英文の UTF-8 バイト列の SHA-256。

**カードハッシュ** = カード内の全センテンスを教材上の順序で並べ、次の形の
JSON 配列として直列化した文字列の UTF-8 バイト列の SHA-256:

```json
[{"speaker":"a","sentence":"it's nice to meet you today."},{"speaker":"b","sentence":"i look forward to working with you."}]
```

直列化の規則:

- 要素の順序は教材上のセンテンス順(DATA.md の `talks[]` の順)
- 各要素のキーは `speaker`、`sentence` の順。値はいずれも正規化後の文字列
- 話者を持たないセンテンス(`person` キーが欠落する教材)では `speaker` を
  空文字列とする
- 区切り以外の空白を出力しない
- 文字列内の `"` は `\"`、`\` は `\\`、U+0000〜U+001F は小文字16進の
  `\u00xx` でエスケープし、それ以外の文字(非 ASCII を含む)は `\u` 形式に
  せずそのまま出力する
- UTF-8 で符号化し、BOM を付けない

ハッシュ値の表現は、32 バイトを**小文字の16進数64文字**で表したもの。
サーバーはこの形式のみを検証する(教材内容との一致は検証しない)。

### 1.4 検証用テストベクター

§3 の正準実装(または独自実装)は、次の値を再現しなければならない。値は
DATA.md §7 のサンプルユニット(AB会話教材、`sampleS_unit.xlsx` 由来)の
実データから算出規則 v1 で導出したものである。

**センテンスハッシュ**(カード1のセンテンス1)

- 原文(`en`): `It's nice / to meet / you today.`
- 正規化後: `it's nice to meet you today.`
- センテンスハッシュ: `353380bfc96b926ea44f670303b62de50bd6d492533435b408038db977be01f8`

**カードハッシュ**(カード1、6センテンス。話者は `A` / `B` / `類似A` / `類似B`)

直列化結果(1行。話者に非 ASCII が現れる):

```json
[{"speaker":"a","sentence":"it's nice to meet you today."},{"speaker":"b","sentence":"i look forward to working with you."},{"speaker":"類似a","sentence":"i'm glad to meet everyone here."},{"speaker":"類似b","sentence":"i'm excited to work together soon."},{"speaker":"類似a","sentence":"great to meet the team today."},{"speaker":"類似b","sentence":"let's learn from each other this month."}]
```

- カードハッシュ: `ddc949dcfe6ab02a100ca4d39e1ceb9074066760a9946532f8841e7ad39f012b`

### 1.5 ハッシュの前提と教材修正時の扱い

- 1カード内に正規化後の内容が同一となるセンテンスが複数ないこと、1デッキ内に
  同じカードハッシュとなるカードが複数ないこと、正規化結果が空でないことは、
  **教材の作成側が保証する**。アプリは検査しない。カード内のセンテンスの
  順序が確定できること(カードハッシュの前提)は DATA.md §4 の並び順の
  保証による
- 教材内容の修正でハッシュが変わると、サーバー上の旧ハッシュのデータは
  **削除されずに残る**。サーバーは新旧を区別できない。一括読み出しには
  旧ハッシュのデータが混在しうるため、**アプリは自ら算出した現在のハッシュ
  集合と照合し、一致しないデータを現在の教材に結び付けない**(§4)。
  不要なら `delete` で整理してよい(整理はアプリの責務)

## 2. API 仕様

### 2.1 応答規約

- 全エンドポイントは共通形式 `{ status, error, data }` の JSON を返す。
  **`status: 1` が成功、`status: 0` がエラー**(内容は `error`)。
  DATA.md §3.1 と同じく、アプリケーションエラーでも原則 HTTP 200 で返る
- **例外が1つある**: POST の XSRF 検証に失敗した場合だけ **HTTP 403** で
  `{ "status": 0, "error": { "xsrf": { "ERROR": 1 } }, "data": null }` が
  返る(§2.2)。LOGIN.md §1 の「ログイン切れでも HTTP 200」はログイン確認 API
  についての規定であり、本 API の XSRF 失敗はその例外にあたる
- それ以外の HTTP 200 以外(およびネットワークエラー)は**通信失敗**であり、
  成功とも API エラーとも同一視しない(§6)
- `error` は `{ 対象: { 種別: 1 } }` の形。対象は `user` / `xsrf` /
  パラメータ名 / 教材種別(`course` 等)/ `learning_state` / `cursor`。
  種別は `AUTH` / `ERROR` / `INVALID` / `TOO_LONG` / `NOT_FOUND` /
  `FORBIDDEN` / `LIMIT`(§2.3 の表)

### 2.2 送信形式(重要)

- 読み出し(`get` / `list`)は **GET**、パラメータはクエリ文字列
- 書き込み(`set` / `delete`)は **POST**、本文は
  **`application/x-www-form-urlencoded`**。JSON 本文は解釈されない。
  `payload` も**JSON 文字列を1個のフォーム値として**送る
- POST には **`X-XSRF-TOKEN` ヘッダを常に付ける**。値は cookie `XSRF-TOKEN`
  の値を**無加工で**用いる(LOGIN.md §3 の `getXSRFToken()` がこの用途の
  予約であり、そのまま使う)。サーバーは Referer のない要求では検証を省くが、
  ブラウザの同一オリジン fetch は Referer を送るため学習アプリでは常に
  検証対象である。**「送らなくても通ることがある」に依存しないこと**
- XSRF 検証は認証より前に行われる。トークンが不整合なら未ログインでも
  `user.AUTH` ではなく `xsrf.ERROR` + HTTP 403 が返る(扱いは §6)
- いずれも `credentials: "same-origin"` でセッション cookie を送る

### 2.3 エンドポイント

| # | パス(ルートから) | メソッド | 役割 |
|---|---|---|---|
| 1 | `/maker/api/learning_state/set` | POST | 1件の書き込み(新規作成または上書き) |
| 2 | `/maker/api/learning_state/delete` | POST | 1件の削除(未登録へ戻す) |
| 3 | `/maker/api/learning_state/get` | GET | 1件の単独読み出し(`target_type=user` がプリファレンス) |
| 4 | `/maker/api/learning_state/list` | GET | スコープ単位の一括読み出し(分割取得つき) |

**パラメータ**

| パラメータ | set | delete | get | list | 内容 |
|---|---|---|---|---|---|
| `target_type` | ○ | ○ | ○ | — | §1.1 の8種のいずれか |
| `course_id` / `unit_id` / `part_id` / `deck_id` | 種別による | 種別による | 種別による | いずれか1つ | §1.1 の表のとおり。種別に対応しない識別子を送ると `INVALID` |
| `card_hash` / `sentence_hash` | 種別による | 種別による | 種別による | — | 小文字16進64文字 |
| `method` | `sentence_method` のみ○ | 同左 | 同左 | — | `[a-z0-9_]{1,64}` |
| `format_version` | ○ | — | — | — | ペイロードの形式バージョン(0以上の整数。値はアプリが定める) |
| `payload` | ○ | — | — | — | JSON 文字列。UTF-8 で **10,000 バイト以内** |
| `cursor` | — | — | — | 続きのみ | 前回応答の `next_cursor` をそのまま渡す |

- `list` のスコープは `course_id` / `unit_id` / `part_id` / `deck_id` の
  **いずれか1つだけ**指定する(2つ以上は `INVALID`。すべて省略すると
  全教材)。返るのは**スコープの根と配下すべて**(ユニット指定なら
  ユニット・配下のパート・デッキ〈パートに属さないユニット直下のものを
  含む〉・カード・センテンス・センテンス×学習方法)。
  **プリファレンス(`user`)は `list` に含まれない**。`get` で取る
- ページサイズはサーバーが定める。件数指定のパラメータはない

**エラー**(`status: 0` の `error`)

| `error` | 出る操作 | 意味 |
|---|---|---|
| `{ "user": { "AUTH": 1 } }` | 全部 | 未ログイン(セッション失効を含む) |
| `{ "xsrf": { "ERROR": 1 } }` + HTTP 403 | set / delete | XSRF トークン不整合(§2.2) |
| `{ "target_type": { "INVALID": 1 } }` | set / delete / get | 種別が不正 |
| `{ "<識別子名>": { "INVALID": 1 } }` | 全部 | 識別子が不正、種別に対応しない識別子の同送、`list` のスコープ複数指定 |
| `{ "card_hash" \| "sentence_hash": { "INVALID": 1 } }` | set / delete / get | ハッシュが小文字16進64文字でない |
| `{ "method": { "INVALID": 1 } }` | set / delete / get | 学習方法識別子が `[a-z0-9_]{1,64}` に合わない |
| `{ "<教材種別>": { "NOT_FOUND": 1 } }` | set / get / list | 対象の教材(コース〜デッキ)が存在しない(削除済みを含む) |
| `{ "<教材種別>": { "FORBIDDEN": 1 } }` | set / get / list | 対象の教材を閲覧できない |
| `{ "payload": { "INVALID": 1 } }` | set | JSON として不正(`{"a":` / `abc` / `01` 等。`0` / `false` / `null` は正当) |
| `{ "payload": { "TOO_LONG": 1 } }` | set | 10,000 バイト超過 |
| `{ "learning_state": { "LIMIT": 1 } }` | set | 件数上限超過(認証ユーザー×デッキで 1,000 件。`card` / `sentence` / `sentence_method` の合計) |
| `{ "learning_state": { "NOT_FOUND": 1 } }` | delete | 対象のレコードが未登録(他人のレコードを指した場合も同じ) |
| `{ "cursor": { "INVALID": 1 } }` | list | 継続情報が失効・破損 |

### 2.4 応答の器

**`set` の成功**: 書き込んだレコードが `data.learning_state` に返る。

```json
{
    "status": 1,
    "data": {
        "learning_state": {
            "target_type": "sentence_method",
            "deck_id": "a1b2c3d4-0001-0001-0001-000000000001",
            "card_hash": "ddc949dcfe6ab02a100ca4d39e1ceb9074066760a9946532f8841e7ad39f012b",
            "sentence_hash": "353380bfc96b926ea44f670303b62de50bd6d492533435b408038db977be01f8",
            "method": "word_order",
            "format_version": 1,
            "payload": "{\"points\":8,\"maximumPoints\":10,\"errorCount\":1,\"outcome\":\"completed\"}",
            "updated_on": "2026-08-21 12:00:00"
        }
    }
}
```

**`delete` の成功**: `{ "status": 1, "error": null, "data": {} }`

**`get` の成功**: `data.learning_state` に1件。**未登録はエラーではなく
`learning_state: null`** で返る。

**`list` の成功**: `data.learning_states` にレコードの配列、
`data.next_cursor` に続きの継続情報(終端では `null`)。

レコードの共通規定:

- 使わない階層のキーは**返らない**(`sentence_method` のレコードに
  `course_id` / `unit_id` / `part_id` は含まれない)。DATA.md §4 と同じく、
  キーの存在チェックを介して読むこと
- **`payload` は文字列で往復する**。書き込み時は `JSON.stringify` した
  文字列を送り、読み出し時は `JSON.parse` して用いる。サーバーは中身を
  解釈・変換しない。**サーバーが検証するのは JSON として正しいかだけ**で、
  トップレベルのスカラー(`0` / `false` / `null` / `"文字列"`)も通る。
  キーの有無・型・スキーマは検査しない
- `format_version` は書き込み時に指定した値がそのまま返る。異なる版の
  既存ペイロードをどう解釈・移行・破棄するかはアプリが決める
- `updated_on` はサーバー側の最終更新日時。**`YYYY-MM-DD HH:MM:SS` 形式の
  JST**で、タイムゾーン表記を持たない。アプリは表示・並べ替え以外の
  判定(端末時計との比較等)に用いないこと
- 同じ完全な識別情報への再書き込みは**後着優先**(last-write-wins)。
  競合検出はない
- レコード内のキーの**順序は不定**である(レコードごとに揺れる)。順序に
  依存せず、キー名で読むこと
- 本書に列挙されていないフィールドは読み飛ばす(DATA.md §4 と同じ)

### 2.5 教材の存在・閲覧可否の扱い

| 操作 | 教材の存在 | 教材の閲覧可否 |
|---|---|---|
| `set` | 見る(`NOT_FOUND`) | 見る(`FORBIDDEN`) |
| `get` | 見る(`NOT_FOUND`) | 見る(`FORBIDDEN`) |
| `list` | 除外する(削除済み教材のレコードは返らない) | 除外する(閲覧できない教材のレコードは返らない) |
| `delete` | **見ない** | **見ない** |

- `list` の除外は**読み出し時のもので、データは削除されない**。公開範囲が
  戻れば再び返る。したがって「返らない」ことは「未登録」と同じ扱いでよい
  (§4)
- `delete` が教材を見ないのは、閲覧できなくなった教材のデータをアプリが
  整理できるようにするため(§1.5)
- 教材(コース〜デッキ)が削除されると、配下の学習状態も**サーバーが削除
  する**(猶予期間なし)。退会時は全学習状態・プリファレンスが削除される。
  アプリ側での追随処理は不要

## 3. 正準実装

次のコードを**改変せず**アプリに組み込むこと(依存ライブラリなし。
LOGIN.md §3 の `EnhackLogin` が同じページに組み込まれていることを前提と
する)。ハッシュ算出は Web Crypto(`crypto.subtle`)を用いる。`*.enhack.app`
は HTTPS 配信のため利用できる。

```javascript
const EnhackStatus = {
    // ---- §1.3 ハッシュ算出(規則 v1) ----
    normalize: function ( text ) {
        let s = String( text ).normalize( "NFKC" );
        s = s.replace( /[\uFEFF\u200B\u00AD]/g, "" );
        s = s.replace( /[\u2018\u2019]/g, "'" );
        s = s.replace( /\//g, " " );
        s = s.replace( /\p{White_Space}/gu, " " );
        s = s.replace( /[A-Z]/g, ( c ) => c.toLowerCase() );
        s = s.replace( / {2,}/g, " " );
        s = s.replace( /^ +| +$/g, "" );
        return s;
    },
    quote: function ( s ) {
        let out = "\"";
        for ( const ch of s ) {
            const code = ch.codePointAt( 0 );
            if ( ch === "\"" ) {
                out += "\\\"";
            } else if ( ch === "\\" ) {
                out += "\\\\";
            } else if ( code <= 0x1f ) {
                out += "\\u00" + code.toString( 16 ).padStart( 2, "0" );
            } else {
                out += ch;
            }
        }
        return out + "\"";
    },
    sha256hex: async function ( text ) {
        const digest = await crypto.subtle.digest( "SHA-256", new TextEncoder().encode( text ) );
        return Array.from( new Uint8Array( digest ) )
            .map( ( b ) => b.toString( 16 ).padStart( 2, "0" ) ).join( "" );
    },
    sentenceHash: function ( en ) {
        return this.sha256hex( this.normalize( en ) );
    },
    cardHash: function ( talks ) {
        const items = talks.map( ( t ) =>
            "{\"speaker\":" + this.quote( this.normalize( t.person == null ? "" : t.person ) ) +
            ",\"sentence\":" + this.quote( this.normalize( t.en ) ) + "}" );
        return this.sha256hex( "[" + items.join( "," ) + "]" );
    },

    // ---- §2 API 呼び出し ----
    request: async function ( method, path, params ) {
        const form = new URLSearchParams();
        Object.keys( params ).forEach( ( k ) => {
            if ( params[ k ] !== undefined && params[ k ] !== null ) {
                form.append( k, String( params[ k ] ) );
            }
        } );
        const init = { method: method, credentials: "same-origin", headers: {} };
        let url = path;
        if ( method === "POST" ) {
            init.headers[ "Content-Type" ] = "application/x-www-form-urlencoded";
            const token = EnhackLogin.getXSRFToken();
            if ( token !== null ) {
                init.headers[ "X-XSRF-TOKEN" ] = token;
            }
            init.body = form.toString();
        } else {
            url = path + "?" + form.toString();
        }
        const response = await fetch( url, init );
        if ( ! response.ok && response.status !== 403 ) {
            throw new Error( "learning_state request failed: HTTP " + response.status );
        }
        return await response.json();
    },
    post: async function ( path, fields ) {
        let body = await this.request( "POST", path, fields );
        if ( ! body.status && body.error && body.error.xsrf ) {
            body = await this.request( "POST", path, fields );   // トークン再取得のうえ1回だけ再試行(§6)
        }
        return body;
    },
    encodePayload: function ( value ) {
        const text = JSON.stringify( value );
        if ( new TextEncoder().encode( text ).length > 10000 ) {
            throw new Error( "learning_state payload exceeds 10,000 bytes" );
        }
        return text;
    },
    set: function ( fields ) {
        return this.post( "/maker/api/learning_state/set", fields );
    },
    delete: function ( fields ) {
        return this.post( "/maker/api/learning_state/delete", fields );
    },
    get: function ( fields ) {
        return this.request( "GET", "/maker/api/learning_state/get", fields );
    },
    list: function ( scope, cursor ) {
        return this.request( "GET", "/maker/api/learning_state/list", Object.assign( {}, scope, { cursor: cursor } ) );
    },
    listAll: async function ( scope ) {
        for ( let attempt = 0; attempt < 2; attempt++ ) {
            const all = [];
            let cursor = null;
            let restart = false;
            do {
                const body = await this.list( scope, cursor );
                if ( ! body.status ) {
                    if ( body.error && body.error.cursor ) {
                        restart = true;                                // 継続情報の失効: 最初から取り直す(§4)
                        break;
                    }
                    return body;                                       // それ以外のエラー応答はそのまま返す
                }
                all.push( ...body.data.learning_states );
                cursor = body.data.next_cursor;                        // 件数では判断しない
            } while ( cursor !== null );
            if ( ! restart ) {
                return { status: 1, error: null, data: { learning_states: all } };
            }
        }
        throw new Error( "learning_state list: cursor invalidated repeatedly" );
    }
};
```

- `set` / `delete` / `get` / `listAll` は**共通形式の応答をそのまま返す**。
  アプリは `status` を見て分岐し、`status: 0` のときは §6 の表で `error` を
  分類する。通信失敗(HTTP 200 / 403 以外、ネットワークエラー)は例外に
  なる
- `listAll` は §4 の一巡を実装する。`next_cursor` が `null` になるまで
  取り続け(**件数が 0 のページも終端ではない**)、`cursor: INVALID` が
  返れば最初から取り直す。取り直しても失敗する場合は例外
- `post` は XSRF エラーのとき、cookie からトークンを取り直して**1回だけ**
  再試行する。それでも `xsrf.ERROR` なら応答をそのまま返す(扱いは §6)
- `encodePayload` は内部オブジェクトをペイロード文字列に変換し、上限を
  超えるものを例外にする。上限超過は設計の誤りであり実行時に起きてはなら
  ない(§5)
- `cardHash` の引数は DATA.md §3.3 の `talks[]` 配列そのもの(`person` /
  `en` を持つオブジェクトの配列)。`person` が欠落する教材は空文字列として
  扱われる
- 正準実装を組み込んだら、ブラウザのコンソールで §1.4 のテストベクターが
  再現することを確認する:

```javascript
await EnhackStatus.sentenceHash( "It's nice / to meet / you today." );
// → "353380bfc96b926ea44f670303b62de50bd6d492533435b408038db977be01f8"
```

## 4. 読み出し(起動時)

- **起動時に、LOGIN.md の `check()` が true を返した後**、DATA.md §2 の
  `unit_id` ごとに `listAll( { unit_id: <ユニット ID> } )` で一巡する
  (複数ユニットはユニットごとに一巡)。教材読み込み(DATA.md)と並行して
  よいが、ハッシュ照合(下記)は教材の変換が済んでから行う
- **一巡が完了するまで、未登録かどうかは確定しない**。一巡の途中で「まだ
  返っていない」ことを未登録と判断しないこと
- 一巡の途中で `cursor: INVALID` が返った場合(継続情報の失効)は、
  それまでに得た分を捨てて最初から取り直す(正準実装 `listAll` が行う)
- 一巡は完全なスナップショットではない。開始時点で存在し一巡の間存在し
  続けたレコードはちょうど1回返るが、取得中に作られたレコードは次回に回り、
  取得中に更新されたレコードは更新前後どちらの内容でもよい。取得中に教材の
  所属が変わった場合は読み出し時点の所属に従う。起動時の1回読みではこれらは
  問題にならない
- 返ったレコードは、**アプリが教材から算出したハッシュ集合と照合**して
  内部状態に結び付ける。`card_hash` / `sentence_hash` が現在の教材の
  どれにも一致しないレコード(教材修正前の旧データ §1.5)は、現在の教材に
  結び付けない(無視する。整理は任意)
- ハッシュ集合に含まれるが返らなかったカード・センテンスは**未登録**
  (初期状態)である。コース〜デッキの保存単位についても、返らないことが
  未登録を意味する(閲覧できなくなった教材のレコードも返らないが、それは
  §2.5 のとおり未登録と同じ扱いでよい)
- スコープ自体が `NOT_FOUND` / `FORBIDDEN` で拒まれた場合(教材が削除された、
  または利用者が閲覧資格を失った)、そのユニットは**学習状態を持てない
  教材**として扱う: 学習状態なしで動作し、そのユニット配下への書き込みは
  行わない(書き込んでも同じ理由で拒まれる)
- **プリファレンスは `list` に含まれない**。必要なら起動時に
  `get( { target_type: "user" } )` で別途読む。`learning_state: null` なら
  未登録(既定値で動作する)
- **セッション中の再読は不要**。以後はメモリ上の状態が正であり、書き込みの
  応答で得たレコードを反映すればよい(§5)

## 5. 書き込みと削除

- **書き込みは学習の区切りごとに都度行う**(結果の確定、状態の変化のたびに
  `set`)。まとめ書きやセッション終了時の一括保存に頼らないこと(ページを
  閉じられると失われる)。どの出来事を区切りとするかはアプリの意味論に属する
- 1件の書き込みは1つの保存単位への**最新状態の全量**である。差分ではなく、
  その保存単位の現在の状態をペイロードに丸ごと載せる(サーバーはマージ
  しない。後着優先)
- ペイロードは `encodePayload` で文字列にし、`format_version` を添えて送る。
  実効サイズは 100 バイト級を想定し、設計上の目安は 1 レコード 1,000 バイト
  程度とする。10,000 バイトの上限は正当な学習利用が到達しない防護線であり、
  近づく設計は誤りである
- 識別情報は §1.1 の完全な識別情報だけを送る。**上位階層の識別子を添えない**
- `set` の応答の `data.learning_state` は書き込んだレコードそのものである。
  内部状態の更新は書き込み前に済んでいてよく、応答で改めて `JSON.parse`
  する必要はない
- 書き込みに失敗しても(§6)、**メモリ上の内部状態は壊さない**。サーバーは
  永続先であって正ではない。再試行するか、次の区切りの書き込みに任せるかは
  アプリの裁量
- `delete` は完全な識別情報だけを送る(`format_version` / `payload` は
  不要)。**対象が未登録のときの `learning_state: NOT_FOUND` は、整理の
  用途では成功と同じに扱ってよい**(すでに未登録である)
- 認証ユーザー×デッキごとの件数上限(1,000 件)は、標準的な教材構造では
  到達しない(1 デッキあたりカード・センテンス・センテンス×学習方法の合計)。
  `LIMIT` が返る設計は誤りであり、再試行で解決しない
- 複数タブ・複数端末での同時利用は後着優先に委ねる。競合の検出・調停は
  行わない

## 6. エラーの扱い

`status: 0` の `error`、および通信失敗を次の3類に分けて扱う。

**再入・復旧系**(実行時に起こりうる。アプリが対処する)

| 事象 | 扱い |
|---|---|
| `user.AUTH`(全操作) | セッション失効。**LOGIN.md §4 の未ログイン時の扱い**(ログインが必要である旨のメッセージ提示。遷移・誘導はしない)。以後、再度 `check()` が true になるまでサーバーへの書き込みは行わない |
| `xsrf.ERROR` + HTTP 403(POST。正準実装の1回再試行後) | `EnhackLogin.check()` を実行して切り分ける。false なら `user.AUTH` と同じ扱い。true なら書き込み失敗として扱う(メモリ上の状態は保持) |
| `cursor.INVALID`(list) | 継続情報の失効。最初から取り直す(正準実装 `listAll` が行う) |
| 教材種別の `NOT_FOUND` / `FORBIDDEN`(set / get / list) | 教材が削除された、または閲覧資格を失った。その教材は**学習状態を持てない教材**として扱う(§4)。データは消えていない場合もあるが、アプリからは区別しない |
| `learning_state.NOT_FOUND`(delete) | すでに未登録。整理の用途では成功と同じ |
| 通信失敗(例外: HTTP 200 / 403 以外、ネットワークエラー) | **判定不能**。成功とも API エラーとも同一視しない。読み出しなら学習状態なしで動作するか再試行するか、書き込みなら保持して再試行するかはアプリの裁量。ログイン済みとして・未ログインとして扱う根拠にもしない |

**実装誤り系**(正しく実装されていれば起きない。起きたらコードを直す)

| 事象 | 原因 |
|---|---|
| `target_type.INVALID` / `<識別子名>.INVALID` | 種別の誤り、種別に対応しない識別子の同送(上位階層の識別子を添えた)、`list` のスコープ複数指定 |
| `card_hash.INVALID` / `sentence_hash.INVALID` | ハッシュが小文字16進64文字でない(大文字化・切り詰め等) |
| `payload.INVALID` / `payload.TOO_LONG` | `encodePayload` を通していない、または上限に近い設計 |
| `method.INVALID` | 学習方法識別子が `[a-z0-9_]{1,64}` に合わない |

**正当な利用では出ない系**

| 事象 | 扱い |
|---|---|
| `learning_state.LIMIT`(set) | 件数上限超過。再試行しない。ハッシュ集合の作り方(教材と無関係な値を書いていないか)を疑う |

## 7. 自己改造の行動指針

教材を DATA.md で読み込み、LOGIN.md でログイン判定を行っているアプリに、
本書の保存・取得を組み込む際の指針。

1. **内部状態を保存単位へ写像する**。あなたのアプリが永続化したい状態
   (成績、お気に入り、進捗、設定など。どんな名前で呼んでいるにせよ)を、
   §1.1 の8種類の保存単位のどれに置くかを最初に確定させる。利用者全体の
   設定は `user`、カードに紐づく状態は `card`、センテンスの学習方法別の
   結果は `sentence_method`、というように。ペイロードの構造と
   `format_version` の値はあなたが決め、集計値(デッキの合計点など)は
   一次記録にせず、読み出した最新結果から導出する
2. **ハッシュ集合を DATA.md の変換層で算出する**。DATA.md §6 指針3 の
   境界層で、`cards[]` から `cardHash`、`talks[]` の各要素から
   `sentenceHash` を算出し、ハッシュ → 内部オブジェクトの対応表を持つ。
   §1.4 のテストベクターで実装を確認してから先へ進む
3. **読み出し・書き込みも同じ境界層に置く**。§4 の起動時読み出しと §5 の
   書き込みを、内部モデルと API の間の境界層として実装し、既存の内部
   モデル・表示・演出のコードには手を入れない(DATA.md §6 指針3、
   LOGIN.md §5 指針1 と同じ原則)。内部モデルが正であり、サーバーは
   その永続先にすぎない
4. **検証は開発環境で実測する**。(a) ログイン済みブラウザで学習し、
   リロード後に状態が復元されること(`list` の一巡と照合が機能している)、
   (b) 未ログイン(プライベートウィンドウ等)で書き込みが発生しないこと、
   (c) コンソールで §1.4 のテストベクターが再現すること。開発サーバーには
   BASIC 認証があるため、検証はブラウザで行う

## 8. 現物例(開発環境・実測 2026-08-26)

DATA.md §7 と同じサンプルユニット(`FEB49F42-9A05-11F1-B061-10DC160DA7B8`、
1デッキ)を、本書に従って改造した AB会話教材アプリで学習した直後の
`list` の実応答(ユニット単位。全7件中3件を抜粋)。§7 指針4 の検証の
起点に使える。

```
GET /maker/api/learning_state/list?unit_id=FEB49F42-9A05-11F1-B061-10DC160DA7B8
```

```json
{
    "status": 1,
    "error": null,
    "data": {
        "learning_states": [
            {
                "target_type": "card",
                "deck_id": "FEBCFD36-9A05-11F1-B061-10DC160DA7B8",
                "card_hash": "ddc949dcfe6ab02a100ca4d39e1ceb9074066760a9946532f8841e7ad39f012b",
                "format_version": 1,
                "payload": "{\"favorite\":true}",
                "updated_on": "2026-08-26 14:38:04"
            },
            {
                "target_type": "sentence_method",
                "deck_id": "FEBCFD36-9A05-11F1-B061-10DC160DA7B8",
                "card_hash": "e34b457a4d53fa63fc65021e641280cda08391dd93548f2f35909dad608f5c1a",
                "sentence_hash": "40606be6a2363d423840389515233ea01948c59647346a28de85984a7efb50c1",
                "method": "word_order",
                "format_version": 1,
                "payload": "{\"points\":14,\"maximumPoints\":21,\"errorCount\":0,\"quizType\":\"B\",\"kind\":\"main\",\"at\":\"2026-08-26T05:37:12.658Z\"}",
                "updated_on": "2026-08-26 14:37:13"
            },
            {
                "target_type": "sentence_method",
                "deck_id": "FEBCFD36-9A05-11F1-B061-10DC160DA7B8",
                "card_hash": "e34b457a4d53fa63fc65021e641280cda08391dd93548f2f35909dad608f5c1a",
                "sentence_hash": "40606be6a2363d423840389515233ea01948c59647346a28de85984a7efb50c1",
                "method": "pronunciation",
                "format_version": 1,
                "payload": "{\"points\":0,\"maximumPoints\":7,\"matches\":0,\"quizType\":\"B\",\"kind\":\"main\",\"at\":\"2026-08-26T05:37:12.658Z\"}",
                "updated_on": "2026-08-26 14:37:13"
            }
        ],
        "next_cursor": null
    }
}
```

読み取れること:

- 1件目の `card_hash` は §1.4 のテストベクター(カード1)と一致する。
  アプリが規則 v1 で算出したハッシュがそのまま識別子になっている
- 同じセンテンスに `word_order` と `pronunciation` の2レコードが独立して
  並ぶ(§1.1)。使わない階層のキー(`unit_id` / `part_id`)は含まれない
- `updated_on` は JST(ペイロード内でアプリが記録した UTC の `at` と
  9時間差)。ペイロードの中身(`points` / `quizType` / `kind` / `at` 等)は
  このアプリの意味論であり、本書は規定しない
- 実応答ではキーの順序がレコードごとに揺れる(上の例は本書の表の順に
  整えてある。§2.4)
- 7件で `next_cursor: null` — 1ページで一巡が完了している。件数が少なくても
  終端は `next_cursor` だけで判定する(§4)

`get( { target_type: "user" } )` の応答は `data.learning_state` に同じ形の
レコード1件(`target_type: "user"`、識別子キーなし)、未登録なら `null` が
入る(§2.4)。

---

*出典(改訂追跡用): 要求の正本は
`choi/ユーザー別学習状態・プリファレンス保存取得_要求仕様.md`(承認済み版。
ハッシュ算出規則 v1・テストベクターは同書 §3 からの複写)。API のパス・
パラメータ・応答形・エラー表はサーバーサイド API ドキュメント
(学習状態・プリファレンス API)が正。送信形式(form-urlencoded)・
XSRF 検証(POST のみ、HTTP 403、認証より前、Referer 省略時は検証省略)は
実装調査(2026-08-26)による。本書は器のみを宣言し、ペイロードの意味論は
アプリに属する。*
