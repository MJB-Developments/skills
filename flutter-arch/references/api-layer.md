# Data Models & API Layer

## Table of Contents
- [Freezed Entities](#freezed-entities)
- [Helper Extensions](#helper-extensions)
- [Endpoint Factory](#endpoint-factory)
- [API Service Classes](#api-service-classes)
- [ServiceNetwork Methods](#servicenetwork-methods)

---

## Freezed Entities

All API response models use Freezed with json_serializable:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{name}.g.dart';
part '{name}.freezed.dart';

@freezed
class SomeModel with _$SomeModel {
  const factory SomeModel({
    @Default(0) int id,
    @Default('') String name,
    @JsonKey(name: 'api_field_name') @Default('') String dartFieldName,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @Default([]) List<SubModel> items,
  }) = _SomeModel;

  factory SomeModel.fromJson(Map<String, dynamic> json) =>
      _$SomeModelFromJson(json);
}
```

Conventions:

- Use `@Default(value)` for every non-nullable field so deserialization never crashes on missing data
- Use `@JsonKey(name: 'snake_case')` when the API field name differs from the Dart camelCase name
- Nullable fields (`DateTime?`, `String?`) are for truly optional data — prefer defaults over nullability
- Add a `factory SomeModel.preview(int id)` for skeleton/placeholder data used by `Skeletonizer` — do this for all API models, not just some
- Keep models **pure data** — no business logic whatsoever. All derived computations go in helper extension files (`helper_{name}.dart`)

---

## Helper Extensions

Business logic that operates on models lives in separate helper files:

```dart
// helper_{name}.dart
extension {Name}Helper on {Name} {
  String get displayLabel => ...;
  bool get isAvailable => ...;
  String shareUrl(String baseUrl) => ...;
}
```

This keeps models serialization-focused and puts domain logic where it's easily findable and testable. Simple computed getters on Freezed state classes (like `bool get isMe`) are fine — the helper pattern is for richer logic on data models.

---

## Endpoint Factory

All API routes are defined as factory constructors on the `Endpoint` class:

```dart
factory Endpoint.someResource(int id) => Endpoint('some_resources/$id');
factory Endpoint.someAction() => Endpoint('some_resources/action');
```

When adding a new API call, add a new factory to `Endpoint` first.

---

## API Service Classes

Each API domain has a singleton service class with an abstract interface:

```dart
// api_{module}_i.dart (interface)
abstract class ApiSomeModuleI {
  Future<SomeModel> fetchSomething({required int id});
}

// api_{module}.dart (implementation)
class ApiSomeModule implements ApiSomeModuleI {
  static final instance = ApiSomeModule();

  @override
  Future<SomeModel> fetchSomething({required int id}) async {
    final json = await ServiceNetwork.shared.query(
      endpoint: Endpoint.someResource(id),
    );
    return SomeModel.fromJson(json);
  }
}
```

- Always use `ServiceNetwork.shared` for HTTP calls — never create raw Dio instances
- Parse responses with `fromJson` factories
- For list responses, map the JSON array: `(json as List).map((e) => Model.fromJson(e)).toList()`
- The singleton is accessed as `ApiSomeModule.instance` throughout cubits

---

## ServiceNetwork Methods

- `query()` — GET requests
- `post()` — POST with JSON body
- `patch()` — PATCH with JSON body
- `put()` — PUT with JSON body
- `delete()` — DELETE with JSON body

All accept `endpoint` (required) and `parameters` (optional). Auth tokens and error handling are managed by interceptors — you don't handle them manually.
