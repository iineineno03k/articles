---
title: Angular×Netlifyで404エラーを解決する`_redirects`の完全ガイド
tags:
  - 初心者
  - Angular
  - デプロイ
  - Netlify
private: false
updated_at: '2025-05-25T22:18:26+09:00'
id: ebeda1fcfa7c2b5191ee
organization_url_name: null
slide: false
ignorePublish: false
posting_campaign_uuid: null
agreed_posting_campaign_term: false
---
## はじめに

AngularアプリをNetlifyにデプロイした際、「404 Not Found」エラーに遭遇したことはありませんか？この記事では、その原因と解決方法である`_redirects`ファイルについて詳しく解説します。

## 問題の背景：SPAとルーティングの仕組み

### 従来のWebサイト（MPA）とSPAの違い

**従来のWebサイト（Multi-Page Application）**
```
example.com/home     → home.html（実際のファイル）
example.com/about    → about.html（実際のファイル）
example.com/contact  → contact.html（実際のファイル）
```

**SPA（Single Page Application）**
```
example.com/         → index.html（実際のファイル）
example.com/todos    → index.html（ファイルは存在しない）
example.com/profile → index.html（ファイルは存在しない）
```

AngularのようなSPAでは、実際には`index.html`という1つのファイルしか存在せず、JavaScriptがブラウザ内でルーティングを処理します。

## 404エラーが発生するケース

### 1. 直接URLアクセス
ユーザーが`https://yourapp.netlify.app/todos`に直接アクセスした場合：

```
1. ブラウザ → Netlifyサーバー: "todos.htmlファイルをください"
2. Netlifyサーバー: "todos.htmlは存在しません" → 404エラー
```

### 2. ページリロード（F5キー）
現在`/todos`ページにいる状態でページをリロードした場合

### 3. ブックマークからのアクセス
保存されたURL（例：`/profile`）から直接アクセスする場合

## 解決方法：`_redirects`ファイルの設定

### 基本的な設定

プロジェクトの`public`ディレクトリに`_redirects`ファイルを作成します：

```
/*    /index.html   200
```

### ファイル構成例

```
frontend-angular/
├── public/
│   └── _redirects          # ← ここに配置
├── src/
│   ├── app/
│   └── index.html
├── angular.json
└── package.json
```

### angular.jsonでの自動コピー設定

`angular.json`の`assets`設定で、ビルド時に自動的に`_redirects`ファイルがコピーされるようになっています：

```json
{
  "assets": [
    {
      "glob": "**/*",
      "input": "public"
    }
  ]
}
```

## `_redirects`の詳細仕様

### 基本構文

```
[source] [destination] [status_code]
```

### パラメータ説明

- **`/*`**: すべてのパス（ワイルドカード）
- **`/index.html`**: リダイレクト先
- **`200`**: HTTPステータスコード

### なぜ200ステータスが重要か

**301/302リダイレクトの場合（❌ 間違い）**
```
/*    /index.html   301

# 動作：
1. ユーザーが /todos にアクセス
2. ブラウザのURLが / に変更される
3. Angularが正しいルートを認識できない
```

**200ステータスの場合（✅ 正解）**
```
/*    /index.html   200

# 動作：
1. ユーザーが /todos にアクセス
2. ブラウザのURLは /todos のまま
3. index.htmlの内容が返される
4. AngularがURLを見て正しいコンポーネントを表示
```

## 実装手順

### 1. `_redirects`ファイルの作成

```bash
# publicディレクトリに作成
echo "/*    /index.html   200" > public/_redirects
```

### 2. ビルドの実行

```bash
ng build
```

### 3. ビルド結果の確認

```bash
ls dist/your-app-name/browser/
# _redirects ファイルが含まれていることを確認
```

## 代替設定方法：netlify.toml

プロジェクトルートに`netlify.toml`ファイルを作成する方法もあります：

```toml
[build]
  publish = "dist/your-app-name/browser"
  command = "npm run build"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

## 高度な設定例

### API呼び出しの除外

```
# API呼び出しは除外
/api/*  https://your-backend-api.com/api/:splat  200

# その他はSPAルーティング
/*      /index.html                              200
```

### 特定のファイルタイプの除外

```
# 静的ファイルは除外
/*.js   /404.html  404
/*.css  /404.html  404
/*.png  /404.html  404

# その他はSPAルーティング
/*      /index.html  200
```

## 環境別API設定の最適化

### 環境設定ファイルの作成

**src/environments/environment.ts**
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api'
};
```

**src/environments/environment.prod.ts**
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://your-backend-api.com/api'
};
```

### サービスでの使用

```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class TodoService {
  private apiUrl = `${environment.apiUrl}/todos`;

  constructor(private http: HttpClient) { }

  getTodos() {
    return this.http.get(this.apiUrl);
  }
}
```

## トラブルシューティング

### よくある問題と解決方法

1. **`_redirects`ファイルが含まれない**
   - `public`ディレクトリに配置されているか確認
   - `angular.json`の`assets`設定を確認

2. **リダイレクトが効かない**
   - ファイル名が`_redirects`（アンダースコア）になっているか確認
   - 構文が正しいか確認（スペース区切り）

3. **無限リダイレクト**
   - ステータスコードが`200`になっているか確認

## まとめ

- AngularのようなSPAをNetlifyにデプロイする際は`_redirects`ファイルが必須
- `/*    /index.html   200`の設定で直接URLアクセスとページリロードの問題を解決
- `public`ディレクトリに配置することで、ビルド時に自動的に含まれる
- 環境変数を使用してAPI設定を適切に管理する

この設定により、ユーザーがどのURLからアクセスしても、正常にAngularアプリケーションが動作するようになります。

## 参考リンク

- [Netlify Redirects Documentation](https://docs.netlify.com/routing/redirects/)
- [Angular Deployment Guide](https://angular.io/guide/deployment) 
