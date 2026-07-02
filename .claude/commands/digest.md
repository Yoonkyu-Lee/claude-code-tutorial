---
description: YouTube 영상을 digest(시간순 심층 paraphrase + 주제별 상세 요약)로 정리해 digests/<주제>/<채널>/에 저장한다. notes(분석 노트)와 별개 워크플로. 사용법&#58; /digest <URL> [--topic=..] [--channel=..]
---

# /digest — 영상 digest 생성 (paraphrase + 주제별 요약)

`$ARGUMENTS` 에서 YouTube URL과 선택 `--topic` / `--channel`을 읽는다.

digest는 `notes/`와 **별개 워크플로**다. 노트를 만들지 않아도 이 커맨드만으로 digest가 나온다. 산출 파일 구조 = **요약(주제별 상세) 먼저 → `---` → 전문(시간순 paraphrase)**. (배경: `digests/README.md`)

## Step 1: 주제·채널·파일명 결정
- `harness-study-note` 스킬 Step 0/2 규약을 그대로 쓴다. URL의 채널을 식별해 주제+채널을 정한다:
  - 채널이 이미 `notes/<주제>/<채널>/` 또는 `digests/<주제>/<채널>/`에 있으면 그 **주제를 재사용**.
  - 새 채널/주제면 사용자에게 확인(`--topic`/`--channel`로 주면 그대로 사용).
- 파일명: `YYYY-MM-DD-english-title.md` (게시일 기반, 스킬 Step 2 규약). **같은 영상의 노트가 이미 있으면 그 파일명을 재사용**해 노트↔digest 파일명을 일치시킨다.
- 저장 경로 = `digests/<주제>/<채널>/<파일명>`.

## Step 2: 자막 확보 (메인, 셸)
- yt-dlp Plan A → `awk -f scripts/vtt-to-text.awk` dedup → clean text 파일 (스킬 Step 3 경로). 실패 시 MCP 폴백.
- 게시일·조회수·길이 등 메타도 yt-dlp `--print`로 확보.

## Step 3: paraphrase + summary (격리 에이전트)
긴 자막 통독은 토큰이 크므로 **격리 에이전트 1개**에 맡겨 메인 컨텍스트를 보호한다. 그 에이전트에 다음을 지시:
1. `digest-from-transcript` 스킬(L1)로 clean text를 **시간순 심층 paraphrase**로 작성 → `digests/<주제>/<채널>/<파일명>` 저장.
2. 이어서 `summarize-digest` 스킬(L2)로 그 파일을 읽어 **주제별 상세 요약(기본 detailed)**을 파일 맨 위에 삽입.
- 전달 정보: clean text 파일 경로, 메타(원제·채널·게시일·조회수·길이·URL), 저장 경로.
- 규칙 상기: 제목=원제, 화자 주장/미검증·`[의견]`·`[불명확]` 유지, 타임스탬프 날조 금지.

## Step 4: 보고
- 저장 경로 + paraphrase 구간 수 + 요약 주제 수를 짧게 보고. digest 본문은 요약하지 않는다(파일 열면 됨).

## 여러 편 (선택)
- URL이 여러 개면 각 URL을 격리 에이전트로 병렬 처리(`/batch-notes`의 동시성 캡 3~5 준용). 한 편 실패가 나머지를 막지 않는다.

## Negative Space
- study-note를 만들지 않는다 (별개). notes/ 파일을 수정하지 않는다.
- digest 파일 하나에 요약+전문을 함께 둔다 (분리 파일 X).
