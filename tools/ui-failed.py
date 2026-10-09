#!/usr/bin/env python3
"""Reads which tests failed from a result bundle, for the one retry a UI-test group gets
on GitHub (tools/ui-test.sh; 9 Oct 2026: one flaky test cost a 45-minute re-run).

    tools/ui-failed.py RESULT.xcresult

Prints one `-only-testing:` line per failed UI test and exits 0 when a retry makes
sense. Exits 2 (and says why) when it does not:
  - more than MAX tests failed (that is a real break, not a flake),
  - a model test failed (those are never retried),
  - the run went red with no failed test to point at (a build error, a hung runner).
"""
import json, subprocess, sys

MAX = 5
UI_BUNDLE = "AMSPackingUITests"


def failed_cases(path):
    out = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", path, "--compact"],
        check=True, capture_output=True, text=True).stdout
    found = []

    def walk(node, bundle, suite):
        kind = node.get("nodeType")
        if kind in ("UI test bundle", "Unit test bundle"):
            bundle = node.get("name")
        elif kind == "Test Suite":
            suite = node.get("name")
        if kind == "Test Case":
            if node.get("result") == "Failed":
                name = node.get("name", "").removesuffix("()")
                found.append((bundle, suite, name))
            return
        for child in node.get("children", []):
            walk(child, bundle, suite)

    for top in json.loads(out).get("testNodes", []):
        walk(top, None, None)
    return found


def main():
    cases = failed_cases(sys.argv[1])
    if not cases:
        print("red, but no failed test to retry (build error or hung runner?)", file=sys.stderr)
        sys.exit(2)
    other = [c for c in cases if c[0] != UI_BUNDLE]
    if other:
        print("a model test failed — never retried: " + ", ".join(f"{b}/{s}/{n}" for b, s, n in other), file=sys.stderr)
        sys.exit(2)
    if len(cases) > MAX:
        print(f"{len(cases)} tests failed (more than {MAX}) — a real break, no retry", file=sys.stderr)
        sys.exit(2)
    for bundle, suite, name in cases:
        print(f"-only-testing:{bundle}/{suite}/{name}")


if __name__ == "__main__":
    main()
