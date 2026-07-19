---
description: YouTube 영상을 digest(시간순 심층 paraphrase + 주제별 상세 요약)로 정리해 digests/<주제>/<채널>/에 저장한다. 단건·다중·채널 전체 모드. notes와 별개 워크플로. 사용법&#58; /digest <URL...> 또는 /digest --channel=@handle [--all]
---

# /digest — 영상 digest 생성 (단건·배치·채널)

digest는 `notes/`와 **별개 워크플로**다. 각 영상은 `digest-worker` 서브에이전트로 격리 처리한다(study-note↔`/batch-notes`의 digest판). 산출 파일 = **요약(주제별 상세) 먼저 → `---` → 전문(시간순 paraphrase)**. 배경: `digests/README.md`.

`$ARGUMENTS`에서 입력을 읽는다:
- URL 1개 이상 → 그 URL들
- `--channel=@handle` (+ `--all` 또는 `--since=..`) → 채널 열거
- `--topic=` / `--concurrency=` (기본 3, 최대 5)

## Step 1: 대상 영상 목록 확보
- **URL 모드**: 입력에서 YouTube URL 추출.
- **채널 모드**: 공용 열거 스크립트로 UTF-8 목록 확보 (Windows 콘솔이 한글 제목을 깨므로 반드시 이 경로):
  ```bash
  bash scripts/channel-videos.sh @handle --limit=50 --out="<scratch>/ch.tsv"   # id<TAB>YYYYMMDD<TAB>dur<TAB>title (최신순)
  ```
  `--all`이면 전체, `--since=..`면 그 창만 필터.
  **`--limit=N`을 기본으로 붙인다** — 스크립트는 영상 1편당 메타를 조회하므로 수백 편 채널에서 전체 열거는 몇 분씩 걸린다. "최근 N편" 요청이면 `--limit=N`이 정확히 그 일을 한다. 전체가 정말 필요할 때만 생략. (`--jobs=N`으로 동시 실행 수 조절, 기본 8)
- **열거에서 빠진 영상 처리**: 목록 편수가 `--limit`보다 적으면 `<out>.skipped`(`id<TAB>사유<TAB>원문`)를 확인한다.
  - `members-only` / `private` / `geo-blocked` / `age-restricted` / `removed` / `not-yet-public` / `unavailable` → **정상적인 접근 제한**. 자막을 못 받으니 digest 대상이 아니다. 재시도·우회 시도 금지, 쿠키 요구 금지. **최종 보고에 "제외 N편(사유별 개수)"로 한 줄 후보고만** 하고 나머지를 그대로 진행한다.
  - `other` / `no-error-output` → 원인 불명. 이때만 원문 메시지를 사용자에게 보여주고 판단을 구한다.
- **주제·채널 결정**: 채널이 이미 `notes/<주제>/<채널>/` 또는 `digests/<주제>/<채널>/`에 있으면 그 주제 재사용. 새 채널/주제면 사용자 확인(`--topic`으로 주면 사용).

## Step 2: 중복 제외 + 승인
- 각 영상 ID를 `digests/**/*.md`와 대조해 이미 digest된 영상은 제외 (`영상 링크`의 ID 또는 파일명).
- 남은 목록(번호 + 날짜 + 제목)과 개수를 사용자에게 보여주고 **진행 확인**. (대량 비용 방지 — 배치 진입 전 승인 필수. `/batch-notes`와 동일 가드.)

## Step 3: 메타 + 자막 prefetch (메인, 셸)
`digest-worker`는 셸이 없다. 메인이 승인된 영상들의 자막을 미리 받아 clean text 경로로 넘긴다.

**자막은 전용 스크립트로 일괄 처리한다** (직접 yt-dlp를 부르지 말 것 — 언어 코드 함정이 있다):
```bash
# 승인된 ID 목록을 파일로 (channel-videos.sh 출력 TSV를 그대로 줘도 된다 — 첫 칼럼만 읽는다)
bash scripts/fetch-transcripts.sh --ids="<scratch>/ids.txt" --outdir="<scratch>" --jobs=6
# 결과: <scratch>/<id>.txt (clean text, [mm:ss] 포함) — 이 경로를 worker에 넘긴다
```
- 언어 우선순위 기본값은 `ko.*,en.*`. **와일드카드가 핵심**이다 — YouTube는 같은 한국어 자동자막을 영상마다 `ko` 또는 `ko-ko`로 주는데 `--sub-langs ko`는 `ko-ko`를 못 잡아 **자막이 있는데도 조용히 누락**된다.
- 못 받은 영상은 `<outdir>/_skipped.tsv`(`id<TAB>사유<TAB>원문`)에 남는다. 사유 해석은 Step 1의 누락 처리 규칙과 같다 — `no-subs`·`members-only` 등 정상 사유는 **후보고 한 줄**, `other`·`no-error-output`만 사용자에게 판단을 구한다.
- 이미 `<id>.txt`가 있으면 건너뛴다. 실패분만 재시도하려면 같은 명령을 다시 돌리면 된다.

**설명란(더보기)도 함께 받는다** — 자막에 없는 출처가 여기 있다:
```bash
bash scripts/fetch-descriptions.sh --ids="<scratch>/ids.txt" --outdir="<scratch>/desc" --jobs=6
# 결과: <scratch>/desc/<id>.desc — 이 경로도 worker에 넘긴다
```
- **왜**: 유튜버가 인용 출처·기사 링크·챕터를 설명란에 적는다. 자막에서 "로이터 통신"이 "이트 기통신"으로 뭉개져도 설명란에는 Reuters URL이 그대로 있다. 자막만 쓰면 출처가 `[불명확]`으로 남는 자리에 답이 있는 경우가 많다(2026-07 alview 실측: `[불명확]` 줄의 33%가 출처 관련).
- **채널마다 형태가 다르다**: 번호 매긴 「내용 출처」 학술식 인용(softdragon), 기사 URL 직링크(alview), 챕터 타임스탬프(ColorScale).
- 설명란이 비어 있거나 못 받으면 `<outdir>/_desc_skipped.tsv`에 남는다. **설명란은 없어도 정상**이니 후보고만 하고 진행한다.

메타(게시일·원제·조회수)는 채널 모드면 Step 1의 `ch.tsv`에 이미 있으니 재사용한다. URL 모드에서 개별로 필요하면:
```bash
export PATH="$HOME/scoop/shims:$PATH"
# 원제(UTF-8)는 print-to-file로 (콘솔 파이프 우회 — 셸 리다이렉트는 한글을 깨뜨린다)
yt-dlp --skip-download --print-to-file "%(upload_date)s	%(view_count)s	%(duration)s	%(title)s" "<scratch>/<id>.meta" "https://youtu.be/<id>" --no-update
```

## Step 4: 배치 dispatch (격리 병렬)
- 승인 목록을 concurrency(기본 3, 최대 5)만큼 묶어 `digest-worker`를 **동시 호출**.
- 각 worker에 전달: URL + 주제 + 채널 + 게시일(확정) + 원제 + 조회수/길이 + 자막파일(clean text 경로) + **설명란 파일 경로**(있으면).
- 배치가 끝날 때까지 대기 → 짧게 보고 → 다음 배치. 한 편 실패가 나머지를 막지 않는다(격리).

## Step 5: 종합 보고
```
총 N편 처리: ✅ 성공 M / ⏭️ 중복 K / ⚠️ 실패 L
생성 파일: digests/<주제>/<채널>/...
검수 권장: [불명확] 다수 파일
```
digest 본문은 보고에서 요약하지 않는다(파일 열면 됨).

## Negative Space
- 사용자 승인 없이 Step 4 진입 금지 (대량 비용). — 무인 스케줄 경로는 별도(현재 없음).
- 서브에이전트 raw 산출물을 메인 컨텍스트로 끌어오지 않는다 (보고만).
- notes/를 수정하지 않는다. digest 파일 하나에 요약+전문을 함께 둔다.
- **한글 메타는 반드시 `--print-to-file`/스크립트 경유** (`--print` + 셸 리다이렉트는 한글을 깨뜨림).
