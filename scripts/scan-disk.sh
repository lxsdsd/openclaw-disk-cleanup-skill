#!/usr/bin/env bash
# scan-disk.sh — Safe disk space scanner for OpenClaw WSL2+Docker deployments
# Run on wsl-host node. Read-only, no deletions.

set -euo pipefail

echo "=== C Drive Status ==="
df -h /mnt/c 2>/dev/null || echo "WARN: /mnt/c not accessible"

echo ""
echo "=== docker_data.vhdx ==="
ls -lh /mnt/c/Users/Lenovo/AppData/Local/Docker/wsl/disk/docker_data.vhdx 2>/dev/null || echo "NOT FOUND"

echo ""
echo "=== Windows Temp ==="
du -sh /mnt/c/Users/Lenovo/AppData/Local/Temp 2>/dev/null || echo "NOT FOUND"
du -sh /mnt/c/Users/Lenovo/AppData/Local/Temp/wsl-crashes 2>/dev/null || echo "  wsl-crashes: CLEAN"

echo ""
echo "=== WSL /home/gaga top dirs ==="
du -sh /home/gaga/* 2>/dev/null | sort -rh | head -15

echo ""
echo "=== OpenClaw workspace ==="
du -sh /home/gaga/openclaw/var/workspace/* 2>/dev/null | sort -rh | head -15

echo ""
echo "=== OpenClaw var ==="
du -sh /home/gaga/openclaw/var/* 2>/dev/null | sort -rh | head -15

echo ""
echo "=== Backup dirs ==="
du -sh /home/gaga/openclaw/var/backups 2>/dev/null || echo "  var/backups: CLEAN"
du -sh /home/gaga/openclaw_recovery 2>/dev/null || echo "  openclaw_recovery: CLEAN"
ls -d /home/gaga/openclaw/var/workspace/assistant-state-backup 2>/dev/null && \
  du -sh /home/gaga/openclaw/var/workspace/assistant-state-backup || echo "  assistant-state-backup: CLEAN"

echo ""
echo "=== Rebuildable deps ==="
du -sh /home/gaga/agent-reach-env 2>/dev/null || echo "  agent-reach-env: CLEAN"
du -sh /home/gaga/openclaw/node_modules 2>/dev/null || echo "  node_modules: NOT PRESENT"

echo ""
echo "=== Docker ==="
docker system df 2>/dev/null || echo "Docker not accessible"
echo "--- Dangling volumes ---"
docker volume ls -f dangling=true --format '{{.Name}}' 2>/dev/null || true
echo "--- Stopped containers ---"
docker ps -a --filter 'status=exited' --format '{{.Names}} {{.Size}}' 2>/dev/null || true

echo ""
echo "=== Protected paths check ==="
for p in \
  /home/gaga/openclaw/var/config/openclaw.json \
  /home/gaga/openclaw/var/workspace/MEMORY.md \
  /home/gaga/openclaw/var/workspace/SOUL.md \
  /home/gaga/openclaw/var/workspace/AGENTS.md \
  /home/gaga/openclaw/var/config/gh/hosts.yml \
; do
  if [ -e "$p" ]; then echo "  OK: $p"; else echo "  MISSING: $p"; fi
done

echo ""
echo "=== Summary ==="
AVAIL=$(df --output=avail -BG /mnt/c 2>/dev/null | tail -1 | tr -d ' G')
echo "C drive available: ${AVAIL}G"
if [ "${AVAIL:-0}" -lt 5 ]; then
  echo "⚠️  LOW SPACE — cleanup recommended"
elif [ "${AVAIL:-0}" -lt 10 ]; then
  echo "⚡ MODERATE — monitor closely"
else
  echo "✅ HEALTHY"
fi
