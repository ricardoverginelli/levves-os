; Win+Shift+M turns the main monitor off and back on (main-monitor.ps1 toggle),
; like Meta+Shift+M on Linux (os/linux/monitor). It replaces Windows' own
; Win+Shift+M (restore minimized windows).
; Install: python os/windows/monitor/install.py

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

#+m::Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
    . A_ScriptDir '\main-monitor.ps1" toggle', , "Hide")
