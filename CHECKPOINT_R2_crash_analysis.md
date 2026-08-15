# CHECKPOINT R2 — 崩溃分析 & R3 路线

> 时间: 2026-07-16 01:10 (分析 R2_test1 崩溃后)
> 上一个: R1_test4 (20s 重启，0 字节)
> 下一个: R3 (真正重新编译)

---

## R2_test1 发生了什么

### 输出 (仅 5 行, 234 字节)
```
[+] preload starting pid=28781
[+] runtime performance cpu=7 max_freq=3050000 capacity=1024
[+] startup pid=28781 uid=2000 attr=u:r:shell:s0 enforce=1 direct_cpu=7
[-] kernel page retry 1/12 mode=1
```
→ 1m59s 后手机重启，无更多输出。

### 崩溃位置
- `preload.c::load()` → `run_exploit()` 正常进入
- `init_direct_root_cpu()` → CPU7 (prime core, 3050MHz) ✅
- `log_startup_context()` → uid=2000 shell ✅
- `slide_leak_kernel_base()` → `prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE)`
- `prepare_kernel_page()` 第 1 次尝试失败 → `kernel page retry 1/12 mode=1`
- 第 2 次 retry 期间手机重启

### ⚡⚡ 关键发现：R2 = R1 (未重新编译！)
```
preload_mtk_R1.so  SHA256: 017fb8a67a6aecd7a7c6ad1f94c73ca9ca97d6cfa332a2168614a614fdac2b9c
preload_mtk_R2.so  SHA256: 017fb8a67a6aecd7a7c6ad1f94c73ca9ca97d6cfa332a2168614a614fdac2b9c
build/.../preload.so SHA256: 017fb8a67a6aecd7a7c6ad1f94c73ca9ca97d6cfa332a2168614a614fdac2b9c
```
三个文件完全相同。`make clean && make` 从未执行。

### 崩溃根因
1. **未真正编译** — R2 只是 R1 的副本
2. **连续测试耗尽 slab** — R1_test1→2→3→4→R2_test1，prepare_kernel_page 每次 clone 500+ 子进程
3. **MTK 5.10 内核的 slab 回收不积极** — 已有先例 (v26 首次重启)

---

## R3 行动计划

1. ✅ 手机已重启
2. **先开原神 2 分钟** → 极端内存压力触发 slab shrinker
3. **保持原神后台存活**
4. **真·编译 R3:**
   ```
   cd CyberMeowfia/IonStack/CVE-2026-43499/exploit
   make clean && make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
   ```
5. **★ 验证 SHA256 必须变化:**
   ```
   sha256sum build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so
   # 必须 ≠ 017fb8a67a6a...
   ```
6. **验证代码路径:**
   ```
   strings build/.../preload.so | grep -E 'direct mode|direct-root-summary'
   # 必须有输出！
   ```
7. **部署 R3:**
   ```
   cp .../preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_R3.so
   # 通过 rish 部署到 /data/local/tmp/
   ```
8. **只跑一次！**
9. **立刻 tee 日志 + 更新本文档**

### 长期建议（源码改动）
- `SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS` 从 12 降到 4
- 每次 retry 之间 `sleep(2)`

---

## ⚡ 追记 (2026-07-16 01:20): R3 编译完成

**真相修正：**
- `make clean && make` 后 SHA256 仍为 017fb8a6a...
- 这说明**源码从始至终没变过！R1=R2=R3 都是同一个正确编译**
- 之前"源码/二进制不匹配"的诊断是**误判** — 被 R1_test2/3 的 rish 命名空间污染误导了

**真正的崩溃原因只有两个：**
1. R1_test2/3 → 跑的是 rish 里残留的 v 系列旧 .so（SHA256:7d16b26d）
2. R1_test4 / R2_test1 → 正确的二进制，但 slab 耗尽 → 重启

**R3 待跑，环境条件:**
- 手机刚重启 ✅
- 建议先开原神压 slab ⏳
- 部署到 /data/local/tmp/ ⏳
