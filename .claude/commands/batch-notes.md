---
description: 여러 YouTube URL을 한꺼번에 받아 각각을 별도 서브에이전트(study-note-worker)로 격리 처리한다. 동시 3개씩 배치로 처리하며, 한 영상이 실패해도 나머지는 계속 진행. 사용법&#58; /batch-notes 다음 줄부터 URL을 한 줄에 하나씩 붙여넣기.
---

# /batch-notes — 일괄 노트 생성

## 사용자가 준 입력

다음 텍스트 안에 YouTube URL들이 한 줄에 하나씩 들어있다:

$ARGUMENTS

## 너의 작업

### Step 1: URL 파싱
입력에서 YouTube URL만 추출한다. 추출 규칙:
- `youtube.com/watch?v=` 또는 `youtu.be/` 패턴
- 한 줄에 하나라고 가정하되, 같은 줄에 다른 텍스트가 섞여 있어도 URL만 골라낸다
- 중복 URL은 한 번만 처리 (같은 배치 입력 안에서의 중복 제거. 이미 디스크에 노트가 있는 영상은 각 worker의 스킬 Step 0.5가 별도로 걸러낸다)
- 추출 결과를 번호 매긴 리스트로 사용자에게 먼저 보여주고, **추출된 URL 개수와 함께 진행 여부를 확인**한다

예: "총 12개 URL을 찾았어요. 3개씩 배치로 처리할게요 (4 배치). 진행할까요?"

### Step 1.5: 게시일 + 채널 + 자막 일괄 prefetch (dispatch 전 필수)

`study-note-worker`에는 셸 도구가 없어 worker 단독으로는 `yt-dlp`를 실행하지 못한다 (스킬 Step 1의 ⚠ 참조). 그대로 두면 worker가 WebSearch/r.jina.ai로 흘러가 게시일이 하루씩 어긋나는 사고가 난다 (`.claude/known-issues.md` §1). 그래서 **메인이 dispatch 전에 게시일과 채널 핸들을 미리 뽑아 worker에 넘긴다.**

승인된 URL 전체에 대해 한 번에 실행:

```
yt-dlp --skip-download --print "%(id)s|%(upload_date)s|%(uploader_id)s" <URL>   # URL마다, 또는 루프로 일괄
```
- Windows에서 PATH에 없으면 `$env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"` 선행.
- `YYYYMMDD` → `YYYY-MM-DD` 변환. `uploader_id`는 `@핸들` 형태일 때 `@` 제거 후 핸들 슬러그로 사용.
- URL ↔ {게시일, 채널 슬러그} 매핑 표를 만든다.
- **새 채널 발견 시 사용자 확인**: 입력 URL 중 `notes/<핸들>/` 폴더가 아직 없는 채널이 있으면, 진행 전에 그 채널 목록을 사용자에게 한 번 보여주고 "이 채널들도 진행할까요? (`notes/<핸들>/` 폴더를 새로 만듭니다)" 확인을 받는다.
- 어떤 URL의 게시일을 못 뽑으면 그 URL만 표시해두고, 해당 worker에는 게시일 없이 보내 스킬의 WebSearch→사용자입력 fallback을 타게 한다 (나머지는 정상 진행).
- 채널 슬러그를 못 뽑으면 그 URL은 dispatch에서 보류하고 사용자에게 핸들을 묻는다 (저장 경로를 결정 못 함).

#### 자막 prefetch (메타와 같은 패스)

worker는 셸이 없어 yt-dlp를 못 돈다. 자막도 메인이 미리 받아 dedup해 clean text 파일로 worker에 넘긴다 (스킬 Step 3의 Plan A를 메인이 대행). **중복 노트 검사(영상 ID) 후 남은 URL에 대해서만** 실행해 이미 정리된 영상의 자막을 받는 낭비를 막는다.

승인된(중복 제외된) URL마다:
```bash
export PATH="$HOME/scoop/shims:$PATH"
yt-dlp --skip-download --write-auto-subs --sub-langs ko,en --sub-format vtt \
  -o "<scratch>/<videoId>.%(ext)s" <URL> --no-update
awk -f scripts/vtt-to-text.awk "<scratch>/<videoId>.ko.vtt" > "<scratch>/<videoId>.txt"   # ko 없으면 .en.vtt
```
- `<scratch>`는 세션 scratchpad 폴더. clean text 파일 절대경로를 URL별로 매핑 표에 기록.
- yt-dlp가 빈 자막/에러면 스킬 Step 3.3(세션당 1회 `yt-dlp -U` 후 재시도)을 적용. 그래도 실패면 그 URL은 **자막파일 없이** dispatch → worker가 MCP 폴백.
- 자막 prefetch는 메타 prefetch와 한 번의 yt-dlp 호출로 합쳐도 된다(`--print`와 `--write-auto-subs` 병행). 실측으로 더 단순한 쪽 선택.

### Step 2: 사용자 승인 후 배치 실행

승인되면 URL 리스트를 배치(기본 3개, `--concurrency` 지정 시 그 수만큼, 최대 5)로 묶어 처리한다.

각 배치 안에서:
- 배치 크기만큼의 `study-note-worker` 서브에이전트를 **동시에** 호출 (Task tool 사용)
- 각 worker에게 **URL + 게시일(확정) + 채널 슬러그 + 권장 파일명 + 자막파일(clean text 절대경로, 있으면)**을 전달한다. worker에게 "자막파일이 있으면 그걸 자막으로 쓰고, 없거나 비면 MCP(get_timed_transcript→get_transcript)로 폴백하라. 게시일·채널은 그대로 쓰고 yt-dlp/WebSearch/r.jina.ai를 게시일 용도로 호출하지 말라"고 지시한다.
- 저장 경로는 `notes/<채널>/<파일명>`. worker는 그 폴더에만 쓴다.
- 배치의 worker가 모두 끝날 때까지 대기

배치가 끝나면 짧게 보고:

```
배치 1/4 완료 (3/12)
  ✅ <파일명1>
  ℹ️ <파일명>: 자막 MCP 폴백 (yt-dlp prefetch 실패)
  ⏭️ <URL2>: 이미 정리됨 (<기존 파일명>)
  ⚠️ <URL3>: <실패 사유 한 줄>
```

다음 배치로 진행.

### Step 3: 전체 완료 보고

모든 배치가 끝나면 종합 보고:

```
총 12개 URL 처리 완료
✅ 성공: 9개
⏭️ 중복 건너뜀: 1개
⚠️ 실패: 2개 (사유별로 묶어서)
🔍 검수 권장: 3개 (불명확 마커 다수 또는 자발적 보강 있음)

생성된 파일:
  - <파일명1>
  ...

다음에 할 일:
  - 실패한 영상은 수동 처리 또는 재시도
  - 검수 권장 파일은 직접 열어 확인
```

### Step 3.5: 중복 영상 재처리 확인
중복으로 건너뛴 영상이 1개 이상이면, 종합 보고 **뒤에** 한 번 묻는다:

```
⏭️ 다음 N개는 이미 정리되어 있어 건너뛰었어요:
  - <URL> → <기존 파일명>
  ...
다시 만들까요? (실수로 중복 입력한 거면 무시하셔도 됩니다)
```

- 사용자가 재처리를 원하면, 해당 URL만 모아 worker를 다시 호출하되 **기존 파일 덮어쓰기 전 개별 확인**한다.
- 원하지 않으면 그대로 종료. 기존 노트는 유지된다.

### Step 4: 채널별 INDEX.md 일괄 갱신

worker들이 `INDEX.md`를 직접 편집하지 않는 이유는 병렬 race condition 때문이다 (스킬 Step 9 참조). 메인이 받은 보고를 모아 채널별로 한 번에 처리한다.

순서:

1. **메타 수집·라우팅**: 각 worker 종료 보고에서 `INDEX_BLOCK_BEGIN` ~ `INDEX_BLOCK_END` 사이 블록을 추출. 첫 줄의 `채널: <handle>`로 라우팅 키 결정. 성공한 노트만 대상. 실패·중복 건너뜀은 색인에 추가하지 않는다. 라우팅 후 `채널:` 줄은 INDEX 본문에 옮기지 않는다.

2. **중복 점검**: 채널별로, 추출한 블록의 파일명(또는 본문 안의 영상 ID)이 해당 채널 `notes/<handle>/INDEX.md`에 이미 있으면 그 항목을 새 블록으로 교체한다. 같은 영상 ID로 새 노트를 만들어 덮어쓴 경우에 발생.

3. **삽입 위치**: 각 블록은 `## YYYY-MM-DD —`로 시작한다. 게시일 오름차순(오래된 것이 위)을 유지하도록 그 채널 INDEX의 적절한 위치에 끼워 넣는다.

4. **새 채널 처리**: 그 채널의 `INDEX.md`가 아직 없으면 새로 만든다(헤더 한 줄 + 블록). 루트 `INDEX.md` 채널 카탈로그 표에도 새 행을 추가한다 (채널 핸들 / 채널명 / 노트 수 / 기간 / 색인 링크).

5. **카탈로그 카운터 갱신(선택)**: 이미 있는 채널이라도 노트 수와 기간이 바뀐다. 루트 `INDEX.md` 표의 해당 행 카운트·기간을 갱신한다.

6. **검증**: 갱신 후 모든 채널 INDEX에 추가된 블록 수 합 = 성공한 노트 수인지 확인. 불일치면 보고.

7. **요약 보고**: 종합 보고 끝에 "INDEX 갱신: <handle> +N (...) · 루트 카탈로그 갱신" 한 줄로 보고.

## Negative Space

- 한 영상의 실패가 다른 영상 처리를 중단시키면 **안 됨**. 격리 유지.
- 같은 영상을 두 번 처리하지 말 것 (Step 1에서 중복 제거)
- 사용자 승인 없이 Step 2 진입 금지 — 잘못 붙여진 URL이 많은 비용을 일으킬 수 있음
- 서브에이전트의 작업 중간 출력을 메인 컨텍스트로 끌어오지 말 것 (요약 보고만)

## 동시성 한계

배치 크기 3은 안전한 기본값. Claude Code의 rate limit·사용량 한도를 고려한 선택이다.
사용자가 명시적으로 `/batch-notes --concurrency=5` 같이 지정하면 그 값 사용 (단 최대 5).