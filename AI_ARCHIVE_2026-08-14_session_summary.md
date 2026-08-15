# 会话总结 — 2026-08-14 (mt 系列 + Firefox 链评估 + 工具)

## 一、核心定论（全 session 最重要的结论）
**matisse 5.10.209 上 GhostLock 的 rb_erase 写入从未在任何版本落地**（mt1-14 + R 系列 + v 系列 + 电脑端 全部一致）
- 触发有（deep chain + OFF/selinux-8 parent 可达 ret 36-193, calls=1）
- 写入永远不落地（boot_id/selinux 均验证未变）
- **反汇编根因**: chain walk 在 rb_erase 前的多重检查（owner/top_task + wait_lock + waiters-leftmost, +0x3bc 之后）把假 waiter 挡在门外
- v30 源码注释自认: "pselect side-channel fails on MTK scheduler"

## 二、mt 系列版本历史（13 个）
| 版本 | 关键改动 | 结果 |
|------|---------|------|
| mt1 | aristotle 原版 (SIGALRM) | 崩 (slab) |
| mt2 | 无 SIGALRM + 2 尝试 | 稳定跑完, 泄露失败 |
| mt3-4 | slide 13-word | 崩 (早期) |
| mt5 | fops route 泄露 + 常量 0x2065d50 | 触发但写不落地 |
| mt6 | fops 13-word | 崩 (task=NULL) |
| mt7 | 10-word + lock=b | 不崩, 写不落地 |
| mt8 | OFF 强触发 | 不崩, 写不落地 |
| mt9 | 扫 shift 1-8 | shift=2 触发, 写不落地 |
| mt10 | selinux-zero 写 | 触发, getenforce 仍 Enforcing |
| mt11 | v30 原版 (SHA256=7d16b26d 还原) | 基准 |
| mt12 | v30 + pi_tree→selinux | ret=36 触发, 写不落地 |
| mt13 | + ONE_SHOT 单次模式 | 完整跑通, 写不落地 |
| mt14 | boot_id 验证目标 | 触发时 calls=1, boot_id 未变 |

## 三、关键发现
1. **免重启清 slab**: 内存压力 (mem_pressure.c) 清可回收部分; **杀后台应用 (am kill-all) 恢复喷页 cache** (用户超级省电思路, 有效!)
2. **v30 源码** 在 CyberMeowfia/.../exploit/src/.bak_v30 (含 deep chain + 运行时 env 调参)
3. **R8 "phase6 leaked" 是喷页泄露不是 KASLR 泄露**; R8 硬编码 KASLR=0 从未读 boot_id
4. **rb_set_parent 写原语限制** (电脑端分析): 写非零值必破坏 value+0; 只能安全写 0
5. **KASLR 确实开启** (CONFIG_RANDOMIZE_BASE=y); kallsyms/dmesg 全被封

## 四、Firefox 链评估 (CVE-2026-10702, 用户 Firefox 151.0 在影响范围)
- 公开链: JIT RCE → shell → 按设备ID拉 payload → LD_PRELOAD preload.so → GhostLock → root
- **内核步 = 同一 GhostLock 技术, 我们的 5.10 墙照样适用**
- 无 matisse payload (演示在安卓 16/17, GKI 6.x 写能落地)
- 价值: 远程投递机制 (写原语解决后可复用); 确认无隐藏的 5.10 技巧
- 源码: _research/CVE-2026-10702/ (HORKimhab 仓库, exploit.html + index.html)

## 五、工具与资产
- _research/mem_pressure.c / mem_pressure2.c: 免重启清 slab 工具
- scripts/test_mt11.sh (mt13): ONE_SHOT + getenforce 验证
- scripts/test_mt14_bootid.sh: boot_id 写验证
- preload_mt1~14.so: 全部版本归档
- _research/mt11_v30/: v30 工作区 (可继续改)
- AI_ARCHIVE_2026-07-18_kernelsu_plan.md: 28 节全程分析

## 六、剩余选项 (写原语的破局方向)
1. **chain walk 属主检查的可满足条件** — 需要真实 task/锁地址 → 需要一个能用的内核泄露 (boot_id 读在 MTK 不行, 需其他泄露面)
2. **kernelsnitch mm_struct 泄露** (R8 phase6 用过) — 能否间接推出内核地址
3. **换内核版本/换设备** — 该技术在新 GKI 内核 (6.x) 实证可行
4. **Firefox RCE 提供投递** (写解决后) — 远程一键 root 的投递层
