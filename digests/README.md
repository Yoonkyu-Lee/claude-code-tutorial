# digests/ — 영상 digest (notes와 별개 워크플로)

`digests/<주제>/<채널>/YYYY-MM-DD-title.md` — 영상 1편 = digest 1편. `notes/`와 **평행 트리**이며 파일명 규약도 같다(같은 영상이면 노트와 digest 파일명이 일치).

## notes vs digests (역할 구분)

| | `notes/` (study-note) | `digests/` (digest) |
|---|---|---|
| 성격 | 분석 재구성 (핵심개념·카탈로그·팁), 원문 보존·인용 | 영상 대체 정리글 |
| 구조 | 주제별 분석 섹션 | **요약 먼저(주제별 상세) → 아래 전문(시간순 paraphrase)** |
| 목적 | 패턴 추출·하네스 재료 | 영상 안 보고 내용 파악 |
| 만드는 법 | `harness-study-note` 스킬 / `/batch-notes` | `/digest` 커맨드 (digest-from-transcript → summarize-digest) |

두 워크플로는 독립이다. digest만 원하면 노트 없이 `/digest`로 바로 생성한다.
