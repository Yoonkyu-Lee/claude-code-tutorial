---
description: 추적 채널(notes/<주제>/<채널>/)의 어제 신규 영상을 무인 감지해 study-note로 자동 정리한다. 승인 게이트 없이 구조적 4중 상한(시간창·하드캡·ID중복·동시성)으로 비용을 통제. 사용법&#58; /collect-new [--since=yesterday|YYYY-MM-DD|Nd] [--cap=20] [--channels=a,b]
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

- 각 URL에 대해 batch Step 1.5의 메타+자막 prefetch(P1 경로)를 그대로 수행한다.
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

- 승인 프롬프트 없음(무인). 대신 감지 스크립트의 4중 상한(시간창·하드캡·ID중복·동시성)에 의존.
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
