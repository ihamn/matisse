# CHECKPOINT R7 — 崩溃根因确诊 & R8 方案

> 时间: 2026-07-16 03:29 (R7_test1) + 后续分析
> 结论: **R7 二进制没重新编译 — R2 事件的精确重演**

---

## R7_test1 发生了什么

### 输出 (90 行，末尾 NUL 字节 → 重启)
```
uid=2000 attr=u:r:shell:s0        ← Shizuku ✅
prepare: phase1 cloneA prepare=200 spray=150  ← 🔴 关键线索！
prepare: phase5 bruteforce failed × 5
kernel page retry 1/5 mode=1      ← 🔴 retry=5，不是源码写的1
...再重复 5 次 bruteforce 失败...
→ 日志末尾 0x00 字节 → 内核 slab 耗尽 → 重启
```

### 铁证：二进制 ≠ 源码

| 参数 | R7 源码 (common.h) | R7 二进制实际 | 判定 |
|------|-------------------|-------------|------|
| prepare clone 数 | 272 (MM_STRUCT_SZ=0x3C0) | **200** (MM_STRUCT_SZ=0x500) | ❌ |
| max_attempts | 1 | **5** | ❌ |
| mm_objs_per_slab | 34 (=272/8) | **25** (=200/8) | ❌ |

### 验证计算
```
ORDER3_SIZE = 32KB = 32768 bytes
prepare = 8 × mm_objs_per_slab

v25 (成功): 32768 / 0x3C0(960) = 34.13 → floor=34
  → prepare = 8×34 = 272 ✅ 和日志一致

R7 (失败): 32768 / 0x500(1280) = 25.6 → floor=25
  → prepare = 8×25 = 200 ✅ 和日志一致

R7 源码写的是 MM_STRUCT_SZ=0x3C0，但编译出来的是 0x500。
make clean 没做/没生效。和 R2=R1 一模一样的错误。
```

---

## v 系列 vs R 系列路线对比

### v 系列 (v1-v30): rb_erase → fops → configfs → pipe → root ☠️
```
GhostLock UAF → rb_erase type confusion → 覆写 ashmem fops
  → configfs 内核读写 → pipe physrw → cred 覆写 → root
```
死因: MTK 5.10 rb_erase csel `parent->rb_left == node` 永远失败
→ 写不到 fops(0x10)，只写到 name_ptr(0x08)
→ 30个版本验证，确认关闭。

### R 系列: Direct Write — GhostLock 作为读写原语 ✅
```
GhostLock UAF → pselect 竞态 → 直接读写内核内存 → root
```
| 原语 | v 系列 | R 系列 |
|------|--------|--------|
| 内核读 | 无 (需 fops→configfs) | GhostLock + boot_id oracle |
| 内核写 | rb_erase (偏移受限) | GhostLock pselect (任意8字节) |
| 链长 | 4 步 | 2 步 |
| fops依赖 | 必须覆写 | 完全不需要 |

### R 系列完整攻击流
```
1. fork → prepare_good_kernel_page(SLIDE) — 喷 SKB payload
2. GhostLock PI chain (waiter+owner+consumer)
3. GhostLock 读 per_cpu_offset (boot_id oracle)
4. 推导 __entry_task = ENTRY_TASK + per_cpu_offset
5. GhostLock 读 entry_task → task_struct 地址
6. GhostLock 写 init_cred → task->real_cred (0x818)
7. GhostLock 写 init_cred + selinux=0 → task->cred (0x820)
8. SELinux policy 重载 → permissive
9. 安装 su daemon → root ✅
```

---

## R8 修复方案

### 源码已正确，只需真正编译

| # | 文件 | 值 | 原因 |
|---|------|-----|------|
| 1 | common.h | MM_STRUCT_SZ=0x3C0 | v25 验证正确 |
| 2 | common.h | SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS=1 | 杜绝重试 slab 耗尽 |
| 3 | main.c | DIRECT_WRITE_ATTEMPTS=1 | 杜绝外层重试 |

### 编译验证清单（必须逐条过！）
```
[ ] rm -rf build/
[ ] make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
[ ] SHA256 ≠ ce945969 (R7) ≠ e2289c64 (R6)
[ ] ★★★ 运行后 prepare 必须 = 272 (不是 200!) ★★★
```

### 成功标志
```
prepare=272 spray=204    ← MM_STRUCT_SZ=0x3C0
kernel page retry 1/1    ← retry=1
phase6 leaked=...        ← 必须出现！
direct-root-summary root=1
```

## 历史教训

| 版本 | 问题 | 教训 |
|------|------|------|
| R2=R1 | SHA256 相同 | 编译后先验证 SHA256 |
| R3=R1 | 源码从没改过 | 改文件≠改内容 |
| R7≠源码 | build 目录未清理 | **rm -rf build/ 比 make clean 可靠** |
