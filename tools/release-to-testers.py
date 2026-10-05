#!/usr/bin/env python3
"""Releases the build just uploaded to the tester group, so it actually
reaches the phone — and gives it the "What to Test" note the testers read.

A successful upload does NOT put a build in TestFlight. It sits in App Store
Connect until it is released to a group, and an internal group does not pick
new builds up by itself — each one has to be assigned. Twice I told him the
group would do it automatically, and twice he had to come back and say the new
version was not there. So the pipeline does it.

Needs, in the environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH,
APP_BUNDLE_ID, BUILD_VERSION and TESTER_GROUP (the group's name — a repository
variable, not written in this public repository). WHAT_TO_TEST is optional: the
notes typed when the release was started. Standard library and openssl only.

    python3 tools/release-to-testers.py --self-check

checks, without the network, that the "What to Test" requests are built the way
App Store Connect wants them (CI runs it on every push).
"""
import base64, json, os, subprocess, sys, time, urllib.parse, urllib.request, urllib.error

API = "https://api.appstoreconnect.apple.com"
# App Store Connect takes at most 4000 characters of "What to Test".
WHATS_NEW_MAX = 4000
LOCALE = "en-US"


def token(key_id: str, issuer: str, key_path: str) -> str:
    def b64(raw: bytes) -> bytes:
        return base64.urlsafe_b64encode(raw).rstrip(b"=")
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    signing_input = (b64(json.dumps(header, separators=(",", ":")).encode()) + b"."
                     + b64(json.dumps(payload, separators=(",", ":")).encode()))
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                         input=signing_input, capture_output=True, check=True).stdout
    # openssl emits DER; ES256 wants raw r||s.
    i = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    raw = b""
    for _ in range(2):
        length = der[i + 1]
        raw += der[i + 2:i + 2 + length].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + length
    return (signing_input + b"." + b64(raw)).decode()


def q(params: dict) -> str:
    return "?" + urllib.parse.urlencode(params)


# --- "What to Test" -----------------------------------------------------------
#
# His notes used to go only into the run's own summary, which no tester ever
# sees (the spec pass, 5 Oct 2026). TestFlight shows a build's "What to Test"
# from its beta build localization: one per build and language, created with a
# POST, changed with a PATCH. The notes arrive through the environment, never
# pasted into a script — 0.59's notes held quotes and broke the shell.

def whats_new_text(notes: str) -> str:
    """The notes as App Store Connect will take them: trimmed, at most 4000 characters."""
    text = (notes or "").strip()
    if len(text) > WHATS_NEW_MAX:
        text = text[:WHATS_NEW_MAX - 1].rstrip() + "…"
    return text


def create_body(build_id: str, text: str) -> dict:
    """POST /v1/betaBuildLocalizations — a new "What to Test" for one build."""
    return {"data": {"type": "betaBuildLocalizations",
                     "attributes": {"locale": LOCALE, "whatsNew": text},
                     "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}}


def update_body(localization_id: str, text: str) -> dict:
    """PATCH /v1/betaBuildLocalizations/{id} — its text changed."""
    return {"data": {"type": "betaBuildLocalizations", "id": localization_id,
                     "attributes": {"whatsNew": text}}}


def existing_localization(call, build_id: str):
    """The build's en-US localization id, or None."""
    code, found = call("GET", "/v1/betaBuildLocalizations"
                       + q({"filter[build]": build_id, "filter[locale]": LOCALE, "limit": 1}))
    if code != 200:
        return None
    data = found.get("data") or []
    return data[0]["id"] if data else None


def set_whats_new(call, build_id: str, text: str) -> bool:
    """Gives one build its "What to Test". Never fails the release — it says why."""
    have = existing_localization(call, build_id)
    if have:
        code, answer = call("PATCH", f"/v1/betaBuildLocalizations/{have}", update_body(have, text))
    else:
        code, answer = call("POST", "/v1/betaBuildLocalizations", create_body(build_id, text))
        if code == 409:
            # Made meanwhile (Apple can make one as processing ends): change it instead.
            have = existing_localization(call, build_id)
            if have:
                code, answer = call("PATCH", f"/v1/betaBuildLocalizations/{have}", update_body(have, text))
    if code in (200, 201):
        print(f"What to Test set on build {build_id[:8]}")
        return True
    detail = "; ".join(e.get("detail", "") for e in (answer or {}).get("errors", [])) or "no detail"
    print(f"::warning::could not set What to Test on build {build_id[:8]} (HTTP {code}: {detail}) — "
          "the build is released all the same; the notes are in the run's summary")
    return False


def self_check() -> None:
    """The request bodies, checked without the network."""
    tricky = 'Settings: "Both have one" — it\'s $HOME & `back`\nline two åäö \U0001F600'
    body = json.loads(json.dumps(create_body("build-1", whats_new_text(tricky))))
    assert body["data"]["type"] == "betaBuildLocalizations"
    assert body["data"]["attributes"] == {"locale": "en-US", "whatsNew": tricky}, body
    assert body["data"]["relationships"]["build"]["data"] == {"type": "builds", "id": "build-1"}
    patch = update_body("loc-1", "x")
    assert patch == {"data": {"type": "betaBuildLocalizations", "id": "loc-1", "attributes": {"whatsNew": "x"}}}
    assert whats_new_text("  \n ") == ""
    long = whats_new_text("a" * 5000)
    assert len(long) == WHATS_NEW_MAX and long.endswith("…"), len(long)

    # The whole conversation against a pretend App Store Connect.
    calls = []
    def pretend(existing, post_code=201, appears=None):
        def call(method, path, body=None):
            calls.append((method, path, body))
            if method == "GET":
                # `appears`: none at first, then one — made while this was asking.
                found = existing or (appears if sum(c[0] == "GET" for c in calls) > 1 else None)
                return 200, {"data": [{"id": found}] if found else []}
            if method == "POST":
                return post_code, {"errors": [{"detail": "already there"}]} if post_code == 409 else {"data": {}}
            return 200, {"data": {}}
        return call
    calls.clear()
    assert set_whats_new(pretend(None), "b1", "Notes")
    assert [c[0] for c in calls] == ["GET", "POST"] and "filter%5Bbuild%5D=b1" in calls[0][1], calls
    calls.clear()
    assert set_whats_new(pretend("L9"), "b1", "Notes")
    assert [c[0] for c in calls] == ["GET", "PATCH"] and calls[1][1].endswith("/L9"), calls
    calls.clear()
    assert set_whats_new(pretend(None, post_code=409, appears="L7"), "b1", "Notes"), "made meanwhile: changed instead"
    assert [c[0] for c in calls] == ["GET", "POST", "GET", "PATCH"] and calls[3][1].endswith("/L7"), calls
    calls.clear()
    assert not set_whats_new(pretend(None, post_code=409), "b1", "Notes"), "a 409 with nothing to change only warns"
    print("self-check: the What to Test requests are well formed")


def main() -> None:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_KEY_PATH"]
    bundle = os.environ.get("APP_BUNDLE_ID", "com.schabbauer.AMSPacking")
    version = os.environ["BUILD_VERSION"]
    # The group's name is not written here: the repository is public. It comes from
    # the repository variable TESTER_GROUP, and without it nothing can be released.
    group_name = os.environ.get("TESTER_GROUP", "").strip()
    if not group_name:
        sys.exit("::error::TESTER_GROUP is empty — set the repository variable TESTER_GROUP "
                 "(Settings > Secrets and variables > Actions > Variables) to the tester group's name.")
    notes = whats_new_text(os.environ.get("WHAT_TO_TEST", ""))

    def call(method: str, path: str, body=None):
        req = urllib.request.Request(
            API + path, method=method,
            data=json.dumps(body).encode() if body else None,
            headers={"Authorization": f"Bearer {token(key_id, issuer, key_path)}",
                     "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            try:
                return e.code, json.loads(e.read() or b"{}")
            except ValueError:
                return e.code, {}

    code, apps = call("GET", "/v1/apps" + q({"filter[bundleId]": bundle}))
    if code != 200 or not apps.get("data"):
        sys.exit(f"could not find the app for {bundle}: HTTP {code}")
    app_id = apps["data"][0]["id"]

    # Apple processes for a few minutes before the builds exist to be released.
    # AMS Packing uploads TWO builds per run — one for the iPhone, one for the Mac —
    # with the same build number, and both must reach the group.
    #
    # 🪤 0.27 (build 33, 2026-09-27): the old loop gave up after five minutes with ONE
    # build and released only that — the Mac's copy appeared minutes later and never
    # reached his Mac. Now it waits up to 30 minutes for BOTH, and checks afterwards.
    def builds_of_this_version():
        code, builds = call("GET", "/v1/builds" + q({"filter[app]": app_id, "filter[version]": version, "limit": 10}))
        return [b for b in builds.get("data", []) if b["attributes"].get("version") == version]

    build_ids = []
    for attempt in range(60):
        mine = builds_of_this_version()
        print(f"attempt {attempt + 1}: " + ", ".join(f"{b['id'][:8]} {b['attributes'].get('processingState')}" for b in mine))
        ready = [b["id"] for b in mine if b["attributes"].get("processingState") in ("VALID", "PROCESSING")]
        if len(ready) >= 2:
            build_ids = ready
            break
        if ready and attempt >= 59:
            build_ids = ready
            print(f"::warning::only {len(ready)} of 2 builds of {version} appeared in 30 minutes — "
                  "the other device will not get this version")
            break
        print(f"waiting for Apple to finish processing {version} (need the iPhone AND the Mac build)...")
        time.sleep(30)

    if not build_ids:
        sys.exit(f"::error::build {version} never appeared in App Store Connect")

    code, groups = call("GET", "/v1/betaGroups" + q({"filter[app]": app_id, "limit": 20}))
    group = next((g for g in groups.get("data", [])
                  if g["attributes"].get("name") == group_name), None)
    if group is None:
        sys.exit("::error::no tester group with the name in TESTER_GROUP. "
                 "Nothing will reach a device until one exists.")

    # The note first, so it is there when a tester opens the build.
    if notes:
        for build_id in build_ids:
            set_whats_new(call, build_id, notes)
    else:
        print("no notes given: the builds go out without a What to Test")

    for build_id in build_ids:
        code, _ = call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                       {"data": [{"type": "builds", "id": build_id}]})
        if code not in (200, 201, 204):
            sys.exit(f"::error::could not release build {build_id} to the tester group: HTTP {code}")

    code, released = call("GET", f"/v1/betaGroups/{group['id']}/builds" + q({"limit": 200}))
    have = [b["attributes"].get("version") for b in released.get("data", [])]
    print(f"released to the tester group. That group now has: {', '.join(have)}")
    copies = have.count(version)
    print(f"build {version} is in the group {copies} time(s) — the iPhone and the Mac need 2")
    if copies < 2:
        print(f"::warning::build {version} reached the group only {copies} time(s): one device will not get it")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-check"]:
        self_check()
    else:
        main()
