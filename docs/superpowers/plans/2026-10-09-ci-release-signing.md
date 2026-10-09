# CI Release Signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and sign release APKs on GitHub Actions (manual trigger) with one fixed release key that is also usable locally.

**Architecture:** A release keystore generated once on the owner's machine (outside the repo) feeds Gradle through a git-ignored `android/key.properties`. Gradle signs `release` with it when present, else falls back to debug with a warning. A `workflow_dispatch` workflow recreates `key.properties` from secrets, tests, builds, verifies the certificate fingerprint and publishes a GitHub release.

**Tech Stack:** Flutter 3.44.5, Gradle Kotlin DSL (AGP), JDK 17 `keytool`/`apksigner`, GitHub Actions, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-10-09-ci-release-signing-design.md`

## Global Constraints

- Keystore: PKCS12, RSA 4096, validity 36500 days, alias `cookbook`, DN `CN=Cookbook, O=TheKotti`, file `cookbook-release.jks`.
- Password: 32 random alphanumeric chars; store password == key password. Never printed in chat, never committed.
- Key folder: `C:\Users\konst\.cookbook-signing\` containing `cookbook-release.jks`, `key.properties`, `keystore.base64.txt`, `cert-sha256.txt`.
- `key.properties` keys: `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
- Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_CERT_SHA256`.
- Workflow: `.github/workflows/release.yml`, `workflow_dispatch` only, input `version` matching `^\d+\.\d+(\.\d+)?$`, `ubuntu-latest`, `permissions: contents: write`, Flutter 3.44.5, Java 17 Temurin.
- Build: `--build-name` = version padded to 3 parts, `--build-number ${{ github.run_number }}`. Release: tag `v<version>`, title `<version>`, asset `app-release.apk`, `--generate-notes --latest`, `--target` = the built commit SHA.
- Shell for local commands: Git Bash; JDK at `/c/Program Files/Microsoft/jdk-17.0.20.101-hotspot`, build-tools at `$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0`, Flutter at `/c/src/flutter/bin`.

## Review Focus

1. **Windows paths in `key.properties`:** `.properties` treats `\` as an escape, so `storeFile` must use forward slashes (`C:/Users/...`) or the local build can't find the keystore. → Task 1 writes forward slashes; Task 2 Step 3 builds locally with it.
2. **Fingerprint format mismatch:** `keytool` prints `AB:CD:...` (uppercase, colons), `apksigner` prints `abcd...` (lowercase, no colons). The comparison must normalize both (strip `:`, whitespace, lowercase) or every CI run fails. → Task 1 stores the normalized form; Task 3 Step 2 tests the compare logic.
3. **Version typed with a `v` prefix or extra spaces** (`v1.5`, ` 1.5`): must be rejected with a clear message, not create tag `vv1.5`. → Task 3 Step 2.
4. **Workflow dispatched from a non-`main` branch:** would publish a release from unmerged code. Expected: fail unless `github.ref == 'refs/heads/main'`. → Task 3 Step 2 (guard), Task 3 Step 1 lists it.
5. **Base64 secret pasted with line breaks / trailing newline:** decoding must tolerate it (`base64 -d` ignores newlines; strip `\r`). → Task 3 Step 2.

---

### Task 1: Generate the release key (local, nothing committed)

**Files:**
- Create (outside repo): `C:\Users\konst\.cookbook-signing\{cookbook-release.jks,key.properties,keystore.base64.txt,cert-sha256.txt}`
- Create (git-ignored): `android/key.properties` (copy)

**Interfaces:**
- Produces: `android/key.properties` with `storeFile=C:/Users/konst/.cookbook-signing/cookbook-release.jks` (forward slashes); `cert-sha256.txt` holding 64 lowercase hex chars, no colons, no newline.

- [ ] **Step 1: Refuse to overwrite.** If `~/.cookbook-signing/cookbook-release.jks` exists, stop and ask the owner. (Overwriting a key = another forced reinstall.)
- [ ] **Step 2: Generate password + keystore** in one bash invocation without echoing the password: password from `openssl rand` / `/dev/urandom` filtered to `[A-Za-z0-9]`, 32 chars, held in a shell variable; `keytool -genkeypair -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 36500 -alias cookbook -dname "CN=Cookbook, O=TheKotti" -keystore … -storepass "$PW" -keypass "$PW"`.
- [ ] **Step 3: Write the companion files** in the same invocation: `key.properties` (4 keys, forward-slash `storeFile`), `keystore.base64.txt` (`base64 -w0`), `cert-sha256.txt` (from `keytool -list -v`, SHA256 line, normalized per Review Focus 2). Copy `key.properties` to `android/key.properties`.
- [ ] **Step 4: Verify.** `keytool -list -keystore … -storepass "$(grep storePassword …)"` shows alias `cookbook`, type PKCS12; `wc -c cert-sha256.txt` = 64; `git status --short` shows nothing new (key.properties ignored).

### Task 2: Gradle release signing

**Files:**
- Modify: `android/app/build.gradle.kts` (top imports, `android { signingConfigs … buildTypes.release }`)

**Interfaces:**
- Consumes: `android/key.properties` from Task 1 (same 4 keys).
- Produces: release builds signed by the release key when that file exists; debug-signed + `logger.warn("… release build is DEBUG-signed …")` otherwise. Task 3 relies on only the file's presence.

- [ ] **Step 1: Baseline (failing check).** With the current Gradle file, `flutter build apk --release` then `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk` → DN `CN=Android Debug` (this is the bug).
- [ ] **Step 2: Implement.** Load `rootProject.file("key.properties")` into `java.util.Properties` if it exists; `signingConfigs { create("release") { storeFile = file(props["storeFile"]); storePassword; keyAlias; keyPassword } }` (`file()` resolves relative paths against `android/app` — use `rootProject.file` for relative values so they resolve against `android/`); `release` uses it when loaded, otherwise debug + warning. Replace the template TODO comment.
- [ ] **Step 3: Verify release-signed.** Rebuild; `apksigner verify --print-certs` shows `CN=Cookbook, O=TheKotti` and its SHA-256 equals `cert-sha256.txt`.
- [ ] **Step 4: Verify fallback.** Temporarily rename `android/key.properties` → build succeeds, output contains the warning, cert is `CN=Android Debug`. Restore the file.
- [ ] **Step 5: `flutter analyze`** → no issues.
- [ ] **Step 6: Commit** `android/app/build.gradle.kts` — `feat: sign release builds with release key from key.properties`.

### Task 3: Release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Create (scratchpad, not committed): `check_release_logic.sh` — test harness for the shell logic

**Interfaces:**
- Consumes: secrets from Global Constraints; `android/key.properties` format from Task 1 (`storeFile` absolute path under `$RUNNER_TEMP`).
- Produces: release `v<version>` with asset `app-release.apk`.

- [ ] **Step 1: Write the failing logic test** (scratchpad bash script) that sources the workflow's validation/normalization snippets extracted as functions `validate_version`, `build_name`, `norm_fp` and asserts:
  - `validate_version 1.5` ok; `1.5.2` ok; `v1.5`, ` 1.5`, `1`, `1.5.2.1`, `` → fail with message
  - `build_name 1.5` = `1.5.0`; `build_name 1.5.2` = `1.5.2`
  - `norm_fp "AB:CD:ef"` = `abcdef`; `norm_fp $'abcd\r\n'` = `abcd`
  Run → FAIL (functions not defined).
- [ ] **Step 2: Write `release.yml`.** Steps in spec §3 order. The validate step defines the three functions inline (same bodies the harness extracts between `# BEGIN logic` / `# END logic` markers) and also fails if: `github.ref != refs/heads/main`; `git ls-remote --tags origin "v$VERSION"` non-empty; any secret empty. Pass `inputs.version` via `env:`, never interpolated into the script (injection). Keystore decode: `printf '%s' "$B64" | tr -d '\r' | base64 -d > "$RUNNER_TEMP/release.jks"`. Fingerprint check: `apksigner` from `$ANDROID_HOME/build-tools/<latest>`; compare `norm_fp` of its SHA-256 line with `norm_fp` of the secret. Actions: `actions/checkout@v4`, `actions/setup-java@v4` (temurin 17), `subosito/flutter-action@v2` (`flutter-version: 3.44.5`, `channel: stable`). Publish with `GH_TOKEN: ${{ github.token }}`.
- [ ] **Step 3: Run the logic test** → all assertions pass.
- [ ] **Step 4: Lint.** Parse the YAML (`python -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))"`) → no error; if Docker is available, `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest` → no findings.
- [ ] **Step 5: Commit** `.github/workflows/release.yml` — `ci: add manual release workflow with signed APK`.

### Task 4: README

**Files:**
- Modify: `README.md` (`## Building for install` → `### Android APK`; new `## Releasing` before `## Project layout`)

- [ ] **Step 1: Update "Android APK":** release builds are signed with the release key when `android/key.properties` exists (see Releasing); otherwise debug-signed with a warning, and such an APK won't install over a published release. Remove nothing else.
- [ ] **Step 2: Add "Releasing":** run *Actions → Release → Run workflow* on `main`, enter `1.5`-style version; what it checks (main only, tag must be new, analyze + tests, certificate fingerprint); one-time setup: key lives in `C:\Users\konst\.cookbook-signing\` (must be backed up off-machine; losing it forces users to reinstall), the 4 secrets and which file each comes from, copy `key.properties` into `android/` for local signed builds.
- [ ] **Step 3: Commit** `README.md` — `docs: document release workflow and signing`.

### Task 5: Hand-off (no code)

- [ ] **Step 1:** Push the branch, open a PR (not merged by Claude).
- [ ] **Step 2:** Give the owner step-by-step instructions: back up the key folder; add the 4 secrets (Settings → Secrets and variables → Actions, or `gh secret set NAME < file` commands that read from the files, password via `gh secret set ANDROID_KEYSTORE_PASSWORD` interactive prompt); merge the PR; run the workflow with `1.5`; install-over-1.4 caveat.
- [ ] **Step 3:** After the owner's first successful run and with their go-ahead: `gh release edit v1.5 --notes-file` prepending the spec §6 migration paragraph.
