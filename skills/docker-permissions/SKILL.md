---
name: docker-permissions
description: >
  Use when diagnosing or fixing Hermes Agent Docker permission problems involving /opt/data,
  root-owned .env/config/skills files, gateway PermissionError failures, UID/GID mismatches,
  bind-mounted persistent data, or Docker Compose HERMES_UID/HERMES_GID ownership issues.
---

# Docker Permissions Skill

Use this skill when Hermes Agent is running in Docker and anything under `/opt/data` becomes unreadable or root-owned.

The common failure mode is simple: the container gateway runs as the non-root `hermes` user, but some setup/config command was run as root and rewrote persistent files like `.env`, `config.yaml`, `auth.json`, or installed skills with root ownership. The fix is ownership and mode repair on the persistent data directory, not changing Slack/Discord permissions or weakening files to `777`.

## Reference files

| When you're... | Read |
|----------------|------|
| Diagnosing Docker `/opt/data` permission errors | `references/docker-permissions.md` |
| Repairing root-owned `.env`, `config.yaml`, `auth.json`, or skill files | `references/docker-permissions.md` |
| Setting durable Docker Compose UID/GID ownership | `references/docker-permissions.md` |

## Fast rules

- Check whether the gateway is running before chasing platform-specific bot issues.
- Inspect actual file ownership and the actual gateway process user.
- Repair `.env`, `config.yaml`, and `auth.json` before starting/restarting the gateway.
- Prefer fixing the host bind-mounted data path when `/opt/data` is a volume.
- Do not use `chmod 777`.
- Do not run the gateway as root.
- Do not override the official Docker image entrypoint unless you preserve its behavior.

## Minimal diagnosis

Inside the container:

```bash
/opt/hermes/.venv/bin/hermes gateway status
id
stat -c '%U:%G %u:%g %a %n' /opt/data /opt/data/.env /opt/data/config.yaml /opt/data/auth.json 2>&1
ps -eo user:20,pid,comm,args | grep -E '[h]ermes|[p]ython.*gateway|[p]ython.*run'
```

If critical files are `root:root` while the gateway runs as `hermes`, follow the repair recipes in `references/docker-permissions.md`.
