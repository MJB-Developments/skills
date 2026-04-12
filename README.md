# Skills

Custom Claude Code skills.

## Install a single skill

```bash
# Clone just one skill into your Claude Code skills directory
git clone --filter=blob:none --sparse https://github.com/<you>/skills.git /tmp/skills-repo
cd /tmp/skills-repo
git sparse-checkout set flutter-arch
cp -R flutter-arch ~/.agents/skills/flutter-arch
rm -rf /tmp/skills-repo
```

Or use a simple install script:

```bash
./install.sh flutter-arch
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `flutter-arch` | Flutter architecture patterns, BLoC/Cubit, widget composition |
