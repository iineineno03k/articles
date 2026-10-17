---
title: OpenAPI自動生成ファイルの日時問題とその解決方法
tags:
  - gradle
  - 初心者
  - AI
  - OpenAPI
  - OpenAPIGenerator
private: false
updated_at: '2025-07-25T17:51:06+09:00'
id: b308eeb1bcf38daf5e54
organization_url_name: null
slide: false
ignorePublish: false
---
## 背景

### 従来の問題

OpenAPI Generatorで自動生成されるJavaファイルを運用する際、以下のような問題が発生していました：

1. **自動生成ファイルの管理方法の悩み**
   - 従来は自動生成ファイルをbuild成果物として`.gitignore`対象にしていた
   - しかし、AIコーディング支援ツール（Claude Codeなど）が自動生成ファイルを読み込めない
   - 特にモデルクラスのインスタンス生成やAPI呼び出しコードは、AIに任せたい単純作業が多い

2. **Git管理下に置いた場合の問題**
   - 毎回のビルドで生成時刻が更新されてしまう
   - 実際にはAPIの仕様変更がないのに、差分として表示される
   - 不要なコミット履歴やコンフリクトが発生する

### 具体的な問題箇所

OpenAPI Generatorが生成するJavaファイルには、以下のような`@Generated`アノテーションが自動で付与されます：

```java
@jakarta.annotation.Generated(
    value = "org.openapitools.codegen.languages.JavaClientCodegen", 
    date = "2025-07-25T16:11:57.067211+09:00[Asia/Tokyo]", 
    comments = "Generator version: 7.11.0"
)
public class SomeApiModel {
    // クラス内容
}
```

この`date`パラメータが毎回のビルド時に現在時刻で更新されるため、ファイル内容に変更が発生してしまいます。

## 解決方法

### OpenAPI Generatorの設定変更

`hideGenerationTimestamp`オプションを`true`に設定することで、生成時刻の出力を抑制できます。

**修正箇所：** `buildSrc/src/main/groovy/buildlogic.openapi-generator-conventions.gradle`

```groovy
// 共通のGenerateTask設定を行うメソッド
def configureGenerateTask(GenerateTask task, Map config) {
    // デフォルト値を設定
    def defaults = [
        // ...existing code...
        configOptions: [
            dateLibrary           : "java8",
            documentationProvider : "springdoc",
            interfaceOnly         : "true",
            skipDefaultInterface  : "true",
            useSpringBoot3        : "true",
            useJakartaEe          : "true",
            generateBuilders      : "true",
            useSwaggerUI          : "false",
            useEnumCaseInsensitive: "true",
            hideGenerationTimestamp: "true",  // ← 追加
        ]
    ]
    // ...existing code...
}

// クライアント生成のためのヘルパーメソッド
ext.configureApiClient = { String name, String specPath, String apiNameSuffix = null ->
    tasks.register("generate${name.capitalize()}ApiClient", GenerateTask) { task ->
        configureGenerateTask(task, [
            // ...existing code...
            configOptions: [
                dateLibrary          : "java8",
                documentationProvider: "none",
                library              : "restclient",
                useJakartaEe         : "true",
                generateBuilders     : "true",
                generateClientAsBean : "true",
                implicitHeaders      : "true",
                hideGenerationTimestamp: "true"  // ← 追加
            ]
        ])
    }
}
```

### 修正結果

設定変更後、生成されるアノテーションは以下のようになります：

```java
// 修正前
@jakarta.annotation.Generated(
    value = "org.openapitools.codegen.languages.JavaClientCodegen", 
    date = "2025-07-25T16:11:57.067211+09:00[Asia/Tokyo]", 
    comments = "Generator version: 7.11.0"
)

// 修正後
@jakarta.annotation.Generated(
    value = "org.openapitools.codegen.languages.JavaClientCodegen", 
    comments = "Generator version: 7.11.0"
)
```

`date`パラメータが完全に除去されるため、ビルドの度にファイル内容が変更されることがなくなります。

## 効果

### 1. Git管理の最適化
- **実際の仕様変更時のみ**ファイルが更新される
- 不要な差分やコミット履歴が発生しない
- チーム開発でのコンフリクト減少

### 2. AI支援ツールとの連携改善
- 自動生成ファイルをGit管理下に置けるため、AIが内容を参照可能
- モデルクラスの使用方法やAPI呼び出しパターンをAIが学習
- 開発効率の向上

### 3. 運用の簡素化
- ビルドプロセスの安定化
- 開発者が生成ファイルの差分を気にする必要がない

## まとめ

OpenAPI Generatorの`hideGenerationTimestamp`オプションを活用することで、自動生成ファイルをGit管理下に置きつつ、不要な時刻差分を排除できます。これにより、AIコーディング支援の恩恵を受けながら、クリーンなGit履歴を維持することが可能になります。

特に大規模なAPIを扱うプロジェクトでは、この設定により開発体験が大幅に改善されるでしょう。

## 参考情報

- OpenAPI Generator公式ドキュメント: [Configuration Options](https://openapi-generator.tech/docs/generators/java/)
- 対象バージョン: OpenAPI Generator 7.11.0
- 適用プロジェクト: Gradle + Spring Boot 3 + Jakarta EE
