#!/usr/bin/env bash
# 영상 ID 목록을 받아 설명란(더보기)을 받아온다: <outdir>/<id>.desc
# Usage: scripts/fetch-descriptions.sh --ids=<file> --outdir=<dir> [--jobs=N]
#   --ids=FILE     한 줄에 영상 ID 하나. TSV면 첫 칼럼(TAB 앞)만 읽는다.
#   --outdir=DIR   <id>.desc를 쓴다. 없으면 만든다.
#   --jobs=N       동시 실행 수 (기본 6).
#
# 왜 필요한가: 유튜버들이 인용 출처·기사 링크·챕터를 설명란에 적는다. 자막에는
# "로이터 통신"이 "이트 기통신"으로 뭉개져도 설명란에는 Reuters URL이 그대로 있다.
# 자막만 보면 출처가 [불명확]으로 남는 자리가 설명란에는 답이 있는 경우가 많다.
#
# 주의: 설명란은 **화자 발언이 아니다**. digest 본문(paraphrase)에 섞지 말고
# 별도 섹션으로 분리하고 출처가 설명란임을 명시할 것. BGM 크레딧·연락처·
# 자기 홍보 링크는 노이즈이므로 걸러낼 것.
#
# 못 받은 영상은 <outdir>/_desc_skipped.tsv에 `id<TAB>사유<TAB>원문`으로 남는다.
# 사유 분류는 fetch-transcripts.sh와 동일 체계(empty-description 추가).
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

IDS=""; OUTDIR=""; JOBS=4; DELAY=0
for a in "$@"; do case "$a" in
  --ids=*)    IDS="${a#*=}";;
  --outdir=*) OUTDIR="${a#*=}";;
  --jobs=*)   JOBS="${a#*=}";;
  --delay=*)  DELAY="${a#*=}";;
  *) echo "unknown arg: $a" >&2; exit 2;;
esac; done
[ -n "$IDS" ]    || { echo "need --ids=file" >&2; exit 2; }
[ -n "$OUTDIR" ] || { echo "need --outdir=dir" >&2; exit 2; }
[ -f "$IDS" ]    || { echo "no such file: $IDS" >&2; exit 2; }
case "$JOBS" in ''|*[!0-9]*) echo "--jobs must be a positive integer" >&2; exit 2;; esac
[ "$JOBS" -ge 1 ] || { echo "--jobs must be >= 1" >&2; exit 2; }

mkdir -p "$OUTDIR"
ERRDIR="$(mktemp -d)"; trap 'rm -rf "$ERRDIR"' EXIT

fetch_one() {
  id="$1"
  [ -s "$OUTDIR/$id.desc" ] && return 0     # 이미 받아둔 건 건너뛴다
  # 한글 보존을 위해 반드시 --print-to-file (셸 리다이렉트는 콘솔 코드페이지를 타서 깨진다)
  yt-dlp --skip-download --print-to-file "%(description)s" "$OUTDIR/$id.desc" \
    "https://youtu.be/$id" --no-update >/dev/null 2>"$ERRDIR/$id.err" || true
  [ -s "$OUTDIR/$id.desc" ]
}

while read -r line; do
  id="${line%%	*}"                          # TSV면 첫 칼럼만 (구분자는 실제 TAB)
  [ -z "$id" ] && continue
  fetch_one "$id" &
  # `wait -n`은 끝난 작업의 종료코드를 그대로 반환한다. 설명란이 빈 영상에서
  # fetch_one이 1을 내면 set -e가 그걸 잡아 스크립트 전체를 죽인다 → || true 필수.
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do wait -n || true; done
  [ "$DELAY" = "0" ] || sleep "$DELAY"
done < "$IDS"
wait || true

SKIP="$OUTDIR/_desc_skipped.tsv"
: > "$SKIP"
while read -r line; do
  id="${line%%	*}"
  [ -z "$id" ] && continue
  [ -s "$OUTDIR/$id.desc" ] && continue
  msg=$(grep -m1 '^ERROR:' "$ERRDIR/$id.err" 2>/dev/null || true)
  case "$msg" in
    *members-only*|*"channel's members"*|*"Join this channel"*) why=members-only;;
    *"Private video"*|*"private video"*)                        why=private;;
    *"not available in your country"*|*"blocked it in your country"*|*"geo restrict"*) why=geo-blocked;;
    *"Sign in to confirm your age"*|*"age-restricted"*)          why=age-restricted;;
    *"has been removed"*|*"account associated"*|*"terms of service"*) why=removed;;
    *"Video unavailable"*)                                      why=unavailable;;
    # 429 / 봇 확인 요구 = 레이트 리밋. 영상 문제가 아니라 우리가 너무 빨리 긁은 것이다.
    # 쿨다운 후 --jobs 낮추고 --delay 주고 재실행하면 회수된다 (기존 파일은 건너뛴다).
    *"Too Many Requests"*|*"HTTP Error 429"*|*"not a bot"*|*"Sign in to confirm"*) why=rate-limited;;
    "")                                                         why=empty-description;;
    *)                                                          why=other;;
  esac
  printf '%s\t%s\t%s\n' "$id" "$why" "${msg#ERROR: }" >> "$SKIP"
done < "$IDS"

nlines() { grep -c . "$1" 2>/dev/null || true; }
want=$(nlines "$IDS")
got=$((want - $(nlines "$SKIP")))
echo "descriptions $got/$want -> $OUTDIR" >&2

if [ -s "$SKIP" ]; then
  echo "skipped $((want-got)) (see $SKIP):" >&2
  cut -f2 "$SKIP" | sort | uniq -c | sort -rn |
    while read -r c w; do echo "  - $w: $c" >&2; done
else
  rm -f "$SKIP"
fi
