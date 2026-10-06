#!/usr/bin/env python3
"""Splits the UI tests into groups that take about as long, so GitHub runs them side
by side instead of one after another (his ask, 6 Oct 2026: a release took close to
three hours on GitHub once the suite reached 172 tests per device).

    tools/ui-shard.py iphone 2 3   # the -only-testing lines for group 2 of 3
    tools/ui-shard.py --check      # every test in exactly one group, and each group's minutes

The tests are read from the test file itself, so a new test is never left out: one
without a measured time counts as the median. Times are the seconds each test took on
GitHub (`tools/ui-test-times.json`, from 0.63's release run); a test measured on one
platform only (an `#if os(...)` test) costs nothing on the other. Longest first, each
into the group with the least so far. Group 1 also runs the two model bundles, which
the scheme runs on both devices (spec 06 §26).
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "UITests" / "AMSPackingUITests.swift"
TIMES = ROOT / "tools" / "ui-test-times.json"
BUNDLE = "AMSPackingUITests/AMSPackingUITests"
MODEL = ["PackingCoreTests", "PackingLibraryTests"]
GROUPS = {"iphone": 3, "mac": 2}   # what .github/workflows/tests.yml runs


def tests():
    return sorted(set(re.findall(r"^\s*func (test\w+)\(\)", SOURCE.read_text(), re.M)))


def groups(platform, count):
    times = json.loads(TIMES.read_text())
    names = tests()
    known = sorted(times[n][platform] for n in names if platform in times.get(n, {}))
    median = known[len(known) // 2] if known else 30.0

    def cost(n):
        if n not in times:
            return median
        return times[n].get(platform, 1.0)

    out, load = [[] for _ in range(count)], [0.0] * count
    for n in sorted(names, key=lambda n: (-cost(n), n)):
        i = min(range(count), key=lambda k: (load[k], k))
        out[i].append(n)
        load[i] += cost(n)
    return out, load


def check():
    names = set(tests())
    ok = True
    for platform, count in GROUPS.items():
        out, load = groups(platform, count)
        seen = [n for g in out for n in g]
        if sorted(seen) != sorted(names) or len(seen) != len(set(seen)):
            print(f"{platform}: tests missing or doubled")
            ok = False
        print(f"{platform}: " + " · ".join(f"group {i + 1}: {len(g)} tests, {load[i] / 60:.0f} min" for i, g in enumerate(out)))
    return ok


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        sys.exit(0 if check() else 1)
    platform, index, count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    if platform not in GROUPS or not 1 <= index <= count:
        sys.exit("usage: ui-shard.py iphone|mac GROUP OF")
    chosen = groups(platform, count)[0][index - 1]
    lines = [f"-only-testing:{BUNDLE}/{n}" for n in chosen]
    if index == 1:
        lines += [f"-only-testing:{m}" for m in MODEL]
    print("\n".join(lines))
