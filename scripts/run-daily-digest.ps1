# run-daily-digest.ps1
# 매일 아침 추적 채널의 "어제 신규 영상"을 감지->digest->git push 까지 무인 실행한다.
# Windows 작업 스케줄러가 이 스크립트를 매일 호출한다 (등록법은 아래 주석 참고).
#
# 왜 네이티브에서 돌려야 하나:
#   Cowork/Claude Desktop의 격리 샌드박스는 YouTube를 프록시 allowlist로 차단(403)하고
#   yt-dlp도 없다. 그래서 감지 자체가 불가능하다. 이 스크립트는 PC 네이티브(scoop+yt-dlp+
#   무제한 네트워크+git 자격증명)에서 Claude Code 헤드리스로 실행되어 리포 안에서 완주한다.

$ErrorActionPreference = "Stop"
$Repo = "D:\Engineering\claude-code-tutorial"
Set-Location $Repo

# scoop 셸림(yt-dlp)과 claude CLI(.local\bin)를 PATH 앞에 둔다.
# 작업 스케줄러는 최소 환경으로 실행돼 대화형 PATH가 없다 → 필요한 위치를 명시적으로 추가.
$env:PATH = "$env:USERPROFILE\scoop\shims;$env:USERPROFILE\.local\bin;$env:PATH"

# 로그 폴더
$LogDir = Join-Path $Repo "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$Log = Join-Path $LogDir ("daily-digest-{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))

# 프리플라이트: 필수 도구가 PATH에 잡히는지 확인 (없으면 6시에 조용히 죽는 사고 방지)
foreach ($tool in @("claude", "yt-dlp", "git")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    "[{0}] FATAL: '{1}' not found on PATH — 작업 중단" -f (Get-Date -Format s), $tool |
      Tee-Object -FilePath $Log -Append
    exit 1
  }
}

$Prompt = @'
어제 새로 올라온 영상을 digest해줘.
.claude/commands/collect-digest.md 룰북을 그대로 따른다.
신규가 있으면 digest를 digests/<주제>/<채널>/ 에 만들고 INDEX 갱신 후 git add/commit/push origin main 까지 한다.
신규가 없으면 아무것도 만들지 말고 커밋·push 없이 조용히 종료한다(빈 커밋 금지).
'@

# Claude Code 헤드리스(-p) + 무인 승인. 로그는 파일로.
# (자격증명/도구 승인이 필요 없도록 --dangerously-skip-permissions 사용. 이 리포 전용 무인 루틴이라 허용.)
"[{0}] start" -f (Get-Date -Format s) | Tee-Object -FilePath $Log -Append
claude -p $Prompt --dangerously-skip-permissions *>> $Log
"[{0}] done (exit {1})" -f (Get-Date -Format s), $LASTEXITCODE | Tee-Object -FilePath $Log -Append

# --- 작업 스케줄러 1회 등록 (PowerShell 관리자 창에서 한 번만 실행) ---
# schtasks /Create /TN "DailyDigestCollect" `
#   /TR "powershell -NoProfile -ExecutionPolicy Bypass -File `"D:\Engineering\claude-code-tutorial\scripts\run-daily-digest.ps1`"" `
#   /SC DAILY /ST 06:00 /F
# 확인:  schtasks /Query /TN "DailyDigestCollect" /V /FO LIST
# 즉시 테스트:  schtasks /Run /TN "DailyDigestCollect"
# 삭제:  schtasks /Delete /TN "DailyDigestCollect" /F
#
# 주의: 작업 스케줄러는 PC가 켜져 있을 때만 실행된다(6시에 꺼져 있으면 다음 부팅 후 실행되게
#       하려면 작업 속성 > "예약된 시간을 놓친 경우 가능한 한 빨리 작업 시작"을 체크).
