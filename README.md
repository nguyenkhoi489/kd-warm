# KDWarm

A native macOS menu-bar app that serves local sites at `https://<name>.test` with trusted TLS,
multiple language runtimes, and one-click service management — **no Docker**. A Herd/Laragon-class
local dev host for macOS 13+, built in Swift/SwiftUI.

> Free / open-source. Distributed as a Developer-ID-signed, notarized DMG with Sparkle updates.

## Features

- **Manual site registration** (Valet-`link` style) under `~/Sites/WWW/`; each site gets an editable
  `<name>.test` domain, auto-detected type (PHP / static / Node).
- **Trusted local TLS** — vendored **mkcert** mints a local CA + per-site `*.test` leaf certs, trusted
  in the System Keychain (and Firefox/NSS). One-click secure toggle per site.
- **Automatic `.test` DNS** via vendored **dnsmasq** + `/etc/resolver/test`, driven by a privileged
  helper (`SMAppService`, DNS/CA-only trust boundary) with a one-time `sudo` fallback.
- **Service manager** — nginx, PHP-FPM pools, dnsmasq, MySQL, PostgreSQL, Redis, Mailpit unified
  behind one `ServiceManager`. Services are **launchd-managed and persist across app quit** (the app
  is a controller); crashes auto-restart; live status pills + start/stop/restart.
- **Runtime manager** — bundled PHP 8.4 + on-demand download of more PHP versions, Node, Python, Go
  (checksum-verified). Per-project version switching via `.kdwarmrc` / `.nvmrc` / `.php-version`.
- **On-demand database engines** — MySQL / PostgreSQL / Redis install through the UI (not bundled), so
  the app ships lean.
- **Logs viewer** — live, virtualized per-service / per-site log tail with severity gutter + filter.
- **Mail catcher** — Mailpit with an embedded message viewer (sandboxed WKWebView); PHP `mail()`
  routes straight into it.
- **Auto-update** via Sparkle (EdDSA-signed appcast) and a full **Uninstall / Reset** flow.

## Architecture

Three targets, generated with **XcodeGen** (`project.yml`):

- **`KDWarm`** — the SwiftUI menu-bar app (`MenuBarExtra` + a `NavigationSplitView` dashboard).
- **`KDWarmKit`** — framework with all logic: services, runtimes, sites, TLS, DNS, logs, mail, the XPC
  contract, design tokens. (`KDWarmKitTests` covers it — 80+ unit tests.)
- **`KDWarmHelper`** — the privileged helper (root daemon); XPC surface limited to DNS + Keychain-CA.

Runtime data lives under `~/Library/Application Support/KDWarm/` (binaries staged out of the immutable
bundle into `bin/`, language runtimes under `runtimes/<lang>/<version>/`, per-engine data under
`data/`, configs/certs/logs alongside). Long-running services run as user LaunchAgents.

Authoritative design + decisions: `docs/tech-stack-and-architecture.md`, `docs/design-guidelines.md`.
Phase-by-phase implementation plan: `plans/260611-kdwarm-mvp-implementation/`.

## Build from source

Requires Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
# 1. Generate the Xcode project (the .xcodeproj is gitignored)
xcodegen generate

# 2. Build the bundled binaries (relocatable, vendored into KDWarm/Resources/bin — gitignored)
scripts/build-nginx-relocatable.sh
scripts/build-dnsmasq-relocatable.sh
scripts/build-php-static.sh                 # PHP 8.4 (the bundled default)
# mkcert + mailpit: drop the official arm64 binaries into KDWarm/Resources/bin/ (ad-hoc signed)

# 3. Build + test
xcodebuild -project KDWarm.xcodeproj -scheme KDWarm -destination 'platform=macOS' build
xcodebuild test -project KDWarm.xcodeproj -scheme KDWarmKit-Tests -destination 'platform=macOS'
```

On-demand engines (extra PHP versions, Node/Python/Go, MySQL/PostgreSQL/Redis) are downloaded by the
app at runtime; their relocatable build scripts live in `scripts/build-*-relocatable.sh` +
`scripts/build-php-versions.sh` and emit hosted `tar.gz` artifacts + checksums.

## Release

Requires an Apple **Developer ID Application** identity + notarytool credentials.

```bash
APP=path/to/KDWarm.app
DEV_ID="Developer ID Application: NAME (TEAMID)" scripts/release/sign-all-binaries.sh "$APP"
scripts/release/notarize.sh "$APP"          # notarytool submit/wait + staple
scripts/release/build-dmg.sh  "$APP"        # compressed DMG
scripts/release/license-audit.sh            # NOTICES.txt (+ GPL/SSPL source offer)
scripts/release/update-appcast.sh <dir>     # Sparkle EdDSA-signed appcast
```

## Status

All MVP phases (1–9) are implemented. Signing/notarization + appcast/artifact hosting require a
Developer-ID machine (the dev builds are ad-hoc-signed). See the phase plans for details.

## License

Free / open-source. Redistributed components (nginx, PHP, dnsmasq, mkcert, Mailpit, MySQL (GPLv2),
PostgreSQL, Redis (SSPL), Node, Sparkle) keep their own licenses — see the generated `NOTICES.txt`
(`scripts/release/license-audit.sh`), which includes a written offer of source for the GPL/SSPL
components.
