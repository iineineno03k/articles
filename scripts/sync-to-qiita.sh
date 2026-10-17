#!/bin/bash
# sync-to-qiita.sh - Zenn記事をQiita形式に変換してpublic/に配置
#
# Usage: sync-to-qiita.sh <slug>
# Example: sync-to-qiita.sh claude-code-automation
#
# articles/<slug>.md (Zenn形式) → public/<slug>.md (Qiita形式)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${1:?Usage: sync-to-qiita.sh <slug>}"

ZENN_FILE="${REPO_ROOT}/articles/${SLUG}.md"
QIITA_FILE="${REPO_ROOT}/public/${SLUG}.md"

if [[ ! -f "$ZENN_FILE" ]]; then
  echo "Error: ${ZENN_FILE} not found" >&2
  exit 1
fi

mkdir -p "${REPO_ROOT}/public"

# 既存ファイルからID/updated_atを保持（再投稿防止）
EXISTING_ID="null"
EXISTING_UPDATED_AT="''"
if [[ -f "$QIITA_FILE" ]]; then
  _id=$(awk '/^---$/{c++; next} c==1{print}' "$QIITA_FILE" | grep '^id:' | sed 's/^id: *//' || true)
  _ua=$(awk '/^---$/{c++; next} c==1{print}' "$QIITA_FILE" | grep '^updated_at:' | sed 's/^updated_at: *//' || true)
  [[ "$_id" != "null" && -n "$_id" ]] && EXISTING_ID="$_id"
  [[ -n "$_ua" && "$_ua" != "''" ]] && EXISTING_UPDATED_AT="$_ua"
fi

# フロントマター（1つ目---と2つ目---の間）を抽出
FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print}' "$ZENN_FILE")
# 2つ目の---以降が本文
BODY=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2){found=1; next}} found{print}' "$ZENN_FILE")

# Zenn用の画像パス /images/<slug>/<file> を、Qiitaで表示できるURLへ置き換える。置換はbashだけで行う（クラウドでも動かす）
# 1. 対応表 images/<slug>/qiita-urls.tsv（「ファイル名<TAB>URL」）があればそのURL（Qiitaへ手で上げた画像）
# 2. それ以外は、このリポジトリ（公開）の main にある画像の raw URL
RAW_BASE="${QIITA_IMAGE_BASE:-https://raw.githubusercontent.com/iineineno03k/articles/main/images}"
URL_MAP="${REPO_ROOT}/images/${SLUG}/qiita-urls.tsv"
if [[ -f "$URL_MAP" ]]; then
  while IFS=$'\t' read -r name url; do
    [[ -z "$name" || -z "$url" ]] && continue
    # URLはhttps://で始まるものだけ受け付ける（置換結果が再び置換対象になって止まらなくなるのも防ぐ）
    if [[ "$url" != https://* ]]; then
      echo "Error: ${URL_MAP} のURLが https:// で始まっていない: ${name}" >&2
      exit 1
    fi
    # ${var//pat/rep} はbash 3.2の引用の扱いと5.2の & 置換で結果が変わるため、前後を切り出してつなぐ
    pat="(/images/${SLUG}/${name})"
    while [[ "$BODY" == *"$pat"* ]]; do
      BODY="${BODY%%"$pat"*}(${url})${BODY#*"$pat"}"
    done
  done < "$URL_MAP"
fi
for img in "${REPO_ROOT}/images/${SLUG}"/*; do
  [[ -f "$img" ]] || continue
  name="$(basename "$img")"
  [[ "$name" == qiita-urls.tsv ]] && continue
  pat="(/images/${SLUG}/${name})"
  while [[ "$BODY" == *"$pat"* ]]; do
    BODY="${BODY%%"$pat"*}(${RAW_BASE}/${SLUG}/${name})${BODY#*"$pat"}"
  done
done
# 置き換え漏れがあればQiitaへ出さない（画像が表示されないまま公開されるのを防ぐ）
# インライン ](/images/…)、山括弧 (</images/…>)、HTML src="/images/…"、参照定義 [x]: /images/… を見る
LEFT_PATTERN='(\(<?|["'"'"']|\]: *)/images/'
if grep -Eq "$LEFT_PATTERN" <<< "$BODY"; then
  echo "Error: Qiitaで表示できない画像パスが残っている。images/${SLUG}/ に画像を置くか、記法を ![alt](/images/${SLUG}/file) にそろえる:" >&2
  grep -En "$LEFT_PATTERN" <<< "$BODY" | sed 's/^/  /' >&2
  exit 1
fi

# Zennフロントマターからフィールドを抽出
TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/^title: *//' | sed 's/^"//;s/"$//')
TOPICS=$(echo "$FRONTMATTER" | grep '^topics:' | sed 's/^topics: *//')
PUBLISHED=$(echo "$FRONTMATTER" | grep '^published:' | sed 's/^published: *//')
PUBLISHED_AT=$(echo "$FRONTMATTER" | grep '^published_at:' | sed 's/^published_at: *//' | sed 's/^"//;s/"$//' || true)

# topics配列 → Qiita tags形式に変換（Qiitaは最大5タグ、「初心者」を必ず含める）
TAG_LIST=()
if [[ -n "$TOPICS" ]]; then
  CLEANED=$(echo "$TOPICS" | tr -d '[]"' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    TAG_LIST+=("$tag")
  done <<< "$CLEANED"
fi

# 初心者タグを追加（5個制限を超える場合は先頭4個+初心者に切り詰め）
if [[ ${#TAG_LIST[@]} -ge 5 ]]; then
  TAG_LIST=("${TAG_LIST[@]:0:4}")
fi
TAG_LIST+=("初心者")

TAGS=""
for tag in "${TAG_LIST[@]}"; do
  TAGS="${TAGS}  - '${tag}'
"
done

# published → ignorePublish（反転）
# published_at がある場合は予約投稿なので、Qiita側は非公開を維持
# （scheduled-publish.sh が公開時に ignorePublish: false に書き換える）
if [[ -n "$PUBLISHED_AT" ]]; then
  IGNORE_PUBLISH="true"
elif [[ "$PUBLISHED" == "true" ]]; then
  # セーフガード: published: true なのに published_at がない → 即時公開の事故防止
  # 即時公開するには FORCE_PUBLISH_NOW=true を明示的に指定する必要がある
  if [[ "${FORCE_PUBLISH_NOW:-}" != "true" ]]; then
    echo "ERROR: published: true but published_at is not set." >&2
    echo "  予約公開: set-publish-date.sh $SLUG でpublished_atを設定してください" >&2
    echo "  即時公開: FORCE_PUBLISH_NOW=true bash $(basename "$0") $SLUG" >&2
    exit 1
  fi
  IGNORE_PUBLISH="false"
else
  IGNORE_PUBLISH="true"
fi

# Qiita形式で出力
cat > "$QIITA_FILE" << QIITA_EOF
---
title: '${TITLE}'
tags:
${TAGS}private: false
updated_at: ${EXISTING_UPDATED_AT}
id: ${EXISTING_ID}
organization_url_name: null
slide: false
ignorePublish: ${IGNORE_PUBLISH}
---
${BODY}
QIITA_EOF

echo "Synced: ${ZENN_FILE} → ${QIITA_FILE}"
echo ""
echo "Zenn:  published=${PUBLISHED}"
echo "Qiita: ignorePublish=${IGNORE_PUBLISH}"
