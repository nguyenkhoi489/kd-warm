---
phase: 3
title: "Site Rows Controls And Menus"
status: complete
priority: P1
effort: "4h"
dependencies: [1, 2]
---

# Phase 3: Site Rows Controls And Menus

## Context Links

- `assets/readme/dashboard-sites.png`
- `docs/design-guidelines.md`
- `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/site-share-control-view.swift`

## Overview

Refine the table-like site rows, runtime badge, status badge, HTTPS toggle, Open button, share control, overflow menu, hover state, and DNS footer to match the target UI.

Priority: High  
Current status: Pending

## Key Insights

- `SiteRowView` already preserves core functionality and is under 200 lines.
- `sites-screen-components.swift` is close to 200 lines; avoid dumping more types there.
- Active tunnel UI is the highest layout risk because public URLs can be long.
- Overflow actions must remain discoverable and accessible. Do not make them hover-only.

## Requirements

- Functional: keep domain editing through `onEditDomain`.
- Functional: keep PHP version selection through `onSetVersion`.
- Functional: keep HTTPS through `onSetSecure`.
- Functional: keep tunnel sharing through `SiteShareControlView`.
- Functional: keep Open, Finder, Terminal, Logs, VS Code debug, Remove Site.
- Functional: keep remove confirmation owned by parent `SitesContent`.
- Non-functional: stable row height, no control overlap, accessible labels for icon controls.

## Architecture

Keep `SiteRowView` as the row coordinator. Extract only stable subcomponents:

```text
SiteRowView
  ├─ SiteTypeTile
  ├─ SiteIdentityEditor
  ├─ RuntimeBadge
  ├─ StatusBadge
  ├─ secure Toggle
  ├─ SiteShareControlView
  ├─ Open button
  └─ OverflowMenu
```

Suggested extraction:

- `SiteIdentityEditor`: only if domain edit/error block grows.
- `RuntimeBadge`: extract because it is reusable and visually tokenized.
- `StatusBadge`: extract from `SiteRuntimeStatusView` or rename carefully.
- `OverflowMenu`: extract to keep `SiteRowView` compact and testable by inspection.

## Related Code Files

- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-share-control-view.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-overflow-menu.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-runtime-badge.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-status-badge.swift`

## Implementation Steps

1. Preserve `SiteRowView` initializer exactly unless compile forces a local-only change.
2. Stabilize row layout:
   - min height 58-64px
   - 16px horizontal padding
   - no dynamic control width expansion beyond set bounds
3. Verify leading type tile:
   - 36px square
   - semantic tint by site type
   - accessible label with type name
4. Refine identity block:
   - site name `KDFont.body.weight(.semibold)`
   - domain editable `TextField` with `KDFont.mono`
   - domain error inline, red, no row overlap
5. Refine runtime badge:
   - PHP menu pill 108px
   - bordered text background
   - chevron image
   - native menu contents from `availableVersions`
6. Refine status badge:
   - dot plus Running/Stopped text
   - 96px stable width
   - no color-only status
7. Refine HTTPS toggle:
   - mini switch
   - hidden visual label
   - accessibility label includes domain
8. Refine share control:
   - idle is icon button
   - starting is small spinner
   - active URL truncates middle and stays within max width
   - error text truncates with retry affordance
9. Refine Open button:
   - bordered, 78px width
   - disabled state visible
10. Extract overflow menu:
   - accessible `Menu("More actions", systemImage: "ellipsis")`
   - use `Button("Open in Browser", systemImage: ...)`
   - keep destructive Remove Site role and separator
11. Keep hover state subtle:
   - accent opacity around 0.05
   - no layout shift
12. Verify DNS footer matches target:
   - shield/check icon
   - primary and secondary text
   - Reset and Disable DNS actions
   - pinned below list

## Todo List

- [ ] Row layout stable at narrow and wide widths.
- [ ] Runtime badge matches target.
- [ ] Status badge uses dot plus text.
- [ ] HTTPS toggle accessible.
- [ ] Open button style and disabled state match target.
- [ ] Overflow menu native and accessible.
- [ ] Share control cannot blow out row width.
- [ ] DNS footer remains pinned and functional.

## Success Criteria

- [ ] Every existing row action remains present.
- [ ] Long domains and active tunnel URLs truncate without overlap.
- [ ] Rows visually match target screenshot density.
- [ ] VoiceOver can discover icon-only visual controls through text labels.
- [ ] No row behavior changes outside visual/component extraction.

## Risk Assessment

- Risk: Extracting subviews could accidentally capture stale state. Mitigation: pass values and closures explicitly.
- Risk: Active share state creates too many controls in one row. Mitigation: max-width and truncation, not hidden functionality.
- Risk: Menu extraction may break AppKit actions. Mitigation: keep `revealInFinder`, `openTerminal`, and `configureVSCode` behavior in row or pass closures directly.

## Security Considerations

- Remove Site stays destructive and confirmed by parent alert.
- No tunnel URL exposure changes beyond existing visible active state.
- No filesystem or process behavior changes.

## Next Steps

- Phase 4 builds, tests, screenshots, review, and docs.

## Open Questions

None.
