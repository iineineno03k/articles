# articles

[Zenn](https://zenn.dev/iineineno03k) と [Qiita](https://qiita.com/iineineno03k) に公開している技術記事の置き場。公開済みと公開予約済みの記事だけを置く。

| ディレクトリ | 中身 |
|---|---|
| `articles/` | Zenn形式の記事（ZennのGitHub連携で公開） |
| `images/<slug>/` | 記事の画像。Qiita版はここの raw URL を参照する |
| `public/` | Qiita形式の記事（Qiita CLIで公開） |
| `scripts/` | Qiita形式への変換・予約設定・予約公開 |

## 予約公開の流れ

1. `scripts/set-publish-date.sh <slug> [YYYY-MM-DD HH:MM]` で `published: true` と `published_at` を設定してmainへpush（既定は次の平日8:00 JST）
2. Zennは `published_at` の時刻に自分で公開する
3. 毎朝 `scheduled-publish.yml` が時刻を過ぎた記事をQiita形式へ変換（`/images/…` は raw URL へ置換、画像が欠けていれば止まる）してpushし、`publish.yml` がQiitaへ公開する

```bash
npm ci
npm run preview   # Zennのプレビュー
npm test          # スクリプトのテスト
```
