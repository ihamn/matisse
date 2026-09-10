# 装载 GKI 版 kernelsu.ko (2026-09-09 v2 — 已按联网+源码实证修正)

## 资产
- ko: kernelsu_prep/kernelsu_gki209_v2.ko
  sha256 386a0842d9a4db183c7d3f8a15128f0b72156dc784955fcac45c8306ea48e4c8
- 构建树: ~/ksu_build/gki209 (GKI android12-5.10 = 5.10.245 + 设备真实 config + 删掉设备没有的 file_ioctl_compat)
- 重编: bash ~/ksu_build/build_gki209.sh
- 验证报告: VERIFICATION_ko_gki209_v2_20260909.md

## 关键: 不要用 flags=3
设备 CONFIG_MODULE_FORCE_LOAD 未开 → IGNORE_VERMAGIC/IGNORE_MODVERSIONS 都会走
try_to_force_load() → -ENOEXEC。本 ko 改为**真匹配**:
- vermagic 语义匹配 (有 __versions 时 same_magic 跳过版本号段, 其余全等)
- __versions 64 条 CRC = 设备内核 __kcrctab 真值 (与 KSU 官方 GKI ko 交叉验证 64/64 相同)
→ 用 finit_module(fd, "", 0) 即可 (exploit 内置: 先 0, 失败才试 3)

## 怎么装 (需要 root 窗口 + 用户授权)
    HUNT_ALLOW_KO=1 bash ~/ksu_persist.sh
序列: 部署(mt87 preload + ko、本地/远端 SHA-256 门) → 取证/体检(load<15) → R 轮 → E5v3(permissive 窗口)
      → C 轮 (PSELECT_KO → finit_module flags=0) → E5R 还原 → 回收日志回传 gitee

## 成功判据
- /proc/modules 含 ksu                     (最硬)
- dmesg: "ksu: resolver ok (28 required + path_umount optional)"
- 管理器 KernelSU v0.9.5 转绿 + 显示 LKM 模式 (KSU_VERSION=11872, is_lkm=1)

## 失败模式与对策
- Unknown symbol → dmesg 会给出名字 (理论上 0 个: 63 导入全导出)
- "disagrees about version of symbol" → CRC 表对不上 (应不会; 已 64/64 匹配)
- "no symbol version for" → __versions 缺失 (本 ko 有 0x1000 字节 __versions)
- "version magic ... should be" → same_magic 不匹配 (本 ko 已语义匹配)
- resolver hard-fail (-ENOENT) → dmesg 列出缺哪个符号
- CFI failure panic → __cfi_check 桩未被识别 (检查 llvm-nm 有 T __cfi_check @0x6000)
- SELinux 拒绝装载 → E5v3 permissive 窗口未生效
