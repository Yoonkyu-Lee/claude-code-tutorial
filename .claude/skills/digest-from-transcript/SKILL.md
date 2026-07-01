---
name: digest-from-transcript
description: YouTube 영상 자막(원본)을 직접 읽어 핵심 인사이트만 뽑은 압축 digest를 만든다. 영상(MJiQFNp-k10)이 안내한 요약 워크플로우 방식(Method B). study-note와 달리 원문 보존이 아니라 "훑고 넘기기"용 압축이 목적. 노트를 거치지 않고 자막에서 바로 생성.
---

# digest-from-transcript (Method B — 자막기반, 영상 방식)

영상 자막을 **직접** 압축해 digest를 만든다. 우리 study-note를 거치지 않는다 — 노트의 취사선택에 안 갇히고 독립적으로, 빠르게.

산출 포맷은 `.claude/skills/_shared/digest-format.md`를 **그대로** 따른다 (Method A와 동일 포맷 → 공정 비교).

## 입력
- YouTube URL (또는 이미 확보된 자막 clean text 경로)
- 저장 경로 (호출 측이 지정; 실험 시 `experiments/.../digest-B-transcript.md`)

## 워크플로
1. **자막 확보**: study-note 스킬 Step 3의 자막 경로 재사용 (yt-dlp Plan A → MCP 폴백). 이미 clean text 파일이 주어지면 그걸 읽는다.
2. **메타 확보**: 제목·채널·게시일·조회수·길이 (yt-dlp `--print` 또는 호출 측 제공).
3. **1패스 통독**: 자막 전체를 한 번 읽어 영상의 큰 그림과 구간 전환점을 파악.
4. **압축**: `_shared/digest-format.md` 포맷으로 채운다.
   - 핵심 요약 3~5불릿: 자막에서 반복·강조되는 메시지 위주.
   - 파트별 타임라인: 자막의 실제 `[mm:ss]`(clean text의 라인 타임스탬프)를 써서 5~10구간.
   - 한 줄 인사이트: 영상이 결국 말하려는 단 하나.
5. **저장 + 보고**: 지정 경로에 저장. 압축률(자막 대비 대략 %)을 보고.

## 원칙
- 압축이 목적 (원문 보존 아님). 그래도 **없는 말 지어내기 금지**, 타임스탬프 날조 금지.
- 화자 주장과 사실 구분 (마케팅 톤 옮기지 않기).
- 자막 음차 오류는 문맥으로 자연 복원하되, 불확실하면 그대로 두고 압축.

## Negative Space
- study-note를 만들지 않는다 (그건 harness-study-note 스킬 몫). 이 스킬은 digest만.
- 원문 인용 블록을 길게 넣지 않는다 (압축 산출물).
