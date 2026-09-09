# 锁BL 持久 Root 调研报告 (research agent 8b64cc41, 2026-09-10)

## 1) mtkclient/BROM 解锁 MT6983 (D9000): 基本不可行
- mtkclient README: MT6983 属 "V6 protocol, bootrom is patched" 组, Kamakiri 不可用, 只能 preloader+V6 loader; 部分设备 preloader 禁用
- issue #253 (MT6983 OnePlus Nord3): 作者确认 BROM exploit 无法连接, 靠泄露 DA 才拿 flash 读写; DXCC 派生需 Secure World
- Jz8Root (XDA 4784527) RPMB 解锁适用前提 = Kamakiri BROM (MT6769Z/6781/6833/6877 等中低端), 与本 SoC 无关
- 中文检索: 仅商业噪声(EMT/秒开BL), 无可信公开成功案例
  refs: github.com/bkerler/mtkclient ; github.com/bkerler/mtkclient/issues/253 ; xdaforums.com/t/4784527 ; github.com/Jz8Root/xiaomi-hyperos-bootloader-unlock

## 2) KernelSU LKM/init_boot 机制
- LKM 模式 = 向 ramdisk 注入 ksuinit (init 包装: 挂 /proc + insmod kernelsu.ko 后接续原 init) + ksud
- Android13+ GKI 才有 init_boot 分区; matisse 是 2022 Android12 (android12-5.10) -> 大概率无 init_boot, LKM 应 patch boot ramdisk
- 锁 BL + AVB 使刷写不可行 (每次启动校验)
  refs: kernelsu.org/guide/installation.html ; github.com/tiann/KernelSU/tree/main/userspace/ksuinit

## 3) matisse 社区支持: 冷
- MiCode/Xiaomi_Kernel_OpenSource 264 分支无 matisse (官方内核源码未发布)
- 仅 TWRP device tree (需解 BL); 中文教程均以解 BL 为前提
  refs: github.com/hamjin/device_xiaomi_matisse-TWRP ; github.com/MiCode/Xiaomi_Kernel_OpenSource

## 4) 锁BL reality: 逐次 re-root 是唯一模式
- JingMatrix/pixel-ksu-root (锁 BL Pixel, 同 CVE-2026-43499 GhostLock): late-load kernelsu.ko,
  "reboot is the uninstall; re-rooting is re-running the tool" (host wait-for-device 循环)
- 看雪 thread-292846 (Pixel7 GhostLock 移植): "tethered root, 重启即失; 持久需解 BL 刷 Magisk";
  本地 rootd 守护 + reroot.sh, 重启后 ~2min 恢复
- 结论: 跨硬重启的内核级 root 在锁 BL 无公开路径 (AVB 校验 boot; 持久注入点只剩 bootROM/preloader, D9000 无口)
  自动化下限 = host 驱动循环 / directBootAware app 在 LOCKED_BOOT_COMPLETED 后重放 exploit (首次解锁前不跑用户态服务)
  refs: github.com/JingMatrix/pixel-ksu-root ; bbs.kanxue.com/thread-292846.htm ; xdaforums.com/t/4798442

## 对项目目标的收敛
- "跨重启 root 长久化" 的可行定义 = ① 零重启会话内 KSU 持续 (su/管理器可用)
  ② 重启后快速 re-root 规程 (rish/shell 可用即 reroot, 目标 <2min/次)
  ③ 待验证: 设备 /dev/block/by-name 是否有 init_boot (shell 恢复后查) - 有也需解 BL 才能刷
- mqsas 支线 (mi_nobl_root) 若在 HyperOS2.0 有效 = 免内核 exploit 的每 boot 秒级 root, 仍是最高优先实测项
