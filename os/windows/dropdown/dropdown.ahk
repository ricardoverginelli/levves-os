; Yakuake on Windows: the portable Windows Terminal that install.py sets up, docked on
; the left of a monitor (30% wide, full height), slid in and out like
; os/linux/kwin/yakuake-slide, and kept off monitors with a fullscreen window like
; yakuake-avoid-fullscreen.
;   Win+/        open / retract; focuses it when it's open behind another window
;   Win+N        new PowerShell tab (shows it first)
;   Win+Shift+N  new Claude Code tab
; Win+/ is the key right of '.' (SC035, '/' on the GMK104 through gmk104.ahk) or ABNT2's
; own '/' key (SC073). These replace Windows' Win+N (notifications) and Win+Shift+N.
; Args: the open and close durations in ms (install.py passes design/dist's panel ones).
; Install: python os/windows/dropdown/install.py

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

if A_Args.Length < 2 {
    MsgBox "dropdown.ahk needs the open and close durations; run it through install.py."
    ExitApp 1
}
OPEN_MS := Integer(A_Args[1])
CLOSE_MS := Integer(A_Args[2])
WIDTH := 0.30  ; of the monitor's work area, like Yakuake's Width 30%

TERMINAL_DIR := EnvGet("LOCALAPPDATA") "\levves\terminal"
WT := TERMINAL_DIR "\wt.exe"
TERMINAL_EXE := TERMINAL_DIR "\WindowsTerminal.exe"
WINDOW := "levves"  ; wt -w: every launch goes into this one window

; Per-monitor DPI, so window and monitor coordinates are the same physical pixels
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
DetectHiddenWindows true

previous := 0  ; the window that had focus before the terminal opened

#SC035::
#SC073:: Toggle()
#n:: NewTab("")
#+n:: NewTab("Claude Code")

Toggle() {
    term := FindTerminal()
    if !term
        return Open("")
    if !Shown(term)
        return Open("")
    if WinActive(term)
        return Retract(term)
    WinActivate(term)
}

NewTab(profile) {
    term := FindTerminal()
    if !term
        return Open(profile)
    if !Shown(term)
        Open("")
    args := profile = "" ? "" : ' -p "' profile '"'
    Run('"' WT '" -w ' WINDOW ' nt' args, TERMINAL_DIR)
}

; Find, or launch, the terminal; dock it on the right monitor and slide it in
Open(profile) {
    global previous
    fg := WinExist("A")
    if fg && fg != FindTerminal()
        previous := fg
    area := TargetArea()

    term := FindTerminal()
    if !term {
        args := profile = "" ? "" : ' -p "' profile '"'
        Run('"' WT '" -w ' WINDOW args, TERMINAL_DIR)
        deadline := A_TickCount + 10000
        while !(term := FindTerminal()) && A_TickCount < deadline
            Sleep 20
        if !term
            return
        ; Its first frame comes up wherever Windows puts it: hide it until it's docked
        Sleep 150
        WinHide(term)
    }

    frame := Docked(term, area)
    MoveTo(term, frame.hiddenX, frame.y, frame.w, frame.h)
    WinShow(term)
    RemoveTaskbarButton(term)
    WinActivate(term)
    Slide(term, frame.hiddenX, frame.x, frame.y, OPEN_MS)
}

Retract(term) {
    global previous
    WinGetPos(&x, &y, , , term)
    frame := Docked(term, MonitorArea(term))
    Slide(term, x, frame.hiddenX, y, CLOSE_MS)
    WinHide(term)
    if previous && WinExist(previous) && WinGetMinMax(previous) != -1
        WinActivate(previous)
}

; The terminal's window: the Windows Terminal from TERMINAL_DIR, not any other copy
FindTerminal() {
    for hwnd in WinGetList("ahk_class CASCADIA_HOSTING_WINDOW_CLASS") {
        try {
            if WinGetProcessPath(hwnd) = TERMINAL_EXE
                return hwnd
        }
    }
    return 0
}

Shown(term) => DllCall("IsWindowVisible", "ptr", term)

; Where it docks on a work area: left edge, full height, WIDTH wide; hiddenX puts it
; just off the left edge. Windows' invisible resize borders are added around it so
; the visible edges land on the work area's
Docked(term, area) {
    b := Borders(term)
    w := Round((area.right - area.left) * WIDTH)
    return {x: area.left - b.left, y: area.top - b.top,
            w: w + b.left + b.right, h: area.bottom - area.top + b.top + b.bottom,
            hiddenX: area.left - w - b.left - b.right}
}

; The invisible borders: the window rect minus what DWM draws
Borders(term) {
    static known := 0
    if known
        return known
    rect := Buffer(16), frame := Buffer(16)
    DllCall("GetWindowRect", "ptr", term, "ptr", rect)
    if !Shown(term) || DllCall("dwmapi\DwmGetWindowAttribute", "ptr", term, "uint", 9, "ptr", frame, "uint", 16)
        return {left: 0, top: 0, right: 0, bottom: 0}  ; measured once it's on screen
    known := {left: NumGet(frame, 0, "int") - NumGet(rect, 0, "int"),
              top: NumGet(frame, 4, "int") - NumGet(rect, 4, "int"),
              right: NumGet(rect, 8, "int") - NumGet(frame, 8, "int"),
              bottom: NumGet(rect, 12, "int") - NumGet(frame, 12, "int")}
    return known
}

; The work area to open on: the focused window's monitor, unless a fullscreen window
; covers it (a game), then another monitor
TargetArea() {
    count := MonitorGetCount()
    fg := WinExist("A")
    index := fg ? MonitorOf(fg) : MonitorOfMouse()
    if count > 1 && fg && Fullscreen(fg, index)
        index := Mod(index, count) + 1
    MonitorGetWorkArea(index, &l, &t, &r, &b)
    return {left: l, top: t, right: r, bottom: b}
}

MonitorArea(hwnd) {
    MonitorGetWorkArea(MonitorOf(hwnd), &l, &t, &r, &b)
    return {left: l, top: t, right: r, bottom: b}
}

; The monitor holding the window's center
MonitorOf(hwnd) {
    WinGetPos(&x, &y, &w, &h, hwnd)
    cx := x + w // 2, cy := y + h // 2
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if cx >= l && cx < r && cy >= t && cy < b
            return A_Index
    }
    return MonitorGetPrimary()
}

MonitorOfMouse() {
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if mx >= l && mx < r && my >= t && my < b
            return A_Index
    }
    return MonitorGetPrimary()
}

; Covers its whole monitor (fullscreen or borderless fullscreen), and isn't the desktop
Fullscreen(hwnd, index) {
    if WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd)$"
        return false
    WinGetPos(&x, &y, &w, &h, hwnd)
    MonitorGet(index, &l, &t, &r, &b)
    return x <= l && y <= t && x + w >= r && y + h >= b
}

MoveTo(term, x, y, w, h) {
    ; SWP_NOZORDER | SWP_NOACTIVATE
    DllCall("SetWindowPos", "ptr", term, "ptr", 0, "int", x, "int", y, "int", w, "int", h, "uint", 0x14)
}

; Slide horizontally on DESIGN.md's curve (out-quint), one step per DWM frame. Only the
; position changes, so the terminal doesn't re-lay itself out on the way
Slide(term, from, to, y, ms) {
    start := A_TickCount
    loop {
        t := Min((A_TickCount - start) / ms, 1)
        x := Round(from + (to - from) * (1 - (1 - t) ** 5))
        ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
        DllCall("SetWindowPos", "ptr", term, "ptr", 0, "int", x, "int", y, "int", 0, "int", 0, "uint", 0x15)
        if t >= 1
            break
        DllCall("dwmapi\DwmFlush")
    }
}

; Yakuake has no taskbar button; ITaskbarList::DeleteTab takes this one off
RemoveTaskbarButton(term) {
    static taskbar := 0
    if !taskbar {
        taskbar := ComObject("{56FDF344-FD6D-11d0-958A-006097C9A090}", "{56FDF342-FD6D-11d0-958A-006097C9A090}")
        ComCall(3, taskbar)  ; HrInit
    }
    ComCall(5, taskbar, "ptr", term)  ; DeleteTab
}
