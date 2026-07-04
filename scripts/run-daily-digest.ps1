# run-daily-digest.ps1  (ASCII-only on purpose)
# Windows Task Scheduler runs this daily. It launches NATIVE Claude Code headless
# in the repo, which detects yesterday's new videos on tracked channels, digests
# them, and pushes (site auto-redeploys).
#
# Why native (not Cowork/Desktop routine): the Cloud/Cowork sandbox firewalls
# YouTube and has no yt-dlp, so detection fails there. This runs on the PC with
# scoop yt-dlp + open network + git creds.
#
# IMPORTANT: keep this file ASCII-only. Windows PowerShell 5.1 mis-parses a
# non-ASCII (Korean) .ps1 that has no UTF-8 BOM, which silently breaks the task.
# Korean instructions live in .claude/commands/collect-digest.md instead.

$ErrorActionPreference = "Stop"
$Repo = "D:\Engineering\claude-code-tutorial"
Set-Location $Repo

# scoop shims (yt-dlp) + claude CLI (~/.local/bin) on PATH; Task Scheduler PATH is minimal
$env:PATH = "$env:USERPROFILE\scoop\shims;$env:USERPROFILE\.local\bin;$env:PATH"

$LogDir = Join-Path $Repo "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$Log = Join-Path $LogDir ("daily-digest-{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))

# Preflight: abort loudly if a required tool is missing (avoids silent 8am failures)
foreach ($tool in @("claude","yt-dlp","git")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    "[{0}] FATAL: '{1}' not found on PATH - aborting" -f (Get-Date -Format s), $tool |
      Tee-Object -FilePath $Log -Append
    exit 1
  }
}

# English prompt (ASCII). Details are in the Korean rulebook it points to.
$Prompt = @'
You are Claude Code running headless in this repository for a daily unattended job.
Read .claude/commands/collect-digest.md and follow that rulebook exactly.
Goal: on each tracked channel (those with a digests/<topic>/<channel>/ folder),
detect every video that is NOT yet digested within the covered range - i.e.
from that channel's earliest existing digest onward: middle gaps + anything new
after the last. This is a state-based channel scan, NOT a "was it uploaded today"
time window. Create a digest for each, update that channel INDEX, then
git add/commit/push origin main so the site redeploys.
If there is nothing un-digested, do nothing: no files, no commit, no push. Stay silent.
Never ask for confirmation; this is fully unattended.
'@

"[{0}] start" -f (Get-Date -Format s) | Tee-Object -FilePath $Log -Append
claude -p $Prompt --dangerously-skip-permissions *>> $Log
"[{0}] done (exit {1})" -f (Get-Date -Format s), $LASTEXITCODE | Tee-Object -FilePath $Log -Append

# --- Task Scheduler registration (already done via Register-ScheduledTask) ---
# Trigger: Daily 08:00, StartWhenAvailable=True. Runs only while PC is on + user logged in.
# Manage:  schtasks /Run /TN "DailyDigestCollect"   (test now)
#          Get-ScheduledTaskInfo DailyDigestCollect  (status / LastTaskResult)
#          Unregister-ScheduledTask DailyDigestCollect -Confirm:$false  (remove)
