# ★ 2026-09-09 01:1x 重大突破: 设备内核 = GKI (不是 MTK vendor 树) + GKI 版 kernelsu.ko 编译成功

## 1. 关键发现: 设备内核是 GKI, 不是 matisse vendor 树
证据 (从设备内核 ELF 内嵌 IKCFG 提取的真实 config, 离线完成):
- 内嵌 config 在 ~/matisse/ref/kernel_with_symbols.elf 偏移 27476960 (IKCFG_ST) ~ 27516479 (IKCFG_ED)
- 提取命令: tail -c +27476969 kernel_with_symbols.elf | head -c 39511 | zcat > device_config.txt
- 结果: 6724 行, "Linux/arm64 5.10.209 Kernel Configuration"
- CONFIG_GKI_HIDDEN_* / ANDROID_VENDOR_OEM_DATA / ANDROID_KABI_RESERVE / LTO_CLANG_FULL / CFI_CLANG / SHADOW_CALL_STACK → **GKI 内核**
- CONFIG_MTK_* 只有 1 个 (CONFIG_MTK_TIMER), 而 matisse_defconfig 有 255 个 → 设备内核不是 vendor 树编出来的
- ⇒ vendor 5.10.81 树 (kernel_src) 作为构建基线是错的 (布局差异巨大)

## 2. 致命 config 漂移 (之前 vendor 树构建的 ko 因此不可加载)
| 选项 | 设备 | vendor 树 .config |
|---|---|---|
| CONFIG_PREEMPT | y (PREEMPTION/PREEMPT_RCU/PREEMPT_COUNT 全 y) | PREEMPT_NONE |
| CONFIG_PSI | y | not set |
| CONFIG_MEMCG | y | ... |
| CONFIG_MODVERSIONS | y | not set |
| CONFIG_CFI_CLANG | y (+SHADOW, PERMISSIVE=n) | not set |
| CONFIG_SHADOW_CALL_STACK | y | not set |
task_struct 里 PREEMPT_RCU/PSI/MEMCG/TASKS_RCU 各带字段 → 偏移差几百字节 → 直接加载必崩.

## 3. 新 ko: 构建与验证
- 树: ~/ksu_build/gki209 (common209.tar.gz = android_kernel_common_android12-5.10-mahiro-5-rose_r02, 实际 5.10.245)
- 精简解压 (94M): 只取 include/kernel/mm/security/crypto/lib/block/init/ipc/virt/scripts/arch-arm64
  + 排除目录的 Kconfig*/Makefile/*.h + arch/arm/vdso (vdso_prepare 需要)
- .config = 设备真实 config, 仅改: MODVERSIONS=n (免 genksyms, 加载用 flags=3), LTO/CFI=n, DEBUG_INFO=n
- 主机工具 (Bionic 修补): scripts/Makefile 去 recordmcount/sorttable; confdata.c bcmp→memcmp;
  modpost.h 补 ELF32/64_ST_TYPE/BIND; selinux/genheaders 用预编译; scripts/selinux 去 mdp;
  scripts/Makefile 去 asn1_compiler/sign-file/extract-cert/insert-sys-cert
- KSU v0.9.5 driver → drivers/kernelsu, CONFIG_KSU=m
- resolver.c (新写): 29 个 GKI 未导出符号本地强定义 + kprobe 引导 kallsyms_lookup_name,
  **硬失败**: 任一必需符号解析不到 → 返回 -ENOENT 中止加载 (不再静默跳过)
- cfi_stub.c (新写): page-aligned __cfi_check 直通桩 → mod->cfi_check 非空 → CFI shadow 放行
  (设备 CFI_PERMISSIVE=n, 否则间接调用进模块 = panic)
- 产物: bin/ksu/kernelsu_gki209_v1.ko (148448B)
  sha256 2ba4f004a3b632cbe38a3856fa4a9213dca729c62adb4d713783dae04f2a9516
  vermagic 5.10.245 SMP preempt mod_unload aarch64 (设备 5.10.209 → 加载必须 flags=3)

### 布局验证 (设备反汇编铁证 vs 本树 offsetof 探针) — 全部命中
| 字段 | 设备真值(来源) | 本 ko |
|---|---|---|
| task_struct.cred | 0x780 (getuid) | 0x780 |
| task_struct.real_cred | 0x778 (get_task_cred) | 0x778 |
| task_struct.rcu_read_lock_nesting | 0x448 (get_task_cred 内联 rcu_read_lock) | 0x448 |
| task_struct.thread_pid | 0x630 (gettid) | 0x630 |
| task_struct.mm | 0x518 (commit_creds) | 0x518 |
| cred.uid | 0x4 (getuid) | 0x4 |
| cred.euid | 0x14 (geteuid) | 0x14 |
| cred.egid | 0x18 (getegid) | 0x18 |

### 符号验证
- ko 未定义导入 63 个, 全部在设备内核 __ksymtab_ (7179 导出) 中 → 0 missing
- 29 个未导出符号 (selinux_state/security_hook_heads/selinux_blob_sizes/init_nsproxy/
  kallsyms_lookup_name/kernel_read/write/iterate_dir/groups_*/set_groups/security_*/
  avtab_*/ebitmap_*/symtab_*/__hashtab_insert/policydb_filenametr_search/
  strncpy_from_user_nofault/path_umount) 全部在设备 kallsyms 里能找到名字 ✓

## 4. 下一步 (需要 root 窗口, 等 Shizuku)
1. 推 ko 到 /data/local/tmp/kernelsu_gki209.ko
2. root_strike.sh 拿到 root (R→C) → C 轮 insmod/finit_module flags=3
3. 判据: /proc/modules 含 ksu / ksu_done.txt / 管理器转绿
4. 之后: Termux:Boot + Shizuku 自启 → root 常态化

## 5. 复现命令
- 构建: bash ~/ksu_build/build_gki209.sh
- 偏移探针: make ... M=drivers/ksuprobe modules; llvm-objdump -s -j .rodata drivers/ksuprobe/probe.o

## 6. 追加修正 (01:1x)
- KSU_VERSION: 原 Makefile 无 git → 回退值 16, 管理器 v0.9.5 要求 >=11071 (LKM 模式 >=11648)
  → 改为 -DKSU_VERSION=11872 (= 管理器 APK build 号), 已反汇编确认 mov w8,#0x2e60
- is_lkm: core_hook.c 用 #ifdef MODULE → 模块构建自动上报 is_lkm=1 (管理器显示 LKM 模式)
- 最终 ko: sha256 ad60b7841b4fdd060cf71dafc1327dae54ed59fd26f497ffee40c13551e8ae5d
  (bin/ksu/kernelsu_gki209_v1.ko, 148448B)
- ksu_hunt.sh KO 路径已指向 bin/ksu/kernelsu_gki209_v1.ko → /data/local/tmp/kernelsu_gki209.ko
