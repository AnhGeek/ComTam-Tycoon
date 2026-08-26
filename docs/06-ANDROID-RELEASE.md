# 06 — Android: Build & Release Guide

**Platform decision:** ADR-0006 in `00-TECH-STACK.md`. Android leads, iOS follows.

---

## 1. Where the project actually stands

| Layer | State |
|---|---|
| `ComTam.Core` — all game rules | ✅ Built, 77 tests passing, platform-agnostic |
| Console harness — playable loop | ✅ Runs, smoke-tested |
| Android player settings | ✅ Scripted (`AndroidBuildSetup.cs`) |
| Manifest / gradle templates | ✅ Written |
| CI that builds an APK | ✅ Written (`.github/workflows/android-build.yml`) |
| **Unity scene + assets** | ❌ **Missing — this is the only real blocker** |
| **An actual APK** | ❌ Cannot be produced until the scene exists |

**The one thing standing between this repo and an installable APK is the
Restaurant scene.** Everything either side of it is done. Building that scene
requires the Unity Editor once, by a human, following `unity/SCENE-SETUP.md`.

`ComTam.Core` needed **zero changes** for the Android pivot. That is ADR-0001
paying for itself: the simulation never knew what platform it was on.

---

## 2. Two routes to an APK

### Route A — GitHub Actions (recommended; no local Unity install)

1. Build the Restaurant scene once in the Editor (`unity/SCENE-SETUP.md`) and
   commit it.
2. Get a free Unity Personal licence file and add repository secrets:
   `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`
   (activation flow: <https://game.ci/docs/github/activation>)
3. **Actions ▸ Android build ▸ Run workflow**, choose `apk`.
4. Download `comtam-tycoon-android` from the run's artifacts.
5. `adb install ComTamTycoon.apk`, or copy it to a phone and open it.

No keystore is needed for this — an unsigned/debug-signed APK installs fine for
testing. First run takes ~30–40 min; cached runs are much faster.

### Route B — Local Unity

```bash
./tools/sync-core-to-unity.sh          # mirror Core into the Unity project
# open unity/ComTamTycoon in Unity 6000.0 LTS
# menu: Cơm Tấm ▸ Android ▸ Apply Settings
# menu: Cơm Tấm ▸ Android ▸ Verify Vietnamese Font Coverage
# File ▸ Build Settings ▸ Android ▸ Build
```

---

## 3. Why I cannot build the APK in this container

Verified, not assumed:

| Requirement | Status |
|---|---|
| Unity Editor | Not installed; licensed ~10 GB install, not an apt package |
| Android SDK platforms / NDK | `dl.google.com` **blocked** by network policy |
| AndroidX + Android Gradle Plugin | Live on Google Maven → also blocked |
| Ubuntu's `android-sdk` | Only **API 23** (Android 6.0, 2015) — unpublishable |
| Gradle 8.14.3, Java | ✅ Present, but useless without the above |

CI has none of these restrictions, which is why Route A exists.

---

## 4. Google Play release checklist

Ordered by when it blocks you.

### Before you can upload anything

- [ ] **Play Console account** — $25 one-off, identity verification takes days
      to weeks. Start this early; it is the longest-lead item.
- [ ] **Upload keystore** — generate it yourself, never in this repo:
      ```bash
      keytool -genkey -v -keystore upload.keystore \
        -alias comtam -keyalg RSA -keysize 2048 -validity 10000
      ```
      **Back it up offline.** Lose it and you can never update the app again.
      Enrol in Play App Signing so Google holds the release key.
- [ ] **AAB, not APK** — Play only accepts App Bundles.
- [ ] **targetSdkVersion** — Play raises the floor every August. Check the
      current requirement before submitting; it is a hard rejection.

### Store listing

- [ ] App name, short (80 char) and full (4000 char) description — write these
      in **Vietnamese and English**
- [ ] Icon 512×512, feature graphic 1024×500
- [ ] At least 2 phone screenshots (portrait, ≥ 1080 px on the short side)
- [ ] Short gameplay video — cheap to capture, materially improves conversion
- [ ] Category: Games ▸ Simulation. Content rating: IARC questionnaire

### Legal / compliance

- [ ] **Privacy policy URL** — required even for an offline game
- [ ] **Data Safety form** — Phase 1 collects nothing and requests **no
      permissions**, which makes this trivially honest. It gets much harder once
      ads land in Phase 8; declare the ad SDK's collection accurately then.
- [ ] Ads declaration — "No" today, "Yes" from Phase 8
- [ ] Target audience — **not** "children", or you inherit Families Policy
      obligations that conflict with standard ad mediation

### Before you press publish

- [ ] Internal testing track first — never straight to production
- [ ] Test on a real low-end device (Snapdragon 6-series, 4 GB RAM), not just an
      emulator
- [ ] Verify Vietnamese renders on-device — emulator fonts differ from OEM fonts
- [ ] Check APK/AAB size (target < 150 MB, well within reach)
- [ ] Staged rollout at 10%, watch crash-free rate for 48 h before widening

---

## 5. My recommendation on timing

**Do not publish Phase 1.** What exists is one day, one dish, no save, no
upgrades, no art, no audio — a player finishes in ~3 minutes with nothing to
return to. Play's early ratings are sticky and disproportionately weight your
listing forever; spending them on an MVP is an expensive way to learn something
five friends with a sideloaded APK will tell you for free.

**The right sequence:**

1. Build the scene → get an APK from CI
2. Sideload it to 5 people → answer risk R1: *is the grill actually fun?*
3. Only if yes, continue to Phase 2 (polish) and Phase 3 (progression)
4. Internal testing track around Phase 6
5. Public release after Phase 9

Sideloading is the whole reason Android-first is the right call — you can do
step 2 this week, for free, with no store review in the loop.

---

## 6. Device test matrix (risk R12, now continuous)

Android-first promotes fragmentation testing from a Phase 9 task to an
every-phase habit. Minimum viable matrix:

| Tier | Example | Why |
|---|---|---|
| Low | Snapdragon 6-series / Helio G-series, 4 GB, 720×1600 | **The baseline.** If it holds 60 FPS here it holds everywhere |
| Mid | Snapdragon 7-series, 6 GB, 1080×2400 | The volume device in VN |
| High | Snapdragon 8-series, 1440p, 120 Hz | Catches frame-rate-dependent bugs — which the fixed 20 Hz simulation step is designed to prevent |
| Tablet | Any 10" | Verify the portrait UI does not break; not a target |

Watch specifically for: thermal throttling after ~10 minutes, `Vulkan` vs
`OpenGLES3` rendering differences, OEM font substitution mangling Vietnamese,
and back-button behaviour (Android has one; iOS does not — it must pause, never
quit mid-day).
