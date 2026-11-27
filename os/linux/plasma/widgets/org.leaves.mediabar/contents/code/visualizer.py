#!/usr/bin/env python3
"""Audio levels of one media player, for the media popup's visualizer.

GET http://127.0.0.1:48731/levels?app=<MPRIS identity> answers
{"levels": [32 values, 0-1, low to high frequencies]}. The widget starts this
while its popup is open and polls it; with no request for IDLE_EXIT seconds
it exits. A second copy exits at once (the port is taken).

The player's own PipeWire output stream is recorded, found by app name (MPRIS
pids don't help: a Flatpak's is its xdg-dbus-proxy, PipeWire sees the
sandbox's). Nothing is recorded unless that stream exists, and the recorder
never reconnects elsewhere: with a missing target, pw-record would fall back
to the default source, the microphone.
"""

import array
import cmath
import json
import math
import os
import select
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = 48731
IDLE_EXIT = 5  # seconds without a request
RATE = 24000  # PipeWire downmixes and resamples to this, mono
HOP = RATE // 30  # one analysis per ~33ms
SIZE = 1024  # FFT window: 43ms, 23 Hz per bin
BANDS = 32
LOW_HZ, HIGH_HZ = 50, 12000
FLOOR_DB = -36  # below the running peak, drawn as nothing
ATTACK, RELEASE = 0.5, 0.2  # the popup smooths between readings too
RESOLVE_EVERY = 2  # seconds between stream lookups while silent
TILT_DB = 3  # per octave up from LOW_HZ: music has less energy up high


def find_stream(app):
    """object.serial of the app's output stream, preferring a running one."""
    try:
        dump = json.loads(
            subprocess.run(
                ["pw-dump"], capture_output=True, text=True, timeout=3, check=False
            ).stdout
        )
    except (subprocess.SubprocessError, json.JSONDecodeError):
        return None
    app = app.lower()
    found = []
    for obj in dump:
        info = obj.get("info") or {}
        props = info.get("props") or {}
        if props.get("media.class") != "Stream/Output/Audio":
            continue
        names = (
            props.get("application.name"),
            props.get("application.process.binary"),
            props.get("node.name"),
        )
        if any(n and app in n.lower() for n in names):
            found.append((info.get("state") == "running", props.get("object.serial")))
    found.sort(reverse=True)
    return found[0][1] if found and found[0][1] is not None else None


def fft(x):
    """In-place iterative radix-2 FFT of a list of complex numbers."""
    n = len(x)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            x[i], x[j] = x[j], x[i]
    size = 2
    while size <= n:
        step = cmath.exp(-2j * math.pi / size)
        half = size // 2
        for start in range(0, n, size):
            w = 1
            for k in range(start, start + half):
                t = w * x[k + half]
                x[k + half] = x[k] - t
                x[k] += t
                w *= step
        size *= 2
    return x


WINDOW = [0.5 - 0.5 * math.cos(2 * math.pi * i / (SIZE - 1)) for i in range(SIZE)]
# Log-spaced band edges, as FFT bin ranges (each at least one bin wide)
EDGES = []
for b in range(BANDS + 1):
    hz = LOW_HZ * (HIGH_HZ / LOW_HZ) ** (b / BANDS)
    EDGES.append(round(hz * SIZE / RATE))
for b in range(1, len(EDGES)):
    EDGES[b] = max(EDGES[b], EDGES[b - 1] + 1)
TILT = [
    TILT_DB * math.log2(math.sqrt(max(EDGES[b], 1) * EDGES[b + 1]) * RATE / SIZE / LOW_HZ)
    for b in range(BANDS)
]


class Analyzer:
    def __init__(self):
        self.lock = threading.Lock()
        self.app = None
        self.levels = [0.0] * BANDS
        self.peak_db = FLOOR_DB
        self.last_request = time.monotonic()

    def want(self, app):
        with self.lock:
            self.app = app
            self.last_request = time.monotonic()
            return list(self.levels)

    def run(self):
        recorder, serial, app = None, None, None
        samples = array.array("f")
        pending = b""  # a partial sample from the last read
        fresh = 0  # samples since the last analysis
        last_resolve = 0
        while time.monotonic() - self.last_request < IDLE_EXIT:
            with self.lock:
                wanted = self.app
            now = time.monotonic()
            if wanted != app or (recorder is None and now - last_resolve > RESOLVE_EVERY):
                app, last_resolve = wanted, now
                new = find_stream(app) if app else None
                if new != serial or recorder is None:
                    if recorder:
                        recorder.kill()
                        recorder = None
                    serial = new
                    pending = b""
                    if serial is not None:
                        recorder = subprocess.Popen(
                            [
                                "pw-record",
                                "--target",
                                str(serial),
                                "--rate",
                                str(RATE),
                                "--channels",
                                "1",
                                "--format",
                                "f32",
                                "--raw",
                                "-P",
                                "{ node.dont-reconnect = true node.passive = true }",
                                "-",
                            ],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL,
                            bufsize=0,
                        )
            if recorder is None:
                self.decay()
                time.sleep(1 / 30)
                continue
            # A paused player sends nothing: wait a frame, then let the bars fall
            if not select.select([recorder.stdout], [], [], 1 / 30)[0]:
                self.decay()
                continue
            chunk = os.read(recorder.stdout.fileno(), HOP * 4)
            if not chunk:  # the stream went away
                recorder.kill()
                recorder, serial = None, None
                continue
            pending += chunk
            whole = len(pending) // 4 * 4
            samples.frombytes(pending[:whole])
            pending = pending[whole:]
            fresh += whole // 4
            if len(samples) > SIZE:
                del samples[: len(samples) - SIZE]
            if len(samples) == SIZE and fresh >= HOP:
                fresh = 0
                self.analyze(samples)
        if recorder:
            recorder.kill()

    def decay(self):
        with self.lock:
            self.levels = [v * (1 - RELEASE) for v in self.levels]

    def analyze(self, samples):
        spectrum = fft([s * w for s, w in zip(samples, WINDOW, strict=False)])
        raw = []
        for b in range(BANDS):
            lo, hi = EDGES[b], EDGES[b + 1]
            power = sum(abs(c) ** 2 for c in spectrum[lo:hi]) / (hi - lo)
            raw.append(10 * math.log10(power + 1e-12) + TILT[b])
        # Auto gain: follow the loudest band, falling back slowly
        self.peak_db = max(max(raw), self.peak_db - 0.05)
        with self.lock:
            for b, db in enumerate(raw):
                target = min(1.0, max(0.0, (db - self.peak_db - FLOOR_DB) / -FLOOR_DB))
                speed = ATTACK if target > self.levels[b] else RELEASE
                self.levels[b] += (target - self.levels[b]) * speed


analyzer = Analyzer()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/levels":
            self.send_error(404)
            return
        app = parse_qs(url.query).get("app", [""])[0]
        body = json.dumps({"levels": [round(v, 3) for v in analyzer.want(app)]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    try:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    except OSError:
        return  # already running
    threading.Thread(target=server.serve_forever, daemon=True).start()
    analyzer.run()
    server.shutdown()


if __name__ == "__main__":
    main()
