---
title: "Sites Dashboard Target UI Migration"
description: "Migrate the existing Sites dashboard toward the target README screenshot style while preserving KTStack functionality and information architecture."
status: complete
priority: P2
effort: 1d
branch: "main"
tags: [frontend, swiftui, design-system]
blockedBy: [260618-2104-sites-ui-redesign]
blocks: []
created: "2026-06-18T14:36:44.291Z"
createdBy: "ck:plan"
source: skill
---

# Sites Dashboard Target UI Migration

## Overview

Migrate the current KTStack Sites dashboard to visually match `/Users/nguyenkhoi/Data/MacAPP/KDWarm/assets/readme/dashboard-sites.png`.

Scope is visual and component-architecture only. Keep existing navigation, site workflows, domain editing, PHP version selection, HTTPS toggle, tunnel sharing, open actions, logs, Finder, terminal, VS Code debug config, remove confirmation, DNS footer, and server controls.

This plan depends on the completed `260618-2104-sites-ui-redesign` work. Treat that plan as baseline implementation, then close remaining gaps against the target image.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Design Audit And Tokens](./phase-01-design-audit-and-tokens.md) | Complete |
| 2 | [Sidebar Header And Search](./phase-02-sidebar-header-and-search.md) | Complete |
| 3 | [Site Rows Controls And Menus](./phase-03-site-rows-controls-and-menus.md) | Complete |
| 4 | [Verification Screenshots And Docs](./phase-04-verification-screenshots-and-docs.md) | Complete |

## Dependencies

- Prior visual baseline: `plans/260618-2104-sites-ui-redesign/plan.md`
- Target image: `assets/readme/dashboard-sites.png`
- Design guide: `docs/design-guidelines.md`
- Main files: `KDWarm/UI/Dashboard/DashboardWindow.swift`, `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`, `KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`, `KDWarm/UI/Dashboard/Sections/Sites/sites-screen-components.swift`, `KDWarm/UI/Dashboard/Sections/Sites/site-share-control-view.swift`

## Out Of Scope

- New screens
- Feature removal
- Data model or server behavior changes
- Replacing native SwiftUI controls with custom web-like widgets
- Dark-only redesign

## Open Questions

None.
