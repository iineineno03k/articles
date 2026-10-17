#!/bin/bash
# scheduled-publish.sh — 予約投稿の定時公開ジョブ
# articles/ 内の published_at が現在時刻を過ぎた記事を検出し、
# Qiita変換 → git push で両プラットフォームに公開する。
# GitHub Actions（scheduled-publish.yml）から毎朝呼ばれる。手動実行も可。
# Usage: bash scripts/scheduled-publish.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

ARTICLES_DIR="${PROJECT_ROOT}/articles"
SYNC_SCRIPT="${PROJECT_ROOT}/scripts/sync-to-qiita.sh"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/scheduled-publish-$(date +%Y%m%d-%H%M%S).log"
NOW=$(date +%s)
# 時刻はJSTで解釈する（クラウドのランナーはUTC）。
export TZ="${TZ:-Asia/Tokyo}"
BSD_DATE=0
date -j +%s >/dev/null 2>&1 && BSD_DATE=1

mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== scheduled-publish.sh start: $(date) ====="

# --- Step 1: git pull で最新化 ---
echo ""
echo "--- Step 1: git pull ---"
git pull --rebase 2>&1 || {
  echo "⚠ git pull failed. Trying without rebase..." >&2
  git pull 2>&1 || true
}

# --- Step 1.5: Qiita記事の最新化 ---
echo ""
echo "--- Step 1.5: qiita pull ---"
# 投稿済み判定はQiita側のIDに頼る。取得できないまま進むと二重公開になり得るので止める。
npx qiita pull 2>&1 || {
  echo "✗ qiita pull failed. 投稿済み判定ができないため中止する" >&2
  exit 1
}

# --- Step 2: 公開対象の記事を検出 ---
echo ""
echo "--- Step 2: scan articles ---"

TARGETS=()

for f in "$ARTICLES_DIR"/*.md; do
  [[ ! -f "$f" ]] && continue

  # フロントマターを抽出
  PUBLISHED=$(awk '/^---$/{c++; next} c==1{print}' "$f" | grep '^published:' | sed 's/^published: *//' || true)
  PUBLISHED_AT=$(awk '/^---$/{c++; next} c==1{print}' "$f" | grep '^published_at:' | sed 's/^published_at: *//' | sed 's/^"//;s/"$//' || true)

  # published: true かつ published_at が設定されている記事のみ対象
  [[ "$PUBLISHED" != "true" ]] && continue
  [[ -z "$PUBLISHED_AT" ]] && continue

  # published_at を epoch に変換（macOSのBSD date / クラウドのGNU date）
  # BSDの date -j -f はフォーマットに無い秒を現在時刻から補完するため、
  # 秒を明示的に :00 に固定しないとレースコンディションが発生する
  if [[ "$BSD_DATE" == "1" ]]; then
    SCHEDULED_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "${PUBLISHED_AT}:00" +%s 2>/dev/null) || \
    SCHEDULED_EPOCH=$(date -j -f "%Y-%m-%d %H:%M" "$PUBLISHED_AT" +%s 2>/dev/null) || \
    SCHEDULED_EPOCH=$(date -j -f "%Y-%m-%d" "$PUBLISHED_AT" +%s 2>/dev/null) || SCHEDULED_EPOCH=""
  else
    SCHEDULED_EPOCH=$(date -d "$PUBLISHED_AT" +%s 2>/dev/null) || SCHEDULED_EPOCH=""
  fi
  if [[ -z "$SCHEDULED_EPOCH" ]]; then
    echo "⚠ Invalid published_at format in $(basename "$f"): $PUBLISHED_AT"
    continue
  fi

  if [[ "$SCHEDULED_EPOCH" -le "$NOW" ]]; then
    SLUG=$(basename "$f" .md)

    # 投稿済みチェック: public/<slug>.md に有効なidがあればスキップ
    QIITA_CHECK="${PROJECT_ROOT}/public/${SLUG}.md"
    if [[ -f "$QIITA_CHECK" ]]; then
      _qid=$(awk '/^---$/{c++; next} c==1{print}' "$QIITA_CHECK" | grep '^id:' | sed 's/^id: *//' || true)
      if [[ "$_qid" != "null" && -n "$_qid" ]]; then
        echo "  Already published: $SLUG (id: $_qid)"
        continue
      fi
    fi

    echo "✓ Ready to publish: $SLUG (scheduled: $PUBLISHED_AT)"
    TARGETS+=("$SLUG")
  else
    SLUG=$(basename "$f" .md)
    echo "  Skipping: $SLUG (scheduled: $PUBLISHED_AT, not yet)"
  fi
done

# --- Step 3: 該当記事がなければ終了 ---
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo ""
  echo "No articles ready to publish."
  echo "===== scheduled-publish.sh complete: $(date) ====="
  exit 0
fi

# --- Step 4: Qiita変換 + ignorePublish を false に ---
echo ""
echo "--- Step 3: sync to qiita ---"

for slug in "${TARGETS[@]}"; do
  # Zenn → Qiita 変換
  bash "$SYNC_SCRIPT" "$slug" 2>&1

  # Qiita側の ignorePublish を false に書き換え（公開する）
  QIITA_FILE="${PROJECT_ROOT}/public/${slug}.md"
  if [[ -f "$QIITA_FILE" ]]; then
    sed -i.bak 's/^ignorePublish: true/ignorePublish: false/' "$QIITA_FILE" && rm -f "${QIITA_FILE}.bak"
    echo "✓ Set ignorePublish: false for $slug"
  fi
done

# --- Step 4.5: 投稿した記事のpublished_atを削除（再投稿防止） ---
# scheduled-publish.sh は published_at がある記事のみ対象にするため、
# 投稿完了後に削除することで翌日以降の再検出を確実に防ぐ。
# これが最も重要な再投稿防止策。sync-to-qiita.sh のID保持だけでは
# qiita-cliがIDベースの別ファイル名で保存するため防げない。
echo ""
echo "--- Step 4.5: remove published_at from articles ---"
for slug in "${TARGETS[@]}"; do
  ARTICLE_FILE="${ARTICLES_DIR}/${slug}.md"
  if [[ -f "$ARTICLE_FILE" ]]; then
    sed -i.bak '/^published_at:/d' "$ARTICLE_FILE" && rm -f "${ARTICLE_FILE}.bak"
    echo "✓ Removed published_at from $slug (prevent re-publish)"
  fi
done

# --- Step 5: git push ---
echo ""
echo "--- Step 5: git push ---"

git add articles/ public/
git commit -m "publish: $(IFS=', '; echo "${TARGETS[*]}")" 2>&1 || {
  echo "⚠ Nothing to commit"
  exit 0
}
git push origin main 2>&1

echo ""
echo "===== scheduled-publish.sh complete: $(date) ====="
echo "Published ${#TARGETS[@]} article(s): ${TARGETS[*]}"
