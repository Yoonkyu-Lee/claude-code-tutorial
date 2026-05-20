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

---

## 새 항목 추가 절차

Claude가 새 재발 패턴을 발견했을 때:

1. 작업 종료 보고에 "재발 패턴 발견" 항목으로 보고
2. 해결법 후보 2~3개를 트레이드오프와 함께 제시 + 추천안 명시
3. 사용자가 채택안을 결정하면 그 결정으로 이 파일에 항목 추가
4. 관련 스킬·룰북도 함께 갱신 (역시 사용자 승인 후)

CLAUDE.md §9 4번 항: 사용자 결정을 자기 판단으로 뒤집지 않는다.
