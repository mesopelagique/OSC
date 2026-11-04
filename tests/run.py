#!/usr/bin/env python3
"""Runs the tests of the OSC project with tool4d, and exits with 1 if one of them fails.

usage: tests/run.py [TOOL4D]     (or set the TOOL4D environment variable)

1. test_all: the unit tests written in 4D.
2. test_emit: decodes what really leaves the process, with stdout and stderr apart, then on a pty.
"""
import base64
import glob
import os
import pty
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "Project", "OSC.4DProject")
SEQUENCE = re.compile(rb"\x1b\]([0-9]+);([^\x07\x1b]*)\x1b\\")

failures = []


def check(actual, expected, label):
    if actual == expected:
        print(f"ok   {label}")
    else:
        failures.append(label)
        print(f"FAIL {label}\n  actual:   {actual!r}\n  expected: {expected!r}")


def find_tool4d():
    if len(sys.argv) > 1:
        return sys.argv[1]
    if os.environ.get("TOOL4D"):
        return os.environ["TOOL4D"]
    base = os.path.expanduser(
        "~/Library/Application Support/Code/User/globalStorage/4d.4d-analyzer/tool4d"
    )
    found = sorted(glob.glob(f"{base}/*/*/tool4d.app/Contents/MacOS/tool4d"))
    if not found:
        sys.exit("tool4d not found: pass its path, or set TOOL4D")
    return found[-1]


def command(tool4d, method):
    return [
        tool4d,
        f"--project={PROJECT}",
        f"--startup-method={method}",
        "--skip-onstartup",
        "--dataless",
    ]


def run_on_pty(cmd):
    """Everything the process writes, as a terminal receives it."""
    master, slave = pty.openpty()
    process = subprocess.Popen(
        cmd, stdin=subprocess.DEVNULL, stdout=slave, stderr=slave, close_fds=True
    )
    os.close(slave)
    data = bytearray()
    while True:
        try:
            chunk = os.read(master, 65536)
        except OSError:  # EIO: the other end of the pty is closed
            break
        if not chunk:
            break
        data.extend(chunk)
    os.close(master)
    process.wait(timeout=60)
    return bytes(data)


def sequences(data):
    return [(code.decode(), body.decode()) for code, body in SEQUENCE.findall(data)]


def status_reports(data):
    """Decodes the OSC 7501 reports with the grammar of the specification."""
    reports = []
    for code, body in sequences(data):
        if code != "7501":
            continue
        report = {}
        for pair in body.split(":"):
            key, value = pair.split("=", 1)
            assert re.fullmatch(r"[a-z]+", key), pair
            assert re.fullmatch(r"[A-Za-z0-9_.,+/=-]*", value), pair
            report[key] = (
                base64.b64decode(value, validate=True).decode("utf-8")
                if key in ("msg", "title")
                else value
            )
        reports.append(report)
    return reports


def test_unit(tool4d):
    result = subprocess.run(
        command(tool4d, "test_all"), capture_output=True, timeout=120
    )
    stdout = result.stdout.decode("utf-8", "replace")
    if result.stderr:
        print(result.stderr.decode("utf-8", "replace"))
    summary = re.search(r"osc-tests: (\d+) passed, (\d+) failed", stdout)
    if not summary:
        check(stdout, "a summary", "unit tests ran to the end")
        return
    print(f"     {summary.group(0)}")
    check(summary.group(2), "0", "unit tests")
    check(int(summary.group(1)) > 0, True, "unit tests are counted")


EXPECTED_STDOUT = [
    {"state": "working", "app": "build", "progress": "40", "msg": "Compiling héllo"},
    {"state": "blocked", "kind": "permission", "app": "build", "msg": "Approve?"},
    {"state": "done", "app": "build", "msg": "Built"},
    {"state": "working", "id": "eu-west", "app": "build", "msg": "Pushing"},
    {"state": "clear", "id": "eu-west"},
    {"state": "idle", "app": "build"},
]
EXPECTED_ERROR = {"state": "error", "app": "build", "msg": "It failed"}


def test_emit(tool4d):
    cmd = command(tool4d, "test_emit")

    result = subprocess.run(cmd, capture_output=True, timeout=120)
    check(status_reports(result.stdout), EXPECTED_STDOUT, "stdout: reports")
    check(status_reports(result.stderr), [EXPECTED_ERROR], "stderr: error report only")
    check(
        [s for s in sequences(result.stdout) if s[0] != "7501"],
        [("777", "notify;Build;Done"), ("9", "Build: Done")],
        "stdout: notifications",
    )
    check(
        SEQUENCE.sub(b"", result.stdout),
        b"",
        "stdout: no extra byte between the sequences",
    )

    # On a terminal both streams arrive in the order they were written.
    expected = list(EXPECTED_STDOUT)
    expected.insert(2, EXPECTED_ERROR)
    data = run_on_pty(cmd)
    check(status_reports(data), expected, "pty: reports in order, error included")
    check(SEQUENCE.sub(b"", data), b"", "pty: nothing visible on screen")


def main():
    tool4d = find_tool4d()
    print(f"tool4d: {tool4d}")
    test_unit(tool4d)
    test_emit(tool4d)
    if failures:
        print(f"\n{len(failures)} failed: {', '.join(failures)}")
        return 1
    print("\nAll tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
