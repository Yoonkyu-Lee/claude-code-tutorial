# Caption Corrections — 한국어 자동자막 영문 고유명사 정정 사전

`harness-study-note` 스킬 Step 4("자막 품질 정정")에서 참조하는 사전.
한국어 YouTube 자동자막이 영문 고유명사·기술 용어를 한글 음차로 잘못 잡는 패턴을 모았다.

## 사용법

자막을 처음 훑을 때 이 표를 머릿속에 띄워두고, 음차 → 정확 표기로 컨텍스트 정합 시 자동 치환한다.
**컨텍스트로 95% 이상 확실한 경우에만** 정정. 모호하면 `[불명확: 원문 "..."]`.

첫 등장 시 한 번 보정 사실을 각주로 노출 (스킬 Step 4 규칙).

## A. AI·Claude·Anthropic 생태계

| 음차 (자동자막) | 정확 표기 | 비고 |
|---|---|---|
| 클로드, 클로드 코드 | Claude, Claude Code | 가장 빈번 |
| 앤트로픽, 안트로픽, 안쓰로픽 | Anthropic | |
| 오퍼스, 오푸스, 오포스 | Opus | Claude 모델 |
| 소넷, 쏘네 | Sonnet | Claude 모델 |
| 하이쿠, 하이큐 | Haiku | Claude 모델 |
| 콜드 | Code | "콜드를 잃는 AI" 같이 잘못 잡힘 |
| 어스 | us | 자주 단독 단어로 오인 |
| 한스 | 하니스 (harness) | 채널 고유 용어 |
| 스킬 | Skill | 일반 단어와 혼동 주의 |
| 멀티션, 멀이션 | Multi-session 또는 Multi-shot | 영상 컨텍스트로 판별 |
| 스킬샵, 스킬샵 | Skill shop / SkillShop | |
| 케이브맨 | Caveman | 영상 고유 비유 |
| 그릴미 | GrillMe | 스킬 이름 |
| 맥퍼커 | Mac Forker / Mac Worker | [불명확]로 두는 게 안전 |

## B. AI 코딩 도구·에이전트

| 음차 | 정확 표기 |
|---|---|
| 커서 | Cursor |
| 윈드서프, 윈서프 | Windsurf |
| 클라인 | Cline |
| 코덱스 | Codex (OpenAI) |
| 제미니, 제미나이 | Gemini (Google) |
| 오픈에이아이, 오픈AI | OpenAI |
| 깃허브 코파일럿, 깃헙 코파일럿 | GitHub Copilot |
| 데벤 | Devin |
| 아이더 | Aider |
| 컨덕터 | Conductor (Anthropic) |
| 위스퍼 플로우, 위스프르 플로우 | Wispr Flow |
| 옴니클로 | OpenClaw 또는 OmniClaw |
| 헤르메스 | Hermes |
| 비브 코딩 | vibe coding |

## C. 프레임워크·라이브러리

| 음차 | 정확 표기 |
|---|---|
| 패스트 APA, 패스 APA, 패스트 A P 아이 | FastAPI |
| 넥트, 넥트 JS, 넥스트 JS | Next.js |
| 리액트 | React |
| 노드, 노드 JS | Node.js |
| 파이썬, 파이쏜 | Python |
| 자바스크립트, 자바 스크립트 | JavaScript |
| 타입스크립트 | TypeScript |
| 멀이드, 머메이드, 머마이드 | Mermaid (다이어그램) |
| 도커 | Docker |
| 도커 멀티 스테이지 | Docker multi-stage |
| 깃 | Git |
| 깃허브, 깃헙 | GitHub |
| 깃랩 | GitLab |

## D. 영문 약어 (자막이 한 글자씩 분리해서 읽음)

| 음차 | 정확 표기 |
|---|---|
| 엠 씨 피, 엠씨피, M C P | MCP |
| 에이 피 아이, 에이피아이 | API |
| 씨 엘 아이, 시엘아이 | CLI |
| 씨 아이, 시아이 | CI |
| 씨 디, 시디 | CD |
| 유 아이, 유아이 | UI |
| 유 엑스, 유엑스 | UX |
| 아이 디 이, 아이디이 | IDE |
| 에스 디 케이 | SDK |
| 알 에이 지, 알에이지 | RAG |
| 엘 엘 엠, 엘엘엠 | LLM |
| 피 알, 피알 | PR (pull request) |
| 큐 에이 | QA |
| 디 비 | DB |

## E. 동작·플로우 용어

| 음차 | 정확 표기 |
|---|---|
| 모크, 목 | mock |
| 모크업 | mockup |
| 디버깅 | debugging |
| 디버그 | debug |
| 인증 미들웨어 | auth middleware |
| 미들웨어 | middleware |
| 핸들러 | handler |
| 미그레이션 | migration |
| 미그레이션 (DB) | DB migration |
| 컴파일 | compile |
| 트랜스파일 | transpile |
| 디플로이 | deploy |
| 컨테이너 | container |
| 워크플로우 | workflow |
| 파이프라인 | pipeline |
| 토큰 | token |
| 컨텍스트 | context |

## F. 회사·인물

| 음차 | 정확 표기 | 비고 |
|---|---|---|
| 안드레이 카스, 안드레이 카파시 | Andrej Karpathy | "vibe coding" 창시자 |
| 매트 포콕 | Matt Pocock | TypeScript 강사 |
| 스트라이프 | Stripe | |
| 와이즈, 와이즈컴 | Wiz | 보안 회사 |
| 스탠포드 | Stanford | |
| 구글 | Google | |
| 마이크로소프트, MS | Microsoft | |
| 아마존 | Amazon | |
| 메타 | Meta | |

## G. 한국어 발화 안 흔한 영문 단어 (자주 누락·오인식)

| 음차 | 정확 표기 |
|---|---|
| 슬랫시, 슬패스트 | slash (`/`) — "슬랫시 명령" → "/명령" |
| 백 슬랫시 | backslash (`\`) |
| 하이픈, 대쉬 | hyphen / dash |
| 언더 스코어 | underscore |
| 카멜 케이스 | camelCase |
| 케밥 케이스 | kebab-case |
| 스네이크 케이스 | snake_case |

## 메타 규칙

1. **이 표는 95% 확신 사례만**. 모호한 발화는 정정하지 말고 `[불명확: 원문 "..."]`.
2. **첫 등장 시 한 번 각주**로 보정 사실 노출 (스킬 Step 4).
3. **컨텍스트가 충돌하면 사전을 무시**한다 — 예: 영상에서 "콜드"가 정말 "cold"를 가리키면 정정 X.
4. 새 패턴 발견 시 이 파일을 보강 — 단, **노트 작업 중 자동 수정 금지** (CLAUDE.md 6번).
   사용자 명시 요청 시에만 갱신.
