# Uploads files added or edited on the "Drive Mirror" HDD to Google Drive, so the
# next drive-mirror run on Fedora doesn't move them to _rclone-removed/.
# Usage: drive-push [--full] [--dry-run] [any rclone flag]
# Copy, not sync: it never deletes or overwrites anything newer in the cloud.
#
# Quick pass (every run once the disk has a stamp): a scan of the disk finds files
# written or created since the last successful push, and only those are copied,
# without listing Drive. Seconds instead of the full pass's ~15 minutes, so a
# shutdown rarely cuts it off.
# Full pass (first run, once a day, or --full): rclone compares the whole disk with
# Drive, which also catches what the scan can't see (renames and moves keep a file's
# times).
# Each successful run stamps <disk>\.drive-push-ok with its start time. drive-mirror
# on Fedora won't sync while the disk has files changed after that stamp.

$ErrorActionPreference = 'Stop'

$label = 'Drive Mirror'
$serial = 'C236DF7C'          # NTFS serial; Linux sees it as UUID C4C236E9C236DF7C
$remote = 'gdrive-rw:'
$logdir = Join-Path $env:LOCALAPPDATA 'drive-mirror'
$fullEvery = New-TimeSpan -Hours 20
# Files changed this long before the stamp are scanned again, in case a write
# landed while the last run was starting
$overlap = New-TimeSpan -Minutes 10

function Notify($title, $text) {
    # A toast as PowerShell; the task runs headless, so it's the only way to be seen
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $esc = { [Security.SecurityElement]::Escape($args[0]) }
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$(& $esc $title)</text><text>$(& $esc $text)</text></binding></visual></toast>")
        $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show(
            [Windows.UI.Notifications.ToastNotification]::new($xml))
    } catch { }
}

$full = $args -contains '--full'
$rcloneArgs = @($args | Where-Object { $_ -ne '--full' })
$dryRun = ($rcloneArgs -contains '--dry-run') -or ($rcloneArgs -contains '-n')

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

# Left behind by a run that didn't finish (a shutdown mid-push)
$running = Join-Path $logdir 'running'
if (Test-Path $running) {
    Notify 'drive-push was cut off' 'The last push stopped before finishing. This one picks it up; leave Windows on until it ends.'
}
Set-Content $running $log

$stamp = "$letter\.drive-push-ok"     # read by drive-mirror on Fedora
$fullStamp = Join-Path $logdir 'last-full'
$hasStamp = Test-Path $stamp
$full = $full -or -not $hasStamp -or -not (Test-Path $fullStamp) -or
    ((Get-Item $fullStamp).LastWriteTimeUtc -lt (Get-Date).ToUniversalTime() - $fullEvery)

# The log is rclone's too, which writes UTF-8 (Tee-Object would write UTF-16)
function Say($line) { $line; Add-Content -Path $log -Value $line -Encoding UTF8 }

function Set-Stamp($path, $timeUtc) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType File $path | Out-Null
        if ($path -eq $stamp) { $i = Get-Item $path; $i.Attributes = $i.Attributes -bor [IO.FileAttributes]::Hidden }
    }
    (Get-Item -Force $path).LastWriteTimeUtc = $timeUtc
}

# Same excludes and export formats as os/linux/drive-mirror, so the mirrored
# .docx/.xlsx/.pptx match their Google Docs instead of looking like new files.
$common = @(
    '--update',
    '--drive-export-formats', 'docx,xlsx,pptx,svg',
    '--stats', '1m', '--stats-log-level', 'NOTICE',
    '--log-level', 'INFO', '--log-file', $log
)
# Full pass only: rclone refuses filters next to --files-from-raw, and the scan skips
# the same paths ($skipDirs, $skipRoot, desktop.ini)
$filters = @(
    '--exclude', '/_rclone-removed/**',
    '--exclude', '/$RECYCLE.BIN/**',
    '--exclude', '/System Volume Information/**',
    '--exclude', '/sync.ffs_lock',
    '--exclude', '/.drive-push-ok',
    '--exclude', '/.drive-mirror-ok',
    '--exclude', 'desktop.ini', '--ignore-case'
)
$skipDirs = @('_rclone-removed', '$RECYCLE.BIN', 'System Volume Information')
$skipRoot = @('sync.ffs_lock', '.drive-push-ok', '.drive-mirror-ok')

$status = 0
try {
    if ($hasStamp) {
        $start = (Get-Date).ToUniversalTime()
        # Fedora's mirror stamps the disk when it finishes, so what it downloaded isn't rechecked
        $since = (Get-Item -Force $stamp).LastWriteTimeUtc
        $mirrored = "$letter\.drive-mirror-ok"
        if ((Test-Path $mirrored) -and (Get-Item -Force $mirrored).LastWriteTimeUtc -gt $since) {
            $since = (Get-Item -Force $mirrored).LastWriteTimeUtc
        }
        $since -= $overlap
        # FindFirstFile already returns both times, so this is one walk of the directory tree
        $changed = New-Object System.Collections.Generic.List[string]
        $root = [IO.DirectoryInfo]"$letter\"
        $dirs = New-Object System.Collections.Generic.Stack[IO.DirectoryInfo]
        $dirs.Push($root)
        while ($dirs.Count) {
            $d = $dirs.Pop()
            try { $entries = @($d.EnumerateFileSystemInfos()) } catch { continue }
            foreach ($e in $entries) {
                if ($e -is [IO.DirectoryInfo]) {
                    if (-not ($d.FullName -eq $root.FullName -and $skipDirs -contains $e.Name)) { $dirs.Push($e) }
                } elseif ($e.Name -ne 'desktop.ini' -and
                          -not ($d.FullName -eq $root.FullName -and $skipRoot -contains $e.Name) -and
                          ($e.LastWriteTimeUtc -gt $since -or $e.CreationTimeUtc -gt $since)) {
                    $changed.Add($e.FullName.Substring($root.FullName.Length).Replace('\', '/'))
                }
            }
        }
        Say "Quick pass: $($changed.Count) file(s) changed since $($since.ToLocalTime())"
        if ($changed.Count) {
            $changed | Select-Object -First 50 | ForEach-Object { Say "  $_" }
            $list = Join-Path $env:TEMP 'drive-push-files.txt'
            [IO.File]::WriteAllLines($list, $changed, (New-Object Text.UTF8Encoding $false))
            & $rclone copy "$letter/" $remote --files-from-raw $list --no-traverse @common @rcloneArgs
            $status = $LASTEXITCODE
            Remove-Item $list
        }
        if ($status -eq 0 -and -not $dryRun) { Set-Stamp $stamp $start }
    }

    if ($full -and $status -eq 0) {
        $start = (Get-Date).ToUniversalTime()
        Say "Full pass"
        # "D:/" rather than "D:\": a quoted trailing backslash escapes the quote.
        & $rclone copy "$letter/" $remote --fast-list --transfers 6 --checkers 16 @filters @common @rcloneArgs
        $status = $LASTEXITCODE
        if ($status -eq 0 -and -not $dryRun) {
            Set-Stamp $stamp $start
            Set-Stamp $fullStamp $start
        }
    }
} finally {
    Remove-Item $running -ErrorAction SilentlyContinue
}

if (Test-Path $log) {
    Get-Content $log | Select-String -Pattern 'ERROR|Skipped|Transferred:|Checks:|Errors:|pass' |
        Select-Object -Last 12 | ForEach-Object { $_.Line }
}
"Log: $log"
if ($status -ne 0) {
    Notify 'drive-push failed' "rclone stopped with error $status, so edits on the disk may not be in Drive yet. Fedora's mirror will wait for them. Log: $log"
}
exit $status
