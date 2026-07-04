#!/usr/bin/env bash
# 추적 채널(<tree>/<주제>/<채널>/)에서 "아직 처리 안 된 갭 + 신규"를 감지한다.
# 범위: 그 채널에서 이미 처리한 것 중 "가장 오래된 것(=시작점 앵커)"부터 지금까지.
#   - 앵커보다 이전 백카탈로그는 제외(내가 정한 시작점 이전은 대상 아님).
#   - 앵커~지금 사이의 미처리 = 중간 갭 + 마지막 이후 신규. (시간창 아님 — 현재 상태 기준 스캔)
# stdout: 후보 URL(newest-first, cap). stderr: 로그. <tree>=notes|digests.
# 제외: 이미 <tree>에 있는 ID + .claude/digest-skip.txt(자막 없음 등 처리 불가 확정).
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

CAP=20; ONLY=""; TREE="notes"
for arg in "$@"; do case "$arg" in
  --cap=*)      CAP="${arg#*=}";;
  --channels=*) ONLY="${arg#*=}";;
  --tree=*)     TREE="${arg#*=}";;
  *) echo "unknown arg: $arg" >&2; exit 2;;
esac; done
case "$TREE" in notes|digests) ;; *) echo "bad --tree: $TREE (notes|digests)" >&2; exit 2;; esac

STATE=".claude/collect-state"; [ -f "$STATE" ] || : > "$STATE"
REGISTRY=".claude/channel-handles.tsv"
SKIP=".claude/digest-skip.txt"

DONE="$(mktemp)"; ACC="$(mktemp)"; trap 'rm -f "$DONE" "$ACC"' EXIT

id_of() {  # 파일에서 첫 영상 ID 추출 (youtu.be/<id> 또는 watch?v=<id>)
  grep -hoE '(youtu\.be/|watch\?v=)[A-Za-z0-9_-]{11}' "$1" 2>/dev/null | grep -oE '[A-Za-z0-9_-]{11}$' | head -1
}

# 이미 처리된 ID 집합: <tree>의 링크 + skip 목록
{ grep -rhoE '(youtu\.be/|watch\?v=)[A-Za-z0-9_-]{11}' "$TREE"/ 2>/dev/null | grep -oE '[A-Za-z0-9_-]{11}$'
  [ -f "$SKIP" ] && grep -oE '[A-Za-z0-9_-]{11}' "$SKIP" 2>/dev/null; } | sort -u > "$DONE"
echo "이미 처리(또는 skip): $(wc -l < "$DONE")" >&2

# 채널 열거
if [ -n "$ONLY" ]; then IFS=',' read -ra HANDLES <<< "$ONLY"
else HANDLES=(); for d in "$TREE"/*/*/; do [ -d "$d" ] && HANDLES+=("$(basename "$d")"); done; fi

for h in "${HANDLES[@]}"; do
  chdir=$(ls -d "$TREE"/*/"$h"/ 2>/dev/null | head -1)
  [ -z "$chdir" ] && { echo "  [skip] $h: 폴더 없음" >&2; continue; }
  # 시작점 앵커 = 이 채널 처리분 중 가장 오래된 것(파일명 날짜 최소)의 영상 ID
  oldest=$(ls "$chdir"*.md 2>/dev/null | grep -v INDEX | sort | head -1)
  [ -z "$oldest" ] && { echo "  [skip] $h: 처리분 없음(앵커 불가)" >&2; continue; }
  boundary=$(id_of "$oldest")

  cid=$(awk -F'\t' -v h="$h" '$1==h{print $3; exit}' "$REGISTRY" 2>/dev/null || true)
  [ -n "$cid" ] || cid=$(awk -F'\t' -v h="$h" '$1==h{print $2; exit}' "$STATE" 2>/dev/null || true)
  if [ -z "$cid" ]; then
    cid=$(yt-dlp --playlist-items 1 --print "%(channel_id)s" "https://www.youtube.com/@${h}/videos" --no-update 2>/dev/null | grep -E "^UC" | head -1 || true)
    [ -z "$cid" ] && { echo "  [skip] $h: channel_id resolve 실패" >&2; continue; }
    printf "%s\t%s\n" "$h" "$cid" >> "$STATE"
  fi

  # flat-playlist newest-first를 훑되, 앵커에 닿으면 멈춤(그 이전은 범위 밖)
  scanned=0; new=0; hit=0
  while read -r id; do
    [ -z "$id" ] && continue
    scanned=$((scanned+1))
    [ "$id" = "$boundary" ] && { hit=1; break; }
    grep -qxF -e "$id" "$DONE" && continue    # 이미 처리/skip (-e: '-' 시작 ID 대응)
    echo "$id" >> "$ACC"; new=$((new+1))
  done < <(yt-dlp --flat-playlist --print "%(id)s" "https://www.youtube.com/channel/${cid}/videos" --no-update 2>/dev/null | grep -E '^[A-Za-z0-9_-]{11}$')
  warn=""; [ "$hit" = 0 ] && warn=" (경고: 앵커 미도달 — 앵커 영상이 내려갔을 수 있음)"
  echo "  [$h] 앵커 이후 스캔 ${scanned}편, 미처리 ${new}편${warn}" >&2
done

grand=$(wc -l < "$ACC")
head -n "$CAP" "$ACC" | sed 's#^#https://youtu.be/#'
[ "$grand" -gt "$CAP" ] && echo "  [warn] 미처리 ${grand}편 > cap ${CAP} -> ${CAP}편만(나머지는 다음 실행)" >&2
echo "  미처리 총 ${grand}편" >&2
