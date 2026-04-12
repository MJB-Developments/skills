---
name: flutter-arch
description: >
  Use when writing, reviewing, or refactoring any Flutter or Dart code — new features, bug fixes,
  widgets, cubits, state classes, API models, screens, or data layer changes. Also use when the user
  asks where code should go, how to structure a feature, or discusses Flutter architecture, BLoC,
  state management, or widget composition.
---

# Flutter Architecture Skill

This skill defines how to write Flutter code. Every piece of Flutter code — whether it's a new feature, a single widget, a cubit, or a model — should follow these patterns. The architecture is designed around clarity, consistency, and composability.

**Reference files** — this file covers structure and conventions. For detailed patterns with code examples, read the relevant reference:

| When you're...                        | Read                                |
|---------------------------------------|-------------------------------------|
| Writing cubits or state classes       | `references/state-management.md`    |
| Building widgets or screens           | `references/widget-patterns.md`     |
| Adding API endpoints or data models   | `references/api-layer.md`           |
| Following task checklists             | `references/checklists.md`          |
| Updating this skill itself            | `references/contributing.md`        |

---

## Project Structure

Feature-based organization. Each feature is a self-contained module:

```
lib/
├── {feature}/
│   ├── bloc/                    # Cubits and their states
│   │   ├── {name}/
│   │   │   ├── {name}_cubit.dart
│   │   │   └── {name}_state.dart
│   ├── ui/
│   │   ├── screens/             # Full-page widgets (screen_*.dart)
│   │   └── components/          # Reusable pieces within the feature
├── shared/
│   ├── bloc/                    # Cubits used across features
│   ├── entities/                # Base classes (BaseStateMixin, RetryableCubit)
│   ├── ui/
│   │   ├── components/          # Shared widgets (StateView, SectionListView, etc.)
│   │   └── screens/             # Shared screens
│   └── utils/
├── api/
│   ├── {module}/
│   │   ├── api/                 # API service class + interface
│   │   └── entities/            # Freezed data models
│   ├── network/
│   │   ├── entities/            # Endpoint class
│   │   └── service/             # ServiceNetwork, interceptors
├── theme/                       # ThemeApp, ThemeColors, component themes
└── app/
    ├── bloc_provider.dart       # Global MultiBlocProvider
    └── app_router.dart
```

### Naming Conventions

- **Files**: `snake_case.dart` — screens are `screen_{name}.dart`, sections are `section_{name}.dart`, banners are `banner_{name}.dart`
- **Classes**: `PascalCase` — screens are `Screen{Name}`, cubits are `{Name}Cubit`, states are `{Name}State`
- **Barrel exports**: Each feature can have a `{feature}.dart` barrel file re-exporting public APIs
- **No private widget classes**: Never create private `_WidgetName` classes. Extract to `components/` or use private helper methods instead.

---

## Core Patterns

- **State management**: Cubit + Freezed with four-variant union types (`initial`, `loading`, `error`, `success`) and `BaseStateMixin`. No ChangeNotifier, no setState for data fetching, no raw Streams. See `references/state-management.md`.
- **Widgets**: `StateView` for loading/error/success. Screens are thin `StatelessWidget` orchestrators. See `references/widget-patterns.md`.
- **API layer**: Freezed models with `@Default` values, `Endpoint` factory constructors, singleton service classes. See `references/api-layer.md`.

---

## Dependency Injection

No external DI container (no GetIt, no Injectable). All cubits are provided via `MultiBlocProvider` in `bloc_provider.dart`. When adding a new global cubit:

1. Create the cubit and state files
2. Add a `BlocProvider(create: (context) => NewCubit())` to `OffBlocProvider`
3. If it needs to fetch on startup, chain `..fetch()` in the create callback

For feature-local cubits, provide them at the feature's widget tree level using a local `BlocProvider`.

---

## Theming

Per-component theme classes feed into `ThemeApp.build()`:

- `ThemeColors` — semantic color constants (e.g., `ThemeColors.yellow400`, `ThemeColors.gray600`)
- `ThemeText` — text theme with custom font families
- `ThemeElevatedButton`, `ThemeFilledButton`, `ThemeOutlinedButton`, `ThemeTextButton` — button variant themes
- `ThemeAppBar`, `ThemeBottomSheet`, `ThemeTextField`, etc. — component-specific themes

Always use these theme references. Never hardcode colors or text styles.

---

## Code Generation

After modifying Freezed models or states, run build_runner:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`.freezed.dart`, `.g.dart`) are committed to source control. Include the `part` directives and `fromJson` factory when creating new Freezed classes.
