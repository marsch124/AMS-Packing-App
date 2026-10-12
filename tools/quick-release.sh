#!/bin/bash
# The FAST LANE to TestFlight — his decision, 12 Oct 2026: a finished change reaches TestFlight in
# about half an hour instead of three. A short check on THIS Mac, the archive and the upload from this
# Mac, and GitHub's full suite (every UI test, ~80 min) runs AFTER, on main, as the safety net. If that
# goes red later, the next build fixes it. The TestFlight workflow stays as the fallback (spec 06 §28).
#
#   tools/quick-release.sh VERSION "notes" [extra UI tests…]
#   tools/quick-release.sh --dry-run [VERSION] [extra UI tests…]
#   tools/quick-release.sh --testers-only VERSION BUILD ["notes"]
#
#   VERSION   the version to ship, e.g. 0.73. What's new must already lead with it (and the spec have
#             moved with it, tools/check-spec.sh). project.yml is set to it and committed — the release
#             commit — when it still says another.
#   notes     the builds' "What to Test" in TestFlight.
#   extra UI tests   the changed screens' tests, run with the smoke set (tools/smoke-tests.txt): a bare
#             name (testATickCountsAndStays) or -only-testing:AMSPackingUITests/AMSPackingUITests/test….
#
# The stages, each timed; the first failure stops everything and says where:
#    1 Ready?          clean checkout, main can fast-forward to it, What's new leads with VERSION, the spec
#    2 Model tests     tools/test-core.sh
#    3 Parity          tools/parity/run.sh --invented (the web app's model beside the main checkout)
#    4 iPhone build    for the simulator, unsigned, like GitHub's iPhone job
#    5 iPhone tests    the smoke set + the extras; what failed is run once more (tools/ui-failed.py)
#    6 Build number    one above the highest App Store Connect has
#    7 Certificates    "Created via API" development certificates revoked when the cap is near
#    8 Archive         iPhone and Mac with the TestFlight workflow's settings; entitlements checked
#    9 Upload          both, in the foreground with progress shown; one more try on a dropped connection
#   10 Testers         both builds VALID, with What to Test, in the tester group — added, retried, checked
#   11 Main            the release commit pushed to main — GitHub's full suite starts; its run id is printed
#
# --dry-run: everything but the upload. The export writes to a folder instead (so signing and the
# entitlements of what WOULD go up are proven), and nothing is committed, revoked, released or pushed.
# --testers-only: stage 10 alone, for builds already uploaded (a Testers stage that stopped, run again).
# A build already in the group with its What to Test is only read; "notes" fill an empty What to Test.
#
# Needs: Xcode signed in with his Apple ID (Settings ▸ Accounts — automatic signing, cloud-managed
# distribution certificate), xcodegen, node, gh, and the private helpers that are never committed:
# <main checkout>/private/release-tools/ asc.py, ensure-group.sh, revoke-api-certs.sh (or RELEASE_TOOLS).
#
# Environment (all optional):
#   PACKING_SIM        the simulator to test on            (default "Packing CI iPhone 18 Pro")
#   PARITY_MODEL       the web app's js/model.js            (default: "AMS Packing" beside the main checkout)
#   RELEASE_TOOLS      the private helpers' folder
#   CERT_NEAR          revoke when this many "Created via API" development certificates exist (default 7)
#   SIM_WAIT_MIN       wait this long for another test run to leave the simulator (default 30)
#   EXPORT_IDLE_MIN    an upload silent this long counts as hung (default 10)
#   TESTERS_WAIT_MIN   wait this long for Apple to process the builds (default 90)
#   COMMIT_TRAILER     the last line of the release commit's message
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- the arguments --------------------------------------------------------------------------------
DRY=0 TESTERS_ONLY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift
elif [ "${1:-}" = "--testers-only" ]; then TESTERS_ONLY=1; shift; fi
CURRENT=$(sed -n 's/^ *MARKETING_VERSION: *"\([^"]*\)".*/\1/p' project.yml | head -1)
VERSION="" NOTES="" BUILD=""
if [ $TESTERS_ONLY = 1 ]; then
  if [ $# -lt 2 ] || [ $# -gt 3 ] || ! [[ "$1" =~ ^[0-9]+(\.[0-9]+)+$ ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "Usage: tools/quick-release.sh --testers-only VERSION BUILD [\"notes\"]   e.g. --testers-only 0.74 96"
    exit 2
  fi
  VERSION=$1 BUILD=$2 NOTES=${3:-}
  shift $#
elif [ $DRY = 1 ]; then
  if [[ "${1:-}" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then VERSION=$1; shift; fi
  VERSION=${VERSION:-$CURRENT}
  NOTES="(dry run — nothing is sent)"
else
  if [ $# -lt 2 ] || ! [[ "$1" =~ ^[0-9]+(\.[0-9]+)+$ ]] || [ -z "${2// /}" ]; then
    sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "Usage: tools/quick-release.sh VERSION \"notes\" [extra UI tests…]   (or --dry-run)"
    exit 2
  fi
  VERSION=$1 NOTES=$2
  shift 2
fi

UI_BUNDLE="AMSPackingUITests/AMSPackingUITests"
SMOKE=()
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]')"
  if [ -n "$line" ]; then SMOKE+=("$line"); fi
done < tools/smoke-tests.txt
EXTRA=()
for a in "$@"; do
  case "$a" in
    -only-testing:*) EXTRA+=("${a#-only-testing:}") ;;
    test*) EXTRA+=("$UI_BUNDLE/$a") ;;
    */*) EXTRA+=("$a") ;;
    *) echo "Not a UI test: $a — give its name (testSomething) or -only-testing:…"; exit 2 ;;
  esac
done
ONLY=()
for t in ${SMOKE[@]+"${SMOKE[@]}"}; do ONLY+=("-only-testing:$UI_BUNDLE/$t"); done
for t in ${EXTRA[@]+"${EXTRA[@]}"}; do
  case " ${ONLY[*]:-} " in *" -only-testing:$t "*) ;; *) ONLY+=("-only-testing:$t") ;; esac
done
# A name that is not a test would quietly run nothing: check them all against the test file.
[ ${#ONLY[@]} -gt 0 ] || { echo "tools/smoke-tests.txt names no test"; exit 2; }
for o in "${ONLY[@]}"; do
  name="${o##*/}"
  grep -q "func $name()" UITests/AMSPackingUITests.swift || { echo "No UI test called $name (tools/smoke-tests.txt or the extras)"; exit 2; }
done

# --- how each stage is timed and reported -------------------------------------------------------------
STAGE="starting" T0=$(date +%s) START=$(date +%s) FAILED=0
TIMES=()
DRYTAG=""; [ $DRY = 0 ] || DRYTAG="-dry"
dur() { local s=$1; if [ "$s" -ge 60 ]; then echo "$((s / 60)) min $((s % 60)) s"; else echo "$s s"; fi; }
stage() { STAGE=$1; T0=$(date +%s); echo; echo "== $STAGE"; }
done_stage() {
  local s=$(( $(date +%s) - T0 ))
  TIMES+=("$(printf '%-16s %s' "$STAGE" "$(dur $s)")")
  echo "   done — $(dur $s)${1:+ · $1}"
}
summary() {
  echo
  echo "-- Time per stage"
  for t in ${TIMES[@]+"${TIMES[@]}"}; do echo "   $t"; done
  echo "   all together     $(dur $(( $(date +%s) - START )))"
}
fail() {
  FAILED=1
  echo
  echo "STOPPED at \"$STAGE\": $*"
  summary
  exit 1
}
# Anything else that stops the script (set -e) still says where it stopped.
on_exit() {
  local st=$?
  if [ $st -ne 0 ] && [ $FAILED = 0 ]; then
    echo
    echo "STOPPED at \"$STAGE\": a step went wrong — the lines above say what"
    summary
  fi
  if [ -n "${HELPERS:-}" ]; then rm -rf "$HELPERS"; fi
  exit $st
}
trap on_exit EXIT
say() { echo "   $*"; }

# --- where things go: OUTSIDE ~/Documents (codesign refuses the extended attributes it collects) ------
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
KEY=$(printf '%s' "$ROOT" | shasum | cut -c1-8)
DD_TEST="$TMP/AMSPacking-quick-$KEY"          # the simulator build, kept between runs (faster next time)
DD_ARCHIVE="$TMP/AMSPacking-archive-$KEY"     # the archives' derived data, kept between runs too
SIM_NAME="${PACKING_SIM:-Packing CI iPhone 18 Pro}"
BUNDLE_ID=com.schabbauer.AMSPacking
TEAM=$(/usr/libexec/PlistBuddy -c "Print :teamID" tools/ExportOptions.plist)

# The private helpers live in the MAIN checkout (git-ignored), also when this runs in a worktree.
MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
RT="${RELEASE_TOOLS:-$MAIN/private/release-tools}"
asc_json() {   # asc_json PATH — the answer's JSON; stops on anything but a 2xx
  local out code
  out=$(python3 "$RT/asc.py" GET "$1") || return 1
  code=$(printf '%s\n' "$out" | head -1)
  case "$code" in 2??) printf '%s\n' "$out" | tail -n +2 ;; *) echo "App Store Connect answered $code" >&2; return 1 ;; esac
}
# The helpers name asc.py by a folder of their own (S=…) that may be gone, and call it unquoted, so a
# path with spaces breaks them. They run from a temporary folder without spaces that links to asc.py.
# Only revoke-api-certs.sh is run this way now; ensure-group.sh is only READ, for the group id (stage 10).
HELPERS=""
run_helper() {   # run_helper NAME args…
  local name=$1; shift
  if [ -z "$HELPERS" ]; then
    HELPERS=$(mktemp -d "$TMP/ams-release-tools.XXXXXX")
    ln -s "$RT/asc.py" "$HELPERS/asc.py"
  fi
  sed "s|^S=.*|S=$HELPERS|" "$RT/$name" > "$HELPERS/$name"
  bash "$HELPERS/$name" "$@"
}
find_app_id() {   # the app's id in App Store Connect, from its bundle id
  asc_json "/v1/apps?filter%5BbundleId%5D=$BUNDLE_ID&fields%5Bapps%5D=bundleId" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; print(d[0]["id"] if d else "")'
}

# ==== stage 10, Testers — also run on its own: --testers-only VERSION BUILD ["notes"] ======================
# Until 0.75 this ran ensure-group.sh, whose add line put the JSON body inside "…$(…)…": macOS's bash 3.2
# brace-expands the {…,…} in it, so asc.py was called TWICE with broken bodies ({"data":["type":"builds"]}
# and {"data":["id":"…"]}) and Apple answered 400 every time (the doubled "adding — 400 … adding — 400" line
# in the 0.73 and 0.74 logs). Now Python calls asc.py with an argument list (no shell between), writes What to
# Test first (so the testers' notice carries it), adds each missing build, retries a refusal every 30 s for
# 15 minutes (printing Apple's own reason), and reads the group back until both builds are in it.
testers_stage() {
  stage "Testers"
  local group st result
  group=$(sed -n 's/.*G=\([0-9a-f-]\{36\}\).*/\1/p' "$RT/ensure-group.sh" | head -1)
  [ -n "$group" ] || fail "no tester group id in $RT/ensure-group.sh"
  if [ $DRY = 1 ]; then
    asc_json "/v1/betaGroups/$group?fields%5BbetaGroups%5D=isInternalGroup" >/dev/null || fail "the tester group cannot be read"
    done_stage "the tester group is there; a real run waits for both builds and adds them, with the notes"
    return
  fi
  if [ -z "${APP_ID:-}" ]; then
    APP_ID=$(find_app_id) || fail "App Store Connect cannot be asked (private/release-tools/asc.py)"
    [ -n "$APP_ID" ] || fail "App Store Connect has no app $BUNDLE_ID"
  fi
  printf '%s\n' "$NOTES" > "$WORK/notes.txt"
  rm -f "$WORK/testers-result.txt"
  say "Apple processes the builds first — a few minutes, at most ${TESTERS_WAIT_MIN:-90} are waited for"
  st=0
  python3 - "$RT/asc.py" "$APP_ID" "$VERSION" "$BUILD" "$group" "$WORK/notes.txt" "${TESTERS_WAIT_MIN:-90}" \
    "$WORK/testers-result.txt" <<'PY' || st=$?
import json, subprocess, sys, time
asc, app, version, build, group, notes_path, wait_min, result_path = sys.argv[1:]
API = "https://api.appstoreconnect.apple.com"
NAME = {"IOS": "iPhone", "MAC_OS": "Mac"}
text = open(notes_path).read().strip()[:4000]

def call(method, path, body=None):
    args = ["python3", asc, method, path] + ([json.dumps(body)] if body is not None else [])
    out = subprocess.run(args, capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout
    first, _, rest = out.partition("\n")
    try:
        code = int(first.strip())
    except ValueError:
        code = 0
    try:
        data = json.loads(rest) if rest.strip() else {}
    except ValueError:
        data = {}
    return code, data

def apple_says(code, data):
    why = [": ".join(filter(None, (e.get("code"), e.get("detail") or e.get("title")))) for e in data.get("errors", [])]
    return str(code) + (": " + "; ".join(why) if why else "")

def say(line):
    print("   " + line, flush=True)

def stop(why):
    open(result_path, "w").write("stop " + why + "\n")
    sys.exit(1)

def again_later():
    return f"run tools/quick-release.sh --testers-only {version} {build} later"

# 1. Both builds there, VALID, and Apple's beta processing past PROCESSING.
deadline, shown = time.time() + float(wait_min) * 60, None
while True:
    code, d = call("GET", f"/v1/builds?filter%5Bapp%5D={app}&filter%5Bversion%5D={build}"
                          "&include=preReleaseVersion,buildBetaDetail&limit=10")
    builds = []
    if code == 200:
        inc = {(i["type"], i["id"]): i["attributes"] for i in d.get("included", [])}
        for b in d.get("data", []):
            rel = b.get("relationships", {})
            pv = inc.get(("preReleaseVersions", ((rel.get("preReleaseVersion") or {}).get("data") or {}).get("id")), {})
            bd = inc.get(("buildBetaDetails", ((rel.get("buildBetaDetail") or {}).get("data") or {}).get("id")), {})
            builds.append({"id": b["id"], "platform": pv.get("platform", "?"), "version": pv.get("version"),
                           "state": b["attributes"].get("processingState"), "beta": bd.get("internalBuildState")})
        builds.sort(key=lambda b: b["platform"])
        for b in builds:
            if b["version"] and b["version"] != version:
                stop(f"build {build} is version {b['version']} in App Store Connect, not {version}")
            if b["state"] in ("FAILED", "INVALID"):
                stop(f"Apple's processing of the {NAME.get(b['platform'], b['platform'])} build {build} ended "
                     f"{b['state']} — App Store Connect says why")
        now = ", ".join(f"{NAME.get(b['platform'], b['platform'])} {b['state']}" + (f" ({b['beta']})" if b["beta"] else "")
                        for b in builds) or "not there yet"
    else:
        now = f"App Store Connect answered {apple_says(code, d)}"
    if now != shown:
        say(f"build {build}: {now}")
        shown = now
    ready = {b["platform"] for b in builds if b["state"] == "VALID" and b["beta"] != "PROCESSING"}
    if {"IOS", "MAC_OS"} <= ready:
        break
    if time.time() > deadline:
        stop(f"after {wait_min} minutes Apple has not finished build {build} ({now}) — {again_later()}")
    time.sleep(30)
builds = [b for b in builds if b["platform"] in NAME]

# 2. What to Test — read; written only when Apple's record is empty or missing and notes were given.
noted = 0
for b in builds:
    who = f"{NAME[b['platform']]} {build}"
    code, d = call("GET", f"/v1/builds/{b['id']}/betaBuildLocalizations")
    locs = d.get("data", []) if code == 200 else []
    if any((l["attributes"].get("whatsNew") or "").strip() for l in locs):
        say(f"{who}: What to Test is there")
        noted += 1
        continue
    if not text:
        say(f"{who}: no What to Test, and no notes given to write")
        continue
    if locs:
        code, d = call("PATCH", f"/v1/betaBuildLocalizations/{locs[0]['id']}", {"data": {
            "type": "betaBuildLocalizations", "id": locs[0]["id"], "attributes": {"whatsNew": text}}})
    else:
        code, d = call("POST", "/v1/betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}})
    if code in (200, 201):
        say(f"{who}: What to Test written")
        noted += 1
    else:
        say(f"{who}: What to Test NOT written — App Store Connect answered {apple_says(code, d)}")

# 3. The tester group: every page of it read, each missing build added; a refusal retried.
def members():
    ids, path = set(), f"/v1/betaGroups/{group}/builds?limit=200&fields%5Bbuilds%5D=version"
    while path:
        code, d = call("GET", path)
        if code != 200:
            return None, apple_says(code, d)
        ids |= {b["id"] for b in d.get("data", [])}
        nxt = (d.get("links") or {}).get("next") or ""
        path = nxt[len(API):] if nxt.startswith(API) else None
    return ids, ""

inside, err = members()
if inside is None:
    stop(f"the tester group cannot be read ({err}) — {again_later()}")
for b in builds:
    who = f"{NAME[b['platform']]} {build}"
    if b["id"] in inside:
        say(f"{who}: already in the tester group")
        continue
    give_up = time.time() + 15 * 60
    while True:
        code, d = call("POST", f"/v1/betaGroups/{group}/relationships/builds",
                       {"data": [{"type": "builds", "id": b["id"]}]})
        if code in (200, 201, 204):
            say(f"{who}: added to the tester group")
            break
        if time.time() > give_up:
            stop(f"App Store Connect refused for 15 minutes to add the {who} build to the tester group "
                 f"({apple_says(code, d)}) — {again_later()}")
        say(f"{who}: App Store Connect refused the add ({apple_says(code, d)}) — again in 30 s")
        time.sleep(30)

# 4. Checked, not trusted: read the group back until both are in it.
for attempt in range(7):
    inside, err = members()
    missing = [NAME[b["platform"]] for b in builds if inside is None or b["id"] not in inside]
    if not missing:
        break
    time.sleep(10)
else:
    stop(f"build {build} is not in the tester group for: {', '.join(missing)}"
         f"{' (' + err + ')' if err else ''} — {again_later()}")
open(result_path, "w").write(f"ok {len(builds)} {len(builds)} {noted}\n")
PY
  result=$(cat "$WORK/testers-result.txt" 2>/dev/null || true)
  case "$result" in
    ok\ *) read -r _ FOUND INGROUP NOTED <<< "$result" ;;
    stop\ *) fail "${result#stop }" ;;
    *) fail "the tester-group step ended without an answer (exit $st) — run tools/quick-release.sh --testers-only $VERSION $BUILD later" ;;
  esac
  [ "$INGROUP" -ge 2 ] || fail "build $BUILD is in the tester group $INGROUP time(s) of 2 — run tools/quick-release.sh --testers-only $VERSION $BUILD later"
  [ "$NOTED" -ge 2 ] || say "warning: only $NOTED of 2 builds carry the What to Test notes"
  done_stage "build $BUILD — iPhone and Mac — in the tester group, What to Test on $NOTED"
}

if [ $TESTERS_ONLY = 1 ]; then
  echo "AMS Packing $VERSION ($BUILD) — the Testers stage only: builds already uploaded"
  for f in asc.py ensure-group.sh; do
    [ -f "$RT/$f" ] || fail "the private helper $f is not in $RT (set RELEASE_TOOLS)"
  done
  WORK="$TMP/AMSPacking-release/$VERSION-$(date +%Y%m%d-%H%M%S)-testers"
  mkdir -p "$WORK"
  testers_stage
  summary
  echo
  echo "AMS Packing $VERSION ($BUILD): iPhone and Mac are in the tester group."
  exit 0
fi

echo "AMS Packing $VERSION — the fast lane$([ $DRY = 1 ] && echo ', DRY RUN: nothing is uploaded, committed or pushed')"
echo "Checkout: $ROOT"
echo "UI tests: ${#ONLY[@]} (${#SMOKE[@]} smoke + ${#EXTRA[@]} extra) on \"$SIM_NAME\""

# ==== 1 Ready? ===========================================================================================
stage "Ready?"
for tool in xcodebuild xcodegen node gh python3 git; do
  command -v $tool >/dev/null || fail "$tool is not installed"
done
for f in asc.py ensure-group.sh revoke-api-certs.sh; do
  [ -f "$RT/$f" ] || fail "the private helper $f is not in $RT (set RELEASE_TOOLS)"
done
case "$TMP" in *" "*) fail "the temporary folder has a space in its path: $TMP" ;; esac
git fetch -q origin || fail "GitHub cannot be reached"
if [ -n "$(git status --porcelain)" ]; then
  [ $DRY = 1 ] || fail "the checkout has changes that are not committed — commit them first (git status)"
  say "note: uncommitted changes (allowed in a dry run)"
fi
if ! git merge-base --is-ancestor origin/main HEAD; then
  [ $DRY = 1 ] || fail "main has commits this checkout does not have — merge origin/main first"
  say "note: main has moved on; a real run would stop here"
fi
NEWEST=$(grep -m1 -o 'Release(version: "[^"]*"' App/Sources/Guide/Releases.swift | sed 's/.*"\(.*\)"/\1/' || true)
[ "$NEWEST" = "$VERSION" ] || fail "What's new leads with $NEWEST, not $VERSION — add its line in App/Sources/Guide/Releases.swift (and docs/spec) first"
if [ "$CURRENT" != "$VERSION" ]; then
  [ $DRY = 0 ] || fail "a dry run builds the version in project.yml ($CURRENT), not $VERSION"
  sed -i '' "s/MARKETING_VERSION: \"$CURRENT\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
  grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml || fail "could not set the version in project.yml"
  say "project.yml: $CURRENT → $VERSION"
fi
# Every file but .git: anything under ~/Documents collects extended attributes, and codesign refuses them.
find . -path ./.git -prune -o -print0 | xargs -0 xattr -c 2>/dev/null || true
xcodegen generate >/dev/null
if [ $DRY = 0 ] && [ -n "$(git status --porcelain)" ]; then
  OTHER=$(git status --porcelain | grep -v -E ' (project\.yml|AMSPacking\.xcodeproj/.*|App/Config/AMSPacking\.entitlements|App/Config/Info\.plist)$' || true)
  [ -z "$OTHER" ] || fail "unexpected changes after the version was set: $OTHER"
  git add project.yml AMSPacking.xcodeproj App/Config/AMSPacking.entitlements App/Config/Info.plist
  git commit -q -m "AMS Packing $VERSION" -m "${COMMIT_TRAILER:-Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>}"
  say "release commit $(git rev-parse --short HEAD): AMS Packing $VERSION"
fi
tools/check-spec.sh | sed 's/^/   /' || fail "What's new changed without docs/spec — update the spec in the same commit"
done_stage "$VERSION, commit $(git rev-parse --short HEAD)"

# ==== 2 Model tests =======================================================================================
WORK="$TMP/AMSPacking-release/$VERSION-$(date +%Y%m%d-%H%M%S)$DRYTAG"
mkdir -p "$WORK"
say "logs and archives: $WORK"
stage "Model tests"
if ! tools/test-core.sh > "$WORK/model-tests.log" 2>&1; then
  grep -E "error:|failed" "$WORK/model-tests.log" | cut -c1-300 | head -10
  fail "a model test failed — log: $WORK/model-tests.log"
fi
# One total per bundle: the line after "Test Suite 'X.xctest' passed".
done_stage "$(awk '/Test Suite .*\.xctest. (passed|failed)/ { n = $3; gsub(/\047|\.xctest/, "", n); getline; printf "%s%s %s tests", sep, n, $2; sep = " · " }' "$WORK/model-tests.log")"

# ==== 3 Parity ============================================================================================
stage "Parity"
PARITY_MODEL="${PARITY_MODEL:-$(dirname "$MAIN")/AMS Packing/js/model.js}"
[ -f "$PARITY_MODEL" ] || fail "the web app's model is not at $PARITY_MODEL (set PARITY_MODEL)"
if ! PARITY_MODEL="$PARITY_MODEL" tools/parity/run.sh --invented > "$WORK/parity.log" 2>&1; then
  tail -20 "$WORK/parity.log"
  fail "the Swift model and the web app's model answer differently — log: $WORK/parity.log"
fi
done_stage "$(grep -E 'questions|differences' "$WORK/parity.log" | tail -2 | sed 's/^ *//' | tr '\n' ';' | sed 's/;$//; s/;/ · /g')"

# ==== 4 iPhone build ======================================================================================
stage "iPhone build"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and "iOS" in runtime:
            print(d["udid"]); sys.exit()' "$SIM_NAME")
[ -n "$UDID" ] || fail "there is no simulator called \"$SIM_NAME\" (set PACKING_SIM)"
# Several sessions share a simulator; two test runs on one kill each other. Wait for the other to end.
waited=0
while pgrep -f "^[^ ]*/xcodebuild .*$UDID" >/dev/null; do
  [ $waited -ge $(( ${SIM_WAIT_MIN:-30} * 60 )) ] && fail "another test run has held \"$SIM_NAME\" for ${SIM_WAIT_MIN:-30} minutes"
  [ $((waited % 300)) = 0 ] && say "another test run is using \"$SIM_NAME\" — waiting for it to finish"
  sleep 15; waited=$((waited + 15))
done
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
DEST="platform=iOS Simulator,id=$UDID"
if ! xcodebuild build-for-testing -project AMSPacking.xcodeproj -scheme AMSPacking -destination "$DEST" \
     -derivedDataPath "$DD_TEST" CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
     > "$WORK/iphone-build.log" 2>&1; then
  grep -E "error:" "$WORK/iphone-build.log" | sort -u | cut -c1-300 | head -10
  fail "the iPhone app does not build — log: $WORK/iphone-build.log"
fi
done_stage

# ==== 5 iPhone tests ======================================================================================
stage "iPhone tests"
TEST_ARGS=(-project AMSPacking.xcodeproj -scheme AMSPacking -destination "$DEST" -derivedDataPath "$DD_TEST"
  -collect-test-diagnostics never -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="")
counts() {   # counts RESULT.xcresult — "N passed, N failed, N skipped"
  xcrun xcresulttool get test-results summary --path "$1" --compact 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("%d passed, %d failed, %d skipped" % (d.get("passedTests", 0), d.get("failedTests", 0), d.get("skippedTests", 0)))' 2>/dev/null || echo "no result"
}
say "${#ONLY[@]} tests on \"$SIM_NAME\"…"
st=0
xcodebuild test-without-building "${ONLY[@]}" -resultBundlePath "$WORK/smoke.xcresult" "${TEST_ARGS[@]}" \
  > "$WORK/iphone-tests.log" 2>&1 || st=$?
say "$(counts "$WORK/smoke.xcresult")"
if [ $st -ne 0 ]; then
  RETRY=$(python3 tools/ui-failed.py "$WORK/smoke.xcresult" 2> "$WORK/why-no-retry.txt") \
    || { grep -E "error: -\[" "$WORK/iphone-tests.log" | cut -c1-300 | head -8
         fail "the iPhone tests are red and not worth a retry: $(cat "$WORK/why-no-retry.txt") — log: $WORK/iphone-tests.log"; }
  say "failed, so run once more:" $(echo "$RETRY" | sed 's|.*/||')
  st=0
  xcodebuild test-without-building $RETRY -resultBundlePath "$WORK/smoke-retry.xcresult" "${TEST_ARGS[@]}" \
    > "$WORK/iphone-tests-retry.log" 2>&1 || st=$?
  if [ $st -ne 0 ]; then
    grep -E "error: -\[" "$WORK/iphone-tests-retry.log" | cut -c1-300 | head -8
    fail "red twice: $(python3 tools/ui-failed.py "$WORK/smoke-retry.xcresult" 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')— log: $WORK/iphone-tests-retry.log"
  fi
  say "green on the retry (flaky — worth a look):" $(echo "$RETRY" | sed 's|.*/||')
fi
done_stage

# ==== 6 Build number ======================================================================================
stage "Build number"
APP_ID=$(find_app_id) || fail "App Store Connect cannot be asked (private/release-tools/asc.py)"
[ -n "$APP_ID" ] || fail "App Store Connect has no app $BUNDLE_ID"
HIGHEST=$(asc_json "/v1/builds?filter%5Bapp%5D=$APP_ID&sort=-uploadedDate&limit=200&fields%5Bbuilds%5D=version" \
  | python3 -c 'import json,sys; v=[int(b["attributes"]["version"]) for b in json.load(sys.stdin)["data"] if b["attributes"]["version"].isdigit()]; print(max(v) if v else 0)') \
  || fail "App Store Connect did not list the builds"
# Apple refuses a build number used before (and the Mac one lower than the last); the TestFlight
# workflow counts on from the same highest number (its "Number this build" step).
BUILD=$((HIGHEST + 1))
done_stage "highest so far $HIGHEST → this is build $BUILD"

# ==== 7 Certificates ======================================================================================
stage "Certificates"
API_CERTS=$(asc_json "/v1/certificates?limit=200&fields%5Bcertificates%5D=name,certificateType,displayName" | python3 -c '
import json, sys
n = 0
for c in json.load(sys.stdin)["data"]:
    a = c["attributes"]
    if (a.get("displayName") or a["name"]) == "Created via API" and a["certificateType"] == "DEVELOPMENT":
        n += 1
print(n)') || fail "App Store Connect did not list the certificates"
# Every GitHub archive of his apps mints one; at about a dozen, signing stops ("Choose a certificate to
# revoke"). His standing OK (9 Oct 2026): revoke them without asking — NEVER the one with his name.
if [ "$API_CERTS" -ge "${CERT_NEAR:-7}" ]; then
  if [ $DRY = 1 ]; then say "$API_CERTS \"Created via API\" development certificates — a real run revokes them now"
  else run_helper revoke-api-certs.sh | sed 's/^/   /'; fi
fi
done_stage "$API_CERTS \"Created via API\" development certificate(s) on the account"

# ==== 8 Archive ===========================================================================================
stage "Archive"
# The TestFlight workflow's "Entitlements for a build that ships", exactly: the iCloud file made
# Production; the iPhone's copy with the push key under the iPhone's name and Apple Health added.
SHIP="$WORK/AMSPacking-Ship.entitlements" SHIP_IOS="$WORK/AMSPacking-Ship-iOS.entitlements"
sed -e 's|<string>Development</string>|<string>Production</string>|' \
    -e 's|<string>development</string>|<string>production</string>|' \
    App/Config/AMSPacking-iCloud.entitlements > "$SHIP"
sed -e 's|<key>com.apple.developer.aps-environment</key>|<key>aps-environment</key>|' "$SHIP" > "$SHIP_IOS"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.healthkit bool true" \
    -c "Add :com.apple.developer.healthkit.access array" "$SHIP_IOS"

# check_entitlements PLATFORM APP WHAT — the signed app must carry what syncs (and, on the iPhone, Health).
check_entitlements() {
  codesign -d --entitlements - --xml "$2" > "$WORK/entitlements-$1-$3.plist" 2>/dev/null \
    || fail "could not read the entitlements of the $1 app ($3)"
  python3 - "$1" "$WORK/entitlements-$1-$3.plist" <<'PY' || fail "the $1 app ($3) lacks entitlements it needs — see above"
import plistlib, sys
platform, path = sys.argv[1], sys.argv[2]
e = plistlib.load(open(path, "rb"))
need = {"com.apple.developer.icloud-container-identifiers": "iCloud",
        "com.apple.developer.icloud-services": "iCloud (CloudKit)"}
if platform == "iOS":
    need.update({"com.apple.developer.healthkit": "Apple Health", "aps-environment": "iCloud's change notices"})
else:
    need.update({"com.apple.security.network.client": "network client (iCloud from the sandbox)",
                 "com.apple.security.app-sandbox": "the sandbox",
                 "com.apple.developer.aps-environment": "iCloud's change notices"})
missing = [f"{what} ({key})" for key, what in need.items() if not e.get(key)]
if "iCloud.com.schabbauer.AMSPacking" not in (e.get("com.apple.developer.icloud-container-identifiers") or []):
    missing.append("the iCloud container iCloud.com.schabbauer.AMSPacking")
for m in missing:
    print(f"   MISSING: {m}")
if missing:
    sys.exit(1)
env = e.get("aps-environment") or e.get("com.apple.developer.aps-environment")
print(f"   {platform}: iCloud, " + ("Apple Health, " if platform == "iOS" else "network client, ") + f"push {env}")
PY
}

for platform in iOS macOS; do
  ENT="$SHIP"; [ $platform = iOS ] && ENT="$SHIP_IOS"
  say "$platform…"
  if ! xcodebuild archive -project AMSPacking.xcodeproj -scheme AMSPacking \
       -destination "generic/platform=$platform" \
       -archivePath "$WORK/AMSPacking-$platform.xcarchive" \
       -derivedDataPath "$DD_ARCHIVE" \
       -allowProvisioningUpdates \
       DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CODE_SIGN_ENTITLEMENTS="$ENT" \
       PACKING_USES_ICLOUD=YES MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
       > "$WORK/archive-$platform.log" 2>&1 \
     || ! grep -q "\*\* ARCHIVE SUCCEEDED \*\*" "$WORK/archive-$platform.log"; then
    grep -E "error:" "$WORK/archive-$platform.log" | sort -u | cut -c1-300 | head -10
    if grep -E "error:" "$WORK/archive-$platform.log" | grep -qiE "no account|sign in|signed in|account.*expired|session has expired"; then
      fail "Xcode needs his Apple ID: open Xcode, Settings ▸ Accounts, sign in (or press Sign In Again), then run this again"
    fi
    fail "the $platform archive failed — log: $WORK/archive-$platform.log"
  fi
  APP="$WORK/AMSPacking-$platform.xcarchive/Products/Applications/AMSPacking.app"
  [ -d "$APP" ] || fail "the $platform archive holds no AMSPacking.app"
  PLIST="$APP/Info.plist"; [ $platform = macOS ] && PLIST="$APP/Contents/Info.plist"
  got="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST"))"
  [ "$got" = "$VERSION ($BUILD)" ] || fail "the $platform archive says $got, not $VERSION ($BUILD)"
  check_entitlements $platform "$APP" archive
done
done_stage "$VERSION ($BUILD), iPhone and Mac"

# ==== 9 Upload ============================================================================================
stage "$([ $DRY = 1 ] && echo 'Export (dry run)' || echo 'Upload')"
OPTIONS="$ROOT/tools/ExportOptions.plist"
if [ $DRY = 1 ]; then
  OPTIONS="$WORK/ExportOptions-dry.plist"
  cp tools/ExportOptions.plist "$OPTIONS"
  /usr/libexec/PlistBuddy -c "Set :destination export" "$OPTIONS"
fi
PROGRESS='Progress|[Uu]pload|EXPORT|[Ee]xported|error:|offline|[Ss]igning'
# export_one PLATFORM — in the foreground, its progress shown as it comes. A background export once hung
# silently on "The Internet connection appears to be offline" (Workout Sync, 14 Sep 2026): one more try
# when the connection drops or nothing is said for EXPORT_IDLE_MIN minutes, then stop.
export_one() {
  local p=$1 try log pid shown size last idle hung st n
  for try in 1 2; do
    log="$WORK/export-$p-$try.log"
    rm -rf "$WORK/export-$p"; : > "$log"
    xcodebuild -exportArchive -archivePath "$WORK/AMSPacking-$p.xcarchive" -exportPath "$WORK/export-$p" \
      -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates > "$log" 2>&1 &
    pid=$! shown=0 last=0 idle=0 hung=0
    while kill -0 $pid 2>/dev/null; do
      sleep 5
      n=$(wc -l < "$log" | tr -d ' ')
      if [ "$n" -gt "$shown" ]; then
        sed -n "$((shown + 1)),${n}p" "$log" | grep -E "$PROGRESS" | cut -c1-200 | sed 's/^/     /' || true
        shown=$n
      fi
      size=$(stat -f %z "$log")
      if [ "$size" -gt "$last" ]; then last=$size idle=0; else idle=$((idle + 5)); fi
      if [ $idle -ge $(( ${EXPORT_IDLE_MIN:-10} * 60 )) ]; then
        kill $pid 2>/dev/null || true; sleep 3; kill -9 $pid 2>/dev/null || true; hung=1; break
      fi
    done
    st=0; wait $pid 2>/dev/null || st=$?
    n=$(wc -l < "$log" | tr -d ' ')
    [ "$n" -gt "$shown" ] && { sed -n "$((shown + 1)),${n}p" "$log" | grep -E "$PROGRESS" | cut -c1-200 | sed 's/^/     /' || true; }
    if [ $hung = 0 ] && [ $st -eq 0 ] && grep -q "EXPORT SUCCEEDED" "$log"; then return 0; fi
    if [ $try = 1 ] && { [ $hung = 1 ] || grep -qiE "offline|network connection|timed out|could not connect" "$log"; }; then
      say "$([ $hung = 1 ] && echo "nothing happened for ${EXPORT_IDLE_MIN:-10} minutes" || echo "the connection dropped") — one more try in 30 s"
      sleep 30; continue
    fi
    grep -E "error:|Error Domain" "$log" | sort -u | cut -c1-300 | head -8 || true
    if [ $hung = 1 ]; then fail "the $p $([ $DRY = 1 ] && echo export || echo upload) hung twice — check this Mac's internet connection, then run again"; fi
    if grep -qiE "offline|network connection|could not connect" "$log"; then fail "this Mac lost its internet connection twice during the $p upload — run again when it is back"; fi
    if grep -E "error:" "$log" | grep -qiE "no account|sign in|signed in|session has expired"; then fail "Xcode needs his Apple ID: open Xcode, Settings ▸ Accounts, sign in, then run this again"; fi
    fail "the $p $([ $DRY = 1 ] && echo export || echo upload) failed — log: $log"
  done
}
for platform in iOS macOS; do
  say "$platform…"
  export_one $platform
done
if [ $DRY = 1 ]; then
  # What WOULD have gone up, signed for the App Store: its entitlements, and who signed it.
  rm -rf "$WORK/ipa" "$WORK/pkg"
  IPA=$(ls "$WORK/export-iOS"/*.ipa 2>/dev/null | head -1 || true); [ -n "$IPA" ] || fail "the iPhone export made no .ipa"
  mkdir -p "$WORK/ipa"; (cd "$WORK/ipa" && unzip -q "$IPA")
  check_entitlements iOS "$WORK/ipa/Payload/AMSPacking.app" export
  say "iOS signed by: $(codesign -dvv "$WORK/ipa/Payload/AMSPacking.app" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
  PKG=$(ls "$WORK/export-macOS"/*.pkg 2>/dev/null | head -1 || true); [ -n "$PKG" ] || fail "the Mac export made no .pkg"
  pkgutil --expand-full "$PKG" "$WORK/pkg" >/dev/null
  MACAPP=$(find "$WORK/pkg" -name AMSPacking.app -maxdepth 4 -type d | head -1)
  [ -n "$MACAPP" ] || fail "the Mac .pkg holds no AMSPacking.app"
  check_entitlements macOS "$MACAPP" export
  say "macOS signed by: $(codesign -dvv "$MACAPP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
  say "installer signed by: $(pkgutil --check-signature "$PKG" | sed -n 's/^ *1\. //p' | head -1)"
fi
done_stage

# ==== 10 Testers ==========================================================================================
testers_stage   # defined above, beside --testers-only

# ==== 11 Main =============================================================================================
stage "Main"
SHA=$(git rev-parse HEAD)
git fetch -q origin
if [ $DRY = 1 ]; then
  if git merge-base --is-ancestor origin/main HEAD; then
    done_stage "a real run would push ${SHA:0:7} to main (a fast-forward) and print the full suite's run"
  else
    done_stage "a real run would stop here: main has moved on"
  fi
else
  git merge-base --is-ancestor origin/main HEAD \
    || fail "the builds ARE in TestFlight, but main moved on meanwhile — merge origin/main and push to main by hand"
  git push -q origin "HEAD:main" || fail "the push to main was refused — the builds ARE in TestFlight; push ${SHA:0:7} to main by hand"
  RUN=""
  for i in $(seq 1 18); do
    RUN=$(gh run list --workflow tests.yml --branch main --commit "$SHA" -L 1 --json databaseId -q '.[0].databaseId // empty' 2>/dev/null || true)
    [ -n "$RUN" ] && break
    sleep 10
  done
  if [ -n "$RUN" ]; then
    done_stage "${SHA:0:7} is on main; the full suite runs after the fact: run $RUN ($(gh run view "$RUN" --json url -q .url 2>/dev/null || true))"
  else
    done_stage "${SHA:0:7} is on main; its Tests run did not show within 3 minutes — look in the Actions tab"
  fi
fi

summary
echo
if [ $DRY = 1 ]; then
  echo "DRY RUN finished: every stage but the upload worked. Archives and the exported app: $WORK"
else
  echo "AMS Packing $VERSION ($BUILD) is in TestFlight for the iPhone and the Mac."
fi
