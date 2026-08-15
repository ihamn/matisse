# CHECKPOINT R11 — 深度分析与测试计划

> 日期: 2026-07-16 11:47
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM

---

## 1. R10 崩溃根因诊断

### 发现：R10 从未部署
- `/data/local/tmp/preload.so` 的 SHA256 = `ce945969...` → 这是 R8!
- R10.so 的 SHA256 = `90ac1a40...` (110272 bytes) ≠ 部署文件的 108976 bytes
- **用户跑的 "R10_test1" 实际运行的是 R8**

### R10_test1 日志全 NULL 原因
- `logs/R10_test1.txt` — 2692 bytes 全是 0x00
- 连 `deploy.sh` 输出和 `preload starting` 都没有
- Shell pipe (`| tee`) 创建了文件，但在任何输出写入前内核 panic → 数据丢失
- 磁盘可能在 panic 时处于不一致状态 → 文件系统 metadata 残留 2692 bytes

---

## 2. GhostLock 读原语崩溃分析 (R8_test4)

### 成功部分
```
[+] direct-w64[0] target=ffffff80028a77d0 value=ffffffc00a78a590 shape=0 workspace=ffffff80734b8000
```
- GhostLock 写原语**成功触发**！
- prepare=272, bruteforce 成功, leaked=ffffff80734be180

### 崩溃部分
R8_test4 在 `direct-w64[0]` 打印后立即内核 panic。

**崩溃机制分析**:
1. shape=0 的 GhostLock 读原语通过 rb_erase 写入 `child` (=node->rb_right=0) 到 `parent->rb_left/right`
2. parent = value = `percpu_slot` (= PER_CPU_OFFSET + 7*8)
3. 写入目标: `percpu_slot + 0x08` 或 `percpu_slot + 0x10`
4. 这**破坏 per-CPU offset 表** → 内核 panic

per-CPU offset 表的每一项是 CPU 的 per-CPU 数据偏移量。写 0 进去意味着该 CPU 的 per-CPU 变量访问全部指向错误地址 → 立即 panic。

### 为什么 slide 路径不崩
slide.c 的 GhostLock 写到 `SLIDE_LOGGERS_0_1` (logger 结构)，不是关键数据 → 不崩。

### 为什么 R8_test4 的 GhostLock 能触发但后续崩
pselect 内部的 GhostLock type confusion + rb_erase **成功执行了写操作**，
但写入破坏了关键内核数据 → panic 发生在 pselect 返回前。

---

## 3. R11 修复详解

### 修复 A: Page Holder 隔离 (同 R10)
- 父进程 fork page holder 子进程做 prepare
- 543 clone + bruteforce 在子进程中隔离 — 子进程崩不影响父进程
- 但如果是**内核 panic**（不是进程崩），整机重启，隔离无效

### 修复 B: fflush + 超时 (R11 新增)
- page holder fork 前后添加 `fflush(stdout)` — 确保日志落盘
- pipe read 添加 120s 超时 — 防止 holder 卡死导致父进程永久阻塞
- 更详细的错误消息 (addrs[0] 值, n 返回值)

### 修复 C: DIRECT_PCPU_DELTA 逃生舱 (R11 新增)
- 环境变量 `DIRECT_PCPU_DELTA=0xXXXX` 跳过 GhostLock shape=0 读
- 直接使用硬编码的 per-CPU delta → 完全避免最危险的读原语
- 仍需要 GhostLock 读 `entry_task` (从 entry_slot 读 task_struct 指针)
  - 但这个读的目标是 entry_slot (= direct-map 地址)，不破坏 per-CPU 表

### 修复 D: FOPS reprepare 加固 (R11 新增)
- page holder 中调用 `prepare_skb_payload(page_base, PAGE_PAYLOAD_FOPS)`
- write child 中 reuse 路径也调用一次
- 这是安全 no-op（globals 值相同），但确保与 R8 成功路径一致

---

## 4. DIRECT_PCPU_DELTA 值探索

### 已知信息
- `percpu_slot` = PER_CPU_OFFSET + 7*8 = 0xffffffc00a78a590
- 该地址存储 CPU7 的 per-CPU delta (u64)
- delta 必须页对齐 (delta & 0xFFF == 0)
- entry_slot = ENTRY_TASK + delta 必须在 direct map 中

### 如何确定 delta
| 方法 | 难度 | 说明 |
|------|------|------|
| R11 GhostLock 读成功 | 看运气 | 如果凑巧不崩，delta 会打印在日志 |
| 内核镜像分析 | 中 | 从 kernel.Image 找 __per_cpu_offset 符号 |
| /proc/kallsyms | 需root | 已有 root 就可以直接读 |
| 暴力尝试 | 高 | 试多个页对齐值，看哪个不崩 |
| R8_test4 日志 | 已失败 | GhostLock 触发但 panic 前 delta 未打印 |

### rough 估算
ARM64 per-CPU offset 近似值：delta ≈ `DIRECT_MAP_BASE - KIMAGE_TEXT_BASE + small_offset`
= `0xffffff8000000000 - 0xffffffc008000000 + X`
= 大数绕回后的值...

如果能通过内核符号确定 `__per_cpu_start` 和 `__per_cpu_load`:
```
delta[0] = __per_cpu_start - __per_cpu_load + pcpu_unit_offsets[0]
delta[7] = delta[0] + 7 * PERCPU_UNIT_SIZE
```

---

## 5. 测试计划

### Phase 1: R11_test1 (无 DIRECT_PCPU_DELTA)
```bash
# rish 内:
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R11_test1.txt
```
- **预期**: page holder prepare 成功 → direct-fusion holder page OK → GhostLock 读 per-CPU offset
- **风险**: GhostLock 读可能崩 (同 R8_test4)
- 如果成功 → 日志中会打印 delta 值 → 保存下来用于后续硬编码

### Phase 2: R11_test2 (如果 test1 崩了)
用 test1 中打印的 delta 值，或者尝试猜测值:
```bash
DIRECT_PCPU_DELTA=0x... LD_PRELOAD=... /system/bin/sleep 10 2>&1 | tee .../R11_test2.txt
```
- 跳过 per-CPU offset 读 → 直接读 entry_task → 然后写 cred

### 手机状态要求
- ★ 必须在 rish 内运行（uid=2000 shell, 非 Termux/untrusted_app）
- 重启后最多测 2 次
- 测试前关闭自动息屏
- 测试期间不要切后台/开视频小窗

---

## 6. 成功标志

```
direct-fusion: holder pid=XXX page OK base=XXXX lock=XXXX w0=XXXX task=XXXX reuse=1  ← page holder 成功
direct-percpu ... delta=XXXX ...                                                     ← per-CPU leak 成功
direct-entry ... task=XXXX ...                                                       ← task leak 成功
direct credential result uid=0 euid=0 ...                                            ← cred 覆盖成功
direct-root-summary root=1 ...                                                       ← 最终成功！
```
