#!/usr/bin/python3 -I
"""What the launcher's task list can't see by itself, as JSON on stdout.

The list starts from systemd's app-* cgroups (ApplicationDataModel). This adds:

services  Running services that are ours (unit file in ~/.config/systemd/user, or
          an unpackaged one in /etc or /usr/local) or third-party (from a package
          dnf marks as installed by the user: keyd, tailscale, nordvpn…). Desktop
          and Fedora plumbing stays out.
programs  Apps running inside some other unit's cgroup, so they get no app-*
          scope of their own: one opened through the desktop portal (a
          nordvpn-gui:// link), D-Bus, a service, or a terminal. Found by matching
          the process's executable to a visible desktop file that isn't the
          cgroup's own app; its child processes in the same cgroup come with it.

The launcher reads the numbers per pid from the process model, so this only
says which pids make up each row.
"""
import json
import os
import shlex
import shutil
import subprocess

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", HOME + "/.cache"), "leaves-launcher", "service-packages.json")
RPMDB = "/usr/lib/sysimage/rpm/rpmdb.sqlite"
UID = os.getuid()


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode(errors="replace")
    except OSError:
        return ""


def running_services(scope):
    """{unit: {path, main, cgroup, description}} for running services."""
    args = ["systemctl", "--no-pager", "show", "--type=service", "--state=running",
            "--property=Id,FragmentPath,MainPID,ControlGroup,Description", "*"]
    if scope == "user":
        args.insert(1, "--user")
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    units = {}
    for block in out.split("\n\n"):
        p = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        if p.get("Id"):
            units[p["Id"]] = {"path": p.get("FragmentPath", ""), "main": int(p.get("MainPID") or 0),
                              "cgroup": p.get("ControlGroup", ""), "description": p.get("Description", "")}
    return units


def user_installed(paths):
    """The unit files (of those given) whose package the user installed with dnf.
    Cached per file until the rpm database changes."""
    try:
        stamp = os.stat(RPMDB).st_mtime
    except OSError:
        stamp = 0
    try:
        with open(CACHE) as f:
            cache = json.load(f)
        if cache.get("stamp") != stamp:
            cache = {"stamp": stamp, "files": {}}
    except (OSError, ValueError):
        cache = {"stamp": stamp, "files": {}}
    files = cache["files"]
    missing = [p for p in paths if p not in files]
    if missing:
        try:
            out = subprocess.run(["rpm", "-qf", "--qf", "%{NAME}\n", *missing],
                                 capture_output=True, text=True, timeout=10).stdout.splitlines()
        except (OSError, subprocess.SubprocessError):
            out = []
        owners = dict(zip(missing, out)) if len(out) == len(missing) else {}
        packages = sorted({n for n in owners.values() if " " not in n})
        reasons = {}
        if packages:
            try:
                q = subprocess.run(["dnf5", "-q", "repoquery", "--installed", "--qf", "%{name} %{reason}\n", *packages],
                                   capture_output=True, text=True, timeout=20).stdout
                reasons = dict(line.split(" ", 1) for line in q.splitlines() if " " in line)
            except (OSError, subprocess.SubprocessError):
                pass
        for p in missing:
            files[p] = reasons.get(owners.get(p, ""), "").strip() == "User"
        try:
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            with open(CACHE, "w") as f:
                json.dump(cache, f)
        except OSError:
            pass
    return {p for p in paths if files.get(p)}


def cgroup_pids(cgroup):
    pids = []
    for root, _, names in os.walk("/sys/fs/cgroup" + cgroup):
        if "cgroup.procs" in names:
            pids += [int(x) for x in read(root + "/cgroup.procs").split()]
    return pids


def services():
    found = []
    for scope in ("user", "system"):
        units = running_services(scope)
        ours = {u for u, i in units.items()
                if i["path"].startswith((HOME + "/.config/systemd/", "/etc/systemd/", "/usr/local/"))
                and not u.startswith(("app-", "dbus-"))}
        if scope == "system":
            # /etc holds plenty of packaged overrides and symlinks; only unpackaged ones are ours
            ours -= {u for u in ours if units[u]["path"].startswith("/etc/")
                     and subprocess.run(["rpm", "-qf", units[u]["path"]], capture_output=True).returncode == 0}
        packaged = {i["path"] for u, i in units.items() if u not in ours and i["path"].startswith("/usr/lib/")}
        theirs = user_installed(sorted(packaged))
        for unit, info in units.items():
            if unit in ours or info["path"] in theirs:
                pids = cgroup_pids(info["cgroup"]) if info["cgroup"] else []
                if pids:
                    found.append({"unit": unit, "scope": scope, "name": info["description"] or unit,
                                  "cgroup": info["cgroup"], "main": info["main"], "pids": pids})
    return found


def desktop_files():
    """{executable basename: (desktop id, name, icon)} for desktop files shown in menus."""
    dirs = [os.environ.get("XDG_DATA_HOME", HOME + "/.local/share")]
    dirs += os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    by_exe = {}
    for d in reversed(dirs):   # earlier dirs win, like the menu
        apps = os.path.join(d, "applications")
        for root, _, names in os.walk(apps):
            for n in names:
                if not n.endswith(".desktop"):
                    continue
                entry, section = {}, None
                for line in read(os.path.join(root, n)).splitlines():
                    if line.startswith("["):
                        section = line.strip()
                    elif section == "[Desktop Entry]" and "=" in line:
                        k, v = line.split("=", 1)
                        entry.setdefault(k.strip(), v.strip())
                if entry.get("NoDisplay") == "true" or entry.get("Hidden") == "true" or not entry.get("Exec"):
                    continue
                try:
                    argv = shlex.split(entry["Exec"])
                except ValueError:
                    continue
                while argv and (argv[0] == "env" or "=" in argv[0]):
                    argv.pop(0)
                if not argv or argv[0] in ("flatpak", "sh", "bash", "python3", "python"):
                    continue   # flatpaks get scopes of their own; wrappers can't be told apart
                app = (os.path.relpath(os.path.join(root, n), apps).replace("/", "-"),
                       entry.get("Name", n[:-8]), entry.get("Icon", ""))
                names_ = {os.path.basename(argv[0])}
                full = shutil.which(argv[0])
                if full:
                    names_.add(os.path.basename(os.path.realpath(full)))
                for exe in names_:
                    by_exe[exe] = app
    return by_exe


def unit_of(cgroup):
    """The unit a cgroup path belongs to: the first .service/.scope in it, so a
    terminal tab's scope counts as part of the terminal's app scope."""
    for part in cgroup.split("/"):
        if part.endswith((".service", ".scope")) and part != f"user@{UID}.service":
            return part.encode().decode("unicode_escape")
    return ""


def programs(service_list):
    by_exe = desktop_files()
    mains = {s["main"] for s in service_list}
    in_services = {p for s in service_list for p in s["pids"]}
    procs = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        pid = int(name)
        try:
            if os.stat(f"/proc/{pid}").st_uid != UID:
                continue
            exe = os.path.basename(os.readlink(f"/proc/{pid}/exe")).removesuffix(" (deleted)")
        except OSError:
            continue
        stat = read(f"/proc/{pid}/stat")
        ppid = int(stat.rsplit(")", 1)[1].split()[1]) if ")" in stat else 0
        cgroup = read(f"/proc/{pid}/cgroup").strip().split("::", 1)[-1]
        procs[pid] = {"exe": exe, "ppid": ppid, "cgroup": cgroup}

    found = {}
    for pid, p in procs.items():
        app = by_exe.get(p["exe"])
        if not app or pid in mains or pid in in_services:
            continue
        unit = unit_of(p["cgroup"])
        bare = app[0].removesuffix(".desktop")
        if unit.startswith(("app-", "dbus-")) and bare in unit:
            continue   # the app's own scope, already a row
        if not unit or unit.startswith(("session-", "init.")):
            continue
        parent = procs.get(p["ppid"])
        if parent and by_exe.get(parent["exe"]) == app and parent["cgroup"] == p["cgroup"]:
            continue   # a child of the same app, collected below
        pids = [pid]
        for child, c in procs.items():   # its descendants in the same cgroup
            q, seen = c["ppid"], 0
            while q in procs and q != pid and seen < 64:
                q, seen = procs[q]["ppid"], seen + 1
            if q == pid and c["cgroup"] == p["cgroup"]:
                pids.append(child)
        row = found.setdefault(app[0], {"menuId": app[0], "name": app[1], "icon": app[2], "pids": []})
        row["pids"] += pids
    return list(found.values())


if __name__ == "__main__":
    s = services()
    print(json.dumps({"services": [{k: v for k, v in x.items() if k != "main"} for x in s],
                      "programs": programs(s)}))
