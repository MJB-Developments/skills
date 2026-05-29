# Hermes Docker Permissions and Persistent `/opt/data`

## When this applies
Use this reference when Hermes Agent runs inside Docker and reports permission errors reading skills, sessions, memories, config, or other files under `/opt/data`.

## Durable facts from Hermes Docker docs
- `/opt/data` is the single persistent Hermes home inside the container.
- It is usually bind-mounted from the host, commonly `~/.hermes:/opt/data`.
- The official image is stateless; user data lives in `/opt/data`.
- The entrypoint bootstraps `/opt/data`, syncs bundled skills, then drops privileges to the non-root `hermes` user.
- Default container user is UID/GID `10000:10000` unless `HERMES_UID` / `HERMES_GID` are set.
- Do not run the gateway as root; root-owned files in `/opt/data` can break later gateway/dashboard/skill reads.
- Do not override the image entrypoint unless preserving `/opt/hermes/docker/entrypoint.sh` in the command chain.
- Do not run multiple gateway containers against the same data directory.

## Symptom pattern
A skill load can fail with `Permission denied` even when the skill directory is visible. Example root cause:

```text
/opt/data/skills/.../SKILL.md
-rw------- root root SKILL.md
```

Slack/gateway messages can also fail immediately with:

```text
Sorry, I encountered an error (PermissionError).
[Errno 13] Permission denied: '/opt/data/.env'
```

A common cause is running `hermes config set ...` or `hermes model` as root inside the Docker container. That can rewrite `/opt/data/.env` as `root:root 0600`; the gateway runs as the non-root `hermes` user and then cannot read environment variables/secrets.

Healthy default ownership looks like:

```text
uid=10000(hermes) gid=10000(hermes)
/opt/data/.env -> hermes:hermes 0600
```

The fix is ownership/mode of the persistent host-mounted data directory, not Slack permissions.

## Quick diagnosis
**Always start by confirming the gateway is even running.** A silent bot ("I message it and nothing happens") has two very different root causes that look identical from the user's side: (a) gateway process is dead/never started, (b) gateway is running but crashing on every message with a PermissionError. Check (a) first — it takes one command and eliminates half the diagnostic tree.

```bash
/opt/hermes/.venv/bin/hermes gateway status
```

If it reports `✗ Gateway is not running`, the symptom is not (only) a permissions problem — no process is listening. You may *still* have a permissions problem waiting to surface the moment you start the gateway (see "Two-fault scenario" below), so continue with the permission checks before launching it.

Then, inside the running container:

```bash
id
namei -l /opt/data/skills/autonomous-ai-agents/hermes-agent/SKILL.md
stat /opt/data/skills/autonomous-ai-agents/hermes-agent/SKILL.md
stat -c '%U:%G %u:%g %a %n' /opt/data /opt/data/.env 2>&1
ps -eo user:20,pid,comm,args | grep -E '[h]ermes|[p]ython.*gateway|[p]ython.*run'
```

If the error names `/opt/data/.env`, specifically check whether it is `root:root 600` while `hermes gateway run` is owned by `hermes`.

### Two-fault scenario: gateway down AND permissions broken
A common compound failure: someone ran `hermes config set ...` or `hermes model` as root, which (1) rewrote `/opt/data/.env` (and often `config.yaml`, `auth.json`, the entire `/opt/data/home/` cache, and hundreds of files under `/opt/data/skills/`) as `root:root`, and (2) may have left the gateway stopped or never started it. Symptoms from the user's side are identical to a plain "gateway down." Always **repair permissions BEFORE starting the gateway** — otherwise the gateway will come up, then crash on the first incoming Slack/Discord message with the PermissionError because it runs as the `hermes` user and can't read its own `.env`.

When you find no `gateway.log` and no PermissionError traceback in `agent.log` / `errors.log`, that does NOT mean permissions are fine — it just means the gateway never ran long enough to emit those errors. Confirm `.env` ownership directly with `stat` before declaring permissions OK.

### Symptom decision table
| User says | Gateway status | .env owner | Likely cause | Order of fix |
|-----------|----------------|------------|--------------|--------------|
| Bot silent, no response | running | hermes:hermes | platform-specific (Slack scopes, Discord intents, network) — not in this reference | — |
| Bot silent, errors.log has `PermissionError: '/opt/data/.env'` | running (crash-looping per message) | root:root | env stolen by root `hermes config` | fix .env → restart gateway |
| Bot silent, no errors.log entries about it | not running | root:root | gateway never started + env stolen (two-fault) | fix .env → start gateway as hermes |
| Bot silent, no errors.log entries about it | not running | hermes:hermes | gateway never started (one-fault) | start gateway as hermes |

## Docker health-check recipe
When the user asks "is Hermes healthy / are permissions good?", verify the runtime, config, permissions, logs, and scheduled jobs rather than only running `hermes doctor`.

1. **Use the venv entrypoint inside the official Docker image.** Minimal shells may not have `hermes` on `PATH`, and `/opt/hermes/hermes` may run with the system Python instead of the packaged venv. Prefer:

   ```bash
   /opt/hermes/.venv/bin/hermes doctor
   /opt/hermes/.venv/bin/hermes status --all
   /opt/hermes/.venv/bin/hermes config check
   ```

2. **Confirm the actual long-running process user.** `docker exec` may start as root, but the gateway should still be non-root:

   ```bash
   ps -eo user:12,pid,ppid,stat,cmd | grep -E '[h]ermes|[g]ateway|[p]ython'
   ```

3. **Check key ownership/modes and readability.** Healthy Docker defaults commonly look like:

   ```text
   /opt/data              hermes:hermes 0700
   /opt/data/.env         hermes:hermes 0600
   /opt/data/auth.json    hermes:hermes 0600
   /opt/data/config.yaml  hermes:hermes 0640
   /opt/data/skills       hermes:hermes readable by uid 10000
   ```

   Also scan for root-owned or unreadable state under `/opt/data` before declaring permissions clean:

   ```bash
   python3 - <<'PY'
   import os, stat, pwd, grp
   root='/opt/data'; count=0
   for dirpath, dirs, files in os.walk(root):
       depth=dirpath[len(root):].count(os.sep)
       if depth>3:
           dirs[:] = []
           continue
       for p in [dirpath] + [os.path.join(dirpath, f) for f in files]:
           try: st=os.lstat(p)
           except FileNotFoundError: continue
           mode=stat.S_IMODE(st.st_mode)
           bad = st.st_uid != 10000 or st.st_gid != 10000 or (not stat.S_ISDIR(st.st_mode) and not (mode & stat.S_IRUSR))
           if bad:
               u=pwd.getpwuid(st.st_uid).pw_name if st.st_uid in [x.pw_uid for x in pwd.getpwall()] else str(st.st_uid)
               g=grp.getgrgid(st.st_gid).gr_name if st.st_gid in [x.gr_gid for x in grp.getgrall()] else str(st.st_gid)
               print(f'{u}:{g} {mode:04o} {p}')
               count += 1
   print(f'suspicious_entries={count}')
   PY
   ```

4. **Read the current log tail, not only regex hits.** Historical permission errors can remain in logs after repair. Use the last gateway lines to verify the current state shows startup, Slack/platform connection, cron ticker, and responses without fresh PermissionErrors:

   ```bash
   ls /opt/data/logs/
   tail -80 /opt/data/logs/gateway.log 2>/dev/null || echo 'no gateway.log — gateway has not run since logs were last rotated'
   tail -40 /opt/data/logs/errors.log 2>/dev/null
   tail -40 /opt/data/logs/agent.log 2>/dev/null
   grep -Ei 'permission denied|traceback|error|failed|warning' /opt/data/logs/*.log 2>/dev/null | tail -40
   ```

   Note: `gateway.log` is created the first time `hermes gateway run` starts. If it's missing, the gateway has never run in this deployment — that itself is the diagnosis. `agent.log` and `errors.log` exist from CLI sessions too, so they're a useful fallback for surfacing PermissionErrors even when no gateway has booted.

5. **Check cron from the running agent when available.** `hermes cron list` or the cron tool should show active jobs, last status, and next run. A healthy gateway can still have an unhealthy scheduled workflow if cron last status or delivery failed.

On the Docker host, find the running container name and mounted source:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker inspect <container-name> \
  --format '{{range .Mounts}}{{println .Destination "->" .Source}}{{end}}'
```

If guiding a remote operator (for example a VPS/Hostinger root shell), proceed one command at a time: identify the container, inspect mounts, verify `namei -l`, then repair ownership/modes. Do not dump a long multi-command runbook unless they ask for it.

## Immediate repair for default UID/GID
If Slack/gateway errors name `/opt/data/.env` and the file is `root:root 600`, fix just that file first:

```bash
docker exec -u root hermes sh -lc '
  chown 10000:10000 /opt/data/.env
  chmod 600 /opt/data/.env
  stat -c "%U:%G %u:%g %a %n" /opt/data/.env
'
```

Then verify the runtime user can read it:

```bash
docker exec -u root hermes sh -lc '
  if command -v gosu >/dev/null 2>&1; then gosu hermes test -r /opt/data/.env; else su -s /bin/sh hermes -c "test -r /opt/data/.env"; fi
  echo "hermes_can_read_env=$?"
'
```

If messages still fail after ownership is fixed, restart the gateway (`/restart` from the gateway, or `docker restart hermes` / `docker compose restart` from the host).

**Important:** inside the official Docker image, do not run `/opt/hermes/.venv/bin/hermes gateway restart` as root. It may successfully stop the existing non-root gateway, then refuse to start a replacement because root gateway runs are blocked. If that happens, start it again as the `hermes` user:

```bash
su -s /bin/bash hermes -c '/opt/hermes/.venv/bin/hermes gateway run'
```

Then verify with:

```bash
/opt/hermes/.venv/bin/hermes gateway status
ps -eo user,pid,ppid,cmd | grep -E '[h]ermes|[g]ateway'
tail -60 /opt/data/logs/gateway.log | grep -Ei 'permission denied|starting|slack|ready|error|traceback|gateway' | tail -30
```

If the gateway is meant to be durable, prefer the container entrypoint/Compose restart path over a manually spawned `su ... gateway run` process.

**Manual `su` restart verification nuance.** When started from a root shell with `su -s /bin/bash hermes -c 'cd /opt/data && /opt/hermes/.venv/bin/hermes gateway run'`, `hermes gateway status` can report two PIDs: the root-owned `su` parent and the hermes-owned gateway child. That is acceptable for a manual container foreground recovery as long as the actual `hermes gateway run` process is owned by `hermes`, Slack/platform logs show connected, and the critical files are readable by `hermes`. Run one final ownership sweep after launch if the repair was performed from an active root Hermes CLI session, because that root CLI can recreate session/process metadata while you are fixing ownership:

```bash
find /opt/data -xdev -user root -exec chown -h 10000:10000 {} +
chmod 600 /opt/data/.env /opt/data/auth.json /opt/data/config.yaml 2>/dev/null || true
su -s /bin/sh hermes -c 'test -r /opt/data/.env && test -r /opt/data/config.yaml && test -r /opt/data/auth.json'
/opt/hermes/.venv/bin/hermes gateway status
```

Treat `config.yaml` and `auth.json` as critical, not just `.env`: unreadable `config.yaml` makes Hermes silently fall back to default config/model behavior, and unreadable `auth.json` makes OAuth providers appear logged out or corrupt.

If the container is named `hermes` and uses the default Hermes UID/GID, and skill files are also broken:

```bash
docker exec -u root hermes sh -lc '
  chown -R 10000:10000 /opt/data/skills
  find /opt/data/skills -type d -exec chmod 755 {} \;
  find /opt/data/skills -type f -exec chmod 644 {} \;
'
docker restart hermes
```

When a specific host bind mount is known, repair the persistent host path directly. Example from a Hostinger deployment where `/opt/data -> /docker/hermes-agent-8wzy/data`:

```bash
# Fix one broken skill file
chown 10000:10000 /docker/hermes-agent-8wzy/data/skills/autonomous-ai-agents/hermes-agent/SKILL.md
chmod 644 /docker/hermes-agent-8wzy/data/skills/autonomous-ai-agents/hermes-agent/SKILL.md

# Check for other root-owned state files
find /docker/hermes-agent-8wzy/data -user root -ls

# If root-owned files are found, fix ownership while preserving modes
find /docker/hermes-agent-8wzy/data -user root -exec chown 10000:10000 {} +

# Verify the bad ownership is gone
find /docker/hermes-agent-8wzy/data -user root -ls
```

Prefer the host-path repair when the data directory is bind-mounted because it proves persistence and avoids mistaking container-layer state for durable state. In Hostinger-style images, `docker exec <container> sh -lc 'id'` may default to `root` even when the actual gateway process is correctly running as `hermes`; verify the real process owner before concluding the deployment is wrong:

```bash
docker exec <container> sh -lc \
  'ps -eo user,pid,ppid,comm,args | grep -E "hermes chat|hermes gateway run" | grep -v grep'
```

If a stray root-owned interactive chat process exists, stop that process and re-run the host-path ownership check:

```bash
docker exec <container> sh -lc 'kill <root-hermes-chat-pid> 2>/dev/null || true'
find <host-data-path> -user root -exec chown 10000:10000 {} +
find <host-data-path> -user root -ls
```

The target healthy state is usually: `hermes gateway run` owned by `hermes`, no root-owned files under the persistent data directory, and skill files readable by the Hermes runtime.

For the whole data dir:

```bash
docker exec -u root hermes sh -lc '
  chown -R 10000:10000 /opt/data
  find /opt/data -type d -exec chmod 755 {} \;
  find /opt/data -type f -exec chmod 644 {} \;
  chmod 600 /opt/data/.env 2>/dev/null || true
'
```

## Preferred persistent pattern: host user owns data, container maps to host UID/GID
On the host:

```bash
export HERMES_DATA="$HOME/.hermes"
mkdir -p "$HERMES_DATA"
sudo chown -R "$(id -u):$(id -g)" "$HERMES_DATA"
find "$HERMES_DATA" -type d -exec chmod 755 {} \;
find "$HERMES_DATA" -type f -exec chmod 644 {} \;
chmod 600 "$HERMES_DATA/.env" 2>/dev/null || true
```

Compose:

```yaml
services:
  hermes:
    image: nousresearch/hermes-agent:latest
    container_name: hermes
    restart: unless-stopped
    command: gateway run
    ports:
      - "8642:8642"
    volumes:
      - ${HOME}/.hermes:/opt/data
    environment:
      - HERMES_UID=${UID}
      - HERMES_GID=${GID}
    shm_size: "1gb"
```

Start with exported IDs:

```bash
UID=$(id -u) GID=$(id -g) docker compose up -d
```

## Alternative persistent pattern: default Hermes UID owns data
On the host:

```bash
export HERMES_DATA="$HOME/.hermes"
sudo mkdir -p "$HERMES_DATA"
sudo chown -R 10000:10000 "$HERMES_DATA"
sudo find "$HERMES_DATA" -type d -exec chmod 755 {} \;
sudo find "$HERMES_DATA" -type f -exec chmod 644 {} \;
sudo chmod 600 "$HERMES_DATA/.env" 2>/dev/null || true
```

## Pitfalls
- Avoid `chmod 777`; it fixes symptoms by overexposing secrets and creating a worse security posture.
- Preserve `.env` as `0600` where possible, owned by the same UID/GID as the gateway process.
- In Docker, avoid running `hermes config set`, `hermes model`, or interactive `hermes` as root unless you immediately repair ownership under `/opt/data`. Prefer running through the image entrypoint or as the `hermes` user.
- If setting `HERMES_UID`/`HERMES_GID`, make host ownership match those IDs.
- If using Compose variable interpolation, ensure `UID` and `GID` are exported or placed in the Compose `.env` file.
- **Active root-owned CLI session during repair.** When you run `find /opt/data -user root -exec chown 10000:10000 {} +` from a root CLI session, the very CLI doing the chown keeps writing its own session file (`/opt/data/sessions/session_*.json`) as root — so a second `find … -user root` immediately afterward will still show 1-5 root-owned files (the live session and any uv wheel-cache symlinks chown can't follow). This is expected; do not chase it. The active session file becomes inert (not re-opened) once the CLI exits, and the next CLI run as hermes will create its session as hermes. Symlinks in `/opt/data/home/.cache/uv/wheels-v6/` are followable by all users regardless of symlink ownership, so leave them alone.
- **Don't start the gateway before fixing `.env`.** If `.env` is `root:root` and you start the gateway as `hermes`, it will appear to come up cleanly (Socket Mode may even connect) and only fail on the first inbound message, producing a PermissionError per message. Always `stat /opt/data/.env` and repair ownership *before* launching `hermes gateway run`.
