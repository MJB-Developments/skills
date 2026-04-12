# Widget Composition Patterns

## Table of Contents
- [Screen Structure](#screen-structure)
- [Widget Method Ordering](#widget-method-ordering)
- [Anti-patterns](#anti-patterns-scaffold-wrappers--trivial-widget-extraction)
- [Page Naming Convention](#page-naming-convention)
- [Component Patterns](#component-patterns)
- [Widget Complexity & File Separation](#widget-complexity--file-separation)
- [Reuse Detection & the Widget Reuse Subagent](#reuse-detection--the-widget-reuse-subagent)
- [Avoid Duplicating Widget Trees](#avoid-duplicating-widget-trees)
- [Function Placement Rules](#function-placement-rules)
- [Widget Sizing & Spacing](#widget-sizing--spacing)
- [Enums for Fixed Display Variants](#enums-for-fixed-display-variants)
- [Button Usage](#button-usage)

---

## Screen Structure

Screens are thin orchestrators. They set up the scaffold, app bar, and compose sections/components. Business logic lives in cubits, not screens.

```dart
class ScreenSomething extends StatelessWidget {
  const ScreenSomething({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarSomething(),
      body: ListView(
        children: [
          StateView<SomeCubit, SomeState>(
            builder: (context, state) => SectionHeader(data: state.data),
          ),
          const SectionDetails(),
          StateView<SomeCubit, SomeState>(
            builder: (context, state) => SectionOffers(
              offers: state.offers,
            ),
          ),
        ],
      ),
    );
  }
}
```

Screens should almost always be `StatelessWidget`. If you need lifecycle hooks, use `BlocListener` or a separate stateful wrapper.

When a screen uses an app-level cubit (provided in `MultiBlocProvider`), use `BlocProvider.value` to re-expose it and trigger a background fetch — don't wrap it in a new `BlocProvider` or convert to `StatefulWidget`:

```dart
// GOOD: re-expose the app-level cubit, fetch in background
BlocProvider.value(
  value: context.read<SomeCubit>()..fetch(inBackground: true),
  child: Scaffold(...),
)

// BAD: creates a second instance of an app-level cubit
BlocProvider(
  create: (context) => SomeCubit()..fetch(),
  child: Scaffold(...),
)

// BAD: StatefulWidget just to call fetch in initState
class ScreenSomething extends StatefulWidget { ... }
```

---

## Widget Method Ordering

Within a widget class, organize methods in this order:

1. **`build` method** — always first
2. **Widget-returning methods** (`_buildHero()`, `_buildPanel()`, etc.) — UI composition
3. **Action methods** (`_onContinue()`, `_onSubmit()`, etc.) — callbacks, navigation, side effects

This makes it easy to scan a widget: the build method shows overall structure, widget helpers follow, and actions are at the bottom.

```dart
class PageSomething extends StatelessWidget {
  @override
  Widget build(BuildContext context) { ... }      // 1. build

  Widget _buildHeader() { ... }                   // 2. widget functions
  Widget _buildContent() { ... }

  void _onContinue(BuildContext context) { ... }  // 3. actions
  void _onShare() { ... }
}
```

---

## Anti-patterns: Scaffold Wrappers & Trivial Widget Extraction

**Never wrap Scaffold in a custom widget with a different name.** Don't create widgets like "Shell", "Container", or "Wrapper" that just wrap a `Scaffold` or `GradientScaffold` with some decoration. The scaffold belongs directly in the screen — wrapping it obscures what's actually happening and adds indirection with no benefit.

```dart
// BAD: custom scaffold wrapper
class ContestStatusShell extends StatelessWidget {
  final Widget child;
  Widget build(context) => GradientScaffold(body: child);  // just use GradientScaffold directly
}

// GOOD: scaffold directly in the screen
class ScreenContestStatus extends StatelessWidget {
  Widget build(context) => GradientScaffold(
    gradient: ThemeColors.badgeGradient,
    body: ...,
  );
}
```

**Never extract simple buttons into separate widget files.** A `FilledButton` with 2-3 lines of navigation logic does not need its own file. Inline it or use a private helper method (`_onContinue`) in the widget that uses it.

```dart
// BAD: separate file for a trivial button
class DoneButton extends StatelessWidget {
  Widget build(context) => FilledButton(
    onPressed: () => AppNavigator.push(screen: Screen.home),
    child: const Text('Done'),
  );
}

// GOOD: inline or private method
void _onContinue(BuildContext context) {
  final onboarded = context.read<CustomerCubit>().state.onboarded;
  AppNavigator.push(screen: onboarded ? Screen.contests : Screen.onboarding);
}
```

---

## Page Naming Convention

When a screen delegates to multiple sub-views based on state (e.g., enum-driven content switching), name those sub-views as **pages** (`Page*`), not as ambiguously named components. This makes it immediately clear they are page-level widgets rendered inside a screen.

Structure: `Screen*` (scaffold + providers) → `Page*` (enum switch) → `Page*Status*` (individual states)

```dart
// GOOD: clear hierarchy
ScreenContestStatus          // scaffold, BlocProvider, StateView
  → PageContestStatus        // switches on contest.statusView enum
    → PageContestStatusPending
    → PageContestStatusResult
    → PageContestStatusNoMatch
    → PageContestShare       // not tied to "status" since it's reused elsewhere

// BAD: unclear naming — are these widgets? sections? screens?
ContestStatusPending
ContestStatusResult
ContestStatusNoMatch
```

Pages that are reused across multiple screens should have names that don't tie them to a single context. For example, `PageContestShare` (not `PageContestStatusShare`) because it's used in both `ScreenContestStatus` and `ScreenContestInvite`.

---

## Component Patterns

**Section widgets** — horizontal scrollable lists with a title header. Use `SectionListView` for this pattern:

```dart
SectionListView(
  title: Text('Section Title'),
  listHeight: 200,
  itemCount: items.length,
  itemBuilder: (context, index) => SomeCard(item: items[index]),
)
```

**Factory constructors on widgets** — when a widget has multiple display variants, use named factory constructors rather than boolean flags. Do **not** add a `Key? key` parameter to factory constructors unless explicitly instructed — the base `const` constructor already handles `super.key`:

```dart
class SomeCard extends StatelessWidget {
  // private constructor
  const SomeCard._({super.key, required this.title, required this.subtitle, this.isPremium = false});

  factory SomeCard.basic(Item item) => SomeCard._(title: item.name, subtitle: item.description);
  factory SomeCard.premium(Item item) => SomeCard._(title: item.name, subtitle: item.premiumLabel, isPremium: true);
}
```

**Prefer Widget params over derived primitives** — when a component computes display text from raw values (like `"$index/$count"`), accept a `Widget` instead. This keeps the component reusable and moves formatting logic to the call site where it belongs.

```dart
// GOOD: accepts a Widget — caller decides how to display it
class QuestionPage extends StatelessWidget {
  final Widget title;
  const QuestionPage({required this.title});
}
// Usage: QuestionPage(title: Text('3/10'))

// BAD: accepts raw values, formats internally
class QuestionPage extends StatelessWidget {
  final int questionIndex;
  final int questionCount;
  // Now this widget is coupled to a specific display format
}
```

When accepting a `Widget` param, use `DefaultTextStyle.merge` inside the component to apply a sensible default style. This way callers can pass a plain `Text('3/10')` without worrying about styling, but can still override it if needed:

```dart
// Inside the component — apply default styling:
DefaultTextStyle.merge(
  style: const TextStyle(color: Colors.white),
  child: title,
)

// Caller stays clean:
QuestionPage(title: Text('3/10'))

// Caller can still override when needed:
QuestionPage(title: Text('3/10', style: TextStyle(color: Colors.red)))
```

**Enum-driven sections** — for screens with many conditional sections (like a home feed), define a `SectionType` enum and switch on it. Each enum value maps to a widget. Sections that have no data return `SizedBox.shrink()`.

**No private widget classes** — never define private `_SomeWidget extends StatelessWidget` inside a file. Instead, either:

1. Extract the widget into its own file in `components/` (preferred for anything reusable or substantial)
2. Use a private helper method that returns a `Widget` (for small, one-off subtrees within a build method)

```dart
// DO: private method
Widget _buildHeader(BuildContext context) {
  return Column(...);
}

// DO: separate file in components/
// components/section_header.dart
class SectionHeader extends StatelessWidget { ... }

// DON'T: private widget class
class _SectionHeader extends StatelessWidget { ... }  // NEVER do this
```

---

## Widget Complexity & File Separation

Keep widget files focused and manageable. When a widget's build method grows complex (multiple nested sections, many conditional branches, or the file exceeds ~200 lines of widget code), split it:

1. **Separate files** — when a sub-widget is reusable, testable on its own, or substantial enough to warrant its own file, extract it into `components/`. Reusability and abstraction at the widget level is always preferred.
2. **Separate functions** — when splitting into a separate file would be overkill (small, single-use subtrees), extract a private method that returns a `Widget` within the same class. These widget-returning functions belong at the widget level since they produce UI.

The goal is readability: a developer should be able to understand a widget's structure at a glance without scrolling through hundreds of lines.

---

## Reuse Detection & the Widget Reuse Subagent

Duplication is the most common waste in a growing Flutter codebase. When you build something new, there's a good chance a similar widget already exists in `shared/ui/components/` or another feature's `components/` directory. Catching this *before* writing code saves time and keeps the codebase consistent.

### When to scan for reuse

Spawn the **widget reuse scanner subagent** whenever you are about to:

- Create a new file in any `components/` directory
- Write a new `StatelessWidget` or `StatefulWidget` class
- Build a common UI pattern: card, badge, banner, tile, list item, info box, stat row, icon+label, progress indicator, or any styled container with specific padding/decoration/layout

### How to use it

Read `agents/widget-reuse-scanner.md` for the full subagent instructions. Spawn it as an **Explore subagent** in parallel with your main work, providing:

- **Widget purpose**: what you're about to build
- **Visual pattern**: card, badge, row, tile, banner, etc.
- **Key parameters**: the expected constructor params

The subagent scans `shared/ui/components/` and all feature `components/` directories, then returns a report with matches and recommendations (use directly, extend, move to shared, or no match).

### What to do with the results

- **Exact match found**: Use it directly. Don't rebuild what exists.
- **Close match found**: Extend the existing widget (add a factory constructor, add an optional parameter) rather than creating a new one. If the existing widget is feature-specific, move it to `shared/ui/components/` first.
- **No match found**: Build the new widget. If it's generic (not tied to one feature's domain), create it in `shared/ui/components/` from the start.
- **Feature-specific widget is generic enough to share**: Move it to `shared/ui/components/` and update imports.

### Proactive extraction

Even without the subagent, stay alert for duplication:

- If you create a private helper method (`_buildSomething`) that produces a generic UI pattern, consider whether it should be a standalone widget in `components/` instead
- When the same widget structure appears in 2+ places, extract it immediately — don't leave it for later
- Check `shared/ui/components/` before building icon+label rows, info cards, or styled containers from scratch. For example, `IconLabel` already supports icon, label, and optional subtitle.

---

## Avoid Duplicating Widget Trees

When a widget has conditional variants (e.g., with/without a header), do **not** duplicate the entire widget tree in a ternary. Instead, use a single tree with `if` statements for the conditional parts:

```dart
// GOOD: single tree, conditional parts use if statements
Stack(
  children: [
    if (header == null)
      Positioned(top: -70, child: LottieGift()),
    Padding(
      padding: EdgeInsets.only(top: header != null ? 16 : 80),
      child: Column(
        children: [
          if (header != null) header!,
          const DottedLine(...),
          title,
          if (subtitle != null) ...[
            const DottedLine(...),
            subtitle!,
          ],
        ],
      ),
    ),
  ],
)

// BAD: duplicated tree in a ternary
header != null
    ? Padding(
        child: Column(children: [header!, DottedLine(), title, ...]),
      )
    : Stack(
        children: [
          LottieGift(),
          Padding(
            child: Column(children: [title, DottedLine(), ...]),  // duplicated
          ),
        ],
      )
```

---

## Function Placement Rules

Where a function lives depends on what it returns:

- **Functions that return widgets** (UI builders) — belong at the **widget level** as private methods on the widget class, or as separate widget classes in `components/`.
- **Functions that return data** (strings, ints, booleans, formatted values, computed objects based on a state or API entity) — belong in a **helper class/extension on the entity** or as a **getter/function on the state class**. These should never live inside widget code.

```dart
// GOOD: data derivation lives on the entity helper
extension OrderHelper on Order {
  String get formattedTotal => '\$${total.toStringAsFixed(2)}';
  String get statusLabel => status.name.toUpperCase();
  bool get canCancel => status == OrderStatus.pending;
}

// GOOD: derived state lives as a getter on the state class
@freezed
class OrderState with _$OrderState, BaseStateMixin<...> {
  // ...
  int get activeOrderCount => maybeMap(
    success: (s) => s.orders.where((o) => o.isActive).length,
    orElse: () => 0,
  );
}

// BAD: computing display data inside a widget's build method
class ScreenOrder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Don't do this — move to helper or state getter
    final label = order.status.name.toUpperCase();
    final total = '\$${order.total.toStringAsFixed(2)}';
  }
}
```

### Function Parameter Ordering

Follow Flutter/Dart best practices for parameter ordering:

1. `BuildContext context` always comes **first** when present
2. Required positional parameters next
3. Required named parameters
4. Optional named parameters last

```dart
// GOOD
Widget _buildItem(BuildContext context, {required Item item, bool showBadge = false}) { ... }

// BAD — context should come first
Widget _buildItem({required Item item, required BuildContext context}) { ... }
```

---

## Widget Sizing & Spacing

- Use `const SizedBox(height: N)` / `SizedBox(width: N)` for variable spacing between children
- When a `Row` or `Column` has **even spacing** between all children, use the `spacing` parameter instead of inserting `SizedBox` between each child
- Standard horizontal padding is typically `EdgeInsets.symmetric(horizontal: 16)`
- Use `ThemeSizing` for responsive/computed dimensions
- Use `ThemeColors` for colors, never hardcode hex values
- Access text styles via `Theme.of(context).textTheme` or `ThemeText.main`

```dart
// GOOD: even spacing — use spacing parameter
Column(
  spacing: 14,
  children: [
    _buildHeader(),
    _buildContent(),
    _buildFooter(),
  ],
)

// BAD: even spacing with SizedBox between each child
Column(
  children: [
    _buildHeader(),
    const SizedBox(height: 14),
    _buildContent(),
    const SizedBox(height: 14),
    _buildFooter(),
  ],
)

// GOOD: variable spacing — SizedBox is appropriate
Column(
  children: [
    _buildHeader(),
    const SizedBox(height: 22),
    _buildContent(),
    const SizedBox(height: 10),
    _buildFooter(),
  ],
)
```

---

## Enums for Fixed Display Variants

When you have a fixed set of items that just hold display data (icon, label, detail), use an **enum with final fields** instead of creating a data class. Enums are the right tool for a known, closed set of display variants.

```dart
// GOOD: enum with final fields for fixed display data
enum _PendingMoment {
  answersLocked('Answers are locked', 'Your picks are in.', Icons.lock_rounded),
  scoresSettling('Scores are settling', 'The scoreboard is coming.', Icons.emoji_events_rounded);

  const _PendingMoment(this.label, this.detail, this.icon);
  final String label;
  final String detail;
  final IconData icon;
}

// BAD: data class for a fixed set of items
class ContestStatusMoment {
  final String label;
  final String detail;
  final IconData icon;
  const ContestStatusMoment({required this.label, required this.detail, required this.icon});
}
```

### Reuse Existing Shared Widgets

Before building icon + label or icon + label + detail rows from scratch, check if an existing widget handles the pattern. For example, `IconLabel` in `shared/ui/components/` supports an icon, label, and optional subtitle — use it instead of recreating the layout manually.

---

## Button Usage

Always use Flutter's built-in button widgets rather than wrapping `InkWell`, `Material`, `GestureDetector`, or similar low-level widgets to create button-like behavior. The app's theme already styles these buttons consistently via `ThemeFilledButton`, `ThemeOutlinedButton`, `ThemeTextButton`, etc., so using them gives you correct styling for free and keeps the UI consistent.

Preferred buttons (in order of visual weight):
- `FilledButton` — primary actions
- `OutlinedButton` — secondary actions
- `TextButton` — tertiary/inline actions
- `ListTile` — tappable row items in lists

```dart
// GOOD: native Flutter button, styled by theme
FilledButton(
  onPressed: () => context.read<SomeCubit>().submit(),
  child: const Text('Submit'),
)

// BAD: hand-rolled button with InkWell
InkWell(
  onTap: () => context.read<SomeCubit>().submit(),
  child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(...),
    child: const Text('Submit'),
  ),
)
```

The only exception is when you need a fully custom tap target that doesn't resemble any standard button (e.g., a tappable image or an animated interactive area). In those rare cases, `GestureDetector` is acceptable.
