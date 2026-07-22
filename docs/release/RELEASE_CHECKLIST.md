# Flowa — Google Play Release Checklist

## 0. ⚠️ Must‑do before publishing: Firebase package id
The app id was changed to **`com.flowa.app`** (per CLAUDE.md). Your Firebase
project (`flowa-4fca9`) is registered for `com.flowa.flowa`, so **phone sign‑in
will not work in the released app until you re‑register the new id:**

1. Run `flutterfire configure` and select/add the Android app **`com.flowa.app`**
   (or add it manually in the Firebase console). This regenerates
   `android/app/google-services.json` and `lib/firebase_options.dart`.
2. In **Firebase Console → Project settings → Your apps → com.flowa.app**, add
   the **SHA‑1 and SHA‑256** of BOTH:
   - your **upload key** (see command below), and
   - the **Play App Signing** key (Play Console → Setup → App signing).
   Phone Auth's app verification requires these.
3. Enable **Phone** sign‑in under Firebase → Authentication → Sign‑in method,
   and add your test phone numbers there for closed testing.

Get your upload key fingerprints:
```
keytool -list -v -alias upload -keystore android/app/upload-keystore.jks
```

## 1. App identity
- [x] App name **Flowa** (`android:label`)
- [x] Application id **com.flowa.app** (`android/app/build.gradle.kts`)
- [x] Version `1.0.0+1` → versionName `1.0.0`, versionCode `1` (`pubspec.yaml`).
      Bump the `+N` build number for every upload.

## 2. Icon & splash
- [x] Adaptive launcher icon (`flutter_launcher_icons`, cream bg + forest leaf)
- [x] Native splash (`flutter_native_splash`, light + dark)
- Replace `assets/icon/flowa_icon.png` (1024²) with final art and re‑run
  `dart run flutter_launcher_icons` if you refine the brand.

## 3. Signing
- [x] Upload keystore generated at `android/app/upload-keystore.jks`
- [x] `android/key.properties` holds the passwords (alias `upload`)
- [x] Both are **git‑ignored** (`android/.gitignore`)
- [x] Release build wired to the keystore (falls back to debug if absent)
- **Back up `upload-keystore.jks` + the password offline.** The generated
  password is a placeholder — change it (regenerate the key) before publishing if
  you prefer, then update `key.properties`. With **Play App Signing** enabled,
  losing the *upload* key is recoverable via Play Console.

## 4. Build the release artifact
```
flutter build appbundle            # -> build/app/outputs/bundle/release/app-release.aab
```
Upload the `.aab` to Play Console.

## 5. Deploy backend (one‑time)
```
firebase functions:secrets:set GEMINI_API_KEY   # if not done
firebase deploy --only functions,firestore:rules
```

## 6. Play Console — Store listing
- [ ] Short description + full description (see `PLAY_LISTING.md`)
- [ ] **App icon** 512×512 PNG
- [ ] **Feature graphic** 1024×500 PNG (cream bg, leaf mark, "Plan calmly. Focus deeply.")
- [ ] **Phone screenshots** — at least 2 (recommended 4–8), 1080×1920 or similar.
      Capture: Daily plan, AI planner, Deep Focus, Community, Progress, Blocking.
- [ ] (Optional) 7‑inch / 10‑inch tablet screenshots

## 7. Play Console — App content
- [ ] **Privacy policy URL** (host `PRIVACY_POLICY.md`)
- [ ] **Data safety form**:
      - Collected: phone number (account mgmt), name + app activity (tasks),
        app info (chosen blocked packages). Encrypted in transit. Users can
        request deletion.
      - **Not** collected/shared: location, contacts, photos, financial info.
      - No data shared with third parties for ads.
- [ ] **Permissions**: justify Usage Access / overlay / special‑use FGS using the
      text in `PLAY_LISTING.md`. (No Accessibility declaration needed — the app
      doesn't use it.)
- [ ] **Content rating** questionnaire → expected **Everyone / PEGI 3**
      (no violence, no user‑generated public content beyond a points leaderboard).
- [ ] **Target audience**: 13+ (not directed at children).
- [ ] **Ads**: declare **No ads**.

## 8. Testing
- [ ] **Closed testing** track: upload the `.aab`, add tester emails (or a Google
      Group), share the opt‑in link.
- [ ] Verify on a real device: phone sign‑in, create task, AI plan, focus session,
      app blocking (grant Usage Access + overlay), points/streak, dark mode.
- [ ] Google now requires a **closed test with ~12 testers for ~14 days** before a
      personal developer account can promote to production — start this early.

## 9. Production
- [ ] Promote the closed‑testing build to production once stable.
