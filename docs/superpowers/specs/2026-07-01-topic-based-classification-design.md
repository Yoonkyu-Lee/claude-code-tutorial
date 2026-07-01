# P3a 설계: 주제별 분류 리팩토링 (`notes/<topic>/<channel>/`)

- **날짜**: 2026-07-01
- **상태**: 설계 승인 대기
- **범위**: P3의 선행 subsystem. 저장소를 "Claude Code 전용"에서 **다주제 아카이브**로 확장. digest 실험(P3)은 이 위에서 진행.

## 1. 배경

지금까지 노트는 `notes/<channel>/`에 채널만으로 분류됐다. 앞으로 바이브코딩 외 다양한 주제(예: 비즈니스/부업)를 정리하므로, **채널을 주제별로 묶는** 계층이 필요하다. (사용자 결정 2026-07-01.)

## 2. 결정

- **구조**: `notes/<topic>/<channel-handle>/YYYY-MM-DD-title.md` (주제 → 채널 → 노트).
- **기존 이동(지금)**: `notes/maker-evan/`, `notes/코딩알려주는누나/` → `notes/ai-coding/` 아래로 (git mv, ID 보존).
- **주제명**: 코딩 채널 = `ai-coding`. 부업 영상(@MONEY_TOUCH) = `business` (P3에서 생성).
- **INDEX 3계층**:
  - 루트 `INDEX.md` = **주제 카탈로그** (주제 목록 + 각 주제 색인 링크).
  - `notes/<topic>/INDEX.md` = **채널 카탈로그** (그 주제의 채널들).
  - `notes/<topic>/<channel>/INDEX.md` = **노트 색인** (기존, 이동만).

## 3. 목표 · 비목표

**목표**
1. 폴더를 `notes/<topic>/<channel>/`로 이행하고 기존 95노트 무손실 이동.
2. CLAUDE.md 정체성·규약·워크플로를 다주제·주제계층으로 갱신.
3. 스킬·커맨드·수집 스크립트의 경로 로직을 주제 계층에 맞게 갱신.
4. INDEX 3계층 확립.

**비목표**
- 노트 본문 내용 변경 (경로/색인만).
- digest 스킬·실험(P3).
- `harness-bootstrap` 등 외부 스킬 개조 (노트 경로는 재귀 스캔이라 대부분 무영향; 문제 시 별도 처리).

## 4. 변경 대상

| 파일/폴더 | 변경 |
|---|---|
| `notes/maker-evan/`, `notes/코딩알려주는누나/` | → `notes/ai-coding/` 하위로 git mv |
| `notes/ai-coding/INDEX.md` (신규) | ai-coding 채널 카탈로그 (기존 루트 표에서 이관) |
| `INDEX.md` (루트) | 채널 카탈로그 → **주제 카탈로그**로 개편 |
| `CLAUDE.md` | §1 정체성(다주제), §채널규약→주제·채널규약, §5 명명, §4 워크플로(주제 결정 단계) |
| `.claude/skills/harness-study-note/SKILL.md` | Step 0(주제+채널 결정), `<NOTES_DIR>`=`notes/<topic>/<channel>/`, Step 9 INDEX 계층 |
| `.claude/agents/study-note-worker.md` | 입력 `주제:` 추가, 저장경로 `notes/<주제>/<채널>/` |
| `.claude/commands/batch-notes.md` | 라우팅에 주제 차원 추가 |
| `.claude/commands/collect-new.md`, `scripts/collect-detect.sh` | 채널 열거 `notes/*/` → `notes/*/*/` (주제/채널), (주제,채널) 쌍 추적 |
| `COMMANDS.md` | 경로 표기 갱신 |

## 5. 설계 세부

### 5.1 주제 결정 (SKILL Step 0 개정)
- 채널이 이미 어느 주제 폴더 아래 존재하면 → **그 주제를 그대로 사용** (채널=주제 고정).
- 새 채널이면 → 사용자에게 **주제 + 채널 폴더** 확인 (기존 "새 채널 확인"을 "새 채널+주제 확인"으로 확장). 일괄 실행 시 메인이 결정해 worker에 `주제:`로 전달.
- 중복 검사(Step 0.5)는 `notes/**/*.md` 전역이라 계층 추가와 무관하게 그대로 동작.

### 5.2 INDEX 계층
- **노트 생성 시**: 채널 색인(`notes/<topic>/<channel>/INDEX.md`)에 항목 추가 (기존 Step 9).
- **새 채널**: 그 주제의 채널 카탈로그(`notes/<topic>/INDEX.md`)에 행 추가. 주제 자체가 새것이면 루트 주제 카탈로그에 행 추가 + `notes/<topic>/INDEX.md` 생성.
- 배치의 INDEX 일괄 갱신(batch Step 4)도 (주제→채널) 라우팅으로 확장.

### 5.3 collect-detect 열거
- `for d in notes/*/` → `for d in notes/*/*/` (주제/채널 디렉터리만; `notes/*/INDEX.md`는 파일이라 자동 제외).
- 채널 핸들 = `basename "$d"`, 주제 = `basename $(dirname "$d")`. 캐시 키·신규 노트 저장 경로에 주제 포함.
- 채널 URL 복원은 핸들만 필요(주제 무관)하므로 resolve 로직 불변.

## 6. 마이그레이션 절차 (무손실)
1. `mkdir notes/ai-coding` → `git mv notes/maker-evan notes/ai-coding/maker-evan`, 동일하게 코딩알려주는누나.
2. 노트 수 검증: 이동 전후 `find notes -name '*.md' | wc -l` 동일.
3. 루트 INDEX → 주제 카탈로그로 재작성, `notes/ai-coding/INDEX.md`에 채널 카탈로그 이관.
4. 채널 INDEX 내부 링크는 상대경로(파일명)라 이동 후에도 유효 — 확인.
5. 스킬/커맨드/스크립트 경로 로직 갱신.
6. `collect-detect.sh` 재실행으로 열거가 `ai-coding/maker-evan`을 잡는지 검증.

## 7. 엣지 케이스
- 한글 채널 폴더명(`코딩알려주는누나`) URL 인코딩 — 루트 INDEX 링크에 이미 처리됨, 이동 후 재확인.
- collect-state 캐시 키: 채널 핸들만으로 유일하면 유지, 주제 접두 불필요(핸들 전역 유일 가정). 충돌 우려 시 `topic/handle` 키.
- 기존 노트의 `채널:` 메타는 그대로(주제 메타는 신규 노트부터, 선택).

## 8. 검증 신호
- 이동 전후 노트 md 수 동일(95), 영상 ID 검색 그대로 동작.
- 루트 INDEX = 주제 카탈로그, 각 주제 INDEX = 채널 카탈로그로 2단 탐색 가능.
- `/collect-new`가 `notes/ai-coding/*` 채널을 열거·감지.
- 새 노트가 `notes/<topic>/<channel>/`에 저장되고 3계층 INDEX가 갱신됨.

## 9. 로드맵
P1·P2(완료) → **P3a(본 스펙, 주제 리팩토링)** → P3(digest 스킬 2개 + 실험) → P4(주제 최신 메타). 주제 계층은 P4(주제별 메타)의 토대도 된다.
