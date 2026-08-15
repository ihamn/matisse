# AI_ARCHIVE 2026-08-15 dsh web 故障记录（服务无法启动）

日期: 2026-08-15 13:00-13:03 CST
设备: 本机（matisse, kernel 5.10.209），Termux 用户 u0_a474
涉及: dsh web（deepseek-harness），`~/.dsh` 存储目录

## 事件时间线（基于日志 mtime、目录 mtime 与用户陈述）

- 08:43 归档记载：mt26 将 selinux_state.enforcing 改写为 0，getenforce=Permissive（见 `AI_ARCHIVE_2026-08-14_kallsyms_verified.md`）。
- 12:32 `AI_ARCHIVE_2026-08-14_kallsyms_verified.md` 最后更新。
- 12:36 第一次观察到 `.dsh/storages` 目录 mtime 为 12:36，其中已存在 `session_projcache.json`（后续排查中的 touch/rm 测试把目录 mtime 更新为 12:57，不代表文件重建时间）。
- 12:55 `~/dsh-web.log` 最后一次写入，内容为启动失败报错。
- 13:00-13:03 完成排查与处理。
- 用户陈述：此前用 harness 处理 `/storage/emulated/0/Documents/matisse_backup_essentials/`，运行 mt26 尝试关闭 SELinux，随后手机黑屏，重启后出现本故障。

## 故障现象

- `http://127.0.0.1:3080` 无法打开，端口无监听，node 进程不存在。
- `~/dsh-web.log` 报错：
  `EACCES: permission denied, open '/data/data/com.termux/files/home/.dsh/storages/session_projcache.json'`
  由 session-projection-cache 插件启动阶段抛出，plugin tree 加载失败，进程退出。

## 排查结果（均为实际观察）

- `ls -la` 显示该文件为 `-??????????`，属主、大小、时间均不可读。
- 以文件属主 u0_a474 执行 stat / read / mv / unlink / chmod 均返回 EACCES；连元数据（getattr）都无法读取。
- 绕过执行沙箱（escalated）执行相同操作，结果相同，排除沙箱因素。
- SELinux 状态：重启后为 Enforcing（通过 rish 执行 getenforce 确认，13:01）。
- rish（Shizuku，shell uid=2000）可运行，但 shell 无法进入 Termux 私有目录（`~` 权限 700，属主 u0_a474），无法操作该文件。
- 同目录其他文件（`workspace.json`）正常。
- `.dsh/storages` 目录本身正常（属主 u0_a474，700），可在其中正常创建和删除其他文件。
- 结论：该文件 inode 的磁盘状态（属主或 SELinux 标签）已损坏，应用 UID 无法 getattr/unlink，普通文件系统操作无法修复；当前无 root，未尝试 root 手段。
- 归档关联（仅记录，不作因果断言）：`AI_ARCHIVE_2026-08-14_kallsyms_verified.md` 中 mt28g2 条目写有 "Permission denied 污染源头"，时间线与本事件吻合，但未做磁盘级取证。

## 处理方式

- 未删除任何文件。将整个存储目录改名隔离：
  `mv ~/.dsh/storages ~/.dsh/storages.corrupt-20260815`
- 隔离目录内保留 `workspace.json`（1393B，2026-08-14 19:19）与损坏的 `session_projcache.json`。
- dsh web 启动时自动重建 `~/.dsh/storages`，并重新生成 `workspace.json`（1600B，13:03）。
- 验证：`node --expose-internals apps/cli/lib/bin.js` 运行中（PID 30578），`curl http://127.0.0.1:3080/` 返回 HTTP 200。

## 遗留事项

- `~/.dsh/storages.corrupt-20260815/session_projcache.json` 仍无法删除，需 root 权限清理（例如 `rm -rf ~/.dsh/storages.corrupt-20260815`）。
- 若后续 mt 实验再次导致 `.dsh` 下文件 EACCES，可重复"改名隔离 storages 目录"的处置。
- 继续实验前建议确认内核状态（boot_id / dmesg）干净，避免携带悬垂写链。

---

## 复发记录（同日第二次，14:19-14:31 CST）

## 事件时间线

- 14:03-14:19 用户在 harness 上继续 mt 实验相关工作；14:19 `~/mt26f.sh`（mt26f discriminator，LD_PRELOAD `/data/local/tmp/preload.so` + pselect slide 触发）落盘并运行。
- 14:23 `~/.dsh/storages/session_projcache.json` 重新生成（上次修复后重建的目录内）。
- 14:28 `~/dsh-web.log` 再次报同一错误：`EACCES: permission denied, open '~/.dsh/storages/session_projcache.json'`，plugin tree 加载失败，进程退出。
- 14:31 完成处置与验证。

## 故障现象与排查

- 与 13:00 故障完全一致：`session_projcache.json` 显示 `-??????????`，属主 u0_a474 执行 stat / read / chmod 均 EACCES，目录内 `workspace.json` 正常，目录本身可读写。
- 两次故障之间（12:32-14:19）唯一新增的 mt 活动为 mt28g2 与 mt26f 实验，时间线吻合；沿用归档立场，仅记录不作因果断言。

## 处理方式（与首次相同，未删除任何文件）

- 改名隔离：`mv ~/.dsh/storages ~/.dsh/storages.corrupt-20260815b`
- 重启：`export DEEPSEEK_API_KEY=... && ./start-dsh-web.sh --bg`
- 验证：14:31 `curl http://127.0.0.1:3080/` HTTP 200；node 进程运行中；`~/.dsh/storages/workspace.json` 重建（1600B）。

## 新增遗留事项

- 两个隔离目录（`storages.corrupt-20260815`、`storages.corrupt-20260815b`）内的损坏 inode 均需 root 清理。
- 预防建议：跑 mt 实验前先隔离/停止 dsh web（`pkill -f '^node --expose-internals apps/cli/lib/bin.js'`），避免实验污染活存储；或在 mt 运行窗口把 `session_projcache.json` 视作易损介质。
