# WSL2 + Docker Desktop 磁盘空间最佳实践

## 为什么 C 盘会爆

### docker_data.vhdx 只增不缩
- Docker Desktop 在 WSL2 下使用 ext4.vhdx / docker_data.vhdx 存储所有容器数据
- 这个虚拟磁盘文件只会增长，即使删除了容器/镜像/volume，vhdx 不会自动缩小
- 唯一的缩小方法是手动 compact（需要 wsl --shutdown + Optimize-VHD）

### Windows Temp 累积
- WSL crash dumps 默认存在 `%TEMP%\wsl-crashes`，从不自动清理
- Docker 也会在 Temp 里留 swap.vhdx 和临时文件

### 本地备份膨胀
- 每次手动备份如果存在 C 盘的 WSL 文件系统里，都会被 vhdx 吃掉
- 即使删了备份，vhdx 也不会缩——等于双倍浪费

## 预防措施

### 1. 备份和大文件放 D 盘
- 任何备份、下载、venv、大型 git clone 都应该放 `/mnt/d/`
- 可以在 WSL 里用 symlink：`ln -s /mnt/d/backups ~/backups`

### 2. 定期 compact vhdx
- 建议每月或 C 盘 < 10GB 时执行：
  ```powershell
  wsl --shutdown
  Optimize-VHD -Path "C:\Users\Lenovo\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Mode Full
  ```
- 如果没有 Hyper-V 模块，用 diskpart：
  ```
  wsl --shutdown
  diskpart
  select vdisk file="C:\Users\Lenovo\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
  compact vdisk
  exit
  ```

### 3. Docker 定期清理
- `docker system prune -f` — 删除停止的容器、未使用的网络、dangling images
- `docker volume prune -f` — 删除未使用的 volumes
- `docker builder prune -f` — 清理构建缓存

### 4. .wslconfig 限制资源
在 `C:\Users\Lenovo\.wslconfig` 中设置：
```ini
[wsl2]
memory=8GB
swap=4GB
```

### 5. Git 仓库瘦身
- `git gc --aggressive --prune=now` 定期在大仓库上运行
- 考虑 shallow clone：`git clone --depth 1`

### 6. Windows Temp 定期清理
- 可设置"存储感知"自动清理（Windows设置 → 存储 → 存储感知）
- 或手动删除 `%TEMP%` 下超过 7 天的文件
