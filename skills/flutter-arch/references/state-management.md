# State Management: Cubit + Freezed

## Table of Contents
- [The State Pattern](#the-state-pattern)
- [The Cubit Pattern](#the-cubit-pattern)
- [Cubit Ordering & Conventions](#cubit-ordering--conventions)
- [Consuming State in Widgets](#consuming-state-in-widgets)

---

## The State Pattern

All states follow a four-variant union type with `BaseStateMixin`:

```dart
// {name}_state.dart
part of '{name}_cubit.dart';

@freezed
class {Name}State
    with _${Name}State, BaseStateMixin<_Initial, _Loading, _Success, _Error> {
  const {Name}State._();

  const factory {Name}State.initial() = _Initial;
  const factory {Name}State.loading() = _Loading;
  const factory {Name}State.error(String error) = _Error;
  const factory {Name}State.success({
    // success fields here
  }) = _Success;

  @override
  String get errorMessage => mapOrNull(error: (s) => s.error) ?? '';

  // Convenience getters that provide safe defaults for non-success states:
  // This lets widgets read data without checking state type first.
  SomeModel get someData => maybeMap(
        success: (s) => s.someData,
        orElse: () => SomeModel.empty(),
      );
}
```

The `BaseStateMixin<Initial, Loading, Success, Error>` provides: `isInitial`, `isLoading`, `isSuccess`, `isError`, `isLoadingOrInitial`, and `errorMessage`. The state file is always a `part of` the cubit file.

Convenience getters on the state (like `someData` above) are the right place for safe accessors that return defaults for non-success states. This keeps widgets clean — they can just read `state.someData` without type checking. Put simple derived booleans here too (e.g., `bool get isActive => ...`).

---

## The Cubit Pattern

```dart
// {name}_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '{name}_state.dart';
part '{name}_cubit.freezed.dart';

class {Name}Cubit extends Cubit<{Name}State>
    with RetryableCubit<{Name}State> {
  {Name}Cubit() : super(const _Initial());

  @override
  Future<void> retry() async => await fetch();

  Future<void> fetch() async {
    try {
      emit(const _Loading());
      final data = await SomeAPI.instance.getData();
      emit(_Success(data: data));
    } catch (e, s) {
      log(e.toString(), name: '{Name}Cubit.fetch', stackTrace: s);
      emit(_Error(e.toString()));
    }
  }
}
```

Key points:

- Mix in `RetryableCubit<S>` and implement `retry()` — this is what powers the retry button in `StateView`
- Use `dart:developer` `log()` for error logging, with the cubit method name
- Emit `_Loading()` before async work, `_Success(...)` on success, `_Error(message)` on failure
- For background refreshes that shouldn't show a loading indicator, skip the loading emit (see `inBackground` parameter pattern)
- Reference API services via their singleton: `SomeAPI.instance.method()`
- State variants are private (`_Initial`, `_Loading`, etc.) — external code uses `BaseStateMixin` predicates

### Always use regular Cubit

Default to regular `Cubit` for all new cubits. Only use `HydratedCubit` if explicitly instructed to — it's reserved for special cases where data must persist across app sessions.

---

## Cubit Ordering & Conventions

**Method ordering** — organize cubit methods in this order:
1. Constructor
2. `retry()` override
3. `fetch()` and other data-loading methods
4. Action methods (e.g., `selectAnswer`, `submit`)
5. `close()` override (always last)

**Don't add unnecessary guards** — if a method can only be called from a specific UI state (e.g., `submit` is only reachable after all questions are answered), don't add redundant checks for conditions that can't occur. Trust the call site. Unnecessary guards add noise and suggest the code is less reliable than it is.

```dart
// GOOD: submit is only called after all answers are collected
Future<Contest> submit() async {
  final answers = state.answersByQuestionId.values.toList();
  return await SomeAPI.instance.submit(id, answers);
}

// BAD: redundant checks for impossible states
Future<Contest> submit() async {
  final successState = state.maybeMap(success: (s) => s, orElse: () => null);
  if (successState == null) throw Exception('Not loaded');  // can't happen
  if (questions.isEmpty) throw Exception('No questions');    // can't happen
  if (answers.length != questions.length) throw ...;         // can't happen
}
```

**Controller naming** — if a cubit has only one controller (e.g., `PageController`, `ScrollController`), name it `controller` rather than `pageController` or `scrollController`. Only use specific names when there are multiple controllers.

**Constructor parameter naming** — if a cubit has only one constructor parameter (e.g., a single ID), name it `id` rather than a verbose name like `programItemId`. Only use specific names when there are multiple parameters or ambiguity.

```dart
// GOOD: single parameter, use short name
class ExerciseTaskCubit extends Cubit<ExerciseTaskState> {
  ExerciseTaskCubit({required this.id}) : super(const _Initial());
  final int id;
}

// BAD: redundant verbosity when there's only one parameter
class ExerciseTaskCubit extends Cubit<ExerciseTaskState> {
  ExerciseTaskCubit({required this.programItemId}) : super(const _Initial());
  final int programItemId;
}
```

**Success-only state updates** — use `state.mapOrNull` for simple emit-only updates (1-2 fields). For methods with logic before the emit (API calls, conditionals), use the state's convenience getters directly since these methods can only be called from the success state anyway. Reserve `mapOrNull` for the final emit only.

```dart
// GOOD: one-liner with mapOrNull for simple updates
void incrementRep() => state.mapOrNull(
      success: (s) => emit(s.copyWith(currentRep: s.currentRep + 1)),
    );

// GOOD: method with logic uses state getters directly, mapOrNull only for emit
Future<void> completeSet() async {
  await ApiService.instance.completeRep(
    programItemId: id,
    setIndex: state.currentSetIndex,  // convenience getter on state
    repCount: state.currentRep,
  );

  if (state.currentSetIndex < state.task.repsPerSet.length - 1) {
    state.mapOrNull(
      success: (s) => emit(s.copyWith(
        currentSetIndex: s.currentSetIndex + 1,
        currentRep: 0,
      )),
    );
  } else {
    await fetch();
  }
}

// BAD: wrapping the entire method body in maybeMap when there's real logic
Future<void> completeSet() => state.maybeMap(
      success: (s) async {
        await ApiService.instance.completeRep(...);
        if (...) { emit(s.copyWith(...)); }
      },
      orElse: () async {},
    );

// BAD: verbose type check for a simple update
void incrementRep() {
  final s = state;
  if (s is! _Success) return;
  emit(s.copyWith(currentRep: s.currentRep + 1));
}
```

---

## Consuming State in Widgets

### StateView — the primary pattern

`StateView` is a generic widget that handles loading (skeleton), error (with retry), and success states automatically:

```dart
StateView<SomeCubit, SomeState>(
  builder: (context, state) => YourWidget(
    data: state.someData,
  ),
)
```

`StateView` wraps `BlocBuilder` and:

- Shows `Skeletonizer` during loading/initial states (skeleton loading, not spinners)
- Shows `WidgetError` with a retry button on error
- Calls your builder on success
- Supports `sliver: true` for use inside `CustomScrollView`

Use `StateView` as the default way to consume cubit state. Only drop down to raw `BlocBuilder` or `BlocListener` when you need custom behavior (e.g., navigation on state change, showing a snackbar).

### BlocBuilder Placement & Performance

Place `BlocBuilder` (and `StateView`) at the **lowest possible point** in the widget hierarchy — wrap only the subtree that actually needs to rebuild when state changes, not an entire screen or section. This is critical for performance: a `BlocBuilder` placed too high causes unnecessary rebuilds of child widgets that don't depend on the changing state.

Always use `buildWhen` to further limit rebuilds to only the specific state changes a widget cares about. If a widget only needs `state.userName`, it should not rebuild when `state.itemCount` changes.

```dart
// GOOD: BlocBuilder wraps only the text that needs the name
Column(
  children: [
    const HeaderWidget(),  // never rebuilds
    BlocBuilder<UserCubit, UserState>(
      buildWhen: (prev, curr) => prev.userName != curr.userName,
      builder: (context, state) => Text(state.userName),
    ),
    const FooterWidget(),  // never rebuilds
  ],
)

// BAD: entire column rebuilds when any user state changes
BlocBuilder<UserCubit, UserState>(
  builder: (context, state) => Column(
    children: [
      const HeaderWidget(),
      Text(state.userName),
      const FooterWidget(),
    ],
  ),
)
```

When a screen has multiple sections each depending on different parts of the same cubit state, use separate `BlocBuilder`/`StateView` widgets for each section with targeted `buildWhen` methods, rather than one large builder wrapping them all.

### Other BLoC consumption patterns

- `context.read<SomeCubit>()` — get the cubit instance imperatively (for calling methods)
- `BlocListener<SomeCubit, SomeState>` — react to state changes with side effects (navigation, dialogs, snackbars)
- `BlocConsumer` — when you need both a builder and a listener
- `MultiBlocListener` — for screens that react to multiple cubits

### Error handling: action methods over BlocListener

State errors (the `_Error` variant) are for **fetch errors** — when loading data fails. `StateView` handles these automatically with a retry button.

For **action errors** (submitting a form, selecting an answer, deleting an item), do **not** use `BlocListener` to detect state transitions. Instead, make the cubit method return a result and let the widget handle it at the call site:

- **Returns `true`** — action succeeded, navigate or show confirmation
- **Returns `false`** — no-op (e.g., duplicate tap, invalid state)
- **Throws** — show the error to the user

The cubit method should throw on failure rather than swallowing errors into state. The widget wraps the call in try/catch and handles both outcomes directly:

```dart
// In the cubit:
Future<bool> selectAnswer({required Question question, required Option option}) async {
  // ... record answer, emit state ...
  if (!state.isLastQuestion) return false;
  await submit(); // throws on failure
  return true;
}

// In the widget — extract async logic into a separate UI method:
onSelectOption: (option) => _onSelectOption(context, question: question, option: option),

// The UI method handles the result:
Future<void> _onSelectOption(BuildContext context, {required Question question, required Option option}) async {
  try {
    final done = await context.read<SomeCubit>().selectAnswer(question: question, option: option);
    if (done) {
      AppNavigator.push(screen: Screen.nextScreen, extra: id);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
```

This pattern is cleaner than BlocListener for actions because:
- The cause and effect are in one place — no state transition guessing
- Errors surface naturally via throw/catch
- The cubit stays simple — no error-then-clear state management dance
- Data the cubit already has (e.g., elapsed time) stays internal rather than being passed in from the widget

### `context.read` usage

Use `context.read<SomeCubit>()` inline — only extract it into a local variable if you use it **3+ times** in the same scope. Short, direct reads are cleaner than premature variables.

```dart
// GOOD: inline for 1-2 uses
controller: context.read<SomeCubit>().pageController,
onPressed: () => context.read<SomeCubit>().fetch(),

// GOOD: variable when used 3+ times
final cubit = context.read<SomeCubit>();
cubit.setFilter(filter);
cubit.setSort(sort);
cubit.fetch();
```

### Navigation (`AppNavigator`)

`AppNavigator` is a static class — it does not depend on `BuildContext`. You do **not** need to check `context.mounted` before calling `AppNavigator.go()`, `AppNavigator.push()`, or `AppNavigator.pop()`. Only check `context.mounted` for context-dependent calls like `ScaffoldMessenger.of(context)` or `showDialog`.
