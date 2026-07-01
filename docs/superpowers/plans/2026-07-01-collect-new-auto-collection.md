# `/collect-new` 무인 자동 수집 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 추적 채널(`notes/*/`)의 어제 신규 영상을 무인 감지·필터해 기존 study-note 파이프라인으로 자동 노트화하는 `/collect-new` 커맨드.

**Architecture:** 결정적 감지 로직은 두 스크립트로 분리(테스트 가능): `collect-window.awk`(RSS→윈도우 필터, 순수함수)와 `collect-detect.sh`(채널 열거·channel_id 캐시·RSS·dedup·cap 오케스트레이션). 커맨드 룰북 `collect-new.md`가 스크립트를 돌려 URL 목록을 얻고, 비면 종료, 있으면 기존 batch 파이프라인을 **무인 모드**(승인 게이트 생략, 구조적 4중 상한이 대체)로 실행한다.

**Tech Stack:** bash + awk (Git Bash), yt-dlp(channel_id resolve), curl(RSS), GNU date. 노트화·INDEX는 기존 `/batch-notes`·study-note·P1 자막 재사용.

## Global Constraints

- 원문 보존·정정·인용 규칙 변경 금지. 이 작업은 *수집 트리거*만 추가.
- 무인 경로의 비용 통제 = **구조적 4중 상한**: 시간창(기본 어제) · 하드캡(기본 20, 초과 시 skip+경고) · ID중복 제외(`notes/`) · 동시성 캡(기존 3~5). 인터랙티브 `/batch-notes` 승인 게이트는 그대로 유지.
- 채널 소스 = `notes/*/` 디렉터리명(= `@handle`)만. 별도 구독 동기화 없음.
- 시간창 오버라이드: `--since=yesterday|YYYY-MM-DD|Nd`. 하드캡: `--cap=N`. 채널 부분집합: `--channels=a,b`.
- channel_id 캐시 = 플랫 파일 `.claude/collect-state`(`handle<TAB>channel_id` 줄). JSON 아님(bash 단순화). 런타임 생성.
- 하드캡 절단은 **최신 우선 유지**, 절단 수를 반드시 로그(silent truncation 금지).
- 테스트 결정성: 스크립트는 `COLLECT_TODAY` 환경변수로 "오늘"을 오버라이드 가능해야 함(날짜 의존 테스트용).
- Windows: `export PATH="$HOME/scoop/shims:$PATH"` 선행(yt-dlp).

---

### Task 1: RSS 윈도우 필터 (순수 awk)

**Files:**
- Create: `scripts/collect-window.awk`
- Test: `scripts/tests/collect-feed-fixture.xml`, 검증은 셸 명령

**Interfaces:**
- Produces: `awk -f scripts/collect-window.awk -v from=YYYY-MM-DD -v to=YYYY-MM-DD <feed.xml>` → stdout `id|YYYY-MM-DD` 줄들 (from≤date≤to). Task 2가 호출.

- [ ] **Step 1: 픽스처 작성**

`scripts/tests/collect-feed-fixture.xml` (채널레벨 published + entry 3개, 날짜 분산):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
  <title>Test Channel</title>
  <published>2012-09-02T14:46:48+00:00</published>
  <entry>
    <yt:videoId>AAA11111111</yt:videoId>
    <published>2026-06-30T09:00:00+00:00</published>
  </entry>
  <entry>
    <yt:videoId>BBB22222222</yt:videoId>
    <published>2026-06-29T09:00:00+00:00</published>
  </entry>
  <entry>
    <yt:videoId>CCC33333333</yt:videoId>
    <published>2026-06-24T09:00:00+00:00</published>
  </entry>
</feed>
```

- [ ] **Step 2: 스크립트 작성**

`scripts/collect-window.awk` (2026-07-01 실제 RSS로 검증된 로직):

```awk
# YouTube RSS(atom) -> "id|YYYY-MM-DD" for entries with from<=date<=to (ISO 문자열 비교).
# 채널레벨 <published>를 entry로 오인하지 않도록 RS="<entry>" + NR>1.
BEGIN { RS = "<entry>" }
NR > 1 {
  if (match($0, /<yt:videoId>([^<]+)/, a) && match($0, /<published>([^<]+)/, b)) {
    d = substr(b[1], 1, 10)
    if (d >= from && d <= to) print a[1] "|" d
  }
}
```

- [ ] **Step 3: 테스트 — 어제 하루(2026-06-30)만**

Run:
```bash
awk -f scripts/collect-window.awk -v from=2026-06-30 -v to=2026-06-30 scripts/tests/collect-feed-fixture.xml
```
Expected (정확히):
```
AAA11111111|2026-06-30
```

- [ ] **Step 4: 테스트 — 최근 2일(06-29..06-30)**

Run:
```bash
awk -f scripts/collect-window.awk -v from=2026-06-29 -v to=2026-06-30 scripts/tests/collect-feed-fixture.xml
```
Expected (2줄, 채널레벨 2012 published 미포함 확인):
```
AAA11111111|2026-06-30
BBB22222222|2026-06-29
```

- [ ] **Step 5: Commit**

```bash
git add scripts/collect-window.awk scripts/tests/collect-feed-fixture.xml
git commit -m "feat: add RSS window-filter awk for collect-new"
```

---

### Task 2: 감지 오케스트레이터 (bash)

**Files:**
- Create: `scripts/collect-detect.sh`

**Interfaces:**
- Consumes: `scripts/collect-window.awk` (Task 1).
- Produces: `scripts/collect-detect.sh [--since=..] [--cap=N] [--channels=a,b]` → stdout 후보 URL `https://youtu.be/<id>` (최신순, post-cap), stderr 채널별 로그·절단 경고. `.claude/collect-state` 캐시 갱신. Task 3(collect-new.md)이 호출.

- [ ] **Step 1: 스크립트 작성**

`scripts/collect-detect.sh`:

```bash
#!/usr/bin/env bash
# 추적 채널(notes/*/)의 신규 영상 감지 -> 윈도우 필터 -> notes/ dedup -> cap.
# stdout: 후보 URL(newest-first). stderr: 로그. .claude/collect-state = handle<TAB>channel_id 캐시.
set -euo pipefail
export PATH="$HOME/scoop/shims:$PATH"

SINCE="yesterday"; CAP=20; ONLY=""
for arg in "$@"; do case "$arg" in
  --since=*)    SINCE="${arg#*=}";;
  --cap=*)      CAP="${arg#*=}";;
  --channels=*) ONLY="${arg#*=}";;
  *) echo "unknown arg: $arg" >&2; exit 2;;
esac; done

TODAY="${COLLECT_TODAY:-$(date +%Y-%m-%d)}"
case "$SINCE" in
  yesterday)  FROM=$(date -d "yesterday" +%Y-%m-%d); TO="$FROM";;
  *d)         N="${SINCE%d}"; FROM=$(date -d "$N days ago" +%Y-%m-%d); TO="$TODAY";;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) FROM="$SINCE"; TO="$SINCE";;
  *) echo "bad --since: $SINCE" >&2; exit 2;;
esac
echo "window: $FROM..$TO  cap: $CAP" >&2

STATE=".claude/collect-state"; : > /dev/null; [ -f "$STATE" ] || : > "$STATE"

# 채널 열거
if [ -n "$ONLY" ]; then IFS=',' read -ra HANDLES <<< "$ONLY"
else HANDLES=(); for d in notes/*/; do [ -d "$d" ] && HANDLES+=("$(basename "$d")"); done; fi

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
for h in "${HANDLES[@]}"; do
  cid=$(grep -P "^${h}\t" "$STATE" 2>/dev/null | cut -f2 || true)
  if [ -z "$cid" ]; then
    cid=$(yt-dlp --playlist-items 1 --print "%(channel_id)s" \
          "https://www.youtube.com/@${h}/videos" --no-update 2>/dev/null \
          | grep -E "^UC" | head -1 || true)
    if [ -z "$cid" ]; then echo "  [skip] $h: channel_id resolve 실패" >&2; continue; fi
    printf "%s\t%s\n" "$h" "$cid" >> "$STATE"
  fi
  feed=$(curl -s "https://www.youtube.com/feeds/videos.xml?channel_id=${cid}" || true)
  if [ -z "$feed" ]; then echo "  [skip] $h: RSS 접근 실패" >&2; continue; fi
  n_in=$(printf "%s" "$feed" | awk -f scripts/collect-window.awk -v from="$FROM" -v to="$TO" | wc -l | tr -d ' ')
  printf "%s" "$feed" | awk -f scripts/collect-window.awk -v from="$FROM" -v to="$TO" \
    | while IFS='|' read -r id d; do
        if grep -rqF "$id" notes/ 2>/dev/null; then continue; fi   # 이미 노트화 -> 제외
        printf "%s\t%s\n" "$d" "$id" >> "$TMP"
      done
  echo "  [$h] 윈도우 내 $n_in편 (중복 제외 후 후보는 아래 집계)" >&2
done

# 최신순 정렬 -> cap
sort -r "$TMP" | awk -v cap="$CAP" '
  { total++; if (NR<=cap) print "https://youtu.be/" $2 }
  END {
    if (total > cap) printf("  [warn] 후보 %d편 > cap %d -> 오래된 %d편 절단(최신 유지)\n", total, cap, total-cap) > "/dev/stderr"
    printf("  후보 총 %d편, 처리 %d편\n", total, (total<cap?total:cap)) > "/dev/stderr"
  }'
```

- [ ] **Step 2: 실행 권한 + 라이브 스모크 테스트 (형식 검증)**

Run:
```bash
chmod +x scripts/collect-detect.sh
# 최근 20일 창으로 후보가 URL 형식으로 나오는지 (maker-evan 기준)
export PATH="$HOME/scoop/shims:$PATH"
bash scripts/collect-detect.sh --since=20d --channels=maker-evan --cap=5
```
Expected: stdout에 `https://youtu.be/<11자>` 형식 URL 최대 5줄(또는 전부 이미 노트화면 0줄), stderr에 `window:`·`[maker-evan]`·`후보 총 N편` 로그. `.claude/collect-state`에 `maker-evan<TAB>UC...` 생성.

- [ ] **Step 3: dedup 확인 (어제 창 = 신규 없음)**

Run:
```bash
bash scripts/collect-detect.sh --since=yesterday --channels=maker-evan
```
Expected: stdout 빈 줄(어제 업로드 없음 또는 전부 노트화됨), stderr에 window·집계 로그. 에러 없이 종료.

- [ ] **Step 4: Commit**

```bash
git add scripts/collect-detect.sh
git commit -m "feat: add collect-detect orchestrator (enumerate/resolve/RSS/dedup/cap)"
```

---

### Task 3: `/collect-new` 커맨드 룰북 + 스케줄 가이드

**Files:**
- Create: `.claude/commands/collect-new.md`

**Interfaces:**
- Consumes: `scripts/collect-detect.sh` (Task 2), 기존 `/batch-notes` 파이프라인.

- [ ] **Step 1: 커맨드 룰북 작성**

`.claude/commands/collect-new.md`:

````markdown
---
description: 추적 채널(notes/*/)의 어제 신규 영상을 무인 감지해 study-note로 자동 정리한다. 승인 게이트 없이 구조적 4중 상한(시간창·하드캡·ID중복·동시성)으로 비용을 통제. 사용법&#58; /collect-new [--since=yesterday|YYYY-MM-DD|Nd] [--cap=20] [--channels=a,b]
---

# /collect-new — 무인 신규 영상 수집

## 입력(선택)
`$ARGUMENTS` 에서 `--since` / `--cap` / `--channels` 를 그대로 감지 스크립트에 전달한다. 없으면 기본값(어제, cap 20, 전체 채널).

## Step 1: 신규 감지
```bash
export PATH="$HOME/scoop/shims:$PATH"
bash scripts/collect-detect.sh $ARGUMENTS
```
- stdout = 후보 URL 목록(최신순, cap 적용). stderr = 채널별 로그·절단 경고를 사용자에게 그대로 전한다.
- **후보가 0줄이면**: "신규 영상 없음(window: …)" 로그만 남기고 **종료**. batch 진입하지 않는다.

## Step 2: 무인 노트화
후보 URL이 1개 이상이면, 그 목록을 **`/batch-notes` 파이프라인의 Step 1.5~4로 처리하되 Step 2 승인 게이트는 생략**한다(무인 호출 — 상한이 이미 적용됨). 즉:
- 각 URL에 대해 게시일은 감지 단계에서 이미 알지만, batch Step 1.5의 메타+자막 prefetch(P1 경로)를 그대로 수행한다.
- `study-note-worker`로 동시성 캡(3~5) 내에서 격리 병렬 처리.
- 완료 후 batch Step 4로 채널별 INDEX·루트 카탈로그 갱신.

## Step 3: 요약 로그
```
/collect-new 완료 (window: <FROM..TO>)
채널별: <handle> 신규 N편 …
생성: <파일 목록>
스킵: 이미 정리 M편 / 하드캡 절단 K편(있으면)
```

## Negative Space
- 승인 프롬프트 없음(무인). 대신 감지 스크립트의 4중 상한에 의존.
- 후보 0이면 batch 진입 금지(불필요 비용·노이즈 방지).
- 한 채널·한 영상 실패가 전체를 막지 않음(기존 격리 원칙).

## 스케줄링 (Claude Desktop 로컬 루틴)
매일 무인 실행하려면 Claude Desktop에서 로컬 루틴을 만든다:
1. 좌측 **루틴** → 로컬 루틴 생성.
2. 폴더 = 이 저장소 경로.
3. 지침 = `어제 업로드된 영상을 수집해 노트로 정리해줘` (→ `/collect-new` 발동).
4. 실행 시각 지정 후 생성.
- **주의**: 로컬 루틴은 컴퓨터가 켜져 있을 때만 동작(꺼져 있으면 다음 시각에). 원격 루틴 아님.
- 루틴 생성 자체는 UI에서 사용자가 직접 한다.
````

- [ ] **Step 2: 커맨드 인식 확인**

`/collect-new` 가 커맨드 목록에 뜨는지(frontmatter description 유효) 확인. Read로 파일 재확인.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/collect-new.md
git commit -m "feat: add /collect-new command (unattended detection -> batch)"
```

---

### Task 4: batch-notes 무인 분기 + CLAUDE.md 가드레일 분화 + known-issues

**Files:**
- Modify: `.claude/commands/batch-notes.md`
- Modify: `CLAUDE.md`
- Modify: `.claude/known-issues.md`

**Interfaces:**
- Consumes: 없음(문서·룰 정합).

- [ ] **Step 1: batch-notes.md 무인 분기 명시**

`## Negative Space`의 "사용자 승인 없이 Step 2 진입 금지 …" 항목을 다음으로 교체:

```markdown
- 사용자 승인 없이 Step 2 진입 금지 — 잘못 붙여진 URL이 많은 비용을 일으킬 수 있음. **단, 무인 호출(`/collect-new` 발)은 예외**: 승인 게이트 대신 감지 단계의 구조적 4중 상한(시간창·하드캡·ID중복·동시성)이 비용을 통제한다. 인터랙티브(사용자가 URL 붙여넣는) 호출은 승인 게이트 유지.
```

- [ ] **Step 2: CLAUDE.md — 가드레일 분화 + 흐름 한 줄**

(a) §4 흐름 끝의 batch 안내 문단 뒤에 한 줄 추가:
```markdown
채널을 정해 붙여넣는 대신, 추적 채널(`notes/*/`)의 어제 신규 영상을 무인으로 감지·정리하려면 `/collect-new` 커맨드를 쓴다(스케줄러 연동 가능).
```
(b) §6(negative space)에서 승인 관련 문구가 있으면, "인터랙티브 배치는 승인 필요 / 무인 `/collect-new`는 구조적 상한으로 대체"를 한 줄로 명시. 없으면 (a)만.

- [ ] **Step 3: known-issues.md 항목 추가**

`## 3. …` 뒤, `---` 앞에:

```markdown
## 4. 무인 자동 수집의 비용 통제 (승인 게이트 대체)

- **문제**: 완전 자동 수집은 인터랙티브 배치의 "승인 후 진입" 가드레일과 충돌. 승인 없이 폭주 비용 위험.
- **결정(2026-07-01)**: 가드레일을 제거하지 않고 **맥락별 분화**. 인터랙티브 `/batch-notes`는 승인 유지, 무인 `/collect-new`는 구조적 4중 상한(시간창 기본 어제·하드캡 기본 20·ID중복 제외·동시성 3~5)으로 대체. 하드캡 절단은 최신 우선 + 로그(silent 금지).
- **관련**: `docs/superpowers/specs/2026-07-01-collect-new-auto-collection-design.md`, 동명 plan.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/batch-notes.md CLAUDE.md .claude/known-issues.md
git commit -m "docs: reconcile approval guardrail for unattended /collect-new"
```

---

## Self-Review

**Spec coverage:**
- 채널 열거(§4.2) → Task 2 Step 1 ✅
- channel_id 캐시(§4.2) → Task 2(플랫 파일, Global Constraints에 명시된 JSON→플랫 변경) ✅
- 신규 감지·RSS 파싱(§4.3) → Task 1(awk) + Task 2 ✅
- 시간창/dedup/하드캡(§4.3) → Task 1(창) + Task 2(dedup·cap·경고) ✅
- 무인 batch(§4.4) → Task 3 Step 2 + Task 4 Step 1 ✅
- 스케줄 문서(§4.5) → Task 3 룰북 하단 ✅
- CLAUDE.md 분화(§2) → Task 4 ✅
- 엣지(§6): 0건/ resolve실패/ RSS실패/ cap초과/ 전부중복/ 부분실패 → Task 2 스크립트 분기 + Task 3 Negative Space ✅
- 검증 신호(§7) → Task 1 테스트(창·채널레벨 제외), Task 2 스모크(형식·dedup·캐시) ✅

**Placeholder scan:** Task 1/2 실제 awk·bash 전문 포함. `<handle>`·`<id>`·`<FROM..TO>`·`$ARGUMENTS`는 런타임 토큰(형식 명시). 플레이스홀더 없음.

**Type/이름 정합성:** `scripts/collect-window.awk`(Task1 생성=Task2 호출), `scripts/collect-detect.sh`(Task2 생성=Task3 호출), 출력 URL 형식 `https://youtu.be/<id>` 일관, 캐시 `.claude/collect-state`(handle<TAB>channel_id) Task2 내 일관, 4중 상한 용어 spec/plan/CLAUDE/known-issues 통일.

---

## 로드맵
P1(완료) → **P2(본 계획)** → P3(digest) → P4(주제 메타).
