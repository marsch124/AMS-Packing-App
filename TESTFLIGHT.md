# Getting AMS Packing onto the iPhone and the Mac (TestFlight)

Everything is automated except two things only the account owner can do, once.
After that, a new version is one click: **Actions → TestFlight → Run workflow**.

## 1. Create the app's record in App Store Connect (browser, once)

1. Open <https://appstoreconnect.apple.com> and sign in.
2. **My Apps → the "+" → New App.**
3. Tick **both** platforms: **iOS** and **macOS** (one app, two platforms).
4. Name: **AMS Packing**. Bundle ID: **com.schabbauer.AMSPacking** (it is in the
   list already — Xcode registered it). SKU: `AMSPacking`.
5. Create. Nothing else on that page matters for TestFlight.

Then, still in App Store Connect: **TestFlight → Internal Testing → "+"** → make a
group called **Martin** and add yourself to it. (The other apps have this group
already; this app needs its own.)

## 2. Give the workflow the issuer ID (browser, once)

Three of the four secrets are already set. The fourth, the **Issuer ID**, is at
**Users and Access → Integrations → App Store Connect API**, at the top of the
page — a long code with dashes. Copy it, then in GitHub:
<https://github.com/marsch124/AMS-Packing-App/settings/secrets/actions> →
**New repository secret** → name `ASC_ISSUER_ID`, paste, Add.

## 3. Ship

**Actions → TestFlight → Run workflow.** It runs the whole test suite first (a
red suite ships nothing), then builds for the iPhone and for the Mac, sends both
to TestFlight and releases them to the Martin group. Apple takes a few minutes;
then the TestFlight app on each device offers it.

## The first sync

- The first shipped build talks to the **Production** CloudKit environment, which
  is empty until the schema is deployed there: in the browser, **CloudKit
  Console → iCloud.com.schabbauer.AMSPacking → Deploy Schema Changes to
  Production**. (The Development environment already has it, from the Mac.)
- Then, on ONE device, import a fresh backup from the web app. The other device
  shows the two doors; leave it on "My other device has my lists" and watch the
  templates arrive.

## Secrets (already set: key, key id, team id)

| Secret | What |
|---|---|
| `ASC_KEY_ID` | `63M2792NNV` — the ADMIN key (an App Manager key cannot cloud-sign) |
| `ASC_KEY_P8` | the contents of `AuthKey_63M2792NNV.p8` |
| `ASC_TEAM_ID` | `D24ENP83QQ` |
| `ASC_ISSUER_ID` | **to add** — step 2 |
