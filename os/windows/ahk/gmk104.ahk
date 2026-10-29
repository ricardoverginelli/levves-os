; AHK v2 port of linux/keyd/gmk104.conf for the ZUOYA GMK104 on Windows
; (OS layout: Portuguese (Brazil) ABNT2).
; Install: python windows/ahk/install.py, or run this file with AutoHotkey v2.
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

; Shift + key right of '.' -> '?'
+SC035::SendText "?"

; Shift + 'ç' -> ':'
+SC027::SendText ":"

; Ctrl + ']' (key left of Enter) -> '|'
^SC02B::SendText "|"
