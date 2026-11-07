# Turn the main monitor (the Asus XG27ACS) off and back on, to hand it to another
# device on another input. Windows port of os/linux/monitor/main-monitor.
# "off" saves its mode and every screen's position, makes another screen primary
# and detaches it (Display settings' "Disconnect this display"); "on" re-attaches
# it with that mode and makes it primary again.
# Usage: main-monitor.ps1 [toggle|off|on|status]   (default: toggle)
param(
    [ValidateSet("toggle", "off", "on", "status")]
    [string]$Action = "toggle",
    # Hardware ID of the monitor (WmiMonitorID / Device Manager), found on any connector
    [string]$MonitorId = "AUS27FE"
)
$ErrorActionPreference = "Stop"
$state = Join-Path $env:LOCALAPPDATA "levves\main-monitor.json"

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class LevvesDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2;
        public int dmPanningWidth, dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplayDevices(string device, int index, ref DISPLAY_DEVICE dd, int flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ChangeDisplaySettingsEx(string device, ref DEVMODE dm, IntPtr hwnd, int flags, IntPtr param);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ChangeDisplaySettingsEx(string device, IntPtr dm, IntPtr hwnd, int flags, IntPtr param);

    const int ATTACHED = 0x1, PRIMARY = 0x4, EDD_GET_DEVICE_INTERFACE_NAME = 0x1;
    const int DM_POSITION = 0x20, DM_BITSPERPEL = 0x40000, DM_PELSWIDTH = 0x80000,
              DM_PELSHEIGHT = 0x100000, DM_DISPLAYFREQUENCY = 0x400000;
    const int CDS_UPDATEREGISTRY = 0x1, CDS_SET_PRIMARY = 0x10, CDS_NORESET = 0x10000000;

    public class Output {
        public string Name; public bool Attached, Primary; public string Monitors = "";
        public int X, Y, Width, Height, Frequency, Bits;
    }

    // Every display output, with the hardware IDs of the monitors on it
    public static List<Output> Outputs() {
        var list = new List<Output>();
        var dd = new DISPLAY_DEVICE(); dd.cb = Marshal.SizeOf(dd);
        for (int i = 0; EnumDisplayDevices(null, i, ref dd, 0); i++) {
            var o = new Output { Name = dd.DeviceName,
                Attached = (dd.StateFlags & ATTACHED) != 0, Primary = (dd.StateFlags & PRIMARY) != 0 };
            var mon = new DISPLAY_DEVICE(); mon.cb = Marshal.SizeOf(mon);
            for (int j = 0; EnumDisplayDevices(o.Name, j, ref mon, EDD_GET_DEVICE_INTERFACE_NAME); j++) {
                o.Monitors += mon.DeviceID + ";";
                mon = new DISPLAY_DEVICE(); mon.cb = Marshal.SizeOf(mon);
            }
            var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
            if (o.Attached && EnumDisplaySettings(o.Name, -1, ref dm)) {
                o.X = dm.dmPositionX; o.Y = dm.dmPositionY; o.Width = dm.dmPelsWidth;
                o.Height = dm.dmPelsHeight; o.Frequency = dm.dmDisplayFrequency; o.Bits = dm.dmBitsPerPel;
            }
            list.Add(o);
            dd = new DISPLAY_DEVICE(); dd.cb = Marshal.SizeOf(dd);
        }
        return list;
    }

    static int Stage(string name, DEVMODE dm, bool primary) {
        int flags = CDS_UPDATEREGISTRY | CDS_NORESET | (primary ? CDS_SET_PRIMARY : 0);
        return ChangeDisplaySettingsEx(name, ref dm, IntPtr.Zero, flags, IntPtr.Zero);
    }

    // Queue a move (and, with width > 0, a mode); nothing changes until Apply()
    public static int Place(string name, int x, int y, int width, int height, int frequency, int bits, bool primary) {
        var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        dm.dmFields = DM_POSITION; dm.dmPositionX = x; dm.dmPositionY = y;
        if (width > 0) {
            dm.dmFields |= DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY | DM_BITSPERPEL;
            dm.dmPelsWidth = width; dm.dmPelsHeight = height;
            dm.dmDisplayFrequency = frequency; dm.dmBitsPerPel = bits;
        }
        return Stage(name, dm, primary);
    }

    // Queue a detach: a 0x0 mode takes the output off the desktop
    public static int Detach(string name) {
        var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        dm.dmFields = DM_POSITION | DM_PELSWIDTH | DM_PELSHEIGHT;
        return Stage(name, dm, false);
    }

    public static int Apply() {
        return ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
    }
}
"@

function Check([int]$code, [string]$what) {
    if ($code -ne 0) { throw "main-monitor: $what failed (DISP_CHANGE $code)" }
}

# The output showing the main monitor. Only an attached output's first monitor is the
# one it drives: once detached, Windows lists the monitor under every output, the
# other screen's included
function Find-Main {
    [LevvesDisplay]::Outputs() | Where-Object { $_.Attached -and ($_.Monitors -split ";")[0] -match "#$MonitorId#" } |
        Select-Object -First 1
}

# A detached output that can show it again: the one it was on, else any listing it
function Find-Free([string]$preferred) {
    $free = @([LevvesDisplay]::Outputs() | Where-Object { -not $_.Attached -and $_.Monitors -match "#$MonitorId#" })
    $same = $free | Where-Object Name -eq $preferred | Select-Object -First 1
    if ($same) { $same } else { $free | Select-Object -First 1 }
}

function Turn-Off {
    $main = Find-Main
    if (-not $main) { throw "main-monitor: $MonitorId isn't on" }
    $others = @([LevvesDisplay]::Outputs() | Where-Object { $_.Attached -and $_.Name -ne $main.Name })
    if (-not $others) { throw "main-monitor: not turning off the only screen" }

    $saved = @{
        name = $main.Name; primary = $main.Primary
        x = $main.X; y = $main.Y; width = $main.Width; height = $main.Height
        frequency = $main.Frequency; bits = $main.Bits
        others = @($others | ForEach-Object { @{ name = $_.Name; x = $_.X; y = $_.Y; primary = $_.Primary } })
    }
    New-Item -ItemType Directory -Force (Split-Path $state) | Out-Null
    $saved | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 $state

    # Windows keeps the primary screen at (0,0): when the main monitor was primary,
    # the next screen takes over and the layout shifts so it sits at the origin
    if ($main.Primary) {
        $next = $others[0]
        foreach ($o in $others) {
            Check ([LevvesDisplay]::Place($o.Name, $o.X - $next.X, $o.Y - $next.Y, 0, 0, 0, 0, $o.Name -eq $next.Name)) "moving $($o.Name)"
        }
    }
    Check ([LevvesDisplay]::Detach($main.Name)) "detaching $($main.Name)"
    Check ([LevvesDisplay]::Apply()) "applying"
}

function Turn-On {
    if (-not (Test-Path $state)) { throw "main-monitor: nothing to restore" }
    $saved = Get-Content -Raw $state | ConvertFrom-Json
    if (Find-Main) { Remove-Item $state; return }
    # The connector can change while it's off (another port, a GPU swap)
    $free = Find-Free $saved.name
    if (-not $free) { throw "main-monitor: no $MonitorId connected" }
    $name = $free.Name

    Check ([LevvesDisplay]::Place($name, $saved.x, $saved.y, $saved.width, $saved.height, $saved.frequency, $saved.bits, $saved.primary)) "attaching $name"
    $attached = @([LevvesDisplay]::Outputs() | Where-Object Attached | ForEach-Object Name)
    foreach ($o in $saved.others) {
        if ($attached -contains $o.name) {
            Check ([LevvesDisplay]::Place($o.name, $o.x, $o.y, 0, 0, 0, 0, $o.primary)) "moving $($o.name)"
        }
    }
    Check ([LevvesDisplay]::Apply()) "applying"
    Remove-Item $state
}

try {
    switch ($Action) {
        "off" { Turn-Off }
        "on" { Turn-On }
        "toggle" { if (Find-Main) { Turn-Off } else { Turn-On } }
        "status" {
            [LevvesDisplay]::Outputs() | Where-Object { $_.Attached -or $_.Monitors } |
                Format-Table Name, Attached, Primary, X, Y, Width, Height, Frequency, Monitors -AutoSize | Out-String | Write-Host
            if (Find-Main) { Write-Host "main-monitor: $MonitorId is on" }
            elseif (Find-Free "") { Write-Host "main-monitor: $MonitorId is off" }
            else { Write-Host "main-monitor: no $MonitorId connected"; exit 1 }
        }
    }
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
