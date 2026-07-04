#!/usr/bin/env bash
# 각 채널 폴더(notes/<주제>/<채널>/, digests/<주제>/<채널>/)에 awesome-pages용 .pages를 만들어
# 네비를 최신순(날짜 내림차순)으로 정렬한다. 빌드 전(CI/로컬)에 실행. 새 채널도 자동 커버.
set -euo pipefail
cd "$(dirname "$0")/.."
n=0
for d in notes/*/*/ digests/*/*/; do
  [ -d "$d" ] || continue
  printf 'order: desc\nsort_type: natural\n' > "$d/.pages"
  n=$((n+1))
done
echo "wrote .pages to $n channel dirs" >&2
