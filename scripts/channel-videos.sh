#!/usr/bin/env bash
# 채널 영상을 UTF-8 TSV로 나열: id<TAB>YYYYMMDD<TAB>dur_s<TAB>title (최신순)
# Windows 콘솔 파이프가 한글을 깨므로 yt-dlp --print-to-file(직접 파일 기록)로 우회한다.
# Usage: scripts/channel-videos.sh <@handle | channel-url> --out=<file> [--limit=N] [--jobs=N]
#   --limit=N  최신 N편만 (기본: 전체). 대형 채널에서 필수 — 전체 열거는 편당 메타 조회라 매우 느리다.
#   --jobs=N   메타 조회 동시 실행 수 (기본 8). 1이면 순차.
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
TMPL="%(id)s	%(upload_date)s	%(duration)s	%(title)s"   # 구분자는 실제 TAB
i=0
while read -r id; do
  [ -z "$id" ] && continue
  i=$((i+1))
  ( yt-dlp --skip-download --print-to-file "$TMPL" "$PARTS/$(printf '%06d' "$i")" \
      "https://youtu.be/$id" --no-update >/dev/null 2>&1 || true ) &
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do wait -n; done
done < "$IDS"
wait

# flat-playlist 순서(최신순) 유지 — 파트 파일명이 그 순서다
: > "$OUT"
cat "$PARTS"/* >> "$OUT" 2>/dev/null || true

n=$(grep -c . "$OUT" 2>/dev/null || echo 0)
want=$(grep -c . "$IDS" 2>/dev/null || echo 0)
echo "listed $n/$want videos -> $OUT" >&2
[ "$n" -eq "$want" ] || echo "warn: $((want-n)) videos returned no metadata" >&2
