# .ko 可用性验证报告 (2026-09-09, 用户要求"联网确认")

结论: **之前的 v1 ko 不能加载, 已定位并修复; v2 ko 通过全部可离线验证的关卡**
v2: bin/ksu/kernelsu_gki209_v2.ko  sha256 386a0842d9a4db183c7d3f8a15128f0b72156dc784955fcac45c8306ea48e4c8

## 一、推翻的错误假设 (最重要)
之前计划: finit_module flags=3 (IGNORE_MODVERSIONS|IGNORE_VERMAGIC) 绕过校验.
**错** — 内核源码 (kernel/module.c) + 设备 config 实证:
- 设备 `# CONFIG_MODULE_FORCE_LOAD is not set` → try_to_force_load() 返回 -ENOEXEC
- check_modinfo(): 传 IGNORE_VERMAGIC → modmagic=NULL → try_to_force_load → **-ENOEXEC**
- check_version(): 传 IGNORE_MODVERSIONS → versindex=0 → try_to_force_load → **-ENOEXEC**
- 设备 `CONFIG_MODVERSIONS=y` → 每个导出符号都有 CRC, 模块必须自带匹配的 __versions
=> flags=3 在本设备上是**自杀选项**; 唯一可行路径 = vermagic 语义匹配 + CRC 逐符号匹配

## 二、修复方案 (已实施)
1. **真 vermagic**: 设备 = `5.10.209-android12-9-00019-g4ea09a298bb4-ab12292661 SMP preempt mod_unload modversions aarch64`
   (从内核镜像字符串实证). same_magic() 在模块有 __versions (has_crcs) 时**跳过第一段版本号**,
   只比较 ` SMP preempt mod_unload modversions aarch64` → 本 ko (5.10.245 + MODVERSIONS=y) 语义相等 ✓
2. **真 CRC**: 从设备内核镜像的 __ksymtab/__kcrctab 数组按符号索引提取 64 个 CRC,
   合成 Module.symvers 后重编 → 模块 __versions 64 条全部等于设备值 (0 mismatch)
   独立交叉验证: KSU 官方 v0.9.5 GKI 模块 (android12-5.10_kernelsu_v095.ko) 的 __versions
   与本设备提取值 **64/64 完全相同** → 证明提取正确 + GKI KMI CRC 稳定
3. **LSM 结构漂移修复**: 设备 5.10.209 vs 构建树 5.10.245 的 lsm_hook_defs.h 差 1 个 hook
   (upstream 实证: .209=236, .245=237, 新增 `file_ioctl_compat`) → 其后所有 hook 偏移 +8.
   已从构建树头文件删除该 hook → 12/12 hook 偏移与设备一致

## 三、逐项验证 (设备真值 vs 本 ko)
| 项目 | 设备真值(来源) | 本 ko | 结果 |
|---|---|---|---|
| task_struct.cred | 0x780 (getuid 反汇编) | 0x780 | ✓ |
| task_struct.real_cred | 0x778 (get_task_cred) | 0x778 | ✓ |
| task_struct.rcu_read_lock_nesting | 0x448 (rcu_read_lock 内联) | 0x448 | ✓ |
| task_struct.thread_pid | 0x630 (gettid) | 0x630 | ✓ |
| task_struct.mm | 0x518 (commit_creds) | 0x518 | ✓ |
| cred.uid / euid / egid | 0x4 / 0x14 / 0x18 (getuid/geteuid/getegid) | 同 | ✓ |
| security_hook_heads 12 项 | 0x138/0x190/0x1f0/0x230/0x238/0x258/0x260/0x290/0x2a0/0x380/0x308/0x2a8 | 同 | ✓ |
| lsm_blob_sizes.lbs_cred/lbs_file | 0x0 / 0x4 (selinux_file_alloc_security) | 同 | ✓ |
| selinux_state.enforcing | 0x0 (sel_read_enforce) | 0x0 | ✓ |
| 导入符号 | 63 个, 全部在设备 7179 导出表中 | 63/63 | ✓ |
| __versions CRC | 64 个设备值 | 64/64 相同 | ✓ |
| BTI/PAC | 设备 ARM64_BTI_KERNEL=y + PTR_AUTH=y | GNU note: BTI,PAC + paciasp/bti 序 | ✓ |
| SCS | SHADOW_CALL_STACK=y | 138 处 str x30,[x18] 序言 | ✓ |
| CFI | CFI_CLANG=y, PERMISSIVE=n | page-aligned __cfi_check 直通桩 (0x6000) | ✓ (见下) |
| 管理器 | v0.9.5 要求 KERNEL_SU_VERSION>=11648 | KSU_VERSION=11872, is_lkm=1 | ✓ |
| 模块签名 | CONFIG_MODULE_SIG not set | 无签名要求 | ✓ |

## 四、CFI 处理依据 (为什么加 __cfi_check 桩)
- kernel/cfi.c: cfi_slowpath_handler → find_check_fn(ptr) → shadow 未命中则用 `mod->cfi_check`;
  为 NULL → handle_cfi_failure() → panic (设备 CFI_PERMISSIVE=n)
- kernel/module.c: `mod->cfi_check = find_kallsyms_symbol_value(mod, "__cfi_check")`
- 本 ko 未用 LTO/CFI 编译 → 必须自带 __cfi_check; 桩是 page-aligned (add_module_to_shadow 要求),
  且直通放行 → 内核 CFI 插桩的间接调用 (LSM hook / kprobe handler / workqueue 回调) 可进入本模块
- 外部佐证 (看雪《把 .o 变成 .ko(三)》): 非 CFI 二进制被 CFI 插桩代码经函数指针调用 = CFI failure;
  GKI 严格限制导出符号 → 需 kallsyms 统一解析 (与本项目 resolver 做法一致)

## 五、装载流程 (修正版, 不再用 flags=3)
1. 推 ko: /data/local/tmp/kernelsu_gki209.ko
2. R 轮 (c-strike) 拿 root → E5v3 开 SELinux permissive 窗口
3. C 轮: PSELECT_KO=<ko> → finit_module(fd, "", 0)  ← flags=0 (CRC/vermagic 已匹配)
4. E5R 还原 enforcing
5. 判据: /proc/modules 含 ksu / dmesg "ksu: resolver ok" / 管理器转绿

## 六、剩余风险 (诚实清单)
1. selinux_state.avc(0x48)/policy(0x50) 未能在设备侧取到反汇编真值 — 仅用于 KSU sepolicy 功能,
   不影响 su/allowlist/prctl 主功能; 两树同为 android12-5.10 GKI, 结构应一致
2. resolver 运行时行为 (register_kprobe 引导 + 29 符号解析) 未在设备验证 — 已做硬失败保护
3. LSM hook 安装依赖 KSU 的扫描式 find_head_addr (布局无关) + 相对索引; 现已与设备偏移完全对齐
4. SELinux Enforcing 下装载仍需 permissive 窗口 (E5v3), 装载后立即还原
5. 装载后 KSU 自身钩子/工作队列行为需实测 (首个 root 窗口)
