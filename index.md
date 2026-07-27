# Study Note Index — 주제 카탈로그

이 저장소의 모든 study-note는 `notes/<주제>/<채널-handle>/` 아래에 모인다 (주제 → 채널 → 노트).
각 주제의 채널 카탈로그는 그 주제 폴더의 `index.md`, 각 채널의 노트 색인은 채널 폴더의 `index.md`에 있다.

새 주제/채널을 추가할 때:
1. 새 주제면 `notes/<주제>/` + `notes/<주제>/index.md`(채널 카탈로그) 생성 후 아래 주제 표에 한 행 추가.
2. 새 채널이면 `notes/<주제>/<handle>/` + 그 안에 빈 `index.md` 생성 후 해당 주제 INDEX에 한 행 추가.

## 주제 카탈로그

주제마다 두 트리가 있다: **notes**(교차검증 연구 노트)와 **digests**(영상 1편=digest 1편). 각 링크는 그 주제의 채널 카탈로그 페이지로 간다.

| 주제 | 설명 | notes 색인 | digest 색인 |
|---|---|---|---|
| `ai-coding` | Claude Code·AI 코딩·하니스 | [notes](notes/ai-coding/index.md) (채널 2) | [digests](digests/ai-coding/index.md) (채널 5) |
| `business` | 비즈니스·부업·수익화 | [notes](notes/business/index.md) (채널 1) | [digests](digests/business/index.md) (채널 3) |
| `tech` | IT·테크 뉴스·디스플레이·반도체·보안 | — | [digests](digests/tech/index.md) (채널 5) |

## 다른 트리

- [digests/](digests/index.md) — 영상 digest(시간순 전문 + 주제별 상세요약). `notes/`와 별개 워크플로, 같은 `<주제>/<채널>/` 계층.
- [conference/](conference/README.md) — 여러 영상·자료를 가로질러 한 주제를 비판적으로 토론·재구성한 원본 문서(회의 산출물). 영상 요약이 아니라 독립 분석·판단·실행계획.

## 분석 산출물 (주제 무관)

- [HARNESS_ELEMENTS.md](HARNESS_ELEMENTS.md) — 노트들에서 추출한 하니스 요소 정리 (다음 스킬의 재료)
- [COMMANDS.md](COMMANDS.md) — 이 저장소 명령어 짧은 정리
