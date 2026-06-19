---
phase: 1
title: "Design Audit And Tokens"
status: complete
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Design Audit And Tokens

## Context Links

- `README.md`
- `AGENTS.md`
- `docs/design-guidelines.md`
- `assets/readme/dashboard-sites.png`
- `plans/260618-2104-sites-ui-redesign/plan.md`
- `KDWarm/UI/Dashboard/DashboardWindow.swift`
- `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`

## Overview

Lock the design audit, exact UI deltas, and design tokens before touching SwiftUI code.

Priority: High  
Current status: Pending

## Design Audit

### Layout Differences

- Current baseline already uses `NavigationSplitView`, Sites header, search strip, rounded list surface, and DNS footer.
- Target uses stronger app-shell composition: translucent sidebar at fixed 220-260px, content width fills remaining area, header split into title/action row plus server row, search row, table surface, pinned DNS footer.
- Migration: keep same IA, make rhythm exact: 16px content gutters, 12px header row gap, 12px search-to-table gap, rows 58-64px.

### Visual Hierarchy Differences

- Target puts active section and primary CTA in sharp focus: Sites title, site count pill, New Site split button.
- Scan and Import are secondary. New Site is primary.
- Site name is primary, domain is secondary mono text, row controls are aligned columns.
- Migration: use type weight, spacing, and native control prominence. No new content.

### Typography Differences

- Target uses native macOS/SF proportions: bold page title, 13pt body, 11-12pt metadata, mono domain.
- Existing design guide already requires SF system fonts and SF Mono.
- Migration: use `KDFont` tokens; avoid bundled fonts and avoid generic web Inter recommendation from the UI helper.

### Spacing System Differences

- Target is dense but breathable. Content gutters 16-20px, row horizontal padding 16-20px, icon-to-copy gap 20-24px, controls gap 12px.
- Migration: use `KDSpacing` values only. Add a new token only if repeated hard-coded value appears three or more times.

### Sidebar Differences

- Target sidebar has app identity, Pro pill, grouped nav labels, selected Sites item with accent-tinted rounded background and count badge, footer server card.
- Current `DashboardWindow` uses a plain `List` source list without app identity or footer status.
- Migration: keep same `SidebarItem` and `SidebarSection`; add shell chrome around the existing list rather than new destinations.

### Toolbar Differences

- Target does not use a traditional macOS toolbar for these actions; it uses an in-content header action bar.
- Current `SitesHeaderView` already follows this direction.
- Migration: refine sizing, split button, icons, and alignment.

### Table/List Row Differences

- Target rows are table-like inside a bordered surface, with dividers, stable columns, hover highlight, icon tile, primary/secondary copy, runtime menu, status, switch, Open, overflow.
- Current `SiteRowView` has most behavior, but active tunnel controls can widen rows and the overflow trigger is visually icon-only.
- Migration: stabilize widths and move verbose transient share states into compact controls where needed.

### Button Styles

- Target uses bordered secondary buttons for Scan/Import/Open, prominent blue split button for New Site, square icon buttons for view/filter/overflow.
- Migration: keep native `.bordered` and `.borderedProminent`; avoid custom painted buttons unless native style cannot match screenshot.

### Dropdown Menu Styles

- Target menus are native popovers with section label, SF Symbols, keyboard shortcuts aligned right, destructive remove separated.
- SwiftUI `Menu` should provide text labels with `systemImage`; destructive role stays on Remove Site.
- Migration: replace purely visual menu labels with accessible text labels styled icon-only if needed.

### Search Field Styles

- Target search is a rounded bordered control, 40-44px height, magnifying glass, placeholder, clear affordance.
- Current `SitesSearchStrip` matches direction.
- Migration: add no filter/sort behavior unless mapped to existing data.

### Status Indicators

- Target uses green/gray dot plus Running/Stopped text; server status pill uses green dot and text.
- Current row status derives from `canOpen`, which is server-level.
- Migration: preserve existing semantics unless model exposes per-site health later. Label should remain explicit.

### Hover States

- Target rows and controls show subtle hover affordance.
- Current row hover uses accent at 5%.
- Migration: ensure hover does not change row height or hide required actions.

### Empty States

- Target screenshot is populated. Existing app has empty and filtered-empty states.
- Migration: keep existing empty IA, restyle to same calm native density; use existing `EmptyStateView`.

### Color System

- Target light mode: white content, translucent sidebar, light gray separators, blue accent, green running, gray stopped, red destructive.
- Migration: use semantic system colors and `Color.KDStatus`; no raw hex in components except central tokens if needed.

### Shadows And Elevation

- Target is mostly flat. Elevation appears through separators, strokes, materials, and menu popover shadow.
- Migration: avoid heavy card shadows. Use 0.5px separators, material sidebar, bordered surfaces, native popover menu elevation.

## UI Changes

### Sidebar

- Add app identity row: hexagon app symbol, `KTStack`, `Pro` capsule.
- Keep groups: Manage, Inspect, App.
- Keep items: Sites, Services, Runtimes, Database, Logs, Mail, Dumps, Settings, About.
- Add Sites count badge from `registry.sites.count`.
- Add footer server card: dot, `Server Running` or `Server Stopped`, version.
- Use source-list selection with rounded accent tint, not a new screen.

### Header

- Page title `Sites` plus count capsule.
- Right actions: Scan, Import, New Site split button.
- Second row: server status pill plus Start/Stop Server button.
- Keep `Cmd+N` for New Site.

### Search

- Visible when sites exist.
- Rounded bordered 40px control with magnifying glass and clear button.
- Placeholder: `Search sites by name or domain...`.
- Avoid adding filters unless mapped to existing data.

### Site Row

- 58-64px min height.
- Leading type tile 36px.
- Primary site name semibold.
- Editable domain remains mono secondary field.
- Stable trailing columns for runtime, status, HTTPS, share, Open, overflow.
- Long domains and tunnel URLs truncate middle and keep help tooltip.

### Runtime Badge

- PHP sites: bordered `PHP 8.4` menu with chevron.
- Non-PHP sites: muted type label.
- Width 108px. Do not change `onSetVersion`.

### Status Badge

- Dot plus Running/Stopped text.
- Green for running, gray for stopped.
- Width 96px.
- Accessibility label includes status text.

### Toggle

- Native switch, mini control size.
- Label hidden visually, accessible label present.
- Reflects existing `site.secure`.

### Open Button

- Native bordered button, 78px width.
- Disabled when server cannot open.
- Keep existing open URL logic.

### Overflow Menu

- Native `Menu("More actions", systemImage: "ellipsis")`.
- Items: Open in Browser, Reveal in Finder, Open Terminal Here, Logs, Configure VS Code Debug for PHP, Remove Site.
- Destructive Remove Site separated.
- Preserve current callbacks and confirmation.

### Footer

- Keep DNS footer pinned.
- Match target: shield/check symbol, DNS enabled text, secondary explanation, Reset and Disable DNS actions.
- Do not move DNS automation behavior.

## Design Tokens

### Colors

- `window`: `Color(nsColor: .windowBackgroundColor)`
- `content`: `Color(nsColor: .controlBackgroundColor)` or `.textBackgroundColor` for inset fields
- `sidebar`: `.regularMaterial` or system sidebar material through `NavigationSplitView`
- `separator`: `Color(nsColor: .separatorColor)`
- `label`: `.primary`
- `secondaryLabel`: `.secondary`
- `accent`: `Color.accentColor`
- `running`: `Color.KDStatus.running`
- `stopped`: `Color.KDStatus.stopped`
- `warning`: `Color.KDStatus.warning`
- `error`: `Color.KDStatus.error`
- `info`: `Color.KDStatus.info`

### Radius

- Control: `KDRadius.control` at 6px.
- Card/list surface: `KDRadius.card` at 10px.
- Pills: `Capsule`.
- Icon tile: 8px unless token already maps to 6px.

### Spacing

- 4px: icon-label gap, pill vertical inset.
- 8px: control internal gap.
- 12px: row group gap, search/table gap.
- 16px: content gutter.
- 20-24px: major group separation.

### Typography

- Page title: `.largeTitle.weight(.bold)` only for screen title.
- Section label: `KDFont.headline`.
- Row title: `KDFont.body.weight(.semibold)`.
- Row domain: `KDFont.mono`.
- Metadata/status: `KDFont.footnote`.
- Avoid `.caption2` for functional text.

### Shadows

- No custom shadow on main surfaces.
- Use native menu popover elevation.
- Use 0.5px stroke for bordered controls and list surface.

## SwiftUI Implementation

- `SidebarView`: extracted from `DashboardWindow`, owns app identity, grouped nav list, count badges, footer server card.
- `ToolbarView`: existing `SitesHeaderView` role; rename only if codebase allows without churn.
- `SiteListView`: wraps search strip, empty states, scroll/list surface, and rows.
- `SiteRowView`: keeps current public initializer and callbacks; delegates subparts to focused row components.
- `StatusBadge`: maps existing running/stopped state to dot plus text.
- `RuntimeBadge`: wraps PHP menu and non-PHP type label.
- `OverflowMenu`: extracts menu actions with accessible text labels.

## Requirements

- Functional: no feature removal, no new screens, no IA changes.
- Non-functional: native macOS SwiftUI, accessible labels, semantic colors, no code comments, files stay below 200 lines where feasible.

## Architecture

Visual shell is split from business behavior. `SitesContent` continues to own state, sheets, alerts, search text, removal flow, registry callbacks, server callbacks, and tunnel callbacks. New/extracted views receive values and closures only.

## Related Code Files

- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/DashboardWindow.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`
- Modify: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-share-control-view.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/dashboard-sidebar-view.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-overflow-menu.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-runtime-badge.swift`
- Create if needed: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/KDWarm/UI/Dashboard/Sections/Sites/site-row-status-badge.swift`

## Implementation Steps

1. Screenshot-compare current app against `assets/readme/dashboard-sites.png`.
2. Confirm every existing action in `SiteRowView` has a destination in target UI.
3. Lock design tokens to existing `KDSpacing`, `KDRadius`, `KDFont`, and `Color.KDStatus`.
4. Define component boundaries before editing SwiftUI.
5. Reject generic web dark-mode recommendations; target is native macOS light dashboard.

## Todo List

- [ ] Audit current shell/header/search/row/footer against target image.
- [ ] Confirm UI token decisions use existing design guide.
- [ ] Confirm no behavior or IA change needed.
- [ ] List exact component extraction targets.

## Success Criteria

- [ ] Audit covers layout, hierarchy, typography, spacing, sidebar, toolbar, rows, buttons, menus, search, status, hover, empty, color, shadow.
- [ ] Token list is complete enough for SwiftUI implementation.
- [ ] Implementation phases can proceed without design ambiguity.
- [ ] No unresolved design questions remain.

## Risk Assessment

- Risk: Prior `sites-ui-redesign` changes may already satisfy most target details. Mitigation: use this phase as gap audit, not duplicate redesign.
- Risk: Over-customizing native controls to chase pixels. Mitigation: prefer SwiftUI system controls and target proportions.
- Risk: Sidebar app identity requires extra data flow for site count and server status. Mitigation: pass existing environment objects into extracted sidebar view.

## Security Considerations

- No auth/data/security changes.
- Destructive remove behavior and confirmation must remain intact.

## Next Steps

- Phase 2 implements sidebar, header, and search polish.

## Open Questions

None.
