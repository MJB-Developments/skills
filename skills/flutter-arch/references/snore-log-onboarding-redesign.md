# Snore Log Onboarding Redesign Case Study

Session-specific reference for future Flutter onboarding/rebrand work. This captures the reusable pattern, not the one-off PR details.

## Context

A cloned sibling app kept the old onboarding structure and product concepts. The redesign had to preserve the existing Flutter architecture while replacing Airway Trainer concepts with Snore Log tracking concepts and a new Claude design file.

## Durable implementation pattern

1. **Start with theme primitives and semantics**
   - Map the new design palette into primitive colors first.
   - Remap semantic theme fields while keeping semantic names stable.
   - Prefer native Flutter theme usage so widgets need little direct styling.

2. **Preserve existing feature architecture**
   - Keep `ScreenOnboarding`, `OnboardingCubit`, `OnboardingState`, and the `OnboardingPage` enum shape unless there is a strong reason to replace them.
   - Update enum cases and metadata to represent the new product flow.

3. **Use a thin enum router**
   - The onboarding route/page component should switch on `OnboardingPage` and return focused page widgets.
   - Do not let the router contain full page layouts, custom painters, permission copy, charts, or reusable UI primitives.

4. **Split by durable page responsibility**
   - Put each page body in `lib/onboarding/ui/components/page_<product>_<page>.dart`.
   - Put shared cards/buttons/panels/text helpers in a separate component library file.
   - Put charts/visualizations in their own reusable files when they are more than small inline UI.

5. **Wire permission/reminder CTAs to real flows**
   - Pages that say “enable microphone”, “allow notifications”, or “set reminder” must call the actual permission/service path before advancing.
   - If a page is only educational/pre-permission, the copy must not imply that a platform prompt or scheduling action happens there.

6. **Audit stale cloned-app language outside onboarding**
   - Search notifications, reminders, settings/support email subjects, paywall, legal/help, app store URLs, privacy URLs, analytics labels, and generated enum mappings.
   - Rebrand product concepts, not just names. Example: exercise/training language should become recording/tracking/review language for a snore tracker.

## Verification

- Run `dart format` on modified Dart files.
- Run `dart analyze` from the repo with Flutter/Dart on PATH.
- Confirm generated files/hydrated enum mappings are consistent after enum changes.
- Keep the PR branch workflow; do not push directly to `main`.
