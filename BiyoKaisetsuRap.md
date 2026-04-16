# 美容師国家試験 解説ラップ動画自動生成パイプライン

美容師国家試験の用語集（902語）から、解説ラップ動画を自動生成するパイプラインです。

```
用語集 (CSV)
  └─[Step 1]─→ 歌詞 JSON (Claude API)
      └─[Step 3]─→ mp3 (Suno / Playwright)  ※ Step 2: Suno ログイン（初回のみ）
          └─[Step 4]─→ タイムコード付き JSON (OpenAI Whisper API)
              ├─[Step 5]─→ SRT字幕ファイル
              └─[Step 6]─→ 字幕付き動画 (ffmpeg)
                            ↑ assets/bg/ の背景動画 × video-config.json
```

## 必要なもの

| ツール | 用途 | インストール |
|--------|------|-------------|
| [Bun](https://bun.sh) | TypeScript 実行環境 | setup スクリプトが自動インストール |
| [ffmpeg](https://ffmpeg.org) | 動画・字幕合成 | 下記参照 |
| Claude API キー | 歌詞生成 | [Anthropic Console](https://console.anthropic.com) |
| OpenAI API キー | タイムコード生成 | [OpenAI Platform](https://platform.openai.com) |
| Suno アカウント | ラップ音源生成 | [suno.com](https://suno.com) |

**ffmpeg のインストール:**
```bash
# macOS
brew install ffmpeg

# Ubuntu / Debian
sudo apt-get install -y ffmpeg

# Windows
winget install Gyan.FFmpeg
```

## セットアップ

```bash
# 1. リポジトリをクローン
git clone <repository-url>
cd BiyoKaisetsuRap

# 2. セットアップスクリプトを実行
bash setup.sh          # macOS / Linux
setup.bat              # Windows
```

セットアップスクリプトが行うこと：
- Bun のインストール確認（未インストールの場合は自動インストール）
- ffmpeg のインストール確認
- `suno-pipeline/.env` の生成（`.env.example` からコピー）
- OS に合った日本語フォントのデフォルト設定
- 必要なディレクトリの作成

```bash
# 3. .env に API キーを設定
#    suno-pipeline/.env を編集:
ANTHROPIC_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here

# 4. Suno にログイン（Step 2 / 初回のみ）
cd suno-pipeline
bun run src/02-save-session.ts
```

## 使い方

すべてのコマンドは `suno-pipeline/` ディレクトリ内で実行します。

```bash
cd suno-pipeline
```

### プロンプトのカスタマイズ

歌詞の生成ルールや Suno のスタイルは、以下のファイルを編集することで変更できます。

| ファイル | 内容 |
|----------|------|
| `suno-pipeline/data/prompts/lyrics-prompt.md` | Claude API へのプロンプトテンプレート |
| `suno-pipeline/data/prompts/suno-style.json` | Suno へのスタイル指定（ベース文字列・科目別テキスト） |
| `suno-pipeline/data/prompts/subtitle-style.json` | ASS 字幕のビジュアルスタイル（色・サイズ・配置など） |

`lyrics-prompt.md` では `{{term}}` `{{yomi}}` `{{subject}}` `{{meaning}}` `{{question}}` `{{blank_choice}}` `{{katakana_term}}` をプレースホルダーとして使用できます。

`subtitle-style.json` の設定項目：

| キー | 説明 | デフォルト |
|------|------|-----------|
| `fontSizeRatio` | フォントサイズ = 動画幅 ÷ この値 | `12` |
| `bold` | 太字 | `true` |
| `primaryColor` | 文字色（RRGGBB） | `"FFFFFF"`（白） |
| `outlineColor` | アウトライン色（RRGGBB） | `"000000"`（黒） |
| `outlineWidth` | アウトライン太さ | `2.5` |
| `shadow` | 影の深さ | `0` |
| `alignment` | 字幕位置（5=中央, 2=下中央） | `5` |
| `hookColor` | Hook行の文字色（RRGGBB） | `"00FFFF"`（シアン） |

ファイルを削除するとコード内のデフォルト設定にフォールバックします。

---

### Step 1: 歌詞生成

Claude API を使って用語の解説ラップ歌詞を生成します。

```bash
bun run src/01-generate-lyrics.ts --subject "関係法規・制度"
# 出力: data/lyrics/{filename}.json
```

科目一覧：`関係法規・制度` / `保健` / `衛生管理` / `香粧品化学` / `理容・美容技術理論` / `文化論` / `運営管理`

### Step 2: Suno ログインセッション保存

Suno への自動操作に必要なセッションをブラウザに保存します。初回または再ログインが必要な場合に実行します。

```bash
bun run src/02-save-session.ts
# ブラウザが起動するので、画面に従って Suno にログイン
```

### Step 3: Suno で音源生成

Playwright で Suno を自動操作し、mp3 をダウンロードします。

```bash
bun run src/03-suno-upload.ts --subject "関係法規・制度"
bun run src/03-suno-upload.ts --subject "関係法規・制度" --limit 1  # テスト: 1曲のみ
# 出力: downloads/{filename}.mp3
```

### Step 4: タイムコード生成

OpenAI Whisper API で音声を書き起こし、歌詞の各行にタイムスタンプを付与します。

```bash
bun run src/04-whisper.ts
# 更新: data/lyrics/{filename}.json (start/end フィールドを追記)
```

### Step 5: SRT 字幕エクスポート

タイムコード付き JSON から SRT 字幕ファイルを生成します。

```bash
bun run src/05-export-srt.ts
bun run src/05-export-srt.ts --file 23_kan_124  # 1ファイルのみ
# 出力: output/srt/{filename}.srt
```

### Step 6: 字幕付き動画生成

背景動画と音源を合成し、ASS 字幕を焼き込んだ動画を生成します。

```bash
# 事前準備: 背景動画を配置
cp your_video.mp4 assets/bg/rapper.mp4

# video-config.json で用語と背景動画を対応付け
# data/video-config.json:
# [
#   { "filename": "23_kan_124", "bg": "assets/bg/rapper.mp4" }
# ]

bun run src/06-make-video.ts
bun run src/06-make-video.ts --file 23_kan_124   # 1用語のみ
# 出力: output/videos/{filename}.mp4
```

#### フォントの変更

字幕フォントは `.env` または `--font` 引数で変更できます。

```bash
# .env で設定（恒久）
VIDEO_FONT=Hiragino Kaku Gothic ProN

# 引数で一時指定
bun run src/06-make-video.ts --font "Hiragino Kaku Gothic ProN"
```

OS 別デフォルト: macOS → `Hiragino Sans` / Windows → `Yu Gothic` / Linux → `Noto Sans CJK JP`

### 開発用: タイムコード確認動画

```bash
# 黒背景で確認
bun run src/99-preview-video.ts --file 23_kan_124

# 背景動画を指定して確認
bun run src/99-preview-video.ts --file 23_kan_124 --bg assets/bg/rapper.mp4
# 出力: output/preview/{filename}_preview.mp4
```

## 成果物

| ファイル | 説明 |
|----------|------|
| `output/videos/{filename}.mp4` | 字幕付き動画（最終成果物） |
| `output/srt/{filename}.srt` | SRT 字幕ファイル（最終成果物） |
| `data/lyrics/{filename}.json` | タイムコード付き歌詞 JSON（最終成果物） |
| `downloads/{filename}.mp3` | Suno 生成音源（最終成果物） |

## ディレクトリ構成

```
BiyoKaisetsuRap/
├── setup.sh                    セットアップ (macOS / Linux)
├── setup.bat                   セットアップ (Windows)
├── suno-pipeline-spec.md       設計仕様書
└── suno-pipeline/
    ├── src/
    │   ├── 01-generate-lyrics.ts   Step 1: 歌詞生成
    │   ├── 02-save-session.ts      Step 2: Suno ログインセッション保存
    │   ├── 03-suno-upload.ts       Step 3: Suno 自動操作 → mp3 ダウンロード
    │   ├── 04-whisper.ts           Step 4: タイムコード生成
    │   ├── 05-export-srt.ts        Step 5: SRT 字幕エクスポート
    │   ├── 06-make-video.ts        Step 6: 字幕付き動画生成
    │   └── 99-preview-video.ts     開発用: タイムコード確認動画
    ├── assets/
    │   └── bg/                     背景動画置き場（*.mp4 は gitignore）
    ├── data/
    │   ├── term.csv                用語集 (902語)
    │   ├── lyrics/                 生成済み歌詞 JSON
    │   └── video-config.json       用語ごとの背景動画設定
    ├── downloads/                  Suno からダウンロードした mp3
    ├── output/
    │   ├── videos/                 最終成果物: 字幕付き動画
    │   ├── srt/                    最終成果物: SRT 字幕
    │   └── preview/                開発用確認動画
    ├── logs/                       進捗キャッシュ
    ├── .env                        API キー（gitignore）
    └── .env.example                .env テンプレート
```

## コスト目安

| 項目 | 数量 | コスト |
|------|------|--------|
| Claude API（歌詞生成） | 902回 × ~500トークン | ~$5 |
| Suno Premier（2ヶ月） | 4,000クレジット | $60 |
| OpenAI Whisper API（タイムコード） | ~$0.006/分 × 902曲 | ~$5 |
| **合計** | | **~$70** |
