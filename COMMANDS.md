# Claude Code 명령어 — 아주 짧은 정리

Claude Code에서 "명령어"는 `/이름` 형태로 부르는 **정형 작업 단축키**다. 채팅에 길게 설명하는 대신 `/이름`만 치면 Claude가 미리 정의된 워크플로를 실행한다. (파일 위치: `.claude/commands/<이름>.md`. 비슷하게 `.claude/skills/`의 **스킬**은 특정 요청 패턴에서 자동 발동하는 전문 매뉴얼이다.)

## 이 저장소의 명령어·스킬

| 부르는 법 | 하는 일 | 종류 |
|---|---|---|
| YouTube URL + "정리해줘" | 영상 1편을 규칙대로 study-note 1편으로 저장 | 스킬 `harness-study-note` |
| `/batch-notes` + URL 여러 줄 | 여러 영상을 서브에이전트로 격리·병렬 정리 | 커맨드 |
| `/collect-new [--since=어제] [--cap=20]` | 추적 채널(`notes/<주제>/<채널>/`)의 신규 영상을 **무인** 감지→정리 | 커맨드 |
| `/digest <URL>` | 영상을 digest(시간순 전문 + 주제별 상세요약)로 `digests/<주제>/<채널>/`에 저장 | 커맨드 |

## 한눈에

- **한 편** 정리 → URL 주고 "정리해줘"
- **여러 편** 한꺼번에 → `/batch-notes`
- **채널 신규 자동** → `/collect-new` (스케줄러 연동 가능)
- **영상 안 보고 파악용 정리글** → `/digest` (분석 노트와 별개, `digests/`에 저장)

> 더 깊은 규칙은 `CLAUDE.md`(프로젝트 헌법)와 `.claude/skills/harness-study-note/SKILL.md`(실행 룰북)에.
