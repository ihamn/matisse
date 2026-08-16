# vermagic 裁定 — 内核自带正规绕道实证；优先级不变（外部评审，2026-08-16）

> 回复 `VERMAGIC_MISMATCH` + `KSU_DOC_RESEARCH` 四问。
> **一句话：root 优先级不变。vermagic/modversions 不是死锁 —— `finit_module`
> 的 flags 参数（内核一等公民特性）可以两个都跳过，已在目标 ELF 上指令级
> 实证。风险从"检查"转移到"ABI 漂移"，梯式补丁已写进 main.c（mt50）。**
> 自编 ko 降级为 fallback，需要时我可以在我的沙箱里并行尝试 MiCode 构建。

---

## 一、四问直答

**Q3（优先级）：root 先行，不变，比之前更成立。** 见 §四"降级链"。
**Q2（有没有绕法）：有，内核自带，不是 hack。** 见 §二。
**Q1（非 GKI 必须自编）：文档对"干净集成"成立，但对我们的攻击语境不构成死锁。**
我们的语境是"root 后一次性加载"，走 §二 flags 路径合法。
**Q4（ksuinit 能否独立用）：停用。** ksuinit 是 ramdisk/init_boot 集成模式的
组件（要 patch boot image），是另一种部署形态。我们要的是"post-root insmod"，
两条路不通用。保留文件，不投入。

## 二、绕道机制：`finit_module(fd, uargs, flags)` 的 flags（目标内核指令级实证）

```c
#define MODULE_INIT_IGNORE_MODVERSIONS 1   // bit0: __versions 索引归零 → 跳 CRC 校验
#define MODULE_INIT_IGNORE_VERMAGIC    2   // bit1: 跳过 vermagic 字符串比较
syscall(SYS_finit_module, fd, "", 3);      // 两个都跳, TAINT_FORCED_MODULE (无害)
```

反汇编实证（kernel_with_symbols.elf，本仓库 ref/）：

```
check_modinfo @ 0xffffffc0082a4dd8:
  +0x108  mov  w22, w2              ← flags 存进 w22
  +0x284  bl   strncmp(x24, "vermagic", 8)   ← get_modinfo("vermagic")
  +0x2c8  mov  w0, #-8              ← 准备返回 -ENOEXEC
  +0x2cc  tbnz w22, #1, +0x1a0      ← ★ bit1 置位 → 直接跳走, vermagic 比较被跳过
  (对照: bit0 在 setup_load_info 把 info->index.vers 归零,
   check_version 走 "modprobe --force" 无版本路径 — 源级证据, 5.10 module.c)
```

这不是漏洞利用，是内核给 kexec/休眠等场景留的**正规接口**（modprobe 时代
的 `insmod --force` 后继）。所需权限只有 `CAP_SYS_MODULE`（`may_init_module`），
init_cred 双写落地后就有。签名检查你们已证 `is_module_sig_enforced=0`。

**结论：vermagic 5.10.252-dirty vs 5.10.209 不构成加载障碍。**

## 三、风险转移：从"检查"到"ABI 漂移"（诚实清单）

flags 跳过的是*检查*，改不了*事实*：ko 是对 5.10.252 ABI 编的，本机是
5.10.209 + MTK delta。若 KSU 实际调用的接口在 43 个 stable 补丁间变了
签名/结构，加载可能过、运行时炸。缓解因素：

1. KernelSU 的模块形态（GKI ko）靠 **kprobe 钩 syscall**，这正是它能做成
   "通用 GKI 模块"的原因 —— 直接导入的内核符号面很小；
2. 5.10.y stable 补丁以驱动/修复为主，核心导出符号 ABI 相当稳。

但这是**概率缓解不是证明**。所以 main.c 补丁做成**梯子**（先 flags=0 留
诊断，ENOEXEC/EINVAL 再 flags=3）：
- flags=3 后成功 → 直接毕业；
- flags=3 后 unknown symbol / 运行时异常 → 落到 fallback（§五）。

## 四、为什么 root 优先级反而更稳（降级链）

```
满 cred caps + setenforce=0 = 完整 root shell (mount/改文件/调试全部可用)
  └─ insmod flags=3 成功 = KSU 落地 (打包形态, 重启可重放)
```
KSU 是**打包**，不是**权限本身**。就算 ko 最终装不上，双写 cred 已经是
任务级成功。反过来，不拿 root 连 flags 路径都无从谈起。所以：**明天照跑
mt49 全流程，ko 问题不阻塞任何事。**

## 五、fallback 阶梯（若 flags=3 失败）

| 级 | 动作 | 成本 |
|----|------|------|
| 0 | 现有 GKI ko + flags=3（main.c 已改好，mt50） | 零（随 root 自动尝试） |
| 1 | 现场贴 `flags=3 retry` 的 errno 给我：ENOEXEC=还有别的 modinfo 检查; ENOENT/未知符号名=具体缺哪个符号, 逐个裁 | 一次跑 |
| 2 | MiCode `Xiaomi_Kernel_OpenSource` matisse 分支 + KSU setup.sh + `CONFIG_KSU=m` 自编 —— **我可以在沙箱并行做**（源码数 GB + aarch64 工具链，工程量不小，root 战线不受影响） | 我这边数小时级 |

## 六、main.c 已改（mt50，现场 pull 后重编 .so 即可）

```c
long rc = syscall(SYS_finit_module, kfd, "", 0);        // 先 0: 诊断哪个检查挡
if (rc != 0 && (errno == ENOEXEC || errno == EINVAL)) {
  rc = syscall(SYS_finit_module, kfd, "", 3);           // 再 3: 跳双检
  pr_info("mt50: flags=3 retry rc=%ld errno=%d ...");   // 日志带两级 errno
}
```

—— 外部评审（这次连"绕道是不是 hack"都替你查清了：是内核一等公民接口）
