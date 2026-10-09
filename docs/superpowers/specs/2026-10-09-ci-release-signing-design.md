# Cookbook — Design Spec (CI release builds with a fixed signing key)

**Status:** Approved design, not yet implemented
**Date:** 2026-10-09
**Audience:** whoever implements or maintains the release process.

## 0. Summary

Release APKs are built and signed on GitHub Actions with one fixed release
key, triggered manually from the Actions tab. The same key is available
locally, so local release builds and CI builds are interchangeable on a
device.

### Problem being solved
Until now, `android/app/build.gradle.kts` signed release builds with the
**debug** key. Every machine generates its own random debug key, so v1.3
(built on one machine) and v1.4 (built on another) carry different
certificates:

| Release | Signer | SHA-256 |
|---|---|---|
| v1.3 | CN=Android Debug | `f26e4c3b…10bc` |
| v1.4 | CN=Android Debug | `39ff23f9…0d4b` |

Android refuses to update an app whose signature changed ("App not
installed"). Neither old debug key is suitable as a long-term release key, so
a new dedicated release key is introduced. This costs existing users **one
final** back up → uninstall → reinstall → restore, after which updates install
normally for as long as the key is kept.

### Resolved design decisions
- **Trigger:** manual `workflow_dispatch` only, with a `version` input
  (e.g. `1.5`). No tag-push or push-to-main trigger.
- **Key generation:** done once by Claude on the owner's machine with
  `keytool`; the owner backs it up and adds the GitHub secrets themselves.
  The password is never printed in chat or committed.
- **Fallback signing:** local builds without `android/key.properties` still
  fall back to the debug key (with a warning) so anyone can build. CI must
  never do this — missing signing material is a hard failure there.

## 1. The release key

Created once with JDK 17 `keytool`:

- Keystore: `cookbook-release.jks`, PKCS12, RSA 4096, validity 36500 days,
  alias `cookbook`, DN `CN=Cookbook, O=TheKotti`.
- Password: 32 random alphanumeric characters (store and key password are the
  same, as PKCS12 requires).
- Location: `C:\Users\konst\.cookbook-signing\` — outside the repo and outside
  OneDrive. The folder contains:
  - `cookbook-release.jks` — the keystore
  - `key.properties` — `storePassword`, `keyPassword`, `keyAlias`,
    `storeFile` (absolute path to the keystore)
  - `keystore.base64.txt` — the keystore base64-encoded, for the GitHub secret
  - `cert-sha256.txt` — the certificate's SHA-256 fingerprint (public, not
    secret; used for verification)
- A copy of `key.properties` is placed at `android/key.properties`
  (already git-ignored, as are `*.jks` / `*.keystore`).

**Loss of the keystore or its password means existing users must reinstall
again.** The owner is instructed to back the folder up off-machine (e.g. a
password manager or USB stick), not only to a synced folder.

## 2. Gradle signing (`android/app/build.gradle.kts`)

- Read `android/key.properties` if it exists (`rootProject.file("key.properties")`).
- If present: define `signingConfigs.release` from it (`storeFile` resolved
  relative to the `android/` dir when not absolute) and use it for the
  `release` build type.
- If absent: keep `signingConfigs.getByName("debug")` for `release` and log a
  warning (`logger.warn`) that the release build is debug-signed.
- No other Gradle changes.

## 3. GitHub Actions workflow (`.github/workflows/release.yml`)

Trigger: `workflow_dispatch` with required input `version`
(pattern `^\d+\.\d+(\.\d+)?$`). Runs on `ubuntu-latest`, with
`permissions: contents: write`.

Repository secrets (added by the owner):

| Secret | Content |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | contents of `keystore.base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `cookbook` |
| `ANDROID_CERT_SHA256` | contents of `cert-sha256.txt` |

Steps:
1. **Validate:** fail if `version` doesn't match the pattern, if tag
   `v<version>` already exists on origin, or if any secret is empty.
2. Checkout; set up Java 17 (Temurin) and Flutter 3.44.5 (stable).
3. `flutter pub get`, `flutter analyze`, `flutter test` — any failure stops
   the release.
4. **Restore signing:** decode the keystore to `$RUNNER_TEMP`, write
   `android/key.properties` pointing at it.
5. **Build:** `flutter build apk --release --build-name <name>
   --build-number ${{ github.run_number }}` where `<name>` is `version`
   padded to three parts (`1.5` → `1.5.0`).
6. **Verify signature:** run `apksigner verify --print-certs` on the APK and
   fail unless its SHA-256 equals `ANDROID_CERT_SHA256`.
7. **Publish:** `gh release create v<version> <apk> --title <version>
   --target <commit sha> --generate-notes --latest`. The APK keeps the name
   `app-release.apk`, as in earlier releases.

`pubspec.yaml`'s `version:` is not edited by the workflow; the build flags
override it.

## 4. Documentation

`README.md`:
- New **Releasing** section: how to run the workflow, the version input,
  what the workflow checks, and the one-time key/secret setup (pointing at
  where the key lives and stressing the backup).
- Update **Building for install**: release builds are signed with the release
  key when `android/key.properties` exists, otherwise debug-signed (which will
  not install over a published release).

## 5. Verification

- Locally, after key generation: `flutter build apk --release`, then
  `apksigner verify --print-certs` shows the release certificate
  (fingerprint equals `cert-sha256.txt`), not "Android Debug".
- Locally, temporarily without `android/key.properties`: the build still
  succeeds, debug-signed, with the warning.
- `flutter analyze` / `flutter test` unchanged.
- The workflow's first real run happens after the owner adds the secrets; it
  cannot be exercised before then. The first release produced is expected
  to be 1.5.

## 6. User-facing migration note (for the 1.5 release)

This is a one-off edit, not part of the workflow: after the first CI run,
the release notes are edited (`gh release edit --notes-file`, with the
owner's go-ahead) to prepend a paragraph: because the app is now
signed with a new permanent key, users with an older version must **export a
JSON backup in the app → uninstall → install 1.5 → import the backup**. This
is a one-time step; later updates install normally.

## 7. Out of scope

- Play Store publishing, app bundles (`.aab`), split-per-ABI APKs.
- iOS builds/signing.
- Running tests on every push/PR (separate CI concern).
- Fixing the two Windows-only `image_store` path tests (they pass on Linux).
