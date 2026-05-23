# Onboarding / Rebrand PR Review Notes

Use this as an extra checklist when reviewing Flutter PRs that redesign onboarding or reposition a cloned/sibling app.

## Review workflow additions

1. **Map enum/page changes to every consumer**
   - If onboarding enum cases are renamed/replaced, inspect all screens that reuse those enum values (for example settings “How it works” carousels).
   - Verify reused renderers still show meaningful page content, not fallback labels/placeholders.

2. **Verify permission pages perform real actions**
   - Pages that say “Enable microphone”, “Allow notifications”, “Enable reminders”, etc. must call the actual permission/service flow (`permission_handler`, notification/reminder cubit/service, platform prompt wrapper, etc.).
   - Flag mock permission UI or unused button labels if the footer only advances to the next page.
   - Distinguish explanatory pre-permission screens from actual request screens; copy should not promise an action if none occurs.

3. **Verify tool availability independently of the PR body**
   - If the PR description says `flutter analyze`, `dart format`, or local builds were blocked because Flutter/Dart were unavailable, check the current Hermes environment anyway before accepting that limitation.
   - Mike’s Flutter repos may have a persistent SDK available at `/opt/data/sdks/flutter`; run formatting/analyzer when available and report current results, even if the PR author could not run them earlier.
   - Run `flutter pub get` before Dart format/analyze when dependencies are missing or analysis options cannot resolve packages; otherwise formatter/analyzer output can be polluted by package-resolution warnings.
   - For review-only runs, use non-mutating format checks such as `dart format --output=none --set-exit-if-changed <changed files>` so the checkout stays clean.
   - If `flutter pub get` updates `pubspec.lock` in the review checkout, restore that local artifact before posting the review unless the lockfile change itself is part of the PR feedback.

4. **Search for stale product concepts beyond changed files**
   - For cloned/rebranded apps, search `lib/` for old product names, emails, URLs, notification copy, paywall copy, settings/help/legal text, analytics labels, and old domain concepts.
   - Concrete examples: old app name, old support email, old App Store slug, old privacy URL, and obsolete feature copy such as exercise/training language after moving to tracking/logging.
   - Always inspect the screen onboarding routes to after completion (for example auth/sign-in/identify) because stale positioning there is immediately user-visible after the redesigned flow.
   - Treat shared constants for privacy URLs, App Store URLs, review URLs, support/contact email, and share text as first-class rebrand surfaces, even when those files are only lightly touched by the PR.

5. **Keep review-only verification non-mutating**
   - After running formatter check commands, verify the checkout is still clean before posting the review. If a tool unexpectedly writes despite check-only intent, restore those local review artifacts before continuing so the PR checkout remains unchanged.

6. **Check generated/hydrated state compatibility**
   - If enum cases changed and state is hydrated, confirm generated enum maps are updated and stale stored enum values are handled intentionally (fallback/migration/reset).

6. **Enforce file/component boundaries during redesigns**
   - Large single-file page dumps are common in onboarding redesign PRs. Flag files that combine page switching, page bodies, shared components, painters, and reusable widgets in one place.
   - For enum-driven onboarding flows, keep the router/page-switching widget thin: it should switch on the enum and delegate to focused page widgets only. Do not put page body layouts, painters, permission UI, or shared primitives inside the router file.
   - Extract each durable page body into its own feature `components/` file, and extract shared visual primitives/charts into separate reusable component files.
   - Recommend extracting durable widgets to feature/shared `components/` files so the screen/page class remains a thin orchestrator.

7. **Translate reference HTML/design flows literally before improvising**
   - When Mike provides HTML/Claude design flows, treat them as source-of-truth for copy, hierarchy, spacing, visual treatment, and footer behavior. Port those designs into Flutter using existing app primitives instead of inventing a nearby-looking onboarding UI.
   - Preserve the exact product copy from the reference unless there is a concrete platform/product reason to change it; if copy must change, call it out explicitly in the PR.
   - Map design containers to existing project widgets first. In this codebase, prefer `GradientScaffold` for gradient-backed screens instead of wrapping a `Scaffold` in `DecoratedBox`/`Container`, and use `FooterContainer` for bottom button/footer regions because it owns safe-area/footer treatment.
   - If a design section is intentionally deferred (for example an app bar or progress treatment), keep the Flutter placeholder minimal (`AppBar()` when requested) rather than shipping a custom substitute.

## Review output guidance

For concise review summaries, group these as concrete findings with file/line references. Avoid noisy visual nits unless they create correctness issues or violate the architecture conventions above.