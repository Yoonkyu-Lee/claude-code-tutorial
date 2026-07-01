# yt-dlp 자막 Plan A 승격 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** study-note 파이프라인의 자막 획득을 `yt-dlp(Plan A) → yt-dlp -U 재시도 → MCP(Plan B/C) → 실패보고`로 재배치하고, batch 모드에서 메타+자막을 한 패스로 prefetch·dedup해 worker에 clean text만 넘긴다.

**Architecture:** yt-dlp는 이미 메타데이터 추출에 쓰인다. 자막도 같은 도구·같은 prefetch 패스로 통합한다. 실행 주체(항상 셸 보유)가 결정적 awk 스크립트로 VTT를 dedup해 `[MM:SS]` 타임스탬프가 붙은 clean text를 만든다. MCP는 yt-dlp 추출이 깨질 때를 위한 진짜 폴백으로 유지한다.

**Tech Stack:** yt-dlp (자막 다운로드 + self-update), awk (VTT dedup, Git Bash 내장), 마크다운 룰북 파일(`.claude/` 하위).

## Global Constraints

- 원문 보존·의견/사실 분리·`[불명확]`·정정 사전(Step 4) 로직은 **변경 금지**. 이 작업은 자막 *획득 경로*만 바꾼다. (CLAUDE.md §6)
- MCP 자막 경로를 **제거하지 않는다** — Plan B/C 폴백으로 유지 (yt-dlp 추출 fragility 대비).
- yt-dlp 자동 업데이트는 **실패 트리거 기반 lazy, 세션당 최대 1회**. 프로액티브 업데이트 금지.
- yt-dlp 자막 언어: **ko 우선, 없을 때만 en** (동시 요청 금지 — 429 위험). VTT dedup 산출물은 `[MM:SS] 텍스트` 라인 형식 (라인 타임스탬프 보존, 단어 단위 태그 제거).
- Windows 네이티브 환경. yt-dlp는 scoop 설치, PATH에 없으면 `$HOME/scoop/shims` 선행. `yt-dlp -U`는 scoop 설치본에서도 self-update 동작 확인됨(2026-07-01).
- 노트 메타 섹션에 `자막 출처:`를 항상 명시 (`yt-dlp` / `MCP(get_transcript, 타임스탬프 없음)` / `MCP (yt-dlp 실패)`).

---

### Task 1: VTT → clean text dedup 스크립트

**Files:**
- Create: `scripts/vtt-to-text.awk`
- Test: `scripts/tests/vtt-to-text-fixture.vtt`, 검증은 셸 명령으로

**Interfaces:**
- Produces: `awk -f scripts/vtt-to-text.awk <input.vtt>` → stdout에 `[MM:SS] 텍스트` 라인들. Task 2(단독)·Task 3(batch)이 이 스크립트를 호출한다.

- [ ] **Step 1: 테스트 픽스처 작성**

`scripts/tests/vtt-to-text-fixture.vtt` — 실제 yt-dlp auto-sub의 롤링 중복 구조를 축약 재현:

```
WEBVTT
Kind: captions
Language: ko

00:00:00.120 --> 00:00:03.270 align:start position:0%
 
여러분<00:00:00.840><c> 혹시</c><00:00:01.400><c> 안녕</c>

00:00:03.270 --> 00:00:03.280 align:start position:0%
여러분 혹시 안녕
 

00:00:03.280 --> 00:00:05.910 align:start position:0%
여러분 혹시 안녕
다음<00:00:03.800><c> 줄입니다</c>

00:00:05.910 --> 00:00:05.920 align:start position:0%
다음 줄입니다
 
```

- [ ] **Step 2: 스크립트 작성**

`scripts/vtt-to-text.awk` (2026-07-01 실제 VTT로 검증된 로직):

```awk
# yt-dlp YouTube auto-sub VTT -> "[MM:SS] text" clean lines.
# 롤링 중복 라인 제거 + <time>/<c> 태그 제거. 라인 타임스탬프 보존.
/-->/ { ts = substr($1, 1, 8); next }                 # HH:MM:SS.mmm 중 HH:MM:SS 캡처
/^WEBVTT|^Kind:|^Language:|^$/ { next }
{
  line = $0
  gsub(/<[^>]*>/, "", line)                           # <00:00:00.840>, <c>, </c> 제거
  gsub(/^[ \t]+|[ \t]+$/, "", line)                   # 트림
  if (line == "") next
  if (line == prev) next                              # 연속 중복(롤링 반복) 제거
  prev = line
  print "[" substr(ts, 4, 5) "] " line                # MM:SS
}
```

- [ ] **Step 3: 테스트 실행 (기대: 중복 없는 2줄)**

Run:
```bash
awk -f scripts/vtt-to-text.awk scripts/tests/vtt-to-text-fixture.vtt
```
Expected 출력 (정확히):
```
[00:00] 여러분 혹시 안녕
[00:03] 다음 줄입니다
```

- [ ] **Step 4: 실차 검증 (실제 영상 VTT)**

Run (임시 폴더에서):
```bash
export PATH="$HOME/scoop/shims:$PATH"
yt-dlp --skip-download --write-auto-subs --sub-langs ko --sub-format vtt \
  -o "verify.%(ext)s" "https://youtu.be/MJiQFNp-k10" --no-update
awk -f scripts/vtt-to-text.awk verify.ko.vtt | head -5
```
Expected: `[00:00] 여러분 혹시 매일 아침마다 챙겨봤던` 로 시작하는 5줄, 롤링 중복 없음.

- [ ] **Step 5: Commit**

```bash
git add scripts/vtt-to-text.awk scripts/tests/vtt-to-text-fixture.vtt
git commit -m "feat: add VTT->clean-text dedup script for yt-dlp subtitles"
```

---

### Task 2: SKILL.md Step 3 자막 체인 역전 (단독 실행 경로)

**Files:**
- Modify: `.claude/skills/harness-study-note/SKILL.md` (Step 3 섹션)

**Interfaces:**
- Consumes: `scripts/vtt-to-text.awk` (Task 1).
- Produces: 개정된 Step 3 룰북. Task 3의 batch prefetch가 이 체인의 "Plan A" 정의를 참조한다.

- [ ] **Step 1: 기존 Step 3 블록을 아래로 교체**

기존 (`### Step 3: 자막 가져오기` ~ 다음 `###` 직전) 전체를 다음으로 교체:

````markdown
### Step 3: 자막 가져오기

자막 획득 우선순위 (품질은 경로 무관 동일 — YouTube 동일 ASR. 순서는 가용성·의존성 기준):

1. **[Plan A] yt-dlp auto-sub** (셸 있는 실행 주체만):
   ```
   yt-dlp --skip-download --write-auto-subs --sub-langs ko,en --sub-format vtt -o "<videoId>.%(ext)s" <URL> --no-update
   ```
   받은 `<videoId>.ko.vtt`(또는 `.en.vtt`)를 `awk -f scripts/vtt-to-text.awk <vtt>`로 dedup → `[MM:SS] 텍스트` clean text.
   - Windows에서 PATH에 yt-dlp 없으면 `export PATH="$HOME/scoop/shims:$PATH"` 선행.
   - **빈 결과/추출 에러 시**: 이 세션에서 아직 안 했으면 `yt-dlp -U` 1회 실행 후 위 명령을 **1회 재시도** (Step 3.3 참조). 그래도 실패하면 Plan B로.
   - yt-dlp 미설치면 Plan A 건너뛰고 Plan B로.
2. **[Plan B] `get_timed_transcript` (MCP)** — Plan A가 끝내 실패할 때. 타임스탬프 포함.
3. **[Plan C] `get_transcript` (MCP)** — Plan B도 실패. 타임스탬프 없음 → 메타에 "타임스탬프 미제공" 명시.
4. **전부 실패** → 사용자에게 보고하고 멈춤 (CLAUDE.md §7).

동작한 경로를 노트 메타 섹션에 `자막 출처:`로 명시한다 (`yt-dlp` / `MCP(get_transcript, 타임스탬프 없음)` / `MCP (yt-dlp 실패)`).

> **batch 실행 주의**: `study-note-worker`는 셸이 없어 Plan A(yt-dlp)를 직접 못 돈다. batch에서는 `/batch-notes` 메인이 Step 1.5에서 자막을 미리 받아 dedup한 **clean text 파일**을 worker에 넘긴다. worker는 그 파일을 우선 사용하고, 없으면 Plan B/C(MCP)를 직접 호출한다. (batch-notes.md Step 1.5 / study-note-worker.md 참조.)

`get_available_languages`는 호출하지 않는다 — ko/en 자동자막이 모두 없을 때만 fallback으로 검토.

영어 영상은 자막 정정 단계(Step 4)의 한국어 음차 사전이 안 맞을 수 있다. 해당 채널 폴더에 `caption-corrections.md`가 있으면 그걸 우선 사용. 없으면 기본 사전(`.claude/skills/harness-study-note/references/caption-corrections.md`)을 폴백으로 사용.

#### Step 3.3: yt-dlp 자동 업데이트 시도
Plan A가 빈 자막/추출 에러를 내면, **세션당 1회** `yt-dlp -U`를 실행하고 자막 명령을 재시도한다.
- scoop 설치본에서도 `yt-dlp -U` self-update 동작 확인됨(2026-07-01).
- `-U`가 "패키지 매니저 관리라 불가" 류로 거부되면 `scoop update yt-dlp`를 시도.
- 업데이트+재시도 후에도 실패하면 조용히 Plan B(MCP)로 폴백.
- 업데이트는 세션당 1회로 제한 — 매 URL마다 시도해 배치를 느리게 하지 않는다.
````

- [ ] **Step 2: 정합성 확인**

Read로 SKILL.md Step 3~4 경계를 확인. Step 4(자막 품질 정정)가 clean text를 입력으로 받는 흐름이 유지되는지, `자막 출처` 표기가 Step 6 메타 섹션 예시와 안 부딪히는지 확인. 부딪히면 Step 6 메타 예시에 `자막 출처:` 한 줄만 추가.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/harness-study-note/SKILL.md
git commit -m "feat: promote yt-dlp to Plan A in study-note Step 3, MCP as fallback"
```

---

### Task 3: batch-notes.md Step 1.5 — 메타+자막 통합 prefetch

**Files:**
- Modify: `.claude/commands/batch-notes.md` (Step 1.5 섹션, Step 2 dispatch 지시)

**Interfaces:**
- Consumes: `scripts/vtt-to-text.awk` (Task 1), SKILL.md Step 3 Plan A 정의 (Task 2).
- Produces: **worker 입력 계약** — 각 worker에 `자막파일: <경로>` (dedup된 clean text `.txt` 절대경로)를 전달. Task 4의 worker가 이 필드를 소비한다. 파일 없음/빈 파일 시 worker는 MCP 폴백.

- [ ] **Step 1: Step 1.5 제목·본문 확장**

기존 `### Step 1.5: 게시일 + 채널 일괄 prefetch (dispatch 전 필수)` 섹션의 제목을 `### Step 1.5: 게시일 + 채널 + 자막 일괄 prefetch (dispatch 전 필수)`로 바꾸고, 기존 yt-dlp 메타 명령 설명 뒤에 다음을 추가:

````markdown
#### 자막 prefetch (메타와 같은 패스)

worker는 셸이 없어 yt-dlp를 못 돈다. 자막도 메인이 미리 받아 dedup해 clean text 파일로 worker에 넘긴다. **중복 노트 검사(영상 ID) 후 남은 URL에 대해서만** 실행해 이미 정리된 영상의 자막을 받는 낭비를 막는다.

승인된(중복 제외된) URL마다:
```bash
export PATH="$HOME/scoop/shims:$PATH"
yt-dlp --skip-download --write-auto-subs --sub-langs ko,en --sub-format vtt \
  -o "<scratch>/<videoId>.%(ext)s" <URL> --no-update
awk -f scripts/vtt-to-text.awk "<scratch>/<videoId>.ko.vtt" > "<scratch>/<videoId>.txt"   # ko 없으면 .en.vtt
```
- `<scratch>`는 세션 scratchpad 폴더. clean text 파일 절대경로를 URL별로 매핑 표에 기록.
- yt-dlp가 빈 자막/에러면 Step 3.3(세션당 1회 `yt-dlp -U` 후 재시도)을 적용. 그래도 실패면 그 URL은 **자막파일 없이** dispatch → worker가 MCP 폴백.
- 자막 prefetch는 메타 prefetch와 한 번의 yt-dlp 호출로 합쳐도 된다(`--print`와 `--write-auto-subs` 병행). 실측으로 더 단순한 쪽 선택.
````

- [ ] **Step 2: Step 2 dispatch 지시에 자막파일 전달 추가**

`### Step 2: 사용자 승인 후 배치 실행`의 "각 worker에게 ... 전달한다" 항목을 다음으로 교체:

```markdown
- 각 worker에게 **URL + 게시일(확정) + 채널 슬러그 + 권장 파일명 + 자막파일(clean text 절대경로, 있으면)**을 전달한다. worker에게 "자막파일이 있으면 그걸 자막으로 쓰고, 없거나 비면 MCP(get_timed_transcript→get_transcript)로 폴백하라. 게시일·채널은 그대로 쓰고 yt-dlp/WebSearch/r.jina.ai를 게시일 용도로 호출하지 말라"고 지시한다.
```

- [ ] **Step 3: 배치 보고 상태에 자막 폴백 표기(선택) 추가**

Step 2의 배치 보고 예시에 자막이 MCP로 폴백된 경우를 나타낼 수 있게 한 줄 주석 추가 (기존 `✅ <파일명1>` 아래):
```markdown
  ℹ️ <파일명>: 자막 MCP 폴백 (yt-dlp prefetch 실패)
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/batch-notes.md
git commit -m "feat: prefetch+dedup subtitles in batch Step 1.5, pass clean text to workers"
```

---

### Task 4: study-note-worker.md — 자막파일 입력 수용

**Files:**
- Modify: `.claude/agents/study-note-worker.md`

**Interfaces:**
- Consumes: Task 3의 worker 입력 계약 (`자막파일: <경로>`).

- [ ] **Step 1: worker 문서에 자막 입력 규칙 추가**

`study-note-worker.md`에서 자막 획득을 언급하는 부분(스킬 Step 3에 위임하는 지점)에 다음 규칙을 명시:

```markdown
## 자막 입력 (batch 경로)
디스패처가 `자막파일: <절대경로>`를 넘기면:
- 그 파일(dedup된 `[MM:SS] 텍스트` clean text)을 Read로 읽어 자막으로 사용한다 (스킬 Step 3의 Plan A 결과와 동등).
- 파일이 없거나 비어 있으면 스킬 Step 3의 Plan B/C(MCP `get_timed_transcript` → `get_transcript`)로 폴백한다.
- worker에는 셸이 없으므로 yt-dlp를 직접 실행하지 않는다.
- 사용한 경로를 노트 메타 `자막 출처:`에 반영한다 (`yt-dlp` = 자막파일 사용 / `MCP ...` = 폴백).
```

- [ ] **Step 2: 도구 목록 확인**

worker frontmatter의 tools에 `Read`가 있는지 확인 (자막파일 읽기용). 없으면 추가. (`mcp__youtube-transcript__*`는 이미 있어 MCP 폴백 가능.)

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/study-note-worker.md
git commit -m "feat: worker consumes prefetched clean-text subtitle file, MCP fallback"
```

---

### Task 5: known-issues.md 근거 항목 + CLAUDE.md 선택적 언급

**Files:**
- Modify: `.claude/known-issues.md`
- Modify (선택): `CLAUDE.md`

**Interfaces:**
- Consumes: 없음 (문서화).

- [ ] **Step 1: known-issues.md에 항목 추가**

`## 2. ...` 항목 뒤, `---` 앞에 새 항목:

```markdown
## 3. 자막 획득 경로 통합 (yt-dlp Plan A 승격)

- **문제**: 자막을 MCP로 1차 획득하면서, 메타데이터용으로 이미 쓰는 yt-dlp와 자막 원천이 이원화. MCP 서버 의존이 별도 실패점.
- **빈도**: 재발 문제라기보다 구조 개선 (2026-07-01 검증 기반 결정).
- **검증**: 같은 영상(`MJiQFNp-k10`)의 MCP 자막과 yt-dlp 자막 텍스트 품질이 동일 (동일 YouTube ASR, 음차 오류까지 동일). yt-dlp는 단어 단위 타임스탬프까지 제공.
- **채택된 해결**: yt-dlp 자막을 Plan A로, MCP를 Plan B/C 폴백으로 유지 (제거 아님 — yt-dlp 추출 fragility 대비). batch는 메인이 메타+자막 한 패스 prefetch → `scripts/vtt-to-text.awk`로 dedup → worker에 clean text 전달. yt-dlp 빈 결과/에러 시 세션당 1회 `yt-dlp -U` 후 재시도.
- **경고 신호(caveat)**: yt-dlp가 `No supported JavaScript runtime` / 90일+ 구버전 경고를 냄. YouTube 추출은 주기적으로 깨지므로 MCP 폴백 유지가 필수.
- **날짜**: 2026-07-01 확정
- **관련 스펙/계획**: `docs/superpowers/specs/2026-07-01-ytdlp-subtitle-plan-a-design.md`, `docs/superpowers/plans/2026-07-01-ytdlp-subtitle-plan-a.md`
```

- [ ] **Step 2: CLAUDE.md 확인 (선택)**

CLAUDE.md에 자막 도구를 명시한 줄이 있는지 Read로 확인. 있으면 "자막: yt-dlp(1차)/transcript MCP(폴백)" 수준으로 한 줄만 갱신. **규칙 자체는 변경 금지.** 없으면 건드리지 않는다.

- [ ] **Step 3: Commit**

```bash
git add .claude/known-issues.md CLAUDE.md
git commit -m "docs: record yt-dlp Plan A subtitle decision in known-issues"
```

---

## Self-Review

**Spec coverage:**
- 자막 체인 역전(§3.1) → Task 2 ✅
- batch prefetch 통합(§3.2) → Task 3 ✅
- 셸 없는 worker 처리(§3.2) → Task 3(계약)+Task 4(소비) ✅
- yt-dlp 자동 업데이트(§3.3) → Task 2 Step 3.3 + Task 3 Step 1 ✅
- VTT dedup(§3.4) → Task 1 ✅
- 변경 대상 파일(§4) → Task 1~5가 모두 커버 ✅
- 엣지 케이스(§5): 미설치/자막없음/dedup깨짐/추출깨짐/일부실패 → Task 2 체인 + Task 3/4 폴백 규칙에 반영 ✅
- 검증 신호(§6) → Task 1 Step 3/4 (dedup 일관), Task 2/4 (폴백·메타 표기) ✅

**Placeholder scan:** 코드 스텝(Task 1)은 실제 awk·명령 포함. 문서 스텝은 실제 교체 텍스트 포함. `<videoId>`·`<scratch>`·`<URL>`은 런타임 치환 토큰이며 플레이스홀더 아님(형식 명시됨).

**Type/이름 정합성:** `scripts/vtt-to-text.awk` (Task 1 생성 → Task 2/3 참조 동일 경로), 출력 형식 `[MM:SS] 텍스트` 전 태스크 일관, worker 입력 필드명 `자막파일:` (Task 3 생산 = Task 4 소비) 일치. `자막 출처:` 메타 키 전 태스크 일관.

---

## 로드맵 상 위치 (참고)
P1(본 계획) 완료 후 → P2(자동 수집) → P3(digest 레이어) → P4(주제 최신 메타). 각 별도 스펙+계획.
