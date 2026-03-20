# openclaw-disk-cleanup-skill

Safe C drive disk cleanup skill for **WSL2 + Docker Desktop** OpenClaw deployments.

## What it does

- **Auto-detects** when C drive free space drops below 5GB
- **Safely cleans** Windows Temp, Docker dangling resources, expired backups
- **Never touches** OpenClaw runtime state: config, memory, auth, skills, agent workspaces, secrets
- **Three-tier safety model**: auto-clean (always safe) → verify-then-clean → user-manual-only
- **Weekly cron check** with automatic Tier 1 cleanup when space is low
- **Full verification** after every cleanup to confirm nothing was damaged

## Safety guarantees

- Explicit protected-path list covering 30+ critical files/directories
- No wildcards on parent directories — only explicitly listed targets
- Age-gated deletion for temp files (>7 days, >10MB)
- Mandatory scan-before-delete and verify-after-delete workflow
- Emergency procedure for critically low space (<1GB)
- Logs every action to daily memory files

## Structure

```
skills/disk-cleanup/
├── SKILL.md                                      # Main skill file with all rules
├── scripts/
│   └── scan-disk.sh                              # Read-only disk scanner (no deletions)
└── references/
    └── wsl-docker-disk-best-practices.md         # WSL2+Docker disk management reference
```

## Installation

Copy the `skills/disk-cleanup/` directory into your OpenClaw workspace `skills/` folder:

```bash
cp -r skills/disk-cleanup/ ~/openclaw/var/workspace/skills/disk-cleanup/
```

## Designed for

- WSL2 + Docker Desktop deployments on Windows
- OpenClaw running in Docker containers with host-mounted state
- Systems where C drive space is limited and Docker vhdx grows unbounded

## License

MIT
