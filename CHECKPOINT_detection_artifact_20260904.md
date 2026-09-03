# C 阶段悖论解：检测通道致盲假象（2026-09-04 静态分析）

> 推翻 `CHECKPOINT_C_stage_paradox_20260901.md` 的"C 写不落地"结论：
> **C 阶段（写 task+0x780 cred）的写入一直在成功落地。所有"0/N 失败"都是
> 检测通道在成功瞬间被 SELinux 致盲造成的假象。**

## 证据链

1. **off788 vs off778b 子进程存活对照**（决定性）：
   - off788（写 comm@0x790，cred 完好）：心跳 poll 50/100/150，存活 30s+，comm 污染可见。
   - off778b（写 cred@0x780）：零心跳。差异不是"写没写"，而是**写到了哪个槽**。
2. **task+0x780 全内核写入者只有 4 个**（find_offset_access.py 扫描）：
   `exit_creds`（死亡）、`copy_creds`（fork）、`commit_creds`（set*uid）、
   `call_usermodehelper_exec_async`（umh 专用）。**睡眠子进程没有任何回滚路径**
   → H3"写后被中和"不成立 → 只剩"写落地 + 检测致盲"。
3. **致盲机制**：cred=init_cred 别名 → 子进程 SELinux SID = kernel
   （init_cred->security），enforcing=1 下 kernel 域被策略拒绝几乎所有文件操作：
   - `open(mt49_child_status.txt)` EACCES → status 冻结在落地前最后一次轮询（euid=2000）
   - 心跳 pr_info → stdout 写 .out 文件被拒 → **零心跳（活着但哑）**
   - 子进程 `fopen("/proc/self/status")` 被拒 → CapEff 读不到 → STRICT gate 永不触发
4. **时间线吻合**：子进程从 t=0 就 200ms 轮询（"blocking-for-cred-write" 只是标签，
   实际立即进循环）；风暴 t=50-175ms 落写；此后 getresuid 返回 euid=0 但所有
   文件输出被拒。最终 status = t=0 的快照 euid=2000。
5. **R 轮一切正常的原因**：SELinux 钩子用 `current_cred()`（主观 cred@0x780）；
   R 只换 real_cred → SID 仍是 shell → 文件照常写。/proc/self/status CapEff 读
   `__task_cred`=real_cred → 显示满帽。R 的两条检测通道都不受影响。
6. **mt71 Cfork "10s 内死亡"**：旧 OR-gate 在 euid==0（半程即真）触发 setresgid →
   commit_creds 入口 `BUG_ON(task->cred != task->real_cred)` → brk#0x800 → oops
   杀任务。STRICT 门控下是"哑而不死"。
7. **E4a 成功判据结构性永不可见**：写落地→致盲→status 停在 euid=2000；不落地→
   同样 2000。E4a"失败"极可能是成功。**E4b 同病**：R-child 的 CapEff 读取在 E4
   落地瞬间失效 → gate 永不触发 → root_alive.txt 永不出现，即使两写都落地。

## 零成本现场验证（下次进机第一件事）

```sh
# C 轮跑完后（或现在，如果 dmesg 还没滚掉）：
dmesg | grep avc | grep -w kernel | tail
# 出现 kernel 域对 shell_data_file/proc 的 denied → C 写已落地的直接铁证
```

## mt73 检测重造（代码 TODO）

原则：**一切成功信号必须走不依赖 cred 文件权限的通道**。

1. gate 改 sticky：CapEff 满帽在致盲前记录（sticky flag），之后仅凭
   `getresuid()==0`（syscall，永远可用）判 E4 落地。
2. 落地后信号通道（无文件 I/O）：
   - `kill(getppid(), SIGUSR1)` — CAP_KILL 来自 init_cred，越过 uid 不匹配；
   - `sethostname("glroot")` — CAP_SYS_ADMIN，从外部 `cat /proc/sys/kernel/hostname` 可见。
   父进程（正常 cred）负责写 marker 文件。
3. root 落地路径：两写都落地后 `cred==real_cred==init_cred` → setresgid/setresuid
   的 BUG_ON 通过 → commit_creds 私有拷贝 → uid 0 + 满帽。**注意 SID 仍是 kernel**
   （prepare_creds 拷贝 security 字段）→ root 后文件操作仍被 SELinux 拒 →
   后续 su_daemon 落地需要 enforce 零写或 context 切换配合（原计划不变，只是
   现在知道"成功"长什么样了）。
4. 外部观测：R+E4 后从 shell 读 `/proc/<R-child>/status` → Uid: 0 0 0
   （real_cred 已是 uid-0 私有 cred）→ 干净的外部铁证。

## 复盘一句话

R 检测读 real_cred + 主观 SID 未变 → 双通道都活着；C 检测读主观 cred + 主观 SID
变成 kernel → 双通道同时致盲。"7/7 vs 0/N"从来不是写入几何的差异，是**检测几何**
的差异。off788 comm 污染之所以"可见"，恰恰因为 comm 写不碰 cred —— 检测通道活着。
