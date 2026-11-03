# Privacy, telemetry, ads and background noise off, for a lean LTSC install. Needs admin.
# Per-user (HKCU) values go to the user who launched it: it runs elevated as that user.
# -Survey only lists apps, capabilities, features, services, startup entries and tasks.
# -RemoveApps takes appx package names from a survey and removes them (installed and
# provisioned); nothing is removed without it. Safe to re-run.
# Install with: python os/windows/debloat/install.py
param([switch]$Survey, [string[]]$RemoveApps = @())
# -File hands a comma list over as one string
$RemoveApps = @($RemoveApps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$InstallDir = Join-Path $env:ProgramFiles 'scripts'
$Log = Join-Path $InstallDir $(if ($Survey) { 'debloat-survey.log' } else { 'debloat.log' })
$DefenderTask = 'update-defender-signatures'

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Start-Transcript -Path $Log -Force | Out-Null

function Show-Survey {
    '== Appx packages, all users (frameworks left out) =='
    Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
        Select-Object -ExpandProperty Name | Sort-Object -Unique
    '== Provisioned appx packages =='
    Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName | Sort-Object
    '== Installed capabilities =='
    Get-WindowsCapability -Online | Where-Object State -eq Installed | Select-Object -ExpandProperty Name
    '== Enabled optional features =='
    Get-WindowsOptionalFeature -Online | Where-Object State -eq Enabled | Select-Object -ExpandProperty FeatureName | Sort-Object
    '== Running services =='
    Get-Service | Where-Object Status -eq Running | Select-Object -ExpandProperty Name | Sort-Object
    '== Startup entries =='
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Location, Command | Format-Table -AutoSize -Wrap | Out-String -Width 220
    '== Scheduled tasks outside \Microsoft\ =='
    Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
        Select-Object TaskPath, TaskName, State | Format-Table -AutoSize | Out-String -Width 200
}

if ($Survey) {
    Show-Survey
    Stop-Transcript | Out-Null
    exit 0
}

# Every value set below is re-read at the end, so anything that didn't stick is reported
$Expected = [System.Collections.Generic.List[object]]::new()
$Unchanged = 0

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    $Expected.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value })
    $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -ne $current -and "$current" -eq "$Value") { $script:Unchanged++; return }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        "Set $Path\$Name = $Value"
    } catch { "FAILED to set $Path\$Name : $_" }
}

function Disable-Svc($Name) {
    if (-not (Get-Service -Name $Name -ErrorAction SilentlyContinue)) { "Skipped service $Name (not present)"; return }
    Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    # Registry write, like disable-updates.ps1: also works where Set-Service is denied
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if ((Get-ItemProperty $key).Start -eq 4) { return }
    try { Set-ItemProperty -Path $key -Name Start -Value 4 -Type DWord -ErrorAction Stop; "Disabled service $Name" }
    catch { "FAILED to disable service $Name : $_" }
}

function Disable-Tasks($Path, [string[]]$Names = @('*')) {
    foreach ($t in Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue) {
        if (-not ($Names | Where-Object { $t.TaskName -like $_ })) { continue }
        $name = "$($t.TaskPath)$($t.TaskName)"
        if ($t.State -eq 'Disabled') { continue }
        try { Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null; "Disabled task $name" }
        catch { "Skipped task $name (protected by Windows)" }
    }
}

# -- Restore point -----------------------------------------------------------
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    $before = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count
    Checkpoint-Computer -Description 'Before debloat (levves repo)' -RestorePointType MODIFY_SETTINGS -WarningAction SilentlyContinue
    if (@(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count -gt $before) { 'Created restore point "Before debloat (levves repo)"' }
    else { 'Skipped restore point (Windows allows one per 24h; the last one still covers this run)' }
} catch { "FAILED to create a restore point: $_" }

'== Before =='
Show-Survey

# -- Telemetry and diagnostics -----------------------------------------------
Disable-Svc DiagTrack
Disable-Svc dmwappushservice

Disable-Tasks '\Microsoft\Windows\Application Experience\' @('Microsoft Compatibility Appraiser*', 'ProgramDataUpdater', 'StartupAppTask', 'PcaPatchDbTask')
Disable-Tasks '\Microsoft\Windows\Customer Experience Improvement Program\'
Disable-Tasks '\Microsoft\Windows\DiskDiagnostic\' @('Microsoft-Windows-DiskDiagnosticDataCollector')
Disable-Tasks '\Microsoft\Windows\Feedback\Siuf\'
Disable-Tasks '\Microsoft\Windows\Windows Error Reporting\' @('QueueReporting')

$P = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
Set-Reg "$P\DataCollection" AllowTelemetry 0
Set-Reg "$P\DataCollection" DoNotShowFeedbackNotifications 1
Set-Reg "$P\DataCollection" AllowDeviceNameInTelemetry 0
Set-Reg "$P\DataCollection" DisableOneSettingsDownloads 1
Set-Reg "$P\Windows Error Reporting" Disabled 1
Set-Reg "$P\AppCompat" AITEnable 0
Set-Reg "$P\AppCompat" DisableInventory 1
Set-Reg "$P\System" EnableActivityFeed 0
Set-Reg "$P\System" PublishUserActivities 0
Set-Reg "$P\System" UploadUserActivities 0
Set-Reg "$P\CloudContent" DisableTailoredExperiencesWithDiagnosticData 1
Set-Reg "$P\CloudContent" DisableWindowsConsumerFeatures 1
Set-Reg "$P\CloudContent" DisableSoftLanding 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' CEIPEnable 0

Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' NumberOfSIUFInPeriod 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' TailoredExperiencesWithDiagnosticDataEnabled 0
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' RestrictImplicitInkCollection 1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' RestrictImplicitTextCollection 1
Set-Reg 'HKCU:\Control Panel\International\User Profile' HttpAcceptLanguageOptOut 1

# -- AI and search -----------------------------------------------------------
Set-Reg "$P\WindowsAI" DisableAIDataAnalysis 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' DisableAIDataAnalysis 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1
$recall = Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue
if ($recall -and $recall.State -eq 'Enabled') {
    try { Disable-WindowsOptionalFeature -Online -FeatureName Recall -NoRestart -ErrorAction Stop | Out-Null; 'Disabled optional feature Recall' }
    catch { "FAILED to disable optional feature Recall: $_" }
}
# The Windows Search service stays: Start and Explorer search use it
Set-Reg "$P\Windows Search" AllowCortana 0
Set-Reg "$P\Windows Search" DisableWebSearch 1
Set-Reg "$P\Windows Search" ConnectedSearchUseWeb 0
Set-Reg "$P\Windows Search" AllowCloudSearch 0

# -- Ads and suggestions (per user) ------------------------------------------
# The lock screen values (RotatingLockScreen*, SubscribedContent-338387Enabled) belong to theme/install.py
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
               'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
               'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled',
               'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled') {
    Set-Reg $cdm $n 0
}
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' Start_IrisRecommendations 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' Start_AccountNotifications 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0

# -- Edge: stays installed and updating (WebView2 shares the updater), just quieter --
$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Set-Reg $edge StartupBoostEnabled 0
Set-Reg $edge BackgroundModeEnabled 0
Set-Reg $edge HideFirstRunExperience 1
Set-Reg $edge ShowRecommendationsEnabled 0
Set-Reg $edge PersonalizationReportingEnabled 0
Set-Reg $edge DiagnosticData 0
# Startup boost's own login entry; Edge won't re-add it with the policy set
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
foreach ($n in (Get-Item $run).Property | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch_*' }) {
    Remove-ItemProperty -Path $run -Name $n; "Removed startup entry $n"
}

# -- Apps (only the ones named with -RemoveApps) -----------------------------
foreach ($name in $RemoveApps) {
    $pkgs = @(Get-AppxPackage -AllUsers -Name $name)
    $prov = @(Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $name)
    if (-not $pkgs -and -not $prov) { "Skipped app $name (not present)"; continue }
    foreach ($p in $pkgs) {
        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; "Removed app $($p.PackageFullName)" }
        catch { "FAILED to remove app $($p.PackageFullName): $_" }
    }
    foreach ($p in $prov) {
        try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null; "Removed provisioned app $($p.PackageName)" }
        catch { "FAILED to remove provisioned app $($p.PackageName): $_" }
    }
}

# -- Gaming and audio --------------------------------------------------------
Set-Reg 'HKCU:\System\GameConfigStore' GameDVR_Enabled 0
Set-Reg "$P\GameDVR" AllowGameDVR 0

# High performance plan (unhidden under its own GUID if LTSC hides it)
$high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
if (-not (powercfg /list | Select-String $high)) { powercfg -duplicatescheme $high $high | Out-Null; 'Added power plan High performance' }
if (-not (powercfg /getactivescheme | Select-String $high)) { powercfg /setactive $high; 'Set power plan High performance' }
# USB selective suspend off (Audient iD4 dropouts), PCI Express link state power management off
$usb = '2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$pcie = '501a4d13-42af-4429-9fd1-a8218c268e20', 'ee12f906-d277-404b-b6da-e5fa1a576df5'
foreach ($s in @(@('USB selective suspend') + $usb), @(@('PCIe link state power management') + $pcie)) {
    powercfg /setacvalueindex $high $s[1] $s[2] 0
    powercfg /setdcvalueindex $high $s[1] $s[2] 0
    "Set power $($s[0]) off"
}
powercfg /setactive $high

# -- Defender signatures (Windows Update is off, so they come straight from Microsoft) --
$mpcmd = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
$action = New-ScheduledTaskAction -Execute $mpcmd -Argument '-SignatureUpdate -MMPC'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 12:00
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName $DefenderTask -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Weekly Defender signature update from Microsoft (levves repo, os/windows/debloat)' -Force | Out-Null
"Registered weekly task $DefenderTask"
& $mpcmd -SignatureUpdate -MMPC | Out-Null
if ($LASTEXITCODE -eq 0) { 'Updated Defender signatures' } else { "FAILED to update Defender signatures (MpCmdRun exit $LASTEXITCODE)" }

# -- Verify ------------------------------------------------------------------
'== Verify =='
"$Unchanged values were already set"
$bad = 0
foreach ($e in $Expected) {
    $v = (Get-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue).($e.Name)
    if ("$v" -ne "$($e.Value)") { "FAILED to verify $($e.Path)\$($e.Name): is '$v', expected $($e.Value)"; $bad++ }
}
"Verified $($Expected.Count - $bad) of $($Expected.Count) registry values"
Get-Service DiagTrack, dmwappushservice, WSearch, WinDefend | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
Get-MpComputerStatus | Select-Object AMServiceEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated | Format-List | Out-String
powercfg /getactivescheme
Stop-Transcript | Out-Null
