#!/usr/bin/env bash
# 채널 전체 영상을 UTF-8 TSV로 나열: id<TAB>YYYY-MM-DD<TAB>dur_s<TAB>title
# Windows 콘솔 파이프가 한글을 깨므로 yt-dlp --print-to-file(직접 파일 기록)로 우회한다.
# Usage: scripts/channel-videos.sh <@handle | channel-url> --out=<file>
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

HANDLE=""; OUT=""
for a in "$@"; do case "$a" in
  --out=*) OUT="${a#*=}";;
  *) HANDLE="$a";;
esac; done
[ -n "$HANDLE" ] || { echo "need <@handle|url>" >&2; exit 2; }
[ -n "$OUT" ]    || { echo "need --out=file" >&2; exit 2; }

case "$HANDLE" in
  http*) URL="$HANDLE";;
  @*)    URL="https://www.youtube.com/${HANDLE}/videos";;
  *)     URL="https://www.youtube.com/@${HANDLE}/videos";;
esac

IDS="$(mktemp)"; trap 'rm -f "$IDS"' EXIT
# 1) flat-playlist로 전체 video id (ASCII, 안전)
yt-dlp --flat-playlist --print-to-file "%(id)s" "$IDS" "$URL" --no-update >/dev/null 2>&1 || true

# 2) 영상별 date/dur/title를 --print-to-file로 UTF-8 append (한글 title 보존)
: > "$OUT"
TMPL="%(id)s	%(upload_date)s	%(duration)s	%(title)s"   # 구분자는 실제 TAB
while read -r id; do
  [ -z "$id" ] && continue
  yt-dlp --skip-download --print-to-file "$TMPL" "$OUT" "https://youtu.be/$id" --no-update >/dev/null 2>&1 || true
done < "$IDS"

n=$(grep -c . "$OUT" 2>/dev/null || echo 0)
echo "listed $n videos -> $OUT" >&2
