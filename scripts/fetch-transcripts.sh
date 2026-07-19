#!/usr/bin/env bash
# 영상 ID 목록을 받아 자막을 clean text로 prefetch: <outdir>/<id>.txt
# Usage: scripts/fetch-transcripts.sh --ids=<file> --outdir=<dir> [--jobs=N] [--langs="ko.*,en.*"]
#   --ids=FILE     한 줄에 영상 ID 하나. TSV면 첫 칼럼(TAB 앞)만 읽는다 (channel-videos.sh 출력 직결).
#   --outdir=DIR   <id>.txt(clean text) + <id>.<lang>.vtt(원본)을 쓴다. 없으면 만든다.
#   --jobs=N       동시 실행 수 (기본 6). 1이면 순차.
#   --langs=CSV    자막 언어 우선순위 (기본 "ko.*,en.*"). 앞에서부터 시도해 처음 잡히는 것을 쓴다.
#
# 언어 코드에 반드시 와일드카드를 쓸 것. YouTube는 같은 한국어 자동자막을 채널·영상마다
# `ko` 또는 `ko-ko`(Korean from Korean)로 준다. `--sub-langs ko`는 `ko-ko`를 안 잡아
# 자막이 있는데도 조용히 누락된다. `ko.*`는 둘 다 잡는다.
#
# 못 받은 영상은 <outdir>/_skipped.tsv에 `id<TAB>사유<TAB>원문`으로 남는다.
# 사유: no-subs(자막 자체가 없음) / members-only / private / geo-blocked / age-restricted /
#       removed / not-yet-public / unavailable / empty-transcript / other / no-error-output
# 앞의 8개는 정상적인 사유라 후보고만 하면 된다. other·no-error-output만 조사 대상.
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

IDS=""; OUTDIR=""; JOBS=6; LANGS="ko.*,en.*"
for a in "$@"; do case "$a" in
  --ids=*)    IDS="${a#*=}";;
  --outdir=*) OUTDIR="${a#*=}";;
  --jobs=*)   JOBS="${a#*=}";;
  --langs=*)  LANGS="${a#*=}";;
  *) echo "unknown arg: $a" >&2; exit 2;;
esac; done
[ -n "$IDS" ]    || { echo "need --ids=file" >&2; exit 2; }
[ -n "$OUTDIR" ] || { echo "need --outdir=dir" >&2; exit 2; }
[ -f "$IDS" ]    || { echo "no such file: $IDS" >&2; exit 2; }
case "$JOBS" in ''|*[!0-9]*) echo "--jobs must be a positive integer" >&2; exit 2;; esac
[ "$JOBS" -ge 1 ] || { echo "--jobs must be >= 1" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWK="$HERE/vtt-to-text.awk"
[ -f "$AWK" ] || { echo "missing $AWK" >&2; exit 2; }

mkdir -p "$OUTDIR"
ERRDIR="$(mktemp -d)"; trap 'rm -rf "$ERRDIR"' EXIT

fetch_one() {
  id="$1"
  # 이미 받아둔 게 있으면 건너뛴다 (재실행 시 낭비 방지)
  [ -s "$OUTDIR/$id.txt" ] && return 0

  IFS=',' read -ra langlist <<< "$LANGS"
  for lang in "${langlist[@]}"; do
    yt-dlp --skip-download --write-auto-subs --sub-langs "$lang" --sub-format vtt \
      -o "$OUTDIR/$id.%(ext)s" "https://youtu.be/$id" --no-update \
      >/dev/null 2>"$ERRDIR/$id.err" || true
    # 요청 코드와 실제 파일명이 다를 수 있고(ko 요청 -> ko-ko 수신), 한 번에 여러 변형이
    # 떨어지기도 한다(ko / ko-orig / ko-ko). 알파벳순 첫 파일을 집으면 번역본을 고를 수 있어
    # 선호 순서를 명시한다: 정확한 코드 > 원본 오디오(-orig) > 동일 언어 ASR(base-base) > 나머지.
    base="${lang%%.*}"                      # "ko.*" -> "ko"
    vtt=""
    for cand in "$OUTDIR/$id.$base.vtt" "$OUTDIR/$id.$base-orig.vtt" "$OUTDIR/$id.$base-$base.vtt"; do
      [ -s "$cand" ] && { vtt="$cand"; break; }
    done
    [ -n "$vtt" ] || vtt=$(ls "$OUTDIR/$id.$base"*.vtt 2>/dev/null | head -1 || true)
    [ -n "$vtt" ] && break
  done

  [ -n "${vtt:-}" ] || return 1
  awk -f "$AWK" "$vtt" > "$OUTDIR/$id.txt"
  [ -s "$OUTDIR/$id.txt" ] || { rm -f "$OUTDIR/$id.txt"; return 1; }
  return 0
}

while read -r line; do
  id="${line%%	*}"                       # TSV면 첫 칼럼만 (구분자는 실제 TAB)
  [ -z "$id" ] && continue
  fetch_one "$id" &
  # `wait -n`은 끝난 작업의 종료코드를 그대로 반환한다. 자막이 없는 영상에서
  # fetch_one이 1을 내면 set -e가 그걸 잡아 스크립트 전체를 죽인다 → || true 필수.
  # (지금까지는 전건 성공이라 안 터졌을 뿐, 잠복 버그였다.)
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do wait -n || true; done
done < "$IDS"
wait || true

# 실패 분류
SKIP="$OUTDIR/_skipped.tsv"
: > "$SKIP"
while read -r line; do
  id="${line%%	*}"
  [ -z "$id" ] && continue
  [ -s "$OUTDIR/$id.txt" ] && continue
  msg=$(grep -m1 '^ERROR:' "$ERRDIR/$id.err" 2>/dev/null || true)
  case "$msg" in
    *members-only*|*"channel's members"*|*"Join this channel"*) why=members-only;;
    *"Private video"*|*"private video"*)                        why=private;;
    *"not available in your country"*|*"blocked it in your country"*|*"geo restrict"*) why=geo-blocked;;
    *"Sign in to confirm your age"*|*"age-restricted"*|*"inappropriate for some users"*) why=age-restricted;;
    *"has been removed"*|*"account associated"*|*"terms of service"*|*"copyright claim"*) why=removed;;
    *"Premieres in"*|*"This live event will begin"*|*"live event has ended"*) why=not-yet-public;;
    *"Video unavailable"*)                                      why=unavailable;;
    "") # 에러가 없는데 txt가 없다 = 자막 트랙 자체가 없거나 변환 결과가 비었다
        if ls "$OUTDIR/$id".*.vtt >/dev/null 2>&1; then why=empty-transcript; else why=no-subs; fi;;
    *)  why=other;;
  esac
  printf '%s\t%s\t%s\n' "$id" "$why" "${msg#ERROR: }" >> "$SKIP"
done < "$IDS"

# grep -c는 0건일 때 "0"을 찍고 exit 1을 낸다. `|| echo 0`을 붙이면 0이 두 줄 나와
# 산술식이 깨진다. `|| true`로 종료코드만 삼킬 것.
nlines() { grep -c . "$1" 2>/dev/null || true; }
want=$(nlines "$IDS")
got=$((want - $(nlines "$SKIP")))
echo "transcripts $got/$want -> $OUTDIR" >&2

if [ -s "$SKIP" ]; then
  echo "skipped $((want-got)) (see $SKIP):" >&2
  cut -f2 "$SKIP" | sort | uniq -c | sort -rn |
    while read -r c w; do echo "  - $w: $c" >&2; done
  odd=$(awk -F'\t' '$2=="other"||$2=="no-error-output"' "$SKIP" | grep -c . || true)
  [ "${odd:-0}" -eq 0 ] || echo "  ! $odd 편은 사유 불명 — $SKIP 확인" >&2
else
  rm -f "$SKIP"
fi
