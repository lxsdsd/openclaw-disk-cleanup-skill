---
name: disk-cleanup
description: Safe C drive disk cleanup for WSL2 + Docker Desktop OpenClaw deployments. Activate when C drive free space drops below 5GB, user asks about disk space, or periodic cleanup is needed. Ensures OpenClaw runtime state (secrets, auth, config, cookies, skills, memory, feishu bindings, agent workspaces) is never damaged during cleanup.
---

# Disk Cleanup — WSL2 + Docker OpenClaw

## When to trigger

- C drive free space < 5GB (check via `df -h /mnt/c` on wsl-host node)
- User asks about disk space or cleanup
- Weekly cron job `disk-cleanup:space-check` fires

## Golden rules

1. **Never delete anything that would break OpenClaw's running state.** If uncertain, don't delete — ask the user.
2. **Never run `rm -rf` on any path not explicitly listed in the Safe-to-delete section.** No wildcards on parent directories.
3. **Always scan before delete.** Run `scripts/scan-disk.sh` first to confirm what exists and its size.
4. **Always verify after delete.** Run the verification checklist after ANY cleanup operation.
5. **No backups on C drive.** All backups go to git cloud or D drive (`/mnt/d/`).
6. **No large downloads or venvs on C drive.** Use `/mnt/d/` as staging.
7. **Dry-run first.** When adding new cleanup targets, list what would be deleted before actually deleting.
8. **Log everything.** Every cleanup action must be logged to `memory/YYYY-MM-DD.md` with timestamp, path, size, and outcome.

## Protected paths — ABSOLUTE NEVER DELETE

These paths are the running state of OpenClaw. Deleting any of them will break the system.
**Even if disk is critically full, these must NEVER be touched.**

### Runtime config & state
```
~/openclaw/var/config/openclaw.json          # Main config — OpenClaw won't start without this
~/openclaw/var/config/openclaw.json.bak      # Config backup — needed for rollback
~/openclaw/var/config/extensions/            # All installed plugins (context-safe, customprovider-cache, etc.)
~/openclaw/var/config/gh/                    # GitHub CLI auth (hosts.yml) — deletion breaks gh/git push
~/openclaw/var/xiaohongshu-mcp/cookies.json  # Xiaohongshu MCP login state — deletion requires re-login
```

### Workspace — agent identity & memory
```
~/openclaw/var/workspace/MEMORY.md           # Long-term memory — irreplaceable if lost
~/openclaw/var/workspace/SOUL.md             # Agent identity — irreplaceable
~/openclaw/var/workspace/AGENTS.md           # Operating rules — irreplaceable
~/openclaw/var/workspace/USER.md             # User profile — irreplaceable
~/openclaw/var/workspace/IDENTITY.md         # Agent identity metadata
~/openclaw/var/workspace/HEARTBEAT.md        # Heartbeat rules
~/openclaw/var/workspace/BOOTSTRAP.md        # Bootstrap config (if exists)
~/openclaw/var/workspace/TODO_*.md           # All todo files
~/openclaw/var/workspace/STATUS_BOARD.md     # Current status board
~/openclaw/var/workspace/*_STATUS.md         # All status files
~/openclaw/var/workspace/*_POLICY.md         # All policy files
~/openclaw/var/workspace/*_ROLES.md          # All role files
~/openclaw/var/workspace/CONFIG_CHANGELOG.md # Config change history — audit trail
~/openclaw/var/workspace/INFRA_BASELINE.md   # Infrastructure baseline
~/openclaw/var/workspace/memory/             # Daily memory files — all of them, no exceptions
~/openclaw/var/workspace/.learnings/         # Self-improvement logs
```

### Workspace — active content
```
~/openclaw/var/workspace/skills/             # All skills including this one
~/openclaw/var/workspace/agents/             # Agent definitions
~/openclaw/var/workspace/projects/           # Active projects (english-study etc.)
~/openclaw/var/workspace-*/                  # Sub-agent workspaces (workspace-builder-a, etc.)
```

### Auth & secrets
```
~/.openclaw/device-auth.json                 # Device pairing — deletion breaks node connections
~/openclaw/.env                              # Environment secrets — deletion breaks everything
~/openclaw/docker-compose*.yml               # Docker composition — deletion breaks container startup
```

### Source code (contains unreleased fixes)
```
~/openclaw/src/                              # Source code with operator auth fix
~/openclaw/dist/                             # Built artifacts
~/openclaw/extensions/                       # Extension source
~/openclaw/package.json                      # Package manifest
~/openclaw/pnpm-lock.yaml                    # Lock file for reproducible installs
```

### Docker — running containers and their volumes
```
# NEVER run: docker rm on running containers
# NEVER run: docker volume rm on volumes attached to running containers
# NEVER run: docker rmi on images used by running containers
# NEVER run: docker system prune -a (removes ALL unused images including needed ones)
```

## Safe to delete — ordered by safety level

### Tier 1: Always safe — auto-clean without asking

These are pure waste with zero recovery value.

| # | Target | Command (on wsl-host) | Max expected size | Why safe |
|---|--------|----------------------|-------------------|----------|
| 1 | Windows Temp wsl-crashes | `rm -rf /mnt/c/Users/Lenovo/AppData/Local/Temp/wsl-crashes` | 1-10G | WSL crash dumps, never useful |
| 2 | Windows Temp .tmp files (>10MB, >7 days old) | `find /mnt/c/Users/Lenovo/AppData/Local/Temp -maxdepth 1 -type f -name '*.tmp' -size +10M -mtime +7 -delete` | 0.5-3G | Stale temp files, age-gated for safety |
| 3 | Windows Temp DiagOutputDir | `rm -rf /mnt/c/Users/Lenovo/AppData/Local/Temp/DiagOutputDir` | 50-500M | Diagnostic output, no value |
| 4 | Docker dangling images | `docker image prune -f` | 0-2G | Untagged images, not used by any container |
| 5 | Docker dangling volumes | `docker volume prune -f` | 0-1G | Volumes not attached to any container |
| 6 | Docker stopped containers | `docker container prune -f` | 0-100M | Exited containers, easily recreated |
| 7 | Docker build cache | `docker builder prune -f` | 0-5G | Build layer cache, rebuilt on demand |

**Tier 1 total potential**: 2-20G

### Tier 2: Safe after verification — check pre-conditions first

| # | Target | Pre-check | Command | Recovery method |
|---|--------|-----------|---------|----------------|
| 1 | `~/openclaw/var/backups/` | Confirm all entries >7 days old | `rm -rf ~/openclaw/var/backups/` | Re-run backup scripts |
| 2 | `~/agent-reach-env/` | Confirm agent-reach container not using it | `rm -rf ~/agent-reach-env/` | `pip install` to rebuild |
| 3 | `~/openclaw_recovery/` | Confirm session dates are >3 days old | `rm -rf ~/openclaw_recovery/` | Sessions are ephemeral |
| 4 | `~/openclaw/var/workspace/assistant-state-backup/` | Confirm content duplicated in current workspace | `rm -rf ~/openclaw/var/workspace/assistant-state-backup/` | Content exists in workspace + git |

**Tier 2 total potential**: 0.5-2G

### Tier 3: Needs user decision — write to TODO_USER.md

These are large-impact operations that require user awareness or admin privileges.

| # | Target | Size | Action | Why user-only |
|---|--------|------|--------|---------------|
| 1 | `docker_data.vhdx` compact | 20-50G recoverable | `wsl --shutdown` + `Optimize-VHD` in admin PowerShell | Stops all WSL/Docker; needs admin |
| 2 | `~/openclaw/node_modules/` | ~2G | Delete + `pnpm install` to rebuild | May break host CLI commands |
| 3 | Unused Docker images (`docker image prune -a`) | varies | Removes ALL unused images | May remove images needed later |
| 4 | Git repo `.git` shrink | varies | `git gc --aggressive` on large repos | Slow, may need network for refetch |

## Workflow — step by step

```
1. SCAN     → Run scripts/scan-disk.sh on wsl-host
2. REPORT   → Parse output, identify candidates per tier
3. CHECK    → Verify all protected paths exist BEFORE any deletion
4. TIER 1   → Auto-clean (always safe items)
5. TIER 2   → Verify pre-conditions, then clean
6. TIER 3   → Write items to TODO_USER.md with exact commands
7. VERIFY   → Run verification checklist (containers + protected paths)
8. LOG      → Write cleanup summary to memory/YYYY-MM-DD.md
9. NOTIFY   → If >1G recovered or user action needed, notify via feishu
```

## Storage prevention rules

These rules prevent future disk bloat:

1. **No local backups on C drive** — use `git push` or `/mnt/d/`
2. **No Python venvs on C drive** — create on `/mnt/d/`, symlink if needed
3. **No large downloads on C drive** — use `/mnt/d/` as staging
4. **No duplicate copies of workspace** — one workspace, backed by git
5. **Git repos**: run `git gc --aggressive` quarterly on repos >200MB
6. **Docker**: run `docker system prune` monthly (NOT `prune -a`)
7. **vhdx compact**: schedule quarterly or when C drive < 10GB
8. **Windows Temp**: check monthly, clear wsl-crashes + old .tmp files
9. **New plugins/skills**: install to the canonical path only, no extra copies

## Verification checklist — run after ANY cleanup

```bash
# On wsl-host — ALL must pass before cleanup is considered complete:

echo "=== Docker containers ==="
docker ps --format '{{.Names}} {{.Status}}'
# EXPECT: all containers show "Up" and "(healthy)" where applicable

echo "=== Protected config ==="
for f in \
  /home/gaga/openclaw/var/config/openclaw.json \
  /home/gaga/openclaw/var/config/gh/hosts.yml \
  /home/gaga/openclaw/var/config/extensions/context-safe/package.json \
  /home/gaga/openclaw/var/config/extensions/openclaw-customprovider-cache/package.json \
; do [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"; done

echo "=== Protected workspace ==="
for f in \
  /home/gaga/openclaw/var/workspace/MEMORY.md \
  /home/gaga/openclaw/var/workspace/SOUL.md \
  /home/gaga/openclaw/var/workspace/AGENTS.md \
  /home/gaga/openclaw/var/workspace/USER.md \
  /home/gaga/openclaw/var/workspace/TODO_SHORT.md \
  /home/gaga/openclaw/var/workspace/TODO_USER.md \
  /home/gaga/openclaw/var/workspace/CONFIG_CHANGELOG.md \
; do [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"; done

echo "=== Memory directory ==="
ls /home/gaga/openclaw/var/workspace/memory/ | tail -3
# EXPECT: recent daily .md files present

echo "=== Skills ==="
ls /home/gaga/openclaw/var/workspace/skills/
# EXPECT: disk-cleanup and other skills present

echo "=== Auth ==="
[ -f /home/gaga/openclaw/.env ] && echo "OK: .env" || echo "MISSING: .env"

echo "=== C drive space ==="
df -h /mnt/c
# EXPECT: more free space than before cleanup
```

**If ANY protected path shows MISSING**: STOP immediately, do NOT proceed with further cleanup, notify user with the exact missing path.

## Cron integration

Weekly check, every Monday at 10:00 Beijing time (02:00 UTC):
```
Schedule: cron "0 2 * * 1" (every Monday 02:00 UTC = 10:00 BJT)
Payload: Check C drive free space via scan-disk.sh on wsl-host.
         If < 5GB: run Tier 1 auto-cleanup, then notify user.
         If < 10GB: notify user with recommendation.
         If >= 10GB: no action needed.
```

## Emergency procedure — C drive < 1GB

If C drive drops below 1GB, this is an emergency:

1. **Immediately** run Tier 1 cleanup (no questions)
2. **Immediately** notify user via feishu with urgency
3. **Add to TODO_USER.md** as P0: compact docker_data.vhdx
4. **Do NOT** create any new files on C drive until space > 5GB
5. **Redirect** any file operations to `/mnt/d/` temporarily

## What this skill does NOT do

- Does NOT delete anything outside the Safe-to-delete lists
- Does NOT compact docker_data.vhdx (requires admin PowerShell + WSL shutdown)
- Does NOT delete node_modules without user approval
- Does NOT run `docker system prune -a` (too aggressive)
- Does NOT modify any config files
- Does NOT touch any `.env`, token, key, or secret files
- Does NOT delete any git history or repository data
- Does NOT delete files on D drive
