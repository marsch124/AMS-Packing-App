#!/usr/bin/env python3
"""The fast lane's iPhone tests on several simulators side by side (tools/quick-release.sh,
spec 06 §28a; his ask, 14 Oct 2026: "can we deploy more agents to speed things up?").

    tools/ui-split.py split N LOCAL.json test…     # N lines: the tests of each simulator
    tools/ui-split.py record LOCAL.json RESULT.xcresult…
    tools/ui-split.py unpassed RESULT.xcresult… -- test…

split     Shares the tests out so each simulator takes about as long: longest first, each to the
          simulator with the least so far (ties: the lower one). A test's cost is what it took on
          THIS Mac — the median of its last three runs (LOCAL.json, written by `record`), so one
          run on a starved Mac does not skew the next split — else its GitHub time
          (tools/ui-test-times.json) scaled by how this Mac compares on the tests both know, else
          the median. The warm-up (testAAAWarmsUpTheSimulator) goes to EVERY simulator: each one's
          first launch is the slow one. A line may be empty (more simulators than tests).
record    Adds each passed test's seconds from the result bundles to LOCAL.json, keeping its last
          three (outside the repository: this Mac's own times, so the next split is closer).
unpassed  Prints the tests that passed (or skipped themselves, as a Mac-only test does on the
          iPhone) in none of the bundles; the warm-up is never asked for, its failure is allowed.
          A test that never ran — a runner that died half way — is caught here, not only one
          that failed.
"""
import json, pathlib, statistics, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GITHUB = ROOT / "tools" / "ui-test-times.json"
WARM_UP = "testAAAWarmsUpTheSimulator"
KEEP = 3   # runs kept per test in LOCAL.json


def cases(bundle):
    """(name, result, seconds) of every UI test case in a result bundle."""
    out = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", bundle, "--compact"],
        capture_output=True, text=True)
    if out.returncode != 0 or not out.stdout.strip():
        return []
    found = []

    def walk(node):
        if node.get("nodeType") == "Test Case":
            found.append((node.get("name", "").removesuffix("()"), node.get("result"),
                          node.get("durationInSeconds")))
            return
        for child in node.get("children", []):
            walk(child)

    for top in json.loads(out.stdout).get("testNodes", []):
        walk(top)
    return found


def load(path):
    try:
        return json.loads(pathlib.Path(path).read_text())
    except (OSError, ValueError):
        return {}


def runs(value):
    """A test's kept seconds: a list (a single number in a file from before KEEP)."""
    return value if isinstance(value, list) else [value]


def split(count, local_path, names):
    local = {n: statistics.median(runs(v)) for n, v in load(local_path).items()}
    github = {n: t["iphone"] for n, t in load(GITHUB).items() if "iphone" in t}
    both = sorted(local[n] / github[n] for n in local if github.get(n))
    scale = both[len(both) // 2] if both else 1.0
    known = sorted([local[n] for n in names if n in local] +
                   [github[n] * scale for n in names if n not in local and n in github])
    median = known[len(known) // 2] if known else 30.0

    def cost(n):
        if n in local:
            return local[n]
        if n in github:
            return github[n] * scale
        return median

    groups, load_ = [[] for _ in range(count)], [0.0] * count
    rest = sorted(set(names) - {WARM_UP}, key=lambda n: (-cost(n), n))
    for n in rest:
        i = min(range(count), key=lambda k: (load_[k], k))
        groups[i].append(n)
        load_[i] += cost(n)
    if WARM_UP in names:
        for g in groups:
            if g:
                g.insert(0, WARM_UP)
        if not any(groups):
            groups[0].append(WARM_UP)
    for i, g in enumerate(groups):
        print(" ".join(sorted(g)))
        print(f"simulator {i + 1}: {len(g)} tests, about {load_[i] / 60:.1f} min", file=sys.stderr)


def record(local_path, bundles):
    local = load(local_path)
    for b in bundles:
        for name, result, seconds in cases(b):
            if result == "Passed" and seconds and name != WARM_UP:
                local[name] = (runs(local.get(name, [])) + [round(seconds, 1)])[-KEEP:]
    pathlib.Path(local_path).write_text(json.dumps(local, indent=1, sort_keys=True) + "\n")


def unpassed(bundles, names):
    passed = {name for b in bundles for name, result, _ in cases(b) if result in ("Passed", "Skipped")}
    for n in names:
        if n != WARM_UP and n not in passed:
            print(n)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) >= 3 and args[0] == "split" and args[1].isdigit() and int(args[1]) >= 1:
        split(int(args[1]), args[2], args[3:])
    elif len(args) >= 2 and args[0] == "record":
        record(args[1], args[2:])
    elif args and args[0] == "unpassed" and "--" in args:
        cut = args.index("--")
        unpassed(args[1:cut], args[cut + 1:])
    else:
        sys.exit(__doc__)
