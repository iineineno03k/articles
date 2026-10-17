#!/bin/bash
# set-publish-date.sh — 記事を予約公開にする（published: true と published_at を設定）
# Usage: set-publish-date.sh <slug> [YYYY-MM-DD HH:MM]
# 第2引数省略時は「次の平日朝8:00（JST）」。macOS（BSD date）とLinux（GNU date）の両方で動く。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${1:?Usage: set-publish-date.sh <slug> [YYYY-MM-DD HH:MM]}"
ARTICLE="${REPO_ROOT}/articles/${SLUG}.md"
export TZ="${TZ:-Asia/Tokyo}"

if [[ ! -f "$ARTICLE" ]]; then
  echo "Error: $ARTICLE not found" >&2
  exit 1
fi

# n日後の日付（書式指定つき）
plus_days() {
  date -v+"$1"d +"$2" 2>/dev/null || date -d "+$1 day" +"$2"
}

if [[ -n "${2:-}" ]]; then
  PUBLISH_DATE="$2"
else
  case "$(plus_days 1 %u)" in  # 明日の曜日 1=Mon ... 7=Sun
    6) PUBLISH_DATE="$(plus_days 3 %Y-%m-%d) 08:00" ;;  # 明日が土曜 → 月曜
    7) PUBLISH_DATE="$(plus_days 2 %Y-%m-%d) 08:00" ;;  # 明日が日曜 → 月曜
    *) PUBLISH_DATE="$(plus_days 1 %Y-%m-%d) 08:00" ;;
  esac
fi

# frontmatterを書き換える（sed -i の方言差を避けて awk で一時ファイルへ出す）
tmp="$(mktemp)"
awk -v d="$PUBLISH_DATE" '
  /^---$/ { fm++ }
  fm == 1 && /^published_at:/ { next }
  fm == 1 && /^published:/ { print "published: true"; print "published_at: \"" d "\""; next }
  { print }
' "$ARTICLE" > "$tmp"
grep -q '^published_at:' "$tmp" || { rm -f "$tmp"; echo "Error: frontmatter に published: がない" >&2; exit 1; }
mv "$tmp" "$ARTICLE"

echo "Scheduled: ${SLUG} → ${PUBLISH_DATE}"
echo "  File: $ARTICLE"
