# Sites Dashboard Target UI Migration — Code Review

Plan: `plans/260618-2136-sites-dashboard-target-ui-migration/plan.md`
Scope: 9 files (3 modified, 6 new). Build + 548 KDWarmKit tests pass.

## Scope (LOC)

| File | LOC | <200? |
|------|----:|:---:|
| DashboardWindow.swift | 118 | yes |
| dashboard-sidebar-view.swift (new) | 101 | yes |
| SitesSectionView.swift | 187 | yes |
| SiteRowView.swift | 140 | yes |
| sites-screen-components.swift (new) | 186 | yes |
| site-share-control-view.swift (new) | 80 | yes |
| site-row-overflow-menu.swift (new) | 56 | yes |
| site-row-runtime-badge.swift (new) | 46 | yes |
| site-row-status-badge.swift (new) | 27 | yes |

All files comply with the <200 LOC guideline.

## Acceptance Criteria

### (a) Acceptance criteria — per item

1. **Sidebar identity + grouped nav + count badge + footer card** — PASS.
   - Identity row: icon tile + "KTStack" + "Pro" capsule at `dashboard-sidebar-view.swift:34-56`.
   - Grouped nav iterates `SidebarSection.allCases` preserving `manage/inspect/app` groups (`DashboardWindow.swift:78-83`, `dashboard-sidebar-view.swift:16-23`).
   - Live Sites count: `siteCount: server.registry.sites.count` (`DashboardWindow.swift:30`) → badge rendered only when `item == .sites` (`dashboard-sidebar-view.swift:62-69`).
   - Footer server card: dot + "Server \(label)" + version from `CFBundleShortVersionString` with fallback (`dashboard-sidebar-view.swift:74-100`).
   - Selection: `@Binding selection: SidebarItem?` passed through; `List(selection:)` preserved.

2. **Header: title + count pill + Scan + Import + New Site split (⌘N); second row pill + Start/Stop** — PASS.
   - First row at `sites-screen-components.swift:18-54`. New Site button has `.keyboardShortcut("n", modifiers: .command)` (line 40). Split menu has chevron + "Add Existing Folder".
   - Second row server pill + toggle (`sites-screen-components.swift:55-60`). `isBusy` disables toggle, preventing layout jump.

3. **Search ~40px, rounded bordered, magnifying glass, clear when text exists** — PASS.
   - `SitesSearchStrip` (`sites-screen-components.swift:75-105`): `.frame(height: 40)`, `KDRadius.control` border, magnifier icon, conditional clear button with accessibility label.

4. **Site row controls (36px tile, semibold name, mono domain, runtime 108, status 96, HTTPS toggle with domain label, share truncates, Open 78, accessible overflow with destructive Remove)** — PASS.
   - 36px type tile: `SiteTypeTile` `frame(width: 36, height: 36)` (`sites-screen-components.swift:131`).
   - Semibold name + mono domain TextField + inline error (`SiteRowView.swift:47-61`).
   - Runtime badge fixed 108pt (PHP menu + chevron + bordered bg) or non-PHP label fallback (`site-row-runtime-badge.swift:28,43`).
   - Status badge fixed 96pt (`site-row-status-badge.swift:16`).
   - HTTPS Toggle `.mini`, `labelsHidden`, accessibility label `"Serve \(site.domain) over HTTPS"` (`SiteRowView.swift:70-76`).
   - Share control truncation middle for active URL and error text (`site-share-control-view.swift:33,57`).
   - Open button width 78 + `.disabled(!canOpen)` (`SiteRowView.swift:81-83`).
   - Overflow Menu: accessible label "More actions for \(siteName)", destructive Remove with separator (`site-row-overflow-menu.swift:40-54`).

5. **Hover ~5% accent, no layout shift** — PASS. `.background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)` and the background is applied to the same row frame, so no resize (`SiteRowView.swift:99-101`).

6. **DNS footer pinned with shield icon + text + Reset/Disable buttons** — PASS. `DNSStatusBar(dns: dns)` at `SitesSectionView.swift:79`, pinned outside the `VStack` content padding. Reset/Disable buttons in `HelperApprovalView.swift:22-30`. Shield icon is delegated to existing `DNSStatusBar` which is unchanged in this plan — out of scope visually but functional.

7. **`SiteRowView` initializer preserved + no row behavior contract changes** — PASS. Initializer signature in `SiteRowView.swift:24-41` matches existing call site at `SitesSectionView.swift:118-131` with same closures (`onOpen`, `onRemove`, `onEditDomain` throws, `onSetVersion`, `onSetSecure`, `onOpenLogs`, `shareStatus`, `onToggleShare`). `SiteShareControlView` cases match `TunnelStatus` exactly (`idle/expired/starting/active(URL)/activeUnverified(URL)/error(String)` — verified at `KDWarmKit/Sources/Tunnel/TunnelModels.swift:3-9`).

### (b) Business-logic regression check — PASS

- `SitesContent` still owns: `showAddSheet`, `showScanSheet`, `showNewSheet`, `showImportSheet`, `searchText`, `removeError`, `removingSiteID`, `pendingRemoval` and all corresponding `.sheet` / `.alert` modifiers (`SitesSectionView.swift:27-34`, `82-96`).
- Remove flow unchanged: `SiteRemovalCoordinator` still invoked with same closures (`SitesSectionView.swift:165-185`).
- `SiteRowView` callbacks unchanged; types and order match (`SitesSectionView.swift:118-131`).
- `SiteShareControlView` covers all six `TunnelStatus` cases exhaustively; no default branch needed — change-safe for future enum additions if Swift forces exhaustiveness.
- Domain edit, PHP version select, HTTPS toggle, share start/stop, open in browser, Finder reveal, Terminal, Logs nav, VS Code debug, Remove — all still wired through the same callbacks.

### (c) Public-contract changes — PASS

- No `@EnvironmentObject` requirement changes in `DashboardWindow`/`SitesSectionView`.
- `SidebarItem` and `SidebarSection` enums retain identical cases/raw values (`DashboardWindow.swift:64-118`).
- `SiteRowView.init` keeps argument names/order/defaults (`SiteRowView.swift:24-28`).
- No exported symbol removed from KDWarmKit in this scope.

### (d) No new comments — PASS

`grep -nE "^\s*//|^\s*/\*|/\*\*|// MARK|// TODO|// FIXME|// HACK|// NOTE"` against the 9 reviewed files produced zero hits. The only `//` occurrence is inside the URL string at `SitesSectionView.swift:141` (`"\(scheme)://\(site.domain)/"`), which is content, not a comment.

### (e) Accessibility on icon-only controls — PASS

- Search clear button: `.accessibilityLabel("Clear search")` (`sites-screen-components.swift:94`).
- Overflow menu ellipsis: `.accessibilityLabel("More actions for \(siteName)")` (`site-row-overflow-menu.swift:54`).
- Share idle/expired antenna: `.accessibilityLabel(...)` (`site-share-control-view.swift:19`).
- PHP version menu: `.accessibilityLabel("PHP version \(phpVersion)")` (`site-row-runtime-badge.swift:38`).
- HTTPS toggle: `.accessibilityLabel("Serve \(site.domain) over HTTPS")` (`SiteRowView.swift:75`).
- Type tile: `.accessibilityLabel(type.label)` (`sites-screen-components.swift:135`).
- Status badge: `.accessibilityLabel(title)` (`site-row-status-badge.swift:17`).
- Server card: combined label (`dashboard-sidebar-view.swift:95`).

Active-share controls (copy, QR, stop) only have `.help(...)` tooltips — `.accessibilityLabel` is not explicit on each `Button { Image }`. The `.help` does provide a hover/VO hint on macOS, but explicit labels would be safer. Minor.

## Findings

### Medium

1. **Dead view `SiteRuntimeStatusView`** — `sites-screen-components.swift:147-169` defines `SiteRuntimeStatusView` with the same dot+text idiom as `SiteRowStatusBadge`. No call sites in the codebase (`grep` returns only the definition). Remove to avoid drift and shave 23 lines from the 186-line file.

2. **Active-share inner icon buttons lack `.accessibilityLabel`** — `site-share-control-view.swift:60-70` Copy, QR, Stop buttons rely solely on `.help(...)`. Add explicit `.accessibilityLabel("Copy public URL")`, `"Stop sharing"`, etc., to match the pattern used for the idle/error states.

3. **`SiteShareControlView` rendered inside fixed 150pt frame** — `SiteRowView.swift:79` wraps the share control in `.frame(width: 150, alignment: .trailing)`. Active state renders ~4 icon buttons + a truncating host label inside 150pt; on narrow windows this may overflow visually before truncation kicks in for QR/Stop. Plan acceptance says "share control (truncates)" — text does truncate, but inner Buttons do not compress. Verify against target screenshot at min window width (720pt × split sidebar). Not blocking.

### Low

4. **Stray whitespace lines in `DashboardWindow.swift`** — lines 6-8, 19-20 have trailing-only whitespace. Cosmetic.

5. **`SitesSectionView.swift:6-7`** — blank-but-indented line preceding `var onOpenLogs`. Cosmetic.

6. **`SitesServerStatusPill` declared `private struct` inside `sites-screen-components.swift`** — used only by `SitesHeaderView` in same file, so file-scope private is correct, but if reused later for sidebar/header parity, promote to internal. Not an issue today.

7. **Force-cast / fallback for version string** — `Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"` returns a hard-coded fallback "0.1.0" when the bundle is missing. Acceptable, but the hard-coded constant could drift from real bundle minimum. Consider a build-time constant. Cosmetic.

### Positive Observations

- Strict semantic-token usage throughout: `KDSpacing.spaceN`, `KDRadius.control/card`, `KDFont.body/headline/footnote/mono`, `Color.KDStatus.*`, `Color(nsColor: .separatorColor / .textBackgroundColor / .controlBackgroundColor / .controlColor)`. No raw hex or `.red`/`.blue` literals.
- File modularization respects 200-line ceiling; kebab-case for new files.
- `SiteShareControlView` exhaustively switches on `TunnelStatus` — future case additions force a compile error rather than a silent fallthrough.
- Hover state applied to background only, frame fixed via `minHeight: 58`, so no layout shift.
- `displayStatus` in `SitesHeaderView` mirrors the sidebar's `sidebarServerStatus` priority logic for `starting/error/warning` — consistent semantics.
- Initializer of `SiteRowView` retains defaults for `shareStatus` and `onToggleShare` — back-compat preserved.
- `SiteRowView.onChange(of: site.domain)` keeps `domainDraft` synced when the store updates externally — race-safe.

## Concurrency / Trust-boundary / Data Notes

- No new `@StateObject`/`@MainActor` boundaries introduced. Existing remove-flow `Task` + `MainActor.run` in `SitesSectionView.swift:165-186` is unchanged.
- No external input boundaries added; domain edit still goes through `try registry.editDomain(...)` and surfaces error inline.
- No PII or secrets exposure path changed; tunnel URL is the only externally visible string, behavior unchanged.
- No new authz/auth checks needed (UI only); destructive Remove still confirmed by parent alert.

## Recommended Actions

1. Delete dead `SiteRuntimeStatusView` from `sites-screen-components.swift`.
2. Add `.accessibilityLabel` to the three icon buttons inside `activeControls(url:unverified:)` in `site-share-control-view.swift`.
3. (Optional) Sanity-check the 150pt share-control frame against narrowest target window width; relax to `maxWidth` or use a flexible spacer if overflow becomes visible.
4. Trim trailing whitespace lines in `DashboardWindow.swift` and `SitesSectionView.swift`.

## Unresolved Questions

- Should `SiteRuntimeStatusView` be kept as a future hook (e.g., for service rows) or removed? Currently unused — recommending removal pending product intent.
- Active-share inner controls in a fixed 150pt frame: is the target screenshot truncation behavior at min window width acceptable, or should the share column become flexible?

---

**Status:** DONE_WITH_CONCERNS
**Summary:** All seven plan acceptance criteria pass with citations; no business-logic regressions; no breaking public-contract changes; zero new comments; semantic tokens used throughout. One dead view and a few minor a11y/cosmetic items flagged.
**Concerns/Blockers:** Dead `SiteRuntimeStatusView`; missing `.accessibilityLabel` on three active-share icon buttons; fixed 150pt share-control frame may overflow at min window width — none are blocking.
