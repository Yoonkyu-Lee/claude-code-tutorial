# P1 설계: yt-dlp 자막을 Plan A로 (MCP는 Plan B 폴백)

- **날짜**: 2026-07-01
- **상태**: 설계 승인됨 (구현 대기)
- **범위**: 전체 로드맵(P1~P4) 중 **P1만**. P2(자동 수집)·P3(digest 레이어)·P4(주제 최신 메타)는 별도 스펙.
- **원칙 준수**: 원문 보존·의견/사실 분리·`[불명확]`·정정 사전 로직은 **일절 변경 없음**. 이 작업은 자막 *획득 경로*만 바꾼다. 대체가 아니라 우선순위 재배치 + 폴백 유지.

---

## 1. 배경 · 문제

study-note 파이프라인은 자막을 `youtube-transcript` MCP로 1차 획득한다(`get_timed_transcript` → `get_transcript`). 그런데:

- 리포는 이미 **메타데이터(게시일·제목·채널)를 yt-dlp로** 뽑는다 (`known-issues.md` §1). 즉 yt-dlp는 이미 필수 의존이다.
- 2026-07-01 검증: 같은 영상(`MJiQFNp-k10`)을 MCP와 yt-dlp 둘 다로 받아 비교한 결과 **자막 텍스트 품질이 동일**하다. 둘 다 YouTube ko 자동자막(ASR)을 원천으로 하며, 음차 오류(`오퍼스`, `보시는이`)까지 같다.
- yt-dlp는 **단어 단위 타임스탬프**까지 제공 → 우리 `[mm:ss]` 인용 규칙에 유리.
- MCP는 별도 서버 의존이고 메타데이터(`publishDate`)를 안 준다.

품질이 같고 yt-dlp를 이미 쓰고 있으므로, **자막 1차를 MCP로 둘 이유가 없다.** yt-dlp를 Plan A로 승격하고 메타+자막을 한 패스로 통합한다.

### 왜 MCP를 제거하지 않고 폴백으로 남기나

검증 중 yt-dlp가 다음 경고를 냈다:

```
Your yt-dlp version is older than 90 days
No supported JavaScript runtime could be found
YouTube extraction without a JS runtime has been deprecated, some formats may be missing
```

yt-dlp ↔ YouTube는 주기적으로 깨지는 arms race다. yt-dlp를 유일 경로로 삼으면 추출이 깨지는 날 파이프라인 전체가 죽는다. 따라서 **MCP를 진짜 폴백으로 유지**해 회복력을 확보한다. 순서만 뒤집고 두 경로는 모두 남긴다.

---

## 2. 목표 · 비목표

**목표**
1. 자막 획득 우선순위를 `yt-dlp(A) → MCP(B) → MCP(C) → 실패보고`로 재배치.
2. batch 모드에서 메인이 메타+자막을 **한 yt-dlp 패스로 prefetch**, 셸에서 dedup까지 끝내 worker에 clean text 파일을 넘김 (worker의 자막 획득·dedup 비용 0).
3. yt-dlp 추출 실패/빈 결과 시 **자동 업데이트 1회 시도 후 재시도**, 그래도 실패하면 MCP로 폴백.

**비목표**
- 자막 *텍스트 처리* 로직 변경 (정정 사전 Step 4, 인용 규칙 등) — 그대로.
- P2/P3/P4.
- `CLAUDE.md` 본문 규칙 변경. (파일은 필요 시 "환경 셋업" 수준의 짧은 언급만, 규칙 자체는 불변.)

---

## 3. 설계

### 3.1 자막 획득 체인 (SKILL.md Step 3 개정)

```
1. [Plan A] yt-dlp auto-sub (langs: ko,en 우선) → VTT → dedup → clean text
            └ 실패/빈 결과 → 3.3의 자동 업데이트 시도 → 1회 재시도
2. [Plan B] get_timed_transcript (MCP)   ← Plan A가 끝내 실패할 때
3. [Plan C] get_transcript      (MCP)    ← 타임스탬프 없음, 메타에 명시
4. 전부 실패 → 사용자에게 보고하고 멈춤 (CLAUDE.md §7 유지)
```

- 언어 선택: **ko 우선, 없을 때만 en** (ko,en 동시 요청은 안 쓰는 en 자동번역 트랙까지 받아 429 위험 → 순차 시도). 둘 다 없으면 사용 가능한 자동자막 중 원어 트랙. (`get_available_languages`에 대응하는 yt-dlp `--list-subs` 판단은 필요 시에만.)
- 어느 Plan이 동작했는지 노트 메타 섹션에 짧게 명시 (예: `자막 출처: yt-dlp` / `자막 출처: MCP(get_transcript, 타임스탬프 없음)`).

### 3.2 실행 모드별 처리

**단독 실행 (메인 에이전트, 셸 보유)**
- Step 3에서 yt-dlp를 직접 실행 → VTT → 셸에서 dedup → clean text로 진행.
- 실패 시 3.3 업데이트 시도 → MCP 폴백.

**batch 실행 (`study-note-worker`, 셸 없음) — 핵심 통합**
- `study-note-worker`에는 셸 도구가 없어 yt-dlp를 직접 못 돌린다. 그래서 **메인이 `/batch-notes` Step 1.5에서 메타와 자막을 한 번에 prefetch**한다:
  1. Step 1.5의 기존 yt-dlp 메타 호출에 자막 다운로드를 합침 (`--write-auto-subs --sub-langs ko,en --sub-format vtt`, `--skip-download` 유지).
  2. 받은 VTT를 세션 scratch(temp) 폴더에 저장하고, **메인이 셸에서 dedup** → clean text 파일(예: `<videoId>.txt`)로 변환.
  3. 각 worker 디스패치 시 **clean text 파일 경로**를 함께 넘긴다.
  4. worker는 그 파일을 읽어 자막으로 사용 (Plan A). 파일이 없거나 비었으면 worker가 MCP(Plan B/C)를 직접 호출.
- 이로써 "셸 없는 worker" 난점이 해소된다. 자막 획득·dedup은 셸을 가진 메인이 한 번에 처리하고, worker는 읽기만 한다.
- **중복 영상 낭비 방지**: Step 1.5의 자막 prefetch는 batch 입력에서 URL 중복 제거(현행 Step 1) 후에 수행한다. 디스크에 이미 노트가 있는 영상(스킬 Step 0.5에서 걸러짐)의 자막까지 미리 받는 낭비를 줄이려면, 가능하면 Step 1.5 전에 영상 ID 기준 기존 노트 존재 검사를 먼저 수행해 이미 있는 것은 prefetch에서 제외한다. (구현 시 검증: 이 선검사가 과한 복잡도면 "전부 prefetch 후 worker가 Step 0.5로 skip" 현행 흐름을 유지하고 자막 파일만 버린다.)

### 3.3 yt-dlp 자동 업데이트 시도

- yt-dlp 추출이 실패하거나 빈 자막을 반환하면, **세션당 1회** `yt-dlp -U`를 시도하고 같은 명령을 재시도한다.
  - 검증됨(2026-07-01): scoop 설치본에서도 `yt-dlp -U`가 self-update로 동작 (`2026.03.17 → 2026.06.09`).
  - `-U`가 "패키지 매니저 관리라 업데이트 불가" 류로 거부되면 대체로 `scoop update yt-dlp`를 시도. (구현 시 메시지로 분기 검증.)
- 업데이트+재시도 후에도 실패하면 조용히 Plan B(MCP)로 폴백하고, 노트 메타에 `자막 출처: MCP (yt-dlp 실패)`로 남긴다.
- 업데이트 시도는 **세션당 1회로 제한** — 매 URL마다 시도해 배치를 느리게 만들지 않는다.
- 프로액티브 업데이트(작업 시작 시 무조건 업데이트)는 하지 않는다 — 네트워크·지연 낭비. 실패 트리거 기반 lazy 업데이트만.

### 3.4 VTT dedup

- yt-dlp auto-sub VTT는 롤링 중복 라인 + 단어 단위 `<time><c>…</c>` 태그를 포함한다(검증에서 확인).
- yt-dlp가 이제 hot path(매번 실행)이고 실행 주체가 항상 셸을 가지므로, **셸에서 결정적 dedup**을 수행한다 (모델 인라인 dedup 아님 — 토큰 0, 일관성↑).
- 구체 방법(작은 스크립트 `scripts/vtt-to-text` vs 셸 one-liner)은 **구현 단계에서 실측 검증 후 확정**. 산출물은 "타임스탬프 있는 clean text" — `[mm:ss]` 인용에 쓸 라인 타임스탬프는 보존하고 단어 단위 태그는 제거한다.

---

## 4. 변경 대상 파일

| 파일 | 변경 |
|---|---|
| `.claude/skills/harness-study-note/SKILL.md` | Step 3 체인 역전(yt-dlp=A, MCP=B/C), 자막 출처 메타 표기, 3.3 업데이트 시도 참조 |
| `.claude/commands/batch-notes.md` | Step 1.5에 자막 prefetch+dedup 합침, worker에 clean text 파일경로 전달, 자막 실패 처리 |
| `.claude/agents/study-note-worker.md` | 자막 입력을 "전달받은 clean text 파일 우선, 없으면 MCP" 순서로 수용 |
| `.claude/known-issues.md` | P1 근거·결정을 새 항목으로 추가 (§1 메타데이터 항목과 나란히) |
| `scripts/vtt-to-text` (신규, 방법 확정 시) | VTT → 타임스탬프 있는 clean text dedup |
| `CLAUDE.md` | 규칙 불변. 필요 시 "환경 셋업/도구" 수준의 한 줄 언급만 (선택) |

---

## 5. 엣지 케이스 · 에러 처리

- **yt-dlp 미설치**: Plan A 건너뛰고 바로 MCP(B). (단독/ batch 공통.)
- **ko/en 자막 없음**: yt-dlp가 다른 원어 자동자막을 반환하면 그걸 사용. 아무 자동자막도 없으면 MCP로 폴백, 그래도 없으면 Step 4 실패보고.
- **VTT는 받았으나 dedup 결과가 비정상(빈 텍스트/깨짐)**: MCP 폴백.
- **yt-dlp 추출 깨짐(YouTube 변경)**: 3.3 업데이트 시도 → 그래도 실패면 MCP가 받아냄. 회복력의 핵심 시나리오.
- **batch에서 일부 URL만 자막 실패**: 해당 worker만 MCP 경로로 자연히 흐르고 나머지는 정상. 격리 유지(현행 Negative Space 준수).

---

## 6. 검증 신호 (구현이 옳게 됐다는 지표)

- 같은 영상을 단독/batch 두 경로로 돌렸을 때 자막 텍스트가 동일 (dedup 일관).
- MCP 서버를 꺼도(또는 미설정) yt-dlp 경로로 노트가 완성됨.
- yt-dlp를 일부러 깨도(예: 잘못된 옵션) MCP 폴백으로 노트가 완성됨.
- 노트 메타에 `자막 출처`가 항상 명시됨.
- batch 실행에서 worker 컨텍스트에 raw VTT가 유입되지 않음 (clean text만).
- 업데이트 시도가 세션당 최대 1회.

---

## 7. 로드맵 상 위치 (참고, 본 스펙 범위 아님)

- **P1 (본 스펙)**: yt-dlp 자막 Plan A 승격 + 업데이트 시도.
- **P2**: 선택적 자동 수집(채널 신규 영상 감지 → `/batch-notes` 파이프라인 투입).
- **P3**: 핵심 인사이트 digest 레이어. 산출물은 `notes/`와 평행한 `digests/<channel>/`, 노트 수 미러. **미결 쟁점**: digest를 원문 노트 기반으로 뽑을지 자막 기반으로 뽑을지 — P3 스펙에서 결정.
- **P4**: 주제별 최신 정보 메타 레이어 (`HARNESS_ELEMENTS.md`/`harness-bootstrap`의 distill을 정식 도구로 승격).
