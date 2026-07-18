# Known Issues — 재발 문제 이력

이 파일은 `harness-study-note` 작업·`/batch-notes` 실행 중 **두 번 이상 재발한 문제**와 그 채택된 해결책을 누적한다. CLAUDE.md §9(자기 개선 루프)에 따라:

- **새 항목 추가**는 Claude가 자율적으로 제안만 한다 — 실제 추가는 사용자 승인 후
- **기존 항목의 해결책 교체**는 사용자 명시 결정이 있을 때만
- 각 항목 형식: 문제 / 빈도 / 원인 / 채택된 해결 / 날짜

---

## 1. 게시일 자동 추출 실패

- **문제**: YouTube 영상 게시일을 자동으로 못 뽑아서 노트 파일명이 작성일로 잠정 표기되고 본문 메타도 `[불명확]`으로 남는 사례 빈번
- **빈도**: 2026-05-20 batch 19편 중 17편 (≈ 89%)
- **원인**: 
  - `mcp__youtube-transcript__get_video_info`가 `publishDate`/`uploadDate` 필드를 반환하지 않음
  - `WebFetch`는 YouTube SPA 구조 때문에 정적 HTML에서 메타를 못 뽑음 (대부분 빈 결과)
  - `WebSearch`는 종종 무관한 결과 반환
- **채택된 해결**: `yt-dlp` CLI를 1차 fallback으로 사용
  - 명령: `yt-dlp --skip-download --print "%(upload_date)s|%(title)s|%(channel)s|%(duration)s" <URL>`
  - Windows: scoop으로 설치 (`scoop install yt-dlp`)
  - SKILL.md Step 1에 fallback 체인 명시: yt-dlp → WebSearch → 사용자 입력
  - `WebFetch`는 게시일 용도로는 쓰지 않기로 결정 (신뢰성 부족)
  - `r.jina.ai` 프록시는 검토 후 제외 (외부 서비스 의존 + 게시일만 보장 못 함)
- **날짜**: 2026-05-20 확정

## 2. 한국어 자동자막의 영문 고유명사 음차 오인식

- **문제**: 한국어 YouTube 자동자막이 영문 고유명사·기술 용어를 한글 음차로 잘못 잡아, 각 worker가 매번 컨텍스트로 정정하는 중복 작업 발생
- **빈도**: 자막 기반 노트 작성 worker 거의 전부 (≈ 100%)
- **원인**: YouTube 한국어 ASR이 외래어를 한글 발음 그대로 표기 (예: `오퍼스` ← `Opus`, `패스트 APA` ← `FastAPI`, `엠 씨 피` ← `MCP`)
- **채택된 해결**: `.claude/skills/harness-study-note/references/caption-corrections.md` 사전 작성
  - 7개 카테고리, 90+ 매핑 (Anthropic 생태계 / 도구 / 프레임워크 / 약어 / 동작 / 인물 / 발화)
  - SKILL.md Step 4에서 자막을 훑기 전에 이 파일을 먼저 읽도록 룰북 명시
  - 새 패턴 발견 시 사용자 명시 요청이 있을 때만 사전 보강 (자동 갱신 금지)
- **날짜**: 2026-05-20 확정

## 3. 자막 획득 경로 통합 (yt-dlp Plan A 승격)

- **문제**: 자막을 MCP로 1차 획득하면서, 메타데이터용으로 이미 쓰는 yt-dlp와 자막 원천이 이원화. MCP 서버 의존이 별도 실패점.
- **빈도**: 재발 문제라기보다 구조 개선 (2026-07-01 검증 기반 결정).
- **검증**: 같은 영상(`MJiQFNp-k10`)의 MCP 자막과 yt-dlp 자막 텍스트 품질이 동일 (동일 YouTube ASR, 음차 오류까지 동일). yt-dlp는 단어 단위 타임스탬프까지 제공.
- **채택된 해결**: yt-dlp 자막을 Plan A로, MCP를 Plan B/C 폴백으로 유지 (제거 아님 — yt-dlp 추출 fragility 대비). batch는 메인이 메타+자막 한 패스 prefetch → `scripts/vtt-to-text.awk`로 dedup → worker에 clean text 전달. yt-dlp 빈 결과/에러 시 세션당 1회 `yt-dlp -U` 후 재시도.
- **경고 신호(caveat)**: yt-dlp가 `No supported JavaScript runtime` / 90일+ 구버전 경고를 냄. YouTube 추출은 주기적으로 깨지므로 MCP 폴백 유지가 필수.
- **날짜**: 2026-07-01 확정
- **관련 스펙/계획**: `docs/superpowers/specs/2026-07-01-ytdlp-subtitle-plan-a-design.md`, `docs/superpowers/plans/2026-07-01-ytdlp-subtitle-plan-a.md`

## 4. 무인 자동 수집의 비용 통제 (승인 게이트 대체)

- **문제**: 완전 자동 수집은 인터랙티브 배치의 "승인 후 진입" 가드레일과 충돌. 승인 없이 폭주 비용 위험.
- **결정(2026-07-01)**: 가드레일을 제거하지 않고 **맥락별 분화**. 인터랙티브 `/batch-notes`는 승인 유지, 무인 수집은 구조적 4중 상한(시간창 기본 어제·하드캡 기본 20·ID중복 제외·동시성 3~5)으로 대체. 하드캡 절단은 최신 우선 + 로그(silent 금지).
- **후속(2026-07-02)**: notes 무인 수집(`/collect-new`)은 불필요로 폐기, 무인 자동화는 **digest 쪽 `/collect-digest`**(→ commit·push → 사이트 자동 갱신)로 이관. 동일 4중 상한 유지. 채널 슬러그≠핸들 문제는 커밋된 `.claude/channel-handles.tsv`(slug→@handle→channel_id)로 해결.
- **관련**: `docs/superpowers/specs/2026-07-01-collect-new-auto-collection-design.md`(원 설계, notes 대상), `.claude/commands/collect-digest.md`.
- **날짜**: 2026-07-01 확정

## 5. yt-dlp(PyInstaller)와 `TMP`/`TEMP` 셸 변수 충돌

- **문제**: 스크립트에서 임시파일 변수를 `TMP="$(mktemp)"`로 두면 yt-dlp가 `[PYI-xxxx:ERROR] Could not create temporary directory!`로 부팅 실패해 stdout이 빈다(감지·자막 전부 조용히 실패).
- **원인**: Git Bash는 Windows `TMP`/`TEMP`를 이미 **export**된 상태로 상속. 그 이름에 재대입하면 export 속성이 유지돼, PyInstaller 실행파일인 yt-dlp가 그 값(파일 경로)을 임시 디렉터리로 오인.
- **채택된 해결**: 셸 임시변수에 `TMP`/`TEMP`/`TMPDIR` 금지. 다른 이름 사용(예: `ACCUM`). `scripts/collect-detect.sh`에 인라인 경고 주석 있음.
- **부수 발견**: 이 환경 grep은 `-P`(PCRE)를 로케일 문제로 거부("supports only unibyte and UTF-8 locales") → 정확 매칭은 `awk -F'\t'`로.
- **날짜**: 2026-07-01 확정

## 6. yt-dlp 한글 출력이 Windows 콘솔에서 깨짐

- **문제**: `yt-dlp --print "%(title)s"`를 셸 리다이렉트(`> file`)로 받으면 한글 제목이 공백/물음표로 소실. 채널 영상 목록 열거 시 재발.
- **원인**: yt-dlp.exe가 stdout을 Windows 콘솔 코드페이지(cp949/cp1252)로 인코딩. 파이썬 stdout도 동일. `PYTHONUTF8=1`/`PYTHONIOENCODING=utf-8`로도 **안 고쳐짐**(콘솔 핸들 경유라).
- **채택된 해결**: yt-dlp가 **파일을 직접 UTF-8로 쓰게** 한다 — `--print-to-file <tmpl> <file>` (또는 `-J` JSON 덤프). 콘솔 파이프를 우회하면 한글 보존. 채널 열거는 `scripts/channel-videos.sh`(이 방식)로 통일. `/digest` 룰북에도 명시.
- **부수**: 파이썬으로 그 파일을 읽어 표시할 땐 `PYTHONIOENCODING=utf-8` 필요. temp 파일은 Git Bash `/tmp`가 아니라 scratchpad 절대경로로(파이썬-Windows 경로 불일치 회피).
- **날짜**: 2026-07-02 확정

## 7. 대형 채널 전체 열거가 타임아웃

- **문제**: `scripts/channel-videos.sh @handle --out=...`를 옵션 없이 부르면 수백 편 채널에서 5분 Bash 타임아웃을 넘겨 사실상 못 씀. (@softdragon "최근 50편" 요청 때 재발.)
- **원인**: 스크립트 2단계가 영상 1편당 `yt-dlp --skip-download`를 **순차** 호출. 편당 ~1초라도 200편이면 3분 이상. 게다가 "최근 N편"만 필요한데 전체를 조회하고 있었다.
- **채택된 해결**: 스크립트에 `--limit=N`(flat-playlist 단계에서 `--playlist-end`로 잘라 2단계 조회량 자체를 줄임) + `--jobs=N`(메타 조회 동시 실행, 기본 8) 추가. 동시 쓰기로 줄이 섞이지 않게 영상별 파트 파일로 받아 순서대로 병합 → 최신순 보존. `/digest` 룰북에도 `--limit` 기본 사용을 명시.
- **부수**: 일부 영상은 메타 조회가 실패할 수 있어(비공개/지역차단) 스크립트가 `listed n/want`와 누락 경고를 출력한다. 이번 실행에서도 50편 중 4편이 빠졌다.
- **날짜**: 2026-07-18 확정

## 8. digest-worker가 Layer 2 요약을 Write로 통째 재작성

- **문제**: `digest-worker`가 `summarize-digest`(Layer 2) 요약을 파일 맨 위에 삽입할 때, 긴 digest 전문을 컨텍스트에서 다시 출력해 `Write`로 전체 재작성. 3개 워커가 같은 문제를 보고.
- **원인**: 에이전트 `tools:` 목록에 `Edit`이 없었다. 삽입 한 번에 전문 재출력이 강제돼 토큰 낭비 + Layer 1 본문 변조 위험.
- **채택된 해결**: `.claude/agents/digest-worker.md`의 `tools:`에 `Edit` 추가, 워크플로 4단계에 "삽입은 Edit로" 명시.
- **날짜**: 2026-07-18 확정

---

## 새 항목 추가 절차

Claude가 새 재발 패턴을 발견했을 때:

1. 작업 종료 보고에 "재발 패턴 발견" 항목으로 보고
2. 해결법 후보 2~3개를 트레이드오프와 함께 제시 + 추천안 명시
3. 사용자가 채택안을 결정하면 그 결정으로 이 파일에 항목 추가
4. 관련 스킬·룰북도 함께 갱신 (역시 사용자 승인 후)

CLAUDE.md §9 4번 항: 사용자 결정을 자기 판단으로 뒤집지 않는다.
