# 装载 GKI 版 kernelsu.ko (2026-09-09 就绪)

## 资产
- ko: kernelsu_prep/kernelsu_gki209_v1.ko
  sha256 ad60b7841b4fdd060cf71dafc1327dae54ed59fd26f497ffee40c13551e8ae5d
- 构建树: ~/ksu_build/gki209 (GKI android12-5.10 = 5.10.245 + 设备真实 config)
- 重编: bash ~/ksu_build/build_gki209.sh

## 为什么这次不一样
1. 设备内核 = GKI (不是 matisse vendor 树): config 从内核 ELF 内嵌 IKCFG 提取,
   CONFIG_PREEMPT_RCU/PSI/MEMCG/CFI/SCS 全 y — 之前 vendor 树编的 ko 偏移差几百字节
2. 布局实证对齐: cred 0x780 / real_cred 0x778 / rcu_read_lock_nesting 0x448 /
   thread_pid 0x630 / mm 0x518 / uid 0x4 / euid 0x14 (设备反汇编 = 本树 offsetof)
3. 符号: 63 个导入全部被设备内核导出; 29 个未导出符号由模块内 resolver 经
   kprobe->kallsyms_lookup_name 运行时解析, 缺一个就返回 -ENOENT 干净失败(不静默)
4. CFI: 设备 CONFIG_CFI_PERMISSIVE=n → 未插桩模块被间接调用会 panic;
   模块内提供 page-aligned __cfi_check 直通桩 → mod->cfi_check 非空 → 放行
5. vermagic 5.10.245 ≠ 设备 5.10.209 → 必须 finit_module flags=3
   (exploit 已内置: 先 flags=0 再 flags=3)

## 怎么装 (需要 root 窗口 + 用户授权)
    HUNT_ALLOW_KO=1 bash ~/ksu_hunt.sh
序列: 部署(mt85 preload + ko, SHA 门) → 取证/体检(load<15) → R 轮 → E5v3(permissive 窗口)
      → C 轮 (PSELECT_KO → finit_module flags=3) → E5R 还原 → 回收日志回传 gitee

## 成功判据
- /proc/modules 含 ksu            (最硬)
- /data/local/tmp/ksu_done.txt
- dmesg/串口: "ksu: resolver ok (28 required + path_umount optional)"
- 管理器 KernelSU v0.9.5 转绿 + 显示 LKM 模式 (KSU_VERSION=11872)

## 失败模式与对策
- Unknown symbol → 说明有导入没被导出(理论上 0 个), 看 dmesg 具体名字
- "disagrees about version" → flags=3 没生效
- resolver hard-fail (-ENOENT) → dmesg 里会列出缺哪个符号
- CFI failure panic → __cfi_check 桩没被识别 (检查 nm 是否有 T __cfi_check)
- SELinux 拒绝装载 → E5v3 permissive 窗口未生效
