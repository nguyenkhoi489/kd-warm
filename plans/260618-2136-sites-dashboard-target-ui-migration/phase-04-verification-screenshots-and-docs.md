---
phase: 4
title: "Verification Screenshots And Docs"
status: complete
priority: P1
effort: "3h"
dependencies: [2, 3]
---

# Phase 4: Verification Screenshots And Docs

## Context Links

- `README.md`
- `assets/readme/dashboard-sites.png`
- `docs/design-guidelines.md`
- `docs/project-changelog.md`
- `project.yml`
- `KDWarm/UI/Dashboard/DashboardWindow.swift`
- `KDWarm/UI/Dashboard/Sections/SitesSectionView.swift`
- `KDWarm/UI/Dashboard/Sections/Sites/SiteRowView.swift`

## Overview

Verify the migration with compile/build, visual screenshot comparison, behavior checklist, accessibility pass, code review, and docs update.

Priority: High  
Current status: Pending

## Key Insights

- This is a visual migration, but it touches central app navigation and site management.
- The README image is the target and likely the public screenshot; update it only after actual UI matches.
- The project currently has a dirty worktree. Preserve unrelated user changes.
- Existing changelog already mentions Sites dashboard redesign; update only if additional implementation lands.

## Requirements

- Functional: all Sites dashboard workflows still work.
- Functional: all sidebar destinations still route.
- Non-functional: Swift build succeeds.
- Non-functional: screenshot comparison against target passes by design judgment.
- Non-functional: no code comments added.

## Architecture

Verification happens after implementation:

```text
Implementation
  ├─ Build/typecheck
  ├─ Focused behavior checklist
  ├─ Screenshot capture
  ├─ Visual comparison to target
  ├─ SwiftUI code review
  └─ Docs/changelog decision
```

## Related Code Files

- Modify only if implementation changes warrant it: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/docs/project-changelog.md`
- Modify only after screenshot is regenerated intentionally: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/assets/readme/dashboard-sites.png`
- Read for verification: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/project.yml`
- Read for verification: `/Users/nguyenkhoi/Data/MacAPP/KDWarm/README.md`

## Implementation Steps

1. Run build/typecheck:
   - `xcodebuild -project KDWarm.xcodeproj -scheme KDWarm -destination 'platform=macOS' -configuration Debug build`
2. Run relevant tests if row/server behavior changed:
   - `xcodebuild -project KDWarm.xcodeproj -scheme KDWarmKit-Tests -destination 'platform=macOS' test`
3. Manual behavior checklist:
   - open Sites
   - switch sidebar sections and return
   - search by name
   - search by domain
   - clear search
   - open New Site sheet
   - open Add Existing Folder menu item
   - open Scan sheet
   - open Import sheet
   - toggle server
   - edit domain and submit
   - change PHP version
   - toggle HTTPS
   - start/stop share
   - open site
   - open row menu actions
   - trigger Remove Site confirmation without confirming deletion
4. Screenshot verification:
   - capture dashboard at target-like size around 1468x1071
   - compare sidebar, header, search, row rhythm, controls, overflow menu, footer
5. Accessibility review:
   - icon buttons have text labels or accessibility labels
   - status includes text and not only color
   - focus rings visible
   - no hover-only required actions
6. Code review:
   - no new comments
   - no unrelated refactors
   - no behavior contracts changed
   - files over 200 lines either justified or split
7. Docs decision:
   - update `docs/project-changelog.md` if implementation is committed as a user-facing UI change
   - update README screenshot only after target UI is actually captured from app

## Todo List

- [ ] Debug build passes.
- [ ] Relevant tests pass or exact blocker documented.
- [ ] Manual behavior checklist completed.
- [ ] Screenshot captured and compared.
- [ ] Accessibility review completed.
- [ ] Code review completed.
- [ ] Docs/changelog decision recorded.

## Success Criteria

- [ ] Final UI visually matches `assets/readme/dashboard-sites.png`.
- [ ] Existing KTStack functionality preserved.
- [ ] Build passes.
- [ ] No new screens, no feature removal, no IA change.
- [ ] Docs accurately reflect any landed change.

## Risk Assessment

- Risk: Full build may require generated Xcode project or signing context. Mitigation: report exact blocker and run narrower compile checks if available.
- Risk: Screenshot capture may require launching GUI app. Mitigation: use approved `open`/Xcode workflow or document if unavailable.
- Risk: README asset is already dirty. Mitigation: do not overwrite it unless deliberately regenerating final screenshot.

## Security Considerations

- Do not commit confidential files.
- Do not confirm destructive site removal during verification.
- Review any changed file-system actions around Finder/Terminal/remove before finalizing.

## Next Steps

- After this phase, user can implement with `/ck:cook /Users/nguyenkhoi/Data/MacAPP/KDWarm/plans/260618-2136-sites-dashboard-target-ui-migration/plan.md`.

## Open Questions

None.
