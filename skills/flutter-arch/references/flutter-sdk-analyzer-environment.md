# Flutter SDK / Analyzer Environment

Use this when a Flutter repo needs `dart analyze` but the agent environment does not have Flutter/Dart installed yet.

## Goal

Make `flutter`, `dart`, and `dart analyze` available in the persistent Hermes execution environment without polluting project repos.

## Known-good Linux/Hermes setup

1. Discover the latest stable Linux release from Flutter's release manifest:

```bash
python3 - <<'PY'
import json, urllib.request
url='https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json'
with urllib.request.urlopen(url, timeout=30) as r:
    data=json.load(r)
hash_=data['current_release']['stable']
rel=next(x for x in data['releases'] if x['hash']==hash_)
print(rel['version'])
print(rel['archive'])
print(rel.get('sha256',''))
PY
```

2. Install under persistent data, not inside a project checkout:

```bash
mkdir -p /opt/data/sdks /opt/data/tmp
cd /opt/data/tmp
curl -fL --retry 3 -o flutter_linux_<version>-stable.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_<version>-stable.tar.xz
echo '<sha256>  flutter_linux_<version>-stable.tar.xz' | sha256sum -c -
rm -rf /opt/data/sdks/flutter
tar -xJf flutter_linux_<version>-stable.tar.xz -C /opt/data/sdks
```

3. Expose binaries in the agent shell:

```bash
mkdir -p "$HOME/bin"
ln -sfn /opt/data/sdks/flutter/bin/flutter "$HOME/bin/flutter"
ln -sfn /opt/data/sdks/flutter/bin/dart "$HOME/bin/dart"
```

If `$HOME/.bashrc` exists and is sourced by Hermes terminal sessions, ensure it prepends both `$HOME/bin` and `/opt/data/sdks/flutter/bin`:

```bash
export PATH="$HOME/bin:/opt/data/sdks/flutter/bin:$PATH"
```

4. Disable analytics once:

```bash
flutter config --no-analytics
dart --disable-analytics
```

5. Verify from a Flutter repo:

```bash
flutter --version
dart --version
flutter pub get
dart analyze
```

## Pitfalls

- `flutter pub get` can update `pubspec.lock` even when the goal is only verification. Check `git status` afterward and revert generated lockfile changes unless they are part of the intended code change.
- `dart analyze` exits non-zero when warnings exist. Treat that as a successful analyzer invocation plus findings, not as proof the SDK is broken.
- Flutter doctor may complain about Android SDK, Chrome, or Linux desktop build tools. Those are not required for `dart analyze`; do not block analyzer setup on them unless the task needs build/run support.
- Keep SDK installation outside project repos to avoid accidental commits of SDK files.
