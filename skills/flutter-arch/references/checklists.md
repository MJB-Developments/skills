# Checklists for Common Tasks

## Adding a new feature

1. Create `lib/{feature}/bloc/{name}/{name}_cubit.dart` and `{name}_state.dart`
2. Create `lib/{feature}/ui/screens/screen_{name}.dart`
3. Create `lib/{feature}/ui/components/` for sub-widgets
4. Add the cubit to `bloc_provider.dart` if it's global
5. Add the route to `AppNavigator`
6. Run `build_runner`

## Adding a new API endpoint

1. Add a factory to `Endpoint` class
2. Add the method to the relevant API service interface and implementation
3. Create/update Freezed models in `api/{module}/entities/`
4. Call from the cubit's fetch method
5. Run `build_runner`

## Adding a new data model

1. Create `api/{module}/entities/{name}.dart` with Freezed class
2. Use `@Default` for all non-nullable fields, `@JsonKey` for API name mapping
3. Add a `preview` factory if the model will be displayed in skeleton loaders
4. Create `api/{module}/helper/helper_{name}.dart` for business logic extensions
5. Run `build_runner`

## Adding a reusable widget

1. **Run the widget reuse subagent first** — scan `shared/ui/components/` and feature `components/` directories for existing widgets that match your pattern (see `widget-patterns.md` for details)
2. If shared across features: `lib/shared/ui/components/{name}.dart`
3. If feature-specific: `lib/{feature}/ui/components/{name}.dart`
4. Use `const` constructors, accept data via constructor parameters
5. Use factory constructors for distinct variants
6. Reference `ThemeColors` and `Theme.of(context).textTheme` for styling
