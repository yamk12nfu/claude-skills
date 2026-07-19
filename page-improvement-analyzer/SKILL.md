---
name: page-improvement-analyzer
last-verified: 2026-07-19
description: "Playwright MCPツールを使ってWebページを総合的に分析し、開発者向けの改善提案をカテゴリ別優先度付きマークダウンレポートとして出力する。URLを指定して「ページを分析して」「改善点を教えて」「パフォーマンスをチェックして」「アクセシビリティを確認して」「このページのリファクタポイントを洗い出して」「ページレビューして」と言った時に使用する。パフォーマンス、UI/UX、コンソールエラー、アクセシビリティ、ネットワーク最適化、SEO、セキュリティを網羅的にカバーする。"
---

# Page Improvement Analyzer

Playwright MCPツールでWebページにアクセスし、複数の観点からデータを収集・分析して、開発者向け改善レポートをマークダウンで生成する。

## ワークフロー

1. ページにナビゲート & 読み込み完了を待機
2. データ収集（6種のデータソースから取得）
3. 収集データを分析し改善点を特定
4. カテゴリ別優先度付きレポートを生成

## Step 1: ナビゲーション

`mcp__playwright__browser_navigate` でURLにアクセスする。`mcp__playwright__browser_wait_for` で主要コンテンツの表示を待つ。SPAの場合はクライアントサイドレンダリング完了まで適宜待機する。

## Step 2: データ収集

以下の6種のデータを収集する。独立したものは並行で実行する。

### 2-1. スクリーンショット

`mcp__playwright__browser_take_screenshot` でページのスクリーンショットを取得。視覚的なレイアウト崩れ、UI/UXの問題を目視確認する。

### 2-2. コンソールメッセージ

`mcp__playwright__browser_console_messages` でコンソール出力を取得。error/warningを重点的に確認する。

### 2-3. ネットワークリクエスト

`mcp__playwright__browser_network_requests` で全リクエストを取得。レスポンスサイズ、ステータスコード、リクエスト数を分析する。

### 2-4. ページスナップショット（アクセシビリティツリー）

`mcp__playwright__browser_snapshot` でアクセシビリティツリーを取得。セマンティックHTML、ARIA属性、フォーカス管理を確認する。

### 2-5. パフォーマンスメトリクス（JS評価）

`mcp__playwright__browser_evaluate` で以下のJavaScriptを実行:

```javascript
(() => {
  const nav = performance.getEntriesByType('navigation')[0];
  const paint = performance.getEntriesByType('paint');
  const resources = performance.getEntriesByType('resource');
  const fcp = paint.find(e => e.name === 'first-contentful-paint');
  const allElements = document.querySelectorAll('*');
  const maxDepth = (() => {
    let max = 0;
    allElements.forEach(el => {
      let depth = 0, node = el;
      while (node.parentElement) { depth++; node = node.parentElement; }
      if (depth > max) max = depth;
    });
    return max;
  })();
  const images = Array.from(document.images).map(img => ({
    src: img.src?.substring(0, 100),
    naturalWidth: img.naturalWidth, naturalHeight: img.naturalHeight,
    displayWidth: img.width, displayHeight: img.height,
    hasAlt: !!img.alt, loading: img.loading,
    hasExplicitSize: img.hasAttribute('width') && img.hasAttribute('height')
  }));
  const meta = {
    title: document.title,
    description: document.querySelector('meta[name="description"]')?.content,
    viewport: document.querySelector('meta[name="viewport"]')?.content,
    charset: document.characterSet, lang: document.documentElement.lang,
    ogTags: Array.from(document.querySelectorAll('meta[property^="og:"]')).map(m => ({
      property: m.getAttribute('property'), content: m.content?.substring(0, 80)
    }))
  };
  const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => ({
    tag: h.tagName, text: h.textContent?.trim().substring(0, 60)
  }));
  const resourcesByType = {};
  resources.forEach(r => {
    const type = r.initiatorType || 'other';
    if (!resourcesByType[type]) resourcesByType[type] = { count: 0, totalSize: 0 };
    resourcesByType[type].count++;
    resourcesByType[type].totalSize += r.transferSize || 0;
  });
  return {
    timing: {
      domContentLoaded: nav?.domContentLoadedEventEnd - nav?.startTime,
      loadComplete: nav?.loadEventEnd - nav?.startTime,
      ttfb: nav?.responseStart - nav?.startTime,
      domInteractive: nav?.domInteractive - nav?.startTime
    },
    fcp: fcp?.startTime,
    dom: { elementCount: allElements.length, maxDepth },
    images, meta, headings, resourcesByType,
    totalResources: resources.length
  };
})()
```

### 2-6. アクセシビリティ/UIチェック（JS評価）

`mcp__playwright__browser_evaluate` で以下を実行:

```javascript
(() => {
  const formIssues = Array.from(document.querySelectorAll('input,select,textarea')).map(el => {
    const id = el.id;
    const hasLabel = id ? !!document.querySelector(`label[for="${id}"]`) : false;
    const hasAriaLabel = !!el.getAttribute('aria-label') || !!el.getAttribute('aria-labelledby');
    const hasPlaceholder = !!el.placeholder;
    return {
      tag: el.tagName, type: el.type, id,
      labeled: hasLabel || hasAriaLabel,
      placeholderOnly: !hasLabel && !hasAriaLabel && hasPlaceholder
    };
  }).filter(el => !el.labeled);
  const smallTargets = Array.from(document.querySelectorAll('a,button,[role="button"],input,select,textarea'))
    .filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && (rect.width < 44 || rect.height < 44);
    }).length;
  const genericLinks = Array.from(document.querySelectorAll('a')).filter(a => {
    const text = (a.textContent || '').trim().toLowerCase();
    return ['click here', 'here', 'more', 'read more', 'こちら', '詳細'].includes(text)
      && !a.getAttribute('aria-label');
  }).length;
  const highZIndex = Array.from(document.querySelectorAll('*')).filter(el => {
    const z = parseInt(getComputedStyle(el).zIndex);
    return z > 9999;
  }).length;
  return { formIssues, smallTouchTargets: smallTargets, genericLinks, highZIndex };
})()
```

## Step 3: 分析

収集した全データを7カテゴリで分析し、各項目に **Critical / Warning / Info** の優先度を付ける。

詳細な分析基準は [references/analysis-checklist.md](references/analysis-checklist.md) を参照。

| カテゴリ | 主なデータソース |
|---|---|
| Performance | タイミング, リソース集計, 画像 |
| Network | ネットワークリクエスト, リソース集計 |
| Accessibility | スナップショット, フォーム/ラベル, 画像alt |
| Console Errors | コンソールメッセージ |
| UI/UX | スクリーンショット, タッチターゲット, z-index |
| SEO | メタ情報, 見出し構造, OGタグ |
| Security | ネットワーク(mixed content), コンソール(CSP) |

## Step 4: レポート生成

[references/report-template.md](references/report-template.md) のテンプレートに従ってマークダウンレポートを生成する。

出力先: ユーザーの作業ディレクトリに `page-analysis-report.md` として保存する。ユーザーが別パスを指定した場合はそちらに従う。

### 優先度の定義

- **Critical**: 即座に対応すべき。UXやパフォーマンスに重大な影響
- **Warning**: 対応推奨。放置するとユーザー体験や保守性が劣化
- **Info**: 改善の余地あり。ベストプラクティスに沿った提案

## レスポンシブチェック（オプション）

ユーザーが要求した場合、`mcp__playwright__browser_resize` でビューポートを変更し、モバイル（375x667）とタブレット（768x1024）での表示も分析する。デフォルトはデスクトップのみ。

## 注意事項

- 認証が必要なページは先にユーザーにログイン操作を依頼する
- localhost も分析可能
- SPA/CSRでは十分な待機時間を取る
- 収集データが大きい場合は要約してレポートに含める
