# Turns Windows Update off: policy, services and scheduled tasks. Needs admin.
# -Install also copies this file to Program Files and registers it as a
# startup task (SYSTEM), so anything Windows turns back on is undone at boot.
# Install with: python windows/updates/install.py
param([switch]$Install)

$TaskName = 'disable-windows-updates'
$InstallDir = Join-Path $env:ProgramFiles 'scripts'
$InstalledCopy = Join-Path $InstallDir 'disable-updates.ps1'
$Log = Join-Path $InstallDir 'disable-updates.log'

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Start-Transcript -Path $Log -Force | Out-Null

if ($Install) {
    # The task runs as SYSTEM, so it runs a copy in Program Files (admin-only
    # writes) rather than the repo file any user process could change
    if ($PSCommandPath -ne $InstalledCopy) { Copy-Item $PSCommandPath $InstalledCopy -Force }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$InstalledCopy`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Keeps Windows Update off (scripts repo, windows/updates)' -Force | Out-Null
    "Registered startup task $TaskName -> $InstalledCopy"
}

# Policy: no automatic updates, no driver updates, no Windows Update in Settings
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$au = "$wu\AU"
New-Item -Path $au -Force | Out-Null
Set-ItemProperty -Path $au -Name NoAutoUpdate -Value 1 -Type DWord
Set-ItemProperty -Path $au -Name AUOptions -Value 1 -Type DWord
Set-ItemProperty -Path $wu -Name ExcludeWUDriversInQualityUpdate -Value 1 -Type DWord
Set-ItemProperty -Path $wu -Name DisableWindowsUpdateAccess -Value 1 -Type DWord

foreach ($s in 'wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'dosvc') {
    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    # The registry write also works on protected services (WaaSMedicSvc) where Set-Service is denied
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name Start -Value 4 -Type DWord -ErrorAction Stop
        "Disabled service $s"
    } catch { "FAILED to disable service $s : $_" }
}
# WaaSMedicSvc's failure actions can restart the others, so clear them
sc.exe failure WaaSMedicSvc reset= 0 actions= "" | Out-Null

foreach ($path in '\Microsoft\Windows\WindowsUpdate\', '\Microsoft\Windows\UpdateOrchestrator\', '\Microsoft\Windows\WaaSMedic\') {
    foreach ($t in Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue) {
        $name = "$($t.TaskPath)$($t.TaskName)"
        if ($t.State -eq 'Disabled') { continue }
        try { Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null; "Disabled task $name" }
        catch { "Skipped task $name (protected by Windows; does nothing with the services off)" }
    }
}

Get-Service wuauserv, UsoSvc, WaaSMedicSvc, dosvc | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
Stop-Transcript | Out-Null
