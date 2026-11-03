; AHK v2 port of os/linux/keyd/gmk104.conf for the ZUOYA GMK104 on Windows
; (OS layout: Portuguese (Brazil) ABNT2).
; Install: python os/windows/ahk/install.py, or run this file with AutoHotkey v2.
;
; Hotkeys use scan codes, so they match the physical keys like keyd does:
;   SC035 -> key right of '.'      (ABNT2: ';' / ':')
;   SC027 -> 'ç'
;   SC02B -> ']' (key left of Enter)
;
; Unlike keyd's [ids], AHK can't target one device: this applies to every
; keyboard. The F19 sysrq/f10 bindings aren't ported, they only work around
; KWin and the Linux VT switch.

#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows key sends F13 (Tools) in this firmware mode -> restore Win
F13::LWin

; Key right of '.': tap '/', hold 500ms ';'
SC035:: {
    if KeyWait("SC035", "T0.5") {
        SendText "/"
    } else {
        SendText ";"
        ; Swallow auto-repeat until release, so a long hold sends one ';'
        KeyWait "SC035"
    }
}

; Numpad 5 toggles the mic. Windows has no mic-mute key like keyd's micmute,
; so mute the default recording device directly; a tooltip stands in for
; Plasma's OSD. SC04C is the physical key, NumLock on or off
SC04C:: {
    ; IMMDeviceEnumerator -> default capture endpoint (eCapture, eConsole)
    devices := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    ComCall(4, devices, "int", 1, "int", 0, "ptr*", &device := 0)
    ; IMMDevice::Activate -> IAudioEndpointVolume
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "str", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "ptr", iid)
    ComCall(3, device, "ptr", iid, "uint", 23, "ptr", 0, "ptr*", &volume := 0)
    ComCall(15, volume, "int*", &muted := 0)          ; GetMute
    ComCall(14, volume, "int", !muted, "ptr", 0)      ; SetMute
    ObjRelease(volume)
    ObjRelease(device)
    ToolTip muted ? "Mic on" : "Mic muted"
    SetTimer () => ToolTip(), -1000
}

; Shift + key right of '.' -> '?'
+SC035::SendText "?"

; Shift + 'ç' -> ':'
+SC027::SendText ":"

; Ctrl + ']' (key left of Enter) -> '|'
^SC02B::SendText "|"
