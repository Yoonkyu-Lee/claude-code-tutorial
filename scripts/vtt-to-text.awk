# yt-dlp YouTube auto-sub VTT -> "[MM:SS] text" clean lines.
# 롤링 중복 라인 제거 + <time>/<c> 태그 제거. 라인 타임스탬프 보존.
# 사용: awk -f scripts/vtt-to-text.awk <input.vtt> > out.txt
/-->/ { ts = substr($1, 1, 8); next }                 # HH:MM:SS.mmm 중 HH:MM:SS 캡처
/^WEBVTT|^Kind:|^Language:|^$/ { next }
{
  line = $0
  gsub(/<[^>]*>/, "", line)                           # <00:00:00.840>, <c>, </c> 제거
  gsub(/&gt;/, ">", line); gsub(/&lt;/, "<", line)    # HTML 엔티티 복원 (화자 마커 >> 등)
  gsub(/&#39;/, "'", line); gsub(/&quot;/, "\"", line)
  gsub(/&amp;/, "\\&", line)                           # &amp;는 마지막에 (재치환 방지)
  gsub(/^[ \t]+|[ \t]+$/, "", line)                   # 트림
  if (line == "") next
  if (line == prev) next                              # 연속 중복(롤링 반복) 제거
  prev = line
  print "[" substr(ts, 4, 5) "] " line                # MM:SS
}
