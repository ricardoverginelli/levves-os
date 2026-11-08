# Uploads files added or edited on the "Drive Mirror" HDD to Google Drive, so the
# next drive-mirror run on Fedora doesn't move them to _rclone-removed/.
# Usage: drive-push [--dry-run] [any rclone flag]
# Copy, not sync: it never deletes or overwrites anything newer in the cloud.

$ErrorActionPreference = 'Stop'

$label = 'Drive Mirror'
$serial = 'C236DF7C'          # NTFS serial; Linux sees it as UUID C4C236E9C236DF7C
$remote = 'gdrive-rw:'
$logdir = Join-Path $env:LOCALAPPDATA 'drive-mirror'

# Found by label and serial, never by drive letter
$vol = Get-Volume | Where-Object { $_.FileSystemLabel -eq $label -and $_.DriveLetter }
if (-not $vol) { Write-Error "The '$label' disk isn't connected." ; exit 1 }
$letter = "$($vol.DriveLetter):"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter'"
if ($disk.VolumeSerialNumber -ne $serial) {
    Write-Error "$letter is labeled '$label' but its serial is $($disk.VolumeSerialNumber), not $serial."
    exit 1
}

# Full path first: the scheduled task may start before a PATH change reaches it
$rclone = Join-Path $env:LOCALAPPDATA 'Programs\rclone\rclone.exe'
if (-not (Test-Path $rclone)) { $rclone = (Get-Command rclone -ErrorAction SilentlyContinue).Source }
if (-not $rclone) {
    Write-Error 'rclone not found; run os/windows/drive-mirror/install.py.'
    exit 1
}

# One run at a time: the scheduled one and a manual one would do the same work twice
$mutex = New-Object System.Threading.Mutex($false, 'Local\levves-drive-push')
if (-not $mutex.WaitOne(0)) { Write-Error 'drive-push is already running.'; exit 1 }

New-Item -ItemType Directory -Force $logdir | Out-Null
Get-ChildItem $logdir -Filter *.log | Where-Object LastWriteTime -lt (Get-Date).AddDays(-90) | Remove-Item
$log = Join-Path $logdir ("push_" + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.log')

# Same excludes and export formats as os/linux/drive-mirror, so the mirrored
# .docx/.xlsx/.pptx match their Google Docs instead of looking like new files.
# "D:/" rather than "D:\": a quoted trailing backslash escapes the quote.
& $rclone copy "$letter/" $remote `
    --update `
    --exclude '/_rclone-removed/**' `
    --exclude '/$RECYCLE.BIN/**' `
    --exclude '/System Volume Information/**' `
    --exclude '/sync.ffs_lock' `
    --exclude 'desktop.ini' --ignore-case `
    --drive-export-formats docx,xlsx,pptx,svg `
    --fast-list --transfers 6 --checkers 16 `
    --stats 1m --stats-log-level NOTICE `
    --log-level INFO --log-file $log `
    @args
$status = $LASTEXITCODE

Get-Content $log | Select-String -Pattern 'ERROR|Skipped|Transferred:|Checks:|Errors:' | Select-Object -Last 12 | ForEach-Object { $_.Line }
"Log: $log"
exit $status
