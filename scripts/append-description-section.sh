#!/usr/bin/env bash
# digest 파일 끝에 `## 영상 더보기란` 섹션을 붙인다 (설명란 원문을 구분별로 정리).
# Usage: scripts/append-description-section.sh --digest=<file.md> --desc=<file.desc>
#        scripts/append-description-section.sh --manifest=<tsv>   # digest<TAB>desc 목록 일괄
#
# 왜 스크립트인가: 이 작업의 대부분은 "설명란을 구분별로 옮겨 적기"라 결정적이다.
# LLM은 [불명확] 출처 교정처럼 판단이 필요한 곳에만 쓰는 게 맞다(파일럿 실측 편당 48k 토큰).
#
# 분류 규칙(줄 단위):
#   - `0:00 제목` / `00:00 제목`으로 시작        -> 챕터
#   - `1. 저자, "제목", 매체, 연도` 꼴의 번호 인용 -> 인용 출처
#   - http(s) URL 포함                          -> 링크 (홍보·제휴 링크도 버리지 않는다)
#   - 그 외 산문                                 -> 설명
# 이미 섹션이 있으면 건너뛴다(멱등).
set -euo pipefail

DIGEST=""; DESC=""; MANIFEST=""
for a in "$@"; do case "$a" in
  --digest=*)   DIGEST="${a#*=}";;
  --desc=*)     DESC="${a#*=}";;
  --manifest=*) MANIFEST="${a#*=}";;
  *) echo "unknown arg: $a" >&2; exit 2;;
esac; done

append_one() {
  local digest="$1" desc="$2"
  [ -f "$digest" ] || { echo "skip (no digest): $digest" >&2; return 0; }
  [ -s "$desc" ]   || { echo "skip (no desc): $digest" >&2; return 0; }
  if grep -q '^## 영상 더보기란' "$digest"; then
    echo "skip (already has section): $digest" >&2; return 0
  fi

  local tmp; tmp="$(mktemp)"
  awk '
    BEGIN { nc = 0; nl = 0; ns = 0; np = 0; no = 0; mode = "" }
    {
      line = $0
      sub(/\r$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") next
      sub(/^-[[:space:]]*/, "", line)          # 설명란의 선행 "- " 제거 (대시 중복 방지)
      if (line == "") next

      # 설명란이 스스로 붙인 구분 헤더를 인식해 이후 줄의 소속을 정한다.
      # 헤더 자체는 출력하지 않는다.
      if (line ~ /^(내용 ?출처|출처|참고 ?자료|References?|Sources?)[[:space:]]*:?$/) { mode = "src"; next }
      if (line ~ /^(BGM|Music|음악|BGM 출처)[[:space:]]*:?$/)                          { mode = "oth"; next }
      if (line ~ /^(Chapters?|챕터|타임라인|목차)[[:space:]]*:?$/)                      { mode = "chap"; next }

      # 타임스탬프 줄은 헤더가 없어도 챕터다.
      if (line ~ /^[0-9]{1,2}:[0-9]{2}([:][0-9]{2})?[[:space:]]/) { chap[++nc] = line; mode = "chap"; next }

      if (mode == "src")  { src[++ns]  = line; next }
      if (mode == "oth")  { oth[++no]  = line; next }
      if (mode == "chap") { chap[++nc] = line; next }

      if (line ~ /https?:\/\//) { link[++nl] = line; next }
      prose[++np] = line
    }
    END {
      print ""
      print "## 영상 더보기란"
      print ""
      print "아래는 영상 설명란 원문이며 화자 발언이 아니다. 링크는 홍보·제휴 여부와 무관하게 적힌 그대로 옮겼고, 내용을 확인하거나 평가하지 않았다."
      print ""
      if (np > 0) { print "### 설명";      for (i = 1; i <= np; i++) print "> " prose[i]; print "" }
      if (ns > 0) { print "### 인용 출처"; for (i = 1; i <= ns; i++) print "- " src[i];   print "" }
      if (nl > 0) { print "### 링크";      for (i = 1; i <= nl; i++) print "- " link[i];  print "" }
      if (nc > 0) { print "### 챕터";      for (i = 1; i <= nc; i++) print "- " chap[i];  print "" }
      if (no > 0) { print "### 기타";      for (i = 1; i <= no; i++) print "- " oth[i];   print "" }
    }
  ' "$desc" > "$tmp"

  cat "$tmp" >> "$digest"
  rm -f "$tmp"
  echo "ok: $digest"
}

if [ -n "$MANIFEST" ]; then
  [ -f "$MANIFEST" ] || { echo "no such manifest: $MANIFEST" >&2; exit 2; }
  n=0
  while IFS=$'\t' read -r d s; do
    [ -z "$d" ] && continue
    append_one "$d" "$s" >/dev/null && n=$((n+1))
  done < "$MANIFEST"
  echo "processed $n entries from $MANIFEST" >&2
else
  [ -n "$DIGEST" ] && [ -n "$DESC" ] || { echo "need --digest= and --desc= (or --manifest=)" >&2; exit 2; }
  append_one "$DIGEST" "$DESC"
fi
