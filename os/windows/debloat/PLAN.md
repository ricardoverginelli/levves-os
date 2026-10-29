# Debloat plan (for Claude Code on Windows)

Written on the Fedora side (2026-10-29) for Claude running on the desktop's
Windows install. Build `windows/debloat/` from this plan, run it, verify it, then
delete this file once the README section in `CLAUDE.md` replaces it.

## Context
- Desktop PC, dual boot. Fedora is the main OS; Windows 11 IoT Enterprise LTSC 2024
  (on the X15 SSD) is for **music production** (Ableton Live 12, Waves, Arturia,
  NI Kontakt, Toontrack, iLok-style licensing, Audient iD4 interface) and **games**
  (Steam, Riot with Vanguard anti-cheat, Battle.net).
- LTSC is already lean: no Store, no Copilot, no Widgets, few preinstalled apps.
  "Full debloat" here means privacy, telemetry, ads and background noise, not
  ripping out components.
- Done during Setup by `autounattend.xml` (verify these, don't redo them):
  `AllowTelemetry=0`, `DisableWindowsConsumerFeatures=1`, `DisableSoftLanding=1`,
  advertising ID off by policy, `DisableSearchBoxSuggestions=1`, BitLocker device
  encryption prevented, fast startup and hibernation off, `RealTimeIsUniversal=1`,
  local account.
- Already handled by other components in this repo, so leave them alone:
  `windows/updates` (Windows Update off, with a startup task) and `windows/theme`
  (taskbar buttons, lock screen Spotlight/tips, dark mode).
- Secure Boot is on, and Windows is started by the firmware, not GRUB. Never touch
  the boot configuration (`bcdedit`, the EFI partition), and never touch the Lexar
  1 TB disk (Fedora, LUKS). Windows' boot files live on the Lexar's EFI partition.

## Deliverable
Follow the repo pattern (see `windows/updates/`):
- `windows/debloat/debloat.ps1`: does the work, needs admin. Idempotent (safe to
  re-run), logs with `Start-Transcript` to `C:\Program Files\scripts\debloat.log`,
  prints one line per change ("Set ...", "Disabled ...", "Removed ...", "Skipped ...",
  "FAILED ..."). Per-user (HKCU) settings apply to the user who launched it; it runs
  elevated as that same user, so HKCU is still theirs.
- `windows/debloat/install.py`: runs `debloat.ps1` elevated (one UAC prompt), like
  `windows/updates/install.py`, and prints the log summary.
- An entry in `SCRIPTS` in `windows/setup.py`, a line in the repo-structure block and
  a "Notes per Script" section in `CLAUDE.md`, including how to undo each group.
- No startup task: with Windows Update off, nothing should turn these back on.
  Say so in the notes.

## Before changing anything
1. Turn on System Protection for C: and create a restore point
   (`Enable-ComputerRestore`, `Checkpoint-Computer`); do this inside `debloat.ps1`.
2. Read-only survey first, and show the user the results before removing anything:
   `Get-AppxPackage -AllUsers`, `Get-AppxProvisionedPackage -Online`,
   `Get-WindowsCapability -Online | ? State -eq Installed`,
   `Get-WindowsOptionalFeature -Online | ? State -eq Enabled`, running services,
   startup entries (`Get-CimInstance Win32_StartupCommand`), scheduled tasks
   outside `\Microsoft\`.
3. Check whether OneDrive is installed and signed in. **Ask the user before
   removing it**: the old Ableton User Library path was
   `C:/Users/ricar/OneDrive/Documentos/Ableton`, and they still have to check
   OneDrive in the browser for that content.

## What to change

### Telemetry and diagnostics
- Services `DiagTrack` (Connected User Experiences) and `dmwappushservice`: stop,
  set Disabled.
- Scheduled tasks to disable: `\Microsoft\Windows\Application Experience\`
  (Compatibility Appraiser, ProgramDataUpdater, StartupAppTask, PcaPatchDbTask),
  `\Microsoft\Windows\Customer Experience Improvement Program\` (all),
  `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector`,
  `\Microsoft\Windows\Feedback\Siuf\` (all),
  `\Microsoft\Windows\Windows Error Reporting\QueueReporting`.
  Report protected ones as "Skipped", like `disable-updates.ps1` does.
- Policies (HKLM\SOFTWARE\Policies\Microsoft\Windows\...):
  `DataCollection`: `AllowTelemetry=0` (verify), `DoNotShowFeedbackNotifications=1`,
  `AllowDeviceNameInTelemetry=0`, `DisableOneSettingsDownloads=1`;
  `Windows Error Reporting`: `Disabled=1`;
  `AppCompat`: `AITEnable=0`, `DisableInventory=1`;
  `System`: `EnableActivityFeed=0`, `PublishUserActivities=0`, `UploadUserActivities=0`;
  `CloudContent`: `DisableTailoredExperiencesWithDiagnosticData=1` (plus verify the
  two autounattend values);
  `SQMClient\Windows` (under `Microsoft\`, not `Windows\`): `CEIPEnable=0`.
- Per user: feedback frequency off
  (`HKCU\Software\Microsoft\Siuf\Rules` `NumberOfSIUFInPeriod=0`), tailored
  experiences off (`HKCU\...\Privacy` `TailoredExperiencesWithDiagnosticDataEnabled=0`),
  inking/typing personalization off (`HKCU\Software\Microsoft\InputPersonalization`
  `RestrictImplicitInkCollection=1`, `RestrictImplicitTextCollection=1`), "let websites
  access my language list" off (`HKCU\Control Panel\International\User Profile`
  `HttpAcceptLanguageOptOut=1`).

### AI and search
- Recall / AI data analysis off: `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI`
  `DisableAIDataAnalysis=1` (and the same under HKCU). If the `Recall` optional feature
  exists, disable it.
- Copilot policy off for safety: `HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot`
  `TurnOffWindowsCopilot=1`.
- Search: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
  `AllowCortana=0`, `DisableWebSearch=1`, `ConnectedSearchUseWeb=0`,
  `AllowCloudSearch=0`. Keep the Windows Search service itself (Start search and
  Explorer use it).

### Ads and suggestions (per user)
Under `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`:
`SilentInstalledAppsEnabled=0`, `SystemPaneSuggestionsEnabled=0`,
`SoftLandingEnabled=0`, `SubscribedContent-338388Enabled=0`,
`SubscribedContent-338389Enabled=0`, `SubscribedContent-353694Enabled=0`,
`SubscribedContent-353696Enabled=0`, `PreInstalledAppsEnabled=0`,
`OemPreInstalledAppsEnabled=0`. Don't touch the lock screen values
`theme/install.py` owns (`RotatingLockScreen*`, `SubscribedContent-338387Enabled`).
Also: Start menu "recommended" tips and account notifications off
(`Explorer\Advanced` `Start_IrisRecommendations=0`, `Start_AccountNotifications=0`),
Settings app suggestions off (`UserProfileEngagement` `ScoobeSystemSettingEnabled=0`).

### Edge (keep it installed)
Don't uninstall Edge or WebView2: many plugin installers and license managers
(Native Access, Arturia Software Center, iLok License Manager, Toontrack Product
Manager) and Claude desktop render with WebView2. Only quiet it with policies
under `HKLM\SOFTWARE\Policies\Microsoft\Edge`: `StartupBoostEnabled=0`,
`BackgroundModeEnabled=0`, `HideFirstRunExperience=1`, `ShowRecommendationsEnabled=0`,
`PersonalizationReportingEnabled=0`, `DiagnosticData=0`. Disable the
`MicrosoftEdgeUpdateTask*` scheduled tasks only if the user agrees (they'd update
Edge by hand).

### Apps
- Remove leftover consumer appx packages the survey finds (for example
  `Microsoft.BingSearch`, `Microsoft.GetHelp`, `Microsoft.WindowsFeedbackHub`,
  `Microsoft.Windows.DevHome`, `MicrosoftWindows.CrossDevice`, `Clipchamp`),
  both installed (`Remove-AppxPackage -AllUsers`) and provisioned
  (`Remove-AppxProvisionedPackage`). Show the list and get a yes first.
- Keep: Notepad, Paint, Snipping Tool, Calculator, Photos if present, the VCLibs /
  UI.Xaml / .NET / WindowsAppRuntime frameworks, `Microsoft.SecHealthUI`,
  `Microsoft.DesktopAppInstaller` if present.
- OneDrive: only after the user's answer (see above).

### Gaming and audio friendly settings
- Game DVR / background recording off: `HKCU\System\GameConfigStore`
  `GameDVR_Enabled=0`; `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR`
  `AllowGameDVR=0`.
- Power: switch to the High performance plan (unhide it with
  `powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` if missing),
  USB selective suspend off (avoids Audient iD4 dropouts), PCI Express link state
  power management off. Leave hibernation off (verify with `powercfg /a`).
- Leave MMCSS (`Multimedia Class Scheduler`) and the audio services alone.

## Don't
- Don't disable or remove Microsoft Defender, SmartScreen, the firewall, UAC,
  Secure Boot or TPM-related services. Vanguard (Riot) needs Secure Boot, TPM and
  a working driver stack.
  - Defender signatures normally arrive through Windows Update, which `windows/updates`
    turned off. Mention to the user that `"%ProgramFiles%\Windows Defender\MpCmdRun.exe"
    -SignatureUpdate -MMPC` updates them straight from Microsoft, and offer to add a
    weekly scheduled task for it (ask first).
- Don't run third-party debloat scripts (`irm ... | iex`, WinUtil, AtlasOS, etc.);
  everything goes through this repo's own script so it's readable and undoable.
- Don't disable Print Spooler, Windows Installer, the Windows Search service, Windows
  Time, Bluetooth, Wi-Fi/WLAN AutoConfig, BITS (some installers need it), or any
  `Audio*` service.
- Don't remove .NET, Visual C++ runtimes, DirectX or WebView2.
- Don't touch `bcdedit`, the EFI partition, the Lexar disk, the Drive Mirror disk or
  the WD disk (D:).
- Don't edit `hosts` to block Microsoft domains (it breaks activation and Defender).

## Verify after running
- Re-read every value and service state the script set; list anything that didn't
  stick.
- Reboot once (start Windows from the firmware: "Reboot to Windows" on Fedora or the
  F11 menu), then check `Get-Service DiagTrack`, the scheduled tasks, and that
  Defender is on (`Get-MpComputerStatus`).
- Quick functional checks with the user: sound through the Audient iD4, Ableton
  opens, a plugin installer or license manager window renders (WebView2), a game
  launcher signs in.

## Finish
Update `CLAUDE.md` and `windows/setup.py` as described above, delete this
`PLAN.md`, and commit and push (`feat(windows): debloat component ...`).
