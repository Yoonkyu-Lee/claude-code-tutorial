# HARNESS_ELEMENTS.md — 좋은 Claude Code 하네스의 구성 재료

> **2026-06-05 시점 distill 스냅샷.** 이 파일은 사람이 읽기 위한 시점별 정리이며, `harness-bootstrap` 스킬은 이 파일을 읽지 않는다 — 스킬은 매 발동마다 `notes/`에서 fresh distill한다 (참조: `~/.claude/skills/harness-bootstrap/references/synthesis-protocol.md`).
>
> 이 문서는 study-note 모음에서 추출한 **재료**다. 다음에 만들 하네스 관련 스킬의 입력으로 쓴다. 판단·설계는 별도 단계에서 한다.
>
> **수치 caveat**: 아래 정량 수치(점수·퍼센트)는 노트가 **화자 주장**으로 기록한 값이며, 상당수는 노트 자체에서 1차 출처 `[불명확]`으로 표기돼 있다. 재료로만 쓰고 사실 단정에 인용 시 원 출처를 재확인할 것.

## 0. 핵심 명제 — "모델보다 하네스"

- **명제**: 모델이 병목이 아니라 하네스가 병목이다. 모델은 천장, 하네스는 그 천장에 얼마나 가까이 갈지를 정하는 사다리. (harness-engineering [02:12], harness-matters [07:53], [13:28])
- **왜 하네스가 경쟁우위인가**: 모델은 몇 주면 따라잡히지만(GPT↔Claude↔Gemini) 하네스는 복제가 어렵고, 스킬·도메인 매뉴얼은 모델을 갈아타도 안 죽는 **누적 자산**이다. (harness-engineering [04:42], [04:55]; harness-matters [05:32], [05:49])
- **근거 수치** (화자 주장):
  - Cursor 실험: 같은 Claude 모델·같은 벤치마크인데 주변 시스템에 따라 **46 ↔ 80점** (harness-matters [01:12])
  - 스탠포드 연구 인용: 하네스를 잘 짜면 품질 **28%→47%**, 프롬프트만 다듬으면 **3% 미만** (harness-matters [02:29])
  - Anthropic 자체 데이터 인용: 같은 Opus를 그냥 쓰면 **42점**, Claude Code 하네스 안에서 **78점** (harness-matters [08:27])
  - OpenAI Codex 내부 사례: 하네스 세팅 전엔 느렸으나 환경·도구연결·에러복구를 잡자 폭발적 성과 → 5개월 100만 줄, PR 1500개 머지, 엔지니어 1인 하루 3.5작업 (harness-engineering [03:01~03:19])
- **메타 진화**: 프롬프트 엔지니어링(2022~) → 컨텍스트 엔지니어링(2025) → **하네스 엔지니어링(2026)**. (harness-engineering [00:06~05:36])
- **관통하는 태도**: vibe coding이 아니라 **vibe review** — 코드를 맡기되 뭘 만드는지 알고 있어야 한다. (system-not-tool [06:03]) / "AI는 생각을 대체하지 않고, 한 생각을 증폭하거나 안 한 생각의 부재를 증폭한다." (rpi [07:18])

## 1. 하네스 구성 요소 (각각 무엇이고 언제 필요한가)

### A. CLAUDE.md / AGENTS.md (프로젝트 지시 파일)
- **정체**: 프로젝트의 "회사 매뉴얼". 신입이 첫날 받는 업무 매뉴얼. (system-not-tool [03:58])
- **언제**: 하네스의 기본 중 기본. 모든 프로젝트의 출발점. "컨텍스트 파일을 제발 제대로 쓰세요." (harness-engineering [03:52])
- **운영 규칙**:
  - 짧게 유지(~50줄). 길수록 헷갈림 — "출근 첫날 300쪽 사규를 외우게 하면 헷갈려요." (50-tips [02:17])
  - 계층 구조: 글로벌(본사) + 폴더별(지점), 지점 우선. (50-tips [01:56~02:10])
  - 부서별 분리: 큰 매뉴얼 하나가 아니라 도메인/부서별 작은 매뉴얼. (anthropic-five-tools [03:23~03:35])
  - 필수 3요소: ① 뭘 만드는 프로젝트인지 ② 어떤 도구 쓰는지 ③ **검증 방법(체크리스트)=검수 라인**. (50-tips [02:49])
  - 갱신: 실수가 반복되면 직접 고치지 말고 AI에게 "다신 안 그러게 매뉴얼 업데이트 해 줘." (50-tips [07:57])

### B. Skills (전문 매뉴얼 / 반복 작업 묶음)
- **정체**: 특정 분야 전문 지식을 담은 파일. "일반 클로드가 동네 의사라면 스킬을 붙이면 전문의." (harness-explained [00:51])
- **언제**: 같은 작업/리팩토링을 **3번 이상** 반복하면 스킬로 옮길 신호. 한 페이지면 충분 — 언제 발동·어떤 순서·끝나고 뭘 확인. (harness-matters [11:05]; ppt-skill [05:55])
- **핵심 가치**: 쓸 때마다 다듬으면 누적 자산이 되고, 모델을 갈아타도 안 죽는다. (harness-matters [05:32], [05:49])
- **호출**: `/스킬이름` 슬래시로 발동. (harness-explained [01:30])
- **구조**: Progressive Disclosure(목차→필요한 챕터만) — 1,500줄 스킬도 필요 부분만 펴봐서 자원 40~60% 절감. (six-month-reddit [05:06~05:30]; skills-folder [03:56~04:15])

### C. Subagents (전문 에이전트)
- **정체**: 역할별 전문 AI 팀원. 혼자 다 시키면 들쑥날쑥하므로 역할 분리. (six-month-reddit [11:32])
- **언제 (적합)**: 자료 조사처럼 **독립적인 일**, 그리고 코드 리뷰(자기 코드 자기 리뷰가 의외로 잘 됨 — 누락·취약점·일관성 포착). (50-tips [13:20]; six-month-reddit [12:19])
- **언제 (부적합)**: CEO/디자인/테스팅 에이전트처럼 역할을 잘게 쪼개는 건 최악 — 분신은 메인 책상 자료를 못 가져가서 맥락이 끊김. (50-tips [13:12~13:20])

### D. Slash Commands (커맨드)
- **정체**: "이 문제 스스로 해결해 줘"처럼 정형 작업을 한 번에 호출. 에이전트는 관련 파일을 스스로 열고 파악·수정·확인까지 함. (harness-explained [03:29])
- **언제**: 반복 호출하는 정형 워크플로를 단축. (50-tips 슬래시 명령어 항목)

### E. Hooks (자동 트리거 / 강제 장치)
- **정체**: "이런 일이 벌어지면 자동으로 저걸 해" — 트리거 기반 자동 시스템. (system-not-tool [03:24])
- **언제 / 왜**: CLAUDE.md 규칙은 "부탁"이라 AI가 슬슬 무시함. Hooks는 **강제**다 — "메모장에 먼저 적으세요"로 딱 막음. (system-not-tool [03:08], [03:39])
- **활용**: 시작 전 귀띔(PreToolUse), 완료 후 체크(PostToolUse/Stop), 작업 끝나면 자동 lint/build/test로 먼저 거르기. (six-month-reddit [04:03~04:19]; harness-matters [11:49])
- **연동**: DDD 구조 + 도메인 트리거를 달면 "결제 환불 만들어줘" → 결제 도메인 파일을 알아서 먼저 읽음. (ddd [04:55~05:39])

### F. MCP (외부 도구 연결)
- **정체**: AI가 외부 도구(브라우저·문서검색·디자인툴)를 쓰게 해주는 어댑터/전화기. 콘센트처럼 표준화돼 있음. (harness-engineering [04:04]; 50-tips [12:45~12:53])
- **언제**: 외부 시스템 연동이 필요할 때만. **많이 깔수록 나쁨** — 토큰 폭발, 책상 어지러움. "진짜 필요한 것만." (harness-engineering [04:12]; 50-tips [06:29])

### G. Plugins (통째 셋업 패키지)
- **정체**: 스킬·외부도구·서브에이전트·자동화 스크립트를 한 묶음으로 공유. (50-tips [15:59])
- **언제**: 좋은 셋업이 한 사람에게만 머무는 걸 막고 **팀 전체로 전파**할 때. (anthropic-five-tools [05:41])

### H. LSP (정밀 검색, Language Server Protocol)
- **정체**: 같은 이름의 함수/변수가 수백 개일 때 정확히 어느 것인지 짚어주는 시스템. (anthropic-five-tools [05:55~06:03])
- **언제**: 대규모 코드베이스 — AI가 후보를 다 열어보며 토큰 낭비하는 걸 방지.

## 2. 요소별 "언제 필요한가" 결정 기준 (종합 표)

| 요소 | 도입 신호 (이럴 때) | 안 해도 될 때 / 주의 |
|---|---|---|
| CLAUDE.md | 항상 — 프로젝트 시작 즉시 | 길어지면 오히려 해 (§5.1 참조). ~50줄 유지 |
| Skills | 같은 작업 **3회+** 반복 | 1회성 작업엔 과함 |
| Subagents | 독립적 자료조사 / 코드 리뷰 | 맥락 공유 필요한 분업(테스팅 등)엔 부적합 |
| Slash Commands | 반복 호출 정형 워크플로 | — |
| Hooks | 규칙을 AI가 자꾸 무시 → **강제** 필요 / 자동 검사 | 규칙이 "부탁"으로 충분하면 후순위 |
| MCP | 외부 시스템 연동 필수 | 불필요하게 많이 X (토큰·혼란) |
| Plugins | 셋업을 팀에 전파 | 1인/단일 프로젝트면 후순위 |
| LSP | 대규모 코드베이스, 동명 심볼 다수 | 소규모면 효용 낮음 |

## 3. 프로젝트마다 달라지는 변수

- **기술 스택**: AI가 많이 학습한 스택일수록 유리. 노트 추천은 프론트 Next.js+TypeScript / 백엔드 FastAPI+Python, "타입을 빡세게". 회피로 거론: Spring Boot(코드량↑→컨텍스트 터짐), Rails, Node ORM 생태계 미성숙. (stack [01:12~06:34]) — **단, 이는 한 화자의 선택이며 프로젝트별로 다름**
- **아키텍처 패턴(DDD)**: 도메인 정의 파일(`context.md`), 모델/리포지토리/서비스 3구성, 도메인 경계=코드 경계. (ddd [01:39~01:56]; why-degrades [03:08])
- **도메인 언어/규칙**: "개발자끼리·도메인 전문가와 같은 단어를 쓰자" → AI 환각 감소·코드 간결. 프로젝트마다 다른 용어집. (why-degrades [02:57~03:08])
- **테스트 전략(TDD)**: 테스트 먼저→통과 코드→정리. 유닛 크기·mock 범위는 코드베이스마다 다름. (why-degrades [03:52~04:31])
- **코딩 컨벤션·폴더 구조의 규칙성**: 규칙 없으면 AI·사람 모두 전부 머리에 넣어야 함→컨텍스트 터짐. (why-degrades [04:40~05:05])
- **git 습관**: RPI의 Implement 단계에서 "자주 커밋" 강조. (rpi Step 3)
- **참조 산출물 표준(design.md 등)**: 색상/폰트/간격 토큰 + 사람이 읽는 설명. 프로젝트 브랜드마다 값이 다름. (design-md, §5.3 참조)
- **첫 도메인은 직접 손으로**: 한 번 손으로 짜봐야 AI 결과가 맞는지 판단 가능. (ddd [06:15~06:24])

## 4. 불변(공통 원칙) vs 프로젝트별 변수 (종합 표)

| 구분 | 항목 | 출처 |
|---|---|---|
| **불변 (모든 프로젝트 공통)** | DDD(도메인 언어 일치), TDD(작은 단위·피드백 루프), RPI(코딩 전 Research→Plan), 컨텍스트 엔지니어링(저장·선별·정리·분할), Dumb Zone 관리(40% 차면 새 세션), 스킬 기반 규칙성 강제, vibe **review** | why-degrades, ddd, rpi, context-eng, dumb-zone |
| **프로젝트별 변수 (정해줘야 함)** | 기술 스택, 도메인 정의/용어집, 아키텍처 경계, 테스트 단위·전략, 폴더/네이밍 컨벤션, git 습관, 디자인 토큰 값, 어떤 MCP/Hook/스킬을 깔지 | stack, ddd, why-degrades, design-md |

## 5. 좋은 CLAUDE.md / 스킬의 조건

### 5.1 좋은 CLAUDE.md/AGENTS.md
- **써야 할 것**: AI가 코드만 봐선 **모를 것만** — 도구 제약(예: 패키지는 UV로만), 경험으로 발견한 비관적 규칙(예: 테스트 시 no-cache 필수), 시스템 특화 맥락(예: "이 함수 건드리면 외부연동 다 무너짐"). (agents-md-auto [04:11~04:42])
- **빼야 할 것**: AI가 코드/`package.json`만 봐도 아는 자명한 정보(리액트 씀, 폴더 구조 등). (agents-md-auto [03:04])
- **ETH 취리히 연구 인용**: AI 자동생성 파일은 성공률 2~3%↓·비용 20%↑, 사람 작성은 4%↑ (차이 6~7%p). → "정확한 게 중요. 짧아도 됨." (agents-md-auto [01:55~02:24], [04:49])
- **경고 신호**: "건드리지 마세요"가 10개↑면 설계가 잘못된 신호. 매뉴얼을 늘리기 전에 **설명이 필요 없는 구조**로 만들어라. (agents-md-auto [06:09~06:24])

### 5.2 좋은 스킬
- **SKILL.md 구조**: frontmatter `name`(≤64자), `description`(트리거 매칭용) + 본문(동작 규칙·참고자료), 선택 폴더 `scripts/`·`references/`·`assets/`. (skills-nondev [05:54])
- **Progressive Disclosure**: 목록/목차만 먼저, 필요할 때만 펴봄 → 수백 개여도 버팀. (skills-folder [03:56~04:15])
- **선택 6기준** (six-criteria):
  1. **만든 곳(가장 중요)** — 모르면 안 씀 [01:03~01:33]
  2. **업데이트 빈도** — 커밋 기록, 한 달+ 멈추면 의심 [01:55]
  3. **평판** — 스타 수 함정, 이슈판의 실사용자 말이 진짜 [02:11~02:46]
  4. **도메인 전문성** — 그 일 오래 한 사람이 쓴 매뉴얼. 안 해본 사람이 베껴 쓴 건 AI 슬롭 [03:09~03:27]
  5. **보안/권한** — 파일·명령·외부연결 어디까지 손대는지 [03:46]
  6. **소규모 테스트(POC)** — 중요 작업 바로 투입 X, 작게 먼저 [04:03~04:12]
- **토큰 효율**: 간결성 스킬(Caveman)은 출력 토큰 ~65%↓, 메모리 파일 ~46%↓ (정확도 유지/향상). (caveman [04:26], [05:23])
- **일관성·재사용성**: 토큰 절약보다 더 중요한 건 결과가 들쑥날쑥하지 않는 일관성. 형식 통일 덕에 이번 달 배운 걸 다음 달에도 그대로. (design-md [06:22]; skills-folder [05:46])

### 5.3 참조 산출물 표준 패턴 (design.md)
- **위치/연동**: 루트에 `README` 형제로 `design.md`, CLAUDE.md에 `@design.md` 한 줄 추가하면 전 작업에 디자인 규칙 자동 적용. (design-md [03:20], [04:39])
- **구조**: 상단 YAML(색·폰트 등 머신리더블 토큰) + 하단 prose(사람용 설명). 카테고리 8종(색상/타이포/간격/모서리/그림자…). (design-md [03:42~03:55])
- **표준**: W3C DTCG 디자인 토큰 표준 준수("디자인 세계의 콘센트"). (design-md [06:45~07:03])
- **시작은 최소**: 색 5개·폰트 2~3개부터. 효과: 프롬프트 ~30줄 → ~1줄. (design-md [05:13], [11:10])

## 6. 하네스 도입 순서 (여러 노트 종합)

- **harness-engineering 기초 3가지** [03:45~05:08]: ① CLAUDE.md 제대로 ② MCP 세팅 ③ Skill 파일.
- **harness-matters 실전 4단계(한 달에 하나)** [10:43~12:00]: ① 작업 전 계획부터 쓰게 → ② 3회+ 반복은 스킬로 → ③ 코드를 도메인 단위로 → ④ 자동 검사(lint/test). "이 4단계가 곧 당신만의 하니스."
- **anthropic-five-tools 5단계** [07:43~08:26]: ① 책임자(DRI) 지정 → ② CLAUDE.md부터(짧게 시작) → ③ AI가 코드 찾기 쉽게 폴더 정리 → ④ 부서별 가이드·플러그인으로 전파 → ⑤ (큰 회사면) 검수 절차.
- **성공 회사 공통 패턴 3** (anthropic-five-tools [06:34~07:39]): 3~6개월 주기 정기 점검(낡은 규칙이 똑똑해진 AI 발목 잡음), DRI 한 명, AI 운영 매니저(Agent Manager) 직책.
- **워크플로 패턴 (구현 사이클)**:
  - **RPI 루프**: Research(코딩 금지, 탐색만)→Plan(파일/변경/테스트 계획, 코딩 금지)→Implement(새 세션, 플랜만 올림). 모델 분리: 리서치·플랜 Opus / 구현 Sonnet·Codex. 각 단계 사람 확인. (rpi [05:20~06:51])
  - **Superpowers 강제 4단계**: 브레인스토밍→TDD(기준 먼저, 없으면 지우고 다시)→팀 분리(Opus 팀장/Haiku 팀원)→프로젝트 복사본으로 충돌 방지. (superpowers [01:20~05:41])
  - **에반 전체 사이클(2~3h)**: GrillMe 인터뷰(`context.md`)→Office Hours 6질문 비즈니스 검증(여기까지 코드 0줄)→Light Spec→Light Plan→Plan Review(별도 에이전트)→Subagent 구현→Codex 교차검수→Improve Codebase Architecture 리팩토링. (workflow-reveal [04:59~08:36])
  - **컨텍스트 엔지니어링 4전략**: 저장·골라주기(기능 30개 이하면 정확도 3배)·정리·나눠주기. Manus 교훈: To-do 리스트, 실수 기록 남기기, 캐싱. (context-eng [04:18~07:07])
  - **Dumb Zone 관리**: 기억 공간 ~40% 차면 성능 저하 → 요약 후 새 세션, 컨텍스트 게이지 50% 넘으면 전환. (dumb-zone [01:28~02:25]; rpi [04:36~04:56])

## 7. AI 코드가 시간이 지나며 망가지는 원인 → 구조적 장치 (why-degrades, ddd)

- **원인**: 소프트웨어 엔트로피 + 반복. AI는 눈앞 변경만 보고 전체 설계는 무시 → 100~1000번 맡기면 못 알아볼 코드. "나쁜 코드는 그 어느 때보다 비싸졌다." (why-degrades [00:00~01:44])
- **4 실패 패턴 → 해법**: ① 공유된 디자인 컨셉 부재 → 디자인 컨셉 먼저 ② 도메인 언어 불일치 → DDD ③ 피드백 루프 부재 → TDD ④ 규칙성 없음 → 리팩토링 + 스킬로 규칙 강제. (why-degrades 전체)
- **DDD가 듣는 이유**: AI 코딩의 핵심은 창의력이 아니라 **패턴 인식**(기존 패턴 복제) + 컨텍스트 축소(도메인 단위로 필요한 부분만) + 이름 일치(말과 코드가 같은 언어). (ddd [02:24~04:36])

---

## 출처 노트 (파일명)
harness-explained=`2026-03-04-claude-code-harness-explained.md` · harness-matters=`2026-05-19-harness-matters-more-than-model.md` · harness-engineering=`2026-02-18-harness-engineering-the-quiet-design.md` · anthropic-five-tools=`2026-05-20-anthropic-five-tools-large-codebases.md` · system-not-tool=`2026-02-13-claude-code-system-not-tool-four-principles.md` · six-month-reddit=`2026-02-21-six-month-ai-harness-reddit-system.md` · 50-tips=`2026-05-11-claude-code-50-tips-from-10-months.md` · why-degrades=`2026-04-29-why-ai-code-degrades-over-time.md` · ddd=`2026-02-22-ddd-structure-for-ai-coding.md` · rpi=`2026-04-26-agentic-engineering-rpi-loop.md` · context-eng=`2026-02-17-context-engineering-not-prompting.md` · dumb-zone=`2026-02-23-why-ai-increases-your-workload.md` · gstack-review=`2026-04-15-gstack-superpowers-workflow-review.md` · superpowers=`2026-03-28-superpowers-110k-stars-one-line-install.md` · workflow-reveal=`2026-05-05-ai-workflow-complete-reveal.md` · stack=`2026-02-14-vibe-coding-stack-nextjs-fastapi.md` · agents-md-auto=`2026-03-04-agents-md-auto-generated-hurts-performance.md` · design-md=`2026-04-30-design-md-google-spec-explained.md` · six-criteria=`2026-05-14-six-criteria-choosing-ai-skills.md` · skills-folder=`2026-03-08-skills-folder-makes-ai-team-expert.md` · skills-nondev=`2026-02-12-claude-skills-for-non-developers.md` · caveman=`2026-05-11-caveman-skill-token-savings.md` · ppt-skill=`2026-02-08-skills-one-click-ppt-generation.md`
