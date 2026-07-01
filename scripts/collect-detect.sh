#!/usr/bin/env bash
# 추적 채널(notes/*/)의 신규 영상 감지 -> 윈도우 필터 -> notes/ dedup -> cap.
# stdout: 후보 URL(newest-first). stderr: 로그. .claude/collect-state = handle<TAB>channel_id 캐시.
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

SINCE="yesterday"; CAP=20; ONLY=""
for arg in "$@"; do case "$arg" in
  --since=*)    SINCE="${arg#*=}";;
  --cap=*)      CAP="${arg#*=}";;
  --channels=*) ONLY="${arg#*=}";;
  *) echo "unknown arg: $arg" >&2; exit 2;;
esac; done

TODAY="${COLLECT_TODAY:-$(date +%Y-%m-%d)}"
case "$SINCE" in
  yesterday)  FROM=$(date -d "yesterday" +%Y-%m-%d); TO="$FROM";;
  *d)         N="${SINCE%d}"; FROM=$(date -d "$N days ago" +%Y-%m-%d); TO="$TODAY";;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) FROM="$SINCE"; TO="$SINCE";;
  *) echo "bad --since: $SINCE" >&2; exit 2;;
esac
echo "window: $FROM..$TO  cap: $CAP" >&2

STATE=".claude/collect-state"; [ -f "$STATE" ] || : > "$STATE"

# 채널 열거
# 채널은 notes/<주제>/<채널>/ 2계층. 핸들만 있으면 resolve/RSS 가능(주제는 batch가 폴더 위치로 재도출).
if [ -n "$ONLY" ]; then IFS=',' read -ra HANDLES <<< "$ONLY"
else HANDLES=(); for d in notes/*/*/; do [ -d "$d" ] && HANDLES+=("$(basename "$d")"); done; fi

# NOTE: 임시 파일 변수명에 TMP/TEMP/TMPDIR 금지 — yt-dlp(PyInstaller)가 그 env를
# 임시 디렉터리로 오인해 "Could not create temporary directory!"로 부팅 실패한다.
ACCUM="$(mktemp)"; trap 'rm -f "$ACCUM"' EXIT
for h in "${HANDLES[@]}"; do
  cid=$(awk -F'\t' -v h="$h" '$1==h{print $2; exit}' "$STATE" 2>/dev/null || true)
  if [ -z "$cid" ]; then
    cid=$(yt-dlp --playlist-items 1 --print "%(channel_id)s" \
          "https://www.youtube.com/@${h}/videos" --no-update 2>/dev/null \
          | grep -E "^UC" | head -1 || true)
    if [ -z "$cid" ]; then echo "  [skip] $h: channel_id resolve 실패" >&2; continue; fi
    printf "%s\t%s\n" "$h" "$cid" >> "$STATE"
  fi
  feed=$(curl -s "https://www.youtube.com/feeds/videos.xml?channel_id=${cid}" || true)
  if [ -z "$feed" ]; then echo "  [skip] $h: RSS 접근 실패" >&2; continue; fi
  n_in=$(printf "%s" "$feed" | awk -f scripts/collect-window.awk -v from="$FROM" -v to="$TO" | wc -l | tr -d ' ')
  printf "%s" "$feed" | awk -f scripts/collect-window.awk -v from="$FROM" -v to="$TO" \
    | while IFS='|' read -r id d; do
        if grep -rqF "$id" notes/ 2>/dev/null; then continue; fi   # 이미 노트화 -> 제외
        printf "%s\t%s\n" "$d" "$id" >> "$ACCUM"
      done
  echo "  [$h] 윈도우 내 ${n_in}편 (중복 제외 후 후보는 아래 집계)" >&2
done

# 최신순 정렬 -> cap
sort -r "$ACCUM" | awk -v cap="$CAP" '
  { total++; if (NR<=cap) print "https://youtu.be/" $2 }
  END {
    if (total > cap) printf("  [warn] 후보 %d편 > cap %d -> 오래된 %d편 절단(최신 유지)\n", total, cap, total-cap) > "/dev/stderr"
    printf("  후보 총 %d편, 처리 %d편\n", total, (total<cap?total:cap)) > "/dev/stderr"
  }'
