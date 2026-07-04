---
description: 추적 채널(digests/<주제>/<채널>/ 폴더가 있는 채널)의 아직 정리 안 된 영상(중간 갭 + 마지막 이후 신규)을 무인 감지해 digest로 정리하고 커밋·push까지 한다(→ 사이트 자동 갱신). 현재 정리 상태 기준 채널 스캔(시간창 아님). 스케줄러(작업 스케줄러/로컬 루틴)로 매일 돌리는 용도. 사용법&#58; /collect-digest [--cap=20] [--channels=a,b]

---

# /collect-digest — 무인 미처리 영상 digest (매일 자동화용)

추적 채널에서 **아직 digest 안 된 영상(중간 갭 + 마지막 이후 신규)**을 무인 감지 → digest 생성 → **commit + push**한다. push되면 GitHub Actions가 사이트를 자동 재배포한다. 승인 게이트 없이 구조적 상한(하드캡·ID중복·동시성)으로 비용을 통제한다.

`$ARGUMENTS`에서 `--cap`(기본 20) / `--channels`를 읽는다.

## Step 1: 미처리 감지 (갭 + 신규, 시간창 아님)
```bash
export PATH="$HOME/scoop/shims:$PATH"
bash scripts/collect-detect.sh --tree=digests $ARGUMENTS
```
- **감지 방식**: 추적 채널(`digests/*/*/` 폴더가 있는 채널)마다, 그 채널에서 **이미 digest한 것 중 가장 오래된 것(=시작점 앵커)부터 지금까지**를 flat-playlist로 훑어 **아직 digest 안 된 것을 전부** 뽑는다. → 중간에 빠진 **갭** + 마지막 이후 **신규**를 모두 잡는다. (그날 올라왔는지 보는 시간창 방식 아님. 앵커 이전 백카탈로그는 대상 아님.)
- 제외: 이미 `digests/`에 있는 ID + `.claude/digest-skip.txt`(자막 없음 등 처리 불가 확정분).
- stdout = 후보 URL(최신순, cap 기본 20). stderr = 로그(그대로 전달).
- **후보 0이면**: "신규 없음" 로그만 남기고 **종료**(커밋·push 안 함).

## Step 2: 메타 + 자막 prefetch (메인, 셸)
후보 각 URL에 대해:
```bash
# 원제(UTF-8)는 print-to-file로 (콘솔 파이프가 한글을 깨뜨림 — known-issues #6)
yt-dlp --skip-download --print-to-file "%(upload_date)s	%(uploader_id)s	%(view_count)s	%(duration)s	%(title)s" "<scratch>/<id>.meta" "https://youtu.be/<id>" --no-update
# 자막 ko 우선 → dedup
yt-dlp --skip-download --write-auto-subs --sub-langs ko --sub-format vtt -o "<scratch>/<id>.%(ext)s" "https://youtu.be/<id>" --no-update
[ -f "<scratch>/<id>.ko.vtt" ] || yt-dlp ... --sub-langs en ...
awk -f scripts/vtt-to-text.awk "<scratch>/<id>.ko.vtt" > "<scratch>/<id>.txt"
```
- **주제·채널 결정**: `uploader_id`(@handle) → `.claude/channel-handles.tsv`로 슬러그 매핑 → `digests/<주제>/<슬러그>/` 폴더 위치에서 주제 확정. (추적 채널이라 폴더가 이미 존재.)
- **자막을 못 얻은 후보**: ko/en 자동자막이 없으면 digest 불가다. 그 영상 ID를 `.claude/digest-skip.txt`에 한 줄 추가한다 → 다음 실행부터 collect-detect가 재감지하지 않는다(무한 재시도 방지). 그 URL은 이번 배치에서 제외.

## Step 3: digest 생성 (격리 병렬)
후보를 concurrency(기본 3, 최대 5)로 묶어 **`digest-worker`** 서브에이전트를 동시 호출. 각 worker에 전달: URL + 주제 + 채널 슬러그 + 게시일(확정) + 원제 + 조회수/길이 + 자막파일. 저장 경로 `digests/<주제>/<채널>/`. 한 편 실패가 나머지를 막지 않는다.

## Step 4: INDEX 갱신 + commit + push
- 생성된 digest를 `digests/<주제>/<채널>/INDEX.md` 표에 **최신순(최신이 위)**으로 추가. 링크는 **전체 파일명**(`YYYY-MM-DD-slug.md`, 날짜 접두 포함 — 빠뜨리면 사이트 링크가 깨진다).
- **커밋 + push**:
  ```bash
  git add digests/
  git commit -m "digest(<채널>): auto-collect N new video(s) (<날짜>)"
  git push origin main
  ```
  → GitHub Actions가 사이트 재배포. (무인 실행이므로 push 자동. 사용자 상시 승인됨.)
- 후보가 0이었으면 이 Step은 건너뛴다(빈 커밋 금지).

## Step 5: 로그
```
/collect-digest 완료 (window: <FROM..TO>)
신규 N편 digest: <파일 목록>  → push 완료 (사이트 갱신됨)
(또는) 신규 없음.
```

## 스케줄링 (Claude Desktop 로컬 루틴)
1. Claude Desktop → 좌측 **루틴** → 로컬 루틴 생성.
2. 폴더 = 이 저장소 경로.
3. 지침 = `어제 새로 올라온 영상을 digest해줘` (→ `/collect-digest` 발동).
4. 시각 지정(예: 매일 오전 7시) 후 생성.
- 로컬 루틴은 **PC가 켜져 있을 때만** 동작(꺼져 있으면 다음 시각). 원격 루틴 아님.

## Negative Space
- 승인 프롬프트 없음(무인). 4중 상한에 의존.
- 후보 0이면 커밋·push 하지 않는다(노이즈·빈 배포 방지).
- notes/를 건드리지 않는다(이건 digest 전용). 서브에이전트 raw 출력은 메인으로 끌어오지 않는다(로그만).
- 한글 메타는 반드시 `--print-to-file`/스크립트 경유.
