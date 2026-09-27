#!/usr/bin/env python3
"""Releases the build just uploaded to the tester group, so it actually
reaches the phone.

A successful upload does NOT put a build in TestFlight. It sits in App Store
Connect until it is released to a group, and an internal group does not pick
new builds up by itself — each one has to be assigned. Twice I told him the
group would do it automatically, and twice he had to come back and say the new
version was not there. So the pipeline does it.

Needs, in the environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH,
plus APP_BUNDLE_ID and BUILD_VERSION. Standard library and openssl only.
"""
import base64, json, os, subprocess, sys, time, urllib.parse, urllib.request, urllib.error

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ["ASC_KEY_PATH"]
BUNDLE = os.environ.get("APP_BUNDLE_ID", "com.schabbauer.AMSPacking")
VERSION = os.environ["BUILD_VERSION"]
GROUP_NAME = os.environ.get("TESTER_GROUP", "Martin")


def token() -> str:
    def b64(raw: bytes) -> bytes:
        return base64.urlsafe_b64encode(raw).rstrip(b"=")
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": ISSUER, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    signing_input = (b64(json.dumps(header, separators=(",", ":")).encode()) + b"."
                     + b64(json.dumps(payload, separators=(",", ":")).encode()))
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing_input, capture_output=True, check=True).stdout
    # openssl emits DER; ES256 wants raw r||s.
    i = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    raw = b""
    for _ in range(2):
        length = der[i + 1]
        raw += der[i + 2:i + 2 + length].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + length
    return (signing_input + b"." + b64(raw)).decode()


def call(method: str, path: str, body=None):
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def q(params: dict) -> str:
    return "?" + urllib.parse.urlencode(params)


code, apps = call("GET", "/v1/apps" + q({"filter[bundleId]": BUNDLE}))
if code != 200 or not apps.get("data"):
    sys.exit(f"could not find the app for {BUNDLE}: HTTP {code}")
app_id = apps["data"][0]["id"]

# Apple processes for a few minutes before the builds exist to be released.
# AMS Packing uploads TWO builds per run — one for the iPhone, one for the Mac —
# with the same build number, and both must reach the group.
#
# 🪤 0.27 (build 33, 2026-09-27): the old loop gave up after five minutes with ONE
# build and released only that — the Mac's copy appeared minutes later and never
# reached his Mac. Now it waits up to 30 minutes for BOTH, and checks afterwards.
def builds_of_this_version():
    code, builds = call("GET", "/v1/builds" + q({"filter[app]": app_id, "filter[version]": VERSION, "limit": 10}))
    return [b for b in builds.get("data", []) if b["attributes"].get("version") == VERSION]

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
        print(f"::warning::only {len(ready)} of 2 builds of {VERSION} appeared in 30 minutes — "
              "the other device will not get this version")
        break
    print(f"waiting for Apple to finish processing {VERSION} (need the iPhone AND the Mac build)...")
    time.sleep(30)

if not build_ids:
    sys.exit(f"::error::build {VERSION} never appeared in App Store Connect")

code, groups = call("GET", "/v1/betaGroups" + q({"filter[app]": app_id, "limit": 20}))
group = next((g for g in groups.get("data", [])
              if g["attributes"].get("name") == GROUP_NAME), None)
if group is None:
    sys.exit(f"::error::no tester group called '{GROUP_NAME}'. "
             "Nothing will reach a device until one exists.")

for build_id in build_ids:
    code, _ = call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                   {"data": [{"type": "builds", "id": build_id}]})
    if code not in (200, 201, 204):
        sys.exit(f"::error::could not release build {build_id} to '{GROUP_NAME}': HTTP {code}")

code, released = call("GET", f"/v1/betaGroups/{group['id']}/builds" + q({"limit": 200}))
have = [b["attributes"].get("version") for b in released.get("data", [])]
print(f"released to '{GROUP_NAME}'. That group now has: {', '.join(have)}")
copies = have.count(VERSION)
print(f"build {VERSION} is in the group {copies} time(s) — the iPhone and the Mac need 2")
if copies < 2:
    print(f"::warning::build {VERSION} reached the group only {copies} time(s): one device will not get it")
