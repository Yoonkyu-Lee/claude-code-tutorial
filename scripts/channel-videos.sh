#!/usr/bin/env bash
# 채널 영상을 UTF-8 TSV로 나열: id<TAB>YYYYMMDD<TAB>dur_s<TAB>title (최신순)
# Windows 콘솔 파이프가 한글을 깨므로 yt-dlp --print-to-file(직접 파일 기록)로 우회한다.
# Usage: scripts/channel-videos.sh <@handle | channel-url> --out=<file> [--limit=N] [--jobs=N]
#   --limit=N  최신 N편만 (기본: 전체). 대형 채널에서 필수 — 전체 열거는 편당 메타 조회라 매우 느리다.
#   --jobs=N   메타 조회 동시 실행 수 (기본 8). 1이면 순차.
# 메타를 못 받은 영상은 <out>.skipped에 `id<TAB>사유<TAB>원문`으로 남는다.
# 사유: members-only / private / geo-blocked / age-restricted / removed /
#       not-yet-public / unavailable / other / no-error-output
# 앞의 7개는 정상적인 접근 제한이라 후보고만 하면 된다. other·no-error-output만 조사 대상.
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

HANDLE=""; OUT=""; LIMIT=""; JOBS=8
for a in "$@"; do case "$a" in
  --out=*)   OUT="${a#*=}";;
  --limit=*) LIMIT="${a#*=}";;
  --jobs=*)  JOBS="${a#*=}";;
  *) HANDLE="$a";;
esac; done
[ -n "$HANDLE" ] || { echo "need <@handle|url>" >&2; exit 2; }
[ -n "$OUT" ]    || { echo "need --out=file" >&2; exit 2; }
case "$JOBS" in ''|*[!0-9]*) echo "--jobs must be a positive integer" >&2; exit 2;; esac
[ "$JOBS" -ge 1 ] || { echo "--jobs must be >= 1" >&2; exit 2; }
if [ -n "$LIMIT" ]; then
  case "$LIMIT" in ''|*[!0-9]*) echo "--limit must be a positive integer" >&2; exit 2;; esac
  [ "$LIMIT" -ge 1 ] || { echo "--limit must be >= 1" >&2; exit 2; }
fi

case "$HANDLE" in
  http*) URL="$HANDLE";;
  @*)    URL="https://www.youtube.com/${HANDLE}/videos";;
  *)     URL="https://www.youtube.com/@${HANDLE}/videos";;
esac

IDS="$(mktemp)"; PARTS="$(mktemp -d)"; trap 'rm -rf "$IDS" "$PARTS"' EXIT

# 1) flat-playlist로 video id 목록 (ASCII, 안전). --limit이면 최신 N편만 — 여기서 잘라야 2단계가 빨라진다.
FLAT_ARGS=(--flat-playlist --print-to-file "%(id)s" "$IDS" "$URL" --no-update)
[ -n "$LIMIT" ] && FLAT_ARGS=(--playlist-end "$LIMIT" "${FLAT_ARGS[@]}")
yt-dlp "${FLAT_ARGS[@]}" >/dev/null 2>&1 || true

# 2) 영상별 date/dur/title를 --print-to-file로 UTF-8 기록 (한글 title 보존)
#    동시 실행 시 같은 파일에 쓰면 줄이 섞일 수 있어 영상별 파일로 받고 마지막에 합친다.
#    메타를 못 받는 영상은 대부분 정상적인 접근 제한(멤버십/비공개/지역차단)이다.
#    stderr를 영상별로 받아 사유를 분류하고 <OUT>.skipped에 남긴다 — 호출 측은 후보고만 하면 된다.
TMPL="%(id)s	%(upload_date)s	%(duration)s	%(title)s"   # 구분자는 실제 TAB
i=0
while read -r id; do
  [ -z "$id" ] && continue
  i=$((i+1))
  n=$(printf '%06d' "$i")
  ( yt-dlp --skip-download --print-to-file "$TMPL" "$PARTS/$n" \
      "https://youtu.be/$id" --no-update >/dev/null 2>"$PARTS/$n.err" || true
    printf '%s' "$id" > "$PARTS/$n.id" ) &
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do wait -n; done
done < "$IDS"
wait

# flat-playlist 순서(최신순) 유지 — 파트 파일명이 그 순서다
: > "$OUT"
for p in "$PARTS"/[0-9]*[0-9]; do
  [ -s "$p" ] && cat "$p" >> "$OUT"
done

# 실패한 영상의 사유 분류. yt-dlp의 ERROR 줄만 본다(JS 런타임 WARNING 등은 무시).
: > "$OUT.skipped"
# 실패 시 yt-dlp가 파트 파일을 아예 안 만들기도 하므로, 항상 존재하는 .id를 기준으로 순회한다.
for idf in "$PARTS"/*.id; do
  p="${idf%.id}"
  [ -s "$p" ] && continue                      # 메타 확보됨
  id=$(cat "$idf" 2>/dev/null) || continue
  msg=$(grep -m1 '^ERROR:' "$p.err" 2>/dev/null || true)
  case "$msg" in
    *members-only*|*"channel's members"*|*"Join this channel"*) why=members-only;;
    *"Private video"*|*"private video"*)                        why=private;;
    *"not available in your country"*|*"blocked it in your country"*|*"geo restrict"*) why=geo-blocked;;
    *"Sign in to confirm your age"*|*"age-restricted"*|*"inappropriate for some users"*) why=age-restricted;;
    *"has been removed"*|*"account associated"*|*"terms of service"*|*"copyright claim"*) why=removed;;
    *"Premieres in"*|*"This live event will begin"*|*"live event has ended"*) why=not-yet-public;;
    *"Video unavailable"*)                                      why=unavailable;;
    "")                                                         why=no-error-output;;
    *)                                                          why=other;;
  esac
  printf '%s\t%s\t%s\n' "$id" "$why" "${msg#ERROR: }" >> "$OUT.skipped"
done

# grep -c는 0건일 때 "0"을 찍고 exit 1을 낸다. `|| echo 0`이면 0이 두 줄 나와 산술식이 깨진다.
nlines() { grep -c . "$1" 2>/dev/null || true; }
got=$(nlines "$OUT")
want=$(nlines "$IDS")
echo "listed $got/$want videos -> $OUT" >&2

if [ -s "$OUT.skipped" ]; then
  # 정상적인 접근 제한은 정보로만, 원인 불명(other/no-error-output)만 주의 표시
  echo "skipped $((want-got)) (see $OUT.skipped):" >&2
  cut -f2 "$OUT.skipped" | sort | uniq -c | sort -rn |
    while read -r c w; do echo "  - $w: $c" >&2; done
  odd=$(awk -F'\t' '$2=="other"||$2=="no-error-output"' "$OUT.skipped" | grep -c . || true)
  [ "${odd:-0}" -eq 0 ] || echo "  ! $odd 편은 사유 불명 — $OUT.skipped 확인" >&2
else
  rm -f "$OUT.skipped"
fi
