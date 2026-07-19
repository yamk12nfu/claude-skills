# 分析チェックリスト

各カテゴリの分析基準と優先度判定ルール。

## 目次

1. [Performance](#1-performance)
2. [Network](#2-network)
3. [Accessibility](#3-accessibility)
4. [Console Errors](#4-console-errors)
5. [UI/UX](#5-uiux)
6. [SEO](#6-seo)
7. [Security](#7-security)

---

## 1. Performance

### タイミングメトリクス

| メトリクス | Critical | Warning | Info |
|---|---|---|---|
| TTFB | > 800ms | > 200ms | - |
| FCP | > 3000ms | > 1800ms | > 1000ms |
| DOMContentLoaded | > 5000ms | > 3000ms | > 1500ms |
| Load Complete | > 10000ms | > 5000ms | > 3000ms |
| DOM Interactive | > 5000ms | > 3000ms | - |

### DOM統計

| 項目 | Critical | Warning | Info |
|---|---|---|---|
| 要素数 | > 3000 | > 1500 | > 800 |
| 最大ネスト深度 | > 32 | > 15 | > 10 |

### 画像最適化

- **Critical**: 表示サイズの4倍以上の自然サイズを持つ画像（例: 200x200表示で800x800以上）
- **Warning**: `loading="lazy"` が未設定のファーストビュー外の画像
- **Warning**: width/height属性が未設定（CLSの原因）
- **Info**: WebP/AVIF未使用の画像（srcから推定）

## 2. Network

### リクエスト数

| 項目 | Critical | Warning | Info |
|---|---|---|---|
| 総リクエスト数 | > 100 | > 50 | > 30 |
| JS ファイル数 | > 20 | > 10 | > 5 |
| CSS ファイル数 | > 10 | > 5 | > 3 |

### 転送サイズ

| 項目 | Critical | Warning | Info |
|---|---|---|---|
| 総転送サイズ | > 5MB | > 2MB | > 1MB |
| 単一リソース | > 1MB | > 500KB | > 250KB |
| JS 合計 | > 2MB | > 1MB | > 500KB |
| CSS 合計 | > 500KB | > 200KB | > 100KB |

### その他

- **Critical**: HTTPステータス 4xx/5xx のリクエスト
- **Warning**: リダイレクトチェーン（3回以上）
- **Info**: キャッシュ可能だがCache-Control未設定のリソース

## 3. Accessibility

### フォーム要素

- **Critical**: label も aria-label も持たないフォーム入力要素
- **Warning**: placeholder のみでラベルが無い要素（placeholderOnly: true）

### 画像

- **Critical**: alt属性が空のコンテンツ画像（装飾画像を除く）
- **Info**: alt テキストが長すぎる（125文字超）

### セマンティクス（スナップショットから判定）

- **Warning**: main/nav/header/footer ランドマークの欠如
- **Warning**: 見出しレベルのスキップ（h1→h3 など）
- **Warning**: h1が存在しない、または複数存在する
- **Info**: button ではなく div/span に click イベントがある要素

### インタラクション

- **Warning**: タッチターゲットが44x44px未満の要素が多い（10個以上）
- **Info**: タッチターゲットが44x44px未満の要素がある（1-9個）
- **Warning**: 汎用的なリンクテキスト（「こちら」「click here」等）が3つ以上

### 言語

- **Warning**: `<html lang>` が未設定

## 4. Console Errors

- **Critical**: JavaScript runtime error（TypeError, ReferenceError 等）
- **Critical**: Failed to load resource エラー
- **Warning**: Deprecation warning
- **Warning**: CORS関連の警告
- **Info**: その他の console.warn

### パターンマッチング

以下のパターンをコンソールメッセージから検出:
- `TypeError` / `ReferenceError` / `SyntaxError` → Critical
- `Failed to load` / `404` / `net::ERR_` → Critical
- `deprecated` / `will be removed` → Warning
- `CORS` / `Cross-Origin` → Warning
- `CSP` / `Content Security Policy` → Security カテゴリに分類

## 5. UI/UX

### スクリーンショットからの目視確認

以下の観点でスクリーンショットを確認する:
- レイアウト崩れ（要素の重なり、はみ出し）
- テキストの切れ、省略表示の問題
- 空白の不均一、余白の過不足
- ボタンやリンクの視認性
- ローディング状態の残存
- 空の状態（Empty State）の未処理

### z-index

- **Warning**: z-index > 9999 の要素がある（z-index管理の問題を示唆）

### レイアウト

- **Info**: 横スクロールが発生している（ビューポート幅超過要素）

## 6. SEO

### メタ情報

- **Critical**: `<title>` が未設定
- **Warning**: `<meta name="description">` が未設定
- **Warning**: `<meta name="viewport">` が未設定
- **Info**: OGタグが未設定（og:title, og:description, og:image）

### 見出し構造

- **Warning**: h1 が存在しない
- **Warning**: h1 が複数存在する
- **Info**: 見出しレベルのスキップ

### 言語・エンコーディング

- **Info**: charset が UTF-8 でない
- **Warning**: html lang 属性が未設定

## 7. Security

### Mixed Content

- **Critical**: HTTPS ページ上で HTTP リソースを読み込んでいる（ネットワークリクエストから検出）

### CSP

- **Warning**: CSP 違反がコンソールに出ている

### その他

- **Info**: `target="_blank"` のリンクに `rel="noopener"` が無い（スナップショットから検出）
- **Info**: フォームの autocomplete 属性が未設定
