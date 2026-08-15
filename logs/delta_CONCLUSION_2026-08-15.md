# Δ (kernel_phys_load) 结论 — 2026-08-15 15:2x

## 一句话
**Δ = 0（KIMAGE_PHYS == PHYS_OFFSET == 0x40000000）已被真机实验证明**，无需再测。

## 证据（比 iomem 更硬）
- mt25x 写 boot_id (dmap 0xffffff80028a77d0) → **命中** (boot_id 变 00778a02-...)
- mt26x 写 enforcing (dmap 0xffffff8002a41b98) → **命中** (Permissive)
- 两个不同地址的 dmap 目标都写中 ⇒ 地址公式无整体偏移 ⇒ Δ=0

## 为何设备侧无法直接读
- /proc/kallsyms: 全 0 (kptr_restrict 掩码, 与 SELinux 无关)
- /proc/iomem: 全 0 (同上)
- dmesg 早期行: 被滚动裁剪
- Permissive 不影响 kptr_restrict 掩码 ⇒ 掩码与 SELinux 层级独立

## 对项目影响
- 不需要再找 boot.img kernel_addr / MTK lk 源码
- P0_DATA_ALIAS_CONST (P0_KERNEL_PHYS_LOAD=0x80000000, PHYS_OFFSET=0x80000000, delta=0) 正确
- 与 ghostlock README 的 kernel_phys_load 警告无关（那是新设备适配问题）

