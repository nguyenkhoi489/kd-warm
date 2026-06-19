---
phase: 2
title: "Sidebar Header And Search"
status: complete
priority: P1
effort: "3h"
dependencies: [1]
---

# Phase 2: Sidebar Header And Search

## Context Links

- `assets/readme/dashboard-sites.png`
- `docs/design-guidelines.md`
- `KDWarm/UI/Dashboard/DashboardWindow.swift`
- `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`

## Overview

Bring the app shell, Sites header, and search row into exact target screenshot alignment while preserving navigation and workflow.

Priority: High  
Current status: Pending

## Key Insights

- `DashboardWindow` owns navigation IA. Do not change `SidebarItem`, `SidebarSection`, or detail routing.
- `SitesContent` owns server/site state and sheets. Keep that ownership.
- `SitesHeaderView` already contains most target actions; this phase refines size, spacing, and component structure.
- `SitesSearchStrip` is already close to target. Avoid inventing filters.

## Requirements

- Functional: keep all sidebar destinations and selected-state routing.
- Functional: keep Scan, Import, Add Existing Folder, New Site, Start/Stop Server.
- Functional: keep search by site name and domain.
- Non-functional: source-list sidebar must feel native macOS, semantic colors, accessible labels.

## Architecture

Extract dashboard shell chrome without changing routing:

```text
DashboardWindow
  ├─ SidebarView(selection, siteCount, serverState)
  └─ detail(for:)

SitesSectionView
  └─ SitesContent
      ├─ ToolbarView or SitesHeaderView
      ├─ SitesSearchStrip
      ├─ SiteListView
      └─ DNSStatusBar
```

Recommended minimal path:

- Add `DashboardSidebarView` only if `DashboardWindow.swift` grows past 200 lines.
- Keep `SitesHeaderView` name unless renaming reduces confusion.
- Keep `SitesSearchStrip` in `sites-screen-components.swift` unless file exceeds 200 lines after edits.

## Related Code Files

- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/DashboardWindow.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/dashboard-sidebar-view.swift`

## Implementation Steps

1. Add sidebar app identity to the existing source list shell:
   - icon tile using SF Symbol or app asset if available
   - `KTStack` title
   - `Pro` capsule
2. Keep grouped nav sections:
   - Manage: Sites, Services, Runtimes, Database
   - Inspect: Logs, Mail, Dumps
   - App: Settings, About
3. Add count badge only for Sites using live `registry.sites.count`.
4. Add sidebar footer server status card:
   - dot plus `Server Running` or `Server Stopped`
   - version from app bundle when available, fallback current visible version string
5. Preserve `selection` binding and detail routing exactly.
6. Refine `SitesHeaderView`:
   - top row title, count pill, Scan, Import, New Site split action
   - second row server status pill and Start/Stop button
   - consistent control size and no layout jump while busy
7. Refine `SitesSearchStrip`:
   - 40px height
   - rounded border
   - clear button only when text exists
   - no additional filter behavior
8. Keep empty state and filtered-empty state paths unchanged.

## Todo List

- [ ] Sidebar identity row matches target first-viewport signal.
- [ ] Sidebar groups and selection remain same IA.
- [ ] Sites count badge is live.
- [ ] Sidebar footer server card is live.
- [ ] Header action hierarchy matches target.
- [ ] Search row matches target proportions.
- [ ] Existing sheets and callbacks still compile.

## Success Criteria

- [ ] Dashboard opens to Sites with same default selection.
- [ ] All sidebar destinations still route correctly.
- [ ] Sites header visually matches target screenshot hierarchy.
- [ ] Search still filters by name/domain and can clear.
- [ ] No new screens or feature removal.

## Risk Assessment

- Risk: Custom sidebar can lose native List keyboard behavior. Mitigation: keep selection binding and use native list/sidebar patterns where possible.
- Risk: Sidebar needs data from `LocalServerController` and registry. Mitigation: pass environment objects or computed values, not new stores.
- Risk: Header split button custom styling can become fragile. Mitigation: prefer native `Button` plus `Menu` in a compact HStack.

## Security Considerations

- No secret or credential surface.
- No destructive action changes in this phase.

## Next Steps

- Phase 3 refines row controls, badges, overflow menu, and DNS footer.

## Open Questions

None.
