# YouTube RSS(atom) -> "id|YYYY-MM-DD" for entries with from<=date<=to (ISO 문자열 비교).
# 채널레벨 <published>를 entry로 오인하지 않도록 RS="<entry>" + NR>1.
BEGIN { RS = "<entry>" }
NR > 1 {
  if (match($0, /<yt:videoId>([^<]+)/, a) && match($0, /<published>([^<]+)/, b)) {
    d = substr(b[1], 1, 10)
    if (d >= from && d <= to) print a[1] "|" d
  }
}
