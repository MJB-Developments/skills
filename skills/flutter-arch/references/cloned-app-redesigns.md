# Cloned / Sibling App Redesigns

Use this when a Flutter app was cloned from a sibling product and needs to be re-skinned or re-positioned while preserving the existing architecture.

## Workflow

1. **Inventory the existing feature structure first**
   - Identify the current screen, Cubit/BLoC, state, enum/model, and component boundaries.
   - Preserve those boundaries unless they are actively fighting the new product.
   - Avoid replacing working state management just because the product concept changed.

2. **Treat the reference design as design-system input, not only page mockups**
   - Extract primitive palette, semantic roles, spacing/radius/button treatment, and global typography decisions.
   - Update `lib/theme/` before applying widget-level styling.
   - Keep widgets consuming semantic colors/component themes where possible.

3. **Rename product concepts through the model layer**
   - Update enums, state fields, serialization maps, labels, option copy, app constants, and settings/help surfaces.
   - Search for stale sibling-app terms after the first pass.

4. **Keep generated code consistent**
   - Preferred: run `dart run build_runner build --delete-conflicting-outputs` after Freezed/json changes.
   - If the toolchain is unavailable but generated files are committed, carefully update `.freezed.dart` defaults and `.g.dart` enum maps to match source changes, then clearly flag that real `build_runner`, `dart format`, and `flutter analyze` still need to run in a proper Flutter environment.

5. **Verify beyond the changed feature**
   - Search for removed enum cases and old product names across `lib/`.
   - Update secondary surfaces like settings education carousels, app title, constants, and onboarding re-entry flows.
   - Run `git diff --check` and at least a lightweight syntax/balance sanity check if Dart tooling is unavailable.

## Pitfalls

- Do not scatter copied design colors inside feature widgets. Put durable brand/style decisions in primitives, semantics, and component themes.
- Do not leave generated serialization referencing deleted enum cases; hydration/restoration can break before the UI renders.
- Do not only update onboarding copy. Cloned apps often leak old branding through settings, constants, app metadata, analytics labels, and help screens.
- Do not add permission-looking onboarding pages that only show mock system prompts or permission CTA copy while the footer simply advances. If a page says it enables microphone, notifications, ATT, camera, location, etc., wire it to the real permission/service flow, handle denied/permanently-denied states, and only advance after the result is handled. If it is education-only, remove the permission CTA/mock prompt language so the UI does not misrepresent app state.
- Do not convert architecture during a redesign unless required. First make the sibling app fit the existing architecture; refactor later if there is a concrete reason.
