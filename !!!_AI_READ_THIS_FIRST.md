# ⚡ AI 恢复工作上下文 — CVE-2026-43499 GhostLock matisse 利用

> 最后更新: 2026-07-16 (★ v34 已编译已部署，待测试！Selinux直写路线)
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM / MTK 5.10.209

---

## 🆘 TERMUX 环境警告 — AI 必读！

**Termux 极易弹退/卡死/闪退！以下铁律必须遵守：**

1. **运行任何 .so 之前，必须留档！** — 把当前状态写入本文档，确保可恢复
2. **运行 .so 之后，立刻记录结果！** — 不要等分析完再写，先存 raw output 到 `logs/RXX_testN.txt`
3. **AI 收到「继续/测试」指令时，先自检：** 状态文档最新吗？上次结果存档了吗？没有就先补文档
4. **测试前确保不自动息屏**（设置→显示→休眠→10分钟/永不休眠）
5. **测试期间不要开视频小窗、不要切后台** → 极大概率卡死
6. ⚠️ **★ 编译新版本后必须验证 SHA256 不同！** `make` 完立刻 `sha256sum`，禁止改名冒充新版
7. ⚠️ **★ 每次手机重启后最多跑 2 次测试！** MTK slab 扛不住连续折腾；第三个必崩
8. ⚠️ **★ 部署后必须验证哈希！** `cp` 到 `/data/local/tmp/` 后立刻 `sha256sum` 对比源文件，不一致绝不运行！

---

## 当前状态 ★★ v33 — canon_addr 修复版 (2026-07-16)

### v32 崩溃 — 根因已定位 ✅

v32 部署后运行 → 手机 **重启** (kernel panic)。根因审计:

**`canon_addr()` 从未做 direct-map 转换！** (util.c:216)

```c
uintptr_t canon_addr(uintptr_t image_addr) {
  return kaslr_image_addr(image_addr);  // KASLR=0 → 恒等变换!
}
```

KASLR=0 时 `kaslr_image_addr` = 恒等变换 → `canon_addr(ASHMEM_MISC_FOPS)` 返回 **text 段地址** `0xffffffc00a8e76e8`，不是 direct-map `0xffffff80028e76e8`。

GhostLock/kernelsnitch 的 identity mapping 只覆盖 direct-map 范围 (`0xffffff8000000000` - `0xffffff9000000000`)。text 地址不在此范围 → 写入错误的物理页 → kernel panic。

### v33 — 修复 canon_addr (util.c)

```c
uintptr_t canon_addr(uintptr_t image_addr) {
  return P0_DATA_ALIAS_CONST(kaslr_image_addr(image_addr));
}
// P0_DATA_ALIAS_CONST = P0_PAGE_OFFSET | (addr - KIMAGE_TEXT_BASE + P0_KERNEL_PHYS_DELTA)
// P0_KERNEL_PHYS_DELTA = 0 (P0_KERNEL_PHYS_LOAD 0x80000000 == P0_PHYS_OFFSET 0x80000000)
```

验证: ASHMEM_MISC_FOPS (`0xffffffc00a8e76e8`) → `0xffffff80028e76e8` ✅

### v33 编译信息 (2026-07-16 ~13:09) — 已分析，未测试
- 文件: `preload_mtk_v33.so` (105216 bytes)
- SHA256: `b0b8183e25bc5bf0ea4698181440c84250819bde5606d5bcc59f2096fec187f6`
- 修改: util.c:216 `canon_addr` → 加入 `P0_DATA_ALIAS_CONST` 转换
- 🚨 **v33 fops.c word映射错误！** prio/deadline 插在 rb_node 之间，
  导致内核把 page_base+FOPS_OFF 当 task_struct* 解引用 → kernel panic
- 当前代码是 poplicle fork (从 /tmp 丢失后重建)，不是 fusion_release

### ★ v30 重测 (2026-07-16 晚) — 刚完成 ✅
- 部署: `bin_v_archive/preload_mtk_v30.so` SHA256=7d16b26d ✅
- 结果: attempt1 ret=193 calls=1 success=1 → GhostLock 强触发
  FOPS 始终=0 (rb_erase csel 永远写 name_ptr，不写 FOPS)
  手机没崩！v30 架构稳定
- 日志: `logs/v30_retest.txt`

### ★ 代码库审计发现 (2026-07-16 晚)
- **CyberMeowfia/.../src/ 是 poplicle fork** — fops.c word映射坏了，只有 run_fops_stage
- **fusion_release/src/ 是真正的 R 系列** — 有 run_direct_root_stage (cred/selinux直写)
  但 fusion_release 的 fops.c word映射也是同一套坏的布局！
  R9 (fusion) 父进程直接 prepare → 崩。R10 fork page holder → 未部署
- **v30 的 .bak_v30/ 是正确的源码** — fops.c word映射正确，架构稳定不崩
- 自 v30 后每代都在崩：v31 SIGSEGV、v32 kernel panic、v33 未测但 word映射必有 bug、R9 父进程崩

### v32 崩溃 — 已存档
- v32 二进制: `preload_mtk_v32.so` SHA256=cb79a34c
- 崩溃记录: 手机直接重启, 无日志 (kernel panic 太快)
- 分析: `CHECKPOINT_v32_crash_analysis.md`

### v31 回顾 — 失败原因已定位

v31_test1: 子进程 SIGSEGV (status=0xb), GhostLock 未触发.
v31_test2: slab 耗尽, 直接重启.

**根因**: v31 二进制从 poplicle fork (/tmp) 编译, 源码已丢失。该 fork:
- fops.c 用 `fake_task` (喷的 slab 页) 而非 `init_task` → SIGSEGV
- main.c 用 `ASHMEM_MISC_FOPS` (image 地址) 而非 `canon_addr(ASHMEM_MISC_FOPS)`

v 系列 (v25_pi) shape=1 "失败" 真相: tree_pc=0 禁用了 tree_entry 路径, pi_parent=FOPS-8|RED 放在 pi_tree_entry 侧但内核永不 erase pi_tree_entry. GhostLock 触发了 (calls=1 success=1) 但没有 rb_erase 执行 → 零写入.

---

## ★ 历史状态存档 ★

### R11 Page Holder 强化版 (2026-07-16 ~11:47) ★ NEW
- R10 从未部署 → R11 已正确部署并验证哈希
- 修复: fflush, pipe timeout, DIRECT_PCPU_DELTA escape hatch, FOPS reprepare
- 文件: `preload_mtk_R11.so` (111368 bytes) SHA256=8319656a
- 已部署到 /data/local/tmp/preload.so ✅

### R10 原版 (2026-07-16 ~10:30)
- 修复: main.c 父进程 prepare 改为 fork page holder 子进程 + pipe 传回地址
- 编译: 0 错误 0 警告, SHA256=90ac1a40
- **未部署** — /data/local/tmp 仍是 R8

### R9 融合版 (2026-07-16 10:10) — 已废弃
- 父进程直接 prepare → 内核 panic → 手机重启 (40s)

### R8_test4 — 历史性突破！R 系列首次 bruteforce 成功！
- R8_test4 (rish, uid=2000 shell): **phase6 leaked=ffffff80734be180** ← 首次！
- direct-w64[0] 成功触发：target=ffffff80028a77d0 value=ffffffc00a78a590
- GhostLock 触发成功，但 pselect 期间内核 panic → 重启
- 原因: GhostLock shape=0 读原语写 0 到 percpu_slot 区域 → 破坏 per-CPU offset 表 → panic

### R8_test2~3 — bruteforce 失败 (2026-07-16 04:46~05:33, Termux 直跑)
- 原因：从 Termux (untrusted_app_27) 直接跑，非 rish shell

### ⚡ R8 崩溃根因：Shizuku cp 写入全零文件！

## 版本速查

| 位置 | 说明 |
|------|------|
| `bin_v_archive/preload_mtk_v30.so` | v 系列终版 (163KB), rb_erase 死路 |
| `preload_mtk_R8.so` | R8 ce945969 (108976B) — R8_test4 GhostLock触发成功但panic |
| `preload_mtk_R9.so` | R9 bf8d6d35 — 父进程崩(已废弃) |
| `preload_mtk_R10.so` | R10 90ac1a40 — 未部署(已废弃) |
| **`preload_mtk_R11.so`** | **R11 8319656a ★ 已部署到 /data/local/tmp — 待测试** |

## 关键地址 (不变)
```
KIMAGE_TEXT_BASE: 0xffffffc008000000
ASHMEM_MISC_OFF:  0xffffff80028e76d8
PER_CPU_OFFSET:   KIMAGE_TEXT_BASE + 0x278a558
ENTRY_TASK:       KIMAGE_TEXT_BASE + 0x27562f8
INIT_CRED:        KIMAGE_TEXT_BASE + 0x27b0ae0
SELINUX_ENFORCING:KIMAGE_TEXT_BASE + 0x2a41b99
```

## 编译
```
cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
rm -rf build/ && make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
cp build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_RXX.so
```
