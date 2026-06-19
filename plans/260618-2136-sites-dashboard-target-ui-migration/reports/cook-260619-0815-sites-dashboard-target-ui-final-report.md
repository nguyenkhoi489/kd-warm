---
type: cook-completion
phase: all
date: 2026-06-19
plan: 260618-2136-sites-dashboard-target-ui-migration
---

# Sites Dashboard Target UI Migration — Cook Completion

## Result

All 4 phases complete. Build + 548 KDWarmKit tests pass.

## Implementation State

Baseline implementation from blocking plan `260618-2104-sites-ui-redesign` covered Phase 2/3 component extraction. This cook closed accessibility gaps and removed dead code.

### Files Touched This Run

- Modified `KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift` — removed dead `SiteRuntimeStatusView` (superseded by `SiteRowStatusBadge`).
- Modified `KDWarm/UI/Dashboard/Sections/Sites/site-share-control-view.swift` — added `.accessibilityLabel` on Copy and Stop icon-only buttons.
- Modified `docs/project-changelog.md` — augmented Unreleased entry with sidebar shell + accessibility note.
- Marked plan + 4 phase headers `status: complete`.

### Files Verified Unchanged (from baseline plan)

- `KDWarm/UI/Dashboard/DashboardWindow.swift`
- `KDWarm/UI/Dashboard/dashboard-sidebar-view.swift`
- `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/site-row-overflow-menu.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/site-row-runtime-badge.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/site-row-status-badge.swift`

## Acceptance Criteria

| Criterion | Status |
|---|---|
| Sidebar identity row + Pro pill + Sites count badge + server card | Pass |
| Header title + count pill + Scan/Import/New Site split + server row | Pass |
| Search 40px rounded with clear | Pass |
| Site row: tile / name+domain / runtime / status / mini toggle / share / Open / overflow | Pass |
| Hover 5% accent, no layout shift | Pass |
| DNS footer pinned with shield + Reset + Disable | Pass |
| `SiteRowView` init + `SitesContent` ownership preserved | Pass |
| No code comments / KDSpacing+KDRadius+KDFont tokens | Pass |
| Files under 200 LOC | Pass |

## Verification

- `xcodebuild -project KDWarm.xcodeproj -scheme KDWarm -destination 'platform=macOS' -configuration Debug build` — succeeded.
- `xcodebuild -project KDWarm.xcodeproj -scheme KDWarmKit-Tests -destination 'platform=macOS' test` — 548 tests, 30 skipped, 0 failures.
- Code reviewer report: `reports/code-reviewer-260619-0815-sites-dashboard-target-ui-review.md` — DONE_WITH_CONCERNS, all concerns addressed except design judgment on share-control fixed width.

## Out of Scope

- Screenshot capture of `assets/readme/dashboard-sites.png` (per Phase 4 step 7: do not overwrite asset unless deliberately regenerating).
- Modifications to `NewSiteSheet.swift`, `ServiceModels.swift`, `SiteRegistry.swift`, `SiteInspectorAndRegistryTests.swift` (belong to separate in-flight work).

## Open Questions

- Should the README screenshot at `assets/readme/dashboard-sites.png` be regenerated from the running app? Phase 4 deliberately defers this.
- Should commit happen now or be deferred until unrelated dirty files are split into their own commits?
