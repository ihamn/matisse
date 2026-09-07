# REVIEW_2026-09-07_ko_risk.md — 对面 kernelsu.ko 风险评估（用户关切）

> 触发：用户对 .ko 的担忧 + 用户外部资料（出厂内核 5.10.136、2022 讨债
> issue、Gizmochina GPL 违规报道）。本文 = 分析侧独立核验结论。

## 0. 一句话
当前 ko **加载必失败 = 惰性安全**（32 未导出符号 → Unknown symbol，
module init 永不执行）。真正的危险窗口在 resolver 补丁完成之后——
而 resolver 计划本身有 3 个设计缺陷（§3），且版本基线漂移比先前评估
更重（构建树实证 5.10.81，§1）。

## 1. 版本基线（本次核验 + 用户资料）
- **sekaiacg 树 Makefile 实证 `SUBLEVEL = 81`** → 5.10.81，档案记录无误。
- 用户资料：出厂 Android S 内核 = `5.10.136-android12-9-00020-gc9f59ef34367`
  → **构建树(.81)比出厂(.136)还老 55 个 stable**；运行 `.209-android12-9`
  （HyperOS 2.0.6）→ **总漂移 = 128 个 stable 版本 + HyperOS vendor delta**。
- 时间线佐证快照真实性：sekaiacg 快照 2022-07-26 ↔ 讨债 issue
  2022-07-27（Release ... mattise Android S）——小米短暂发布后删除的
  MiCode 分支。GPL 违规有媒体记录（MTK 限制源码分发给 OEM 说）。
- TWRP 设备树 / rubens 移植 / ROM 提取路线对本目标**无增益**：我们已有
  运行内核全套符号 + 142k 行 kallsyms，比任何源码树都真。

## 2. 运行内核 MODVERSIONS = OFF（kallsyms 实证）
`ref/kallsyms.txt` 中 `__crc_` 符号 **0 个** → 无 CRC 机制。
- 后果①：flags bit0（跳 CRC）本无武之地；加载期防线只剩 vermagic
  （bit1 可绕）+ 符号名解析（resolver 绕）。
- 后果②（关键）：**resolver 完成后 flags=3 加载 = 零加载期 ABI 校验**。
  没有任何机制替我们查结构漂移 → 结构安全只能靠「构建基线与运行内核
  同源」保证，不能指望加载器。这把 §5 基线切换从"建议"升级为"必需"。

## 3. resolver 计划三缺陷（RESOLVER_TASK.md × mt85ko_syms.txt 实查）
**R1 skip-on-unresolved 是语义炸弹**。"未解析到的符号 = 跳过对应特性"：
对 `_cond_resched` 恰好无害（运行内核全抢占，cond_resched 本就是 no-op
——kallsyms 中 cond_resched/_cond_resched 双缺席实证）；但
`rcu_read_unlock_strict` 被跳过 = RCU 读临界区不平衡 → grace period
卡死。**必须改硬失败 + 显式豁免白名单**（白名单需逐符号论证无害）。

**R2 数据符号垫不了**。86 导入中 **13 个是数据符号**（selinux_state /
security_hook_heads / selinux_blob_sizes / init_task / init_nsproxy /
system_wq / kmalloc_caches / memstart_addr / kimage_voffset /
vabits_actual / __stack_chk_guard / arm64_use_ng_mappings /
gic_nonsecure_priorities）。"每符号一个函数定义"只对函数有效；数据符号
必须源码级宏别名：
`static struct selinux_state *p_selinux_state; #define selinux_state (*p_selinux_state)`
selinux_state 三件套恰是 KSU sepolicy hook 核心，13 个全要处理。

**R3 配置漂移实锤**。_cond_resched / rcu_read_unlock_strict /
arm64_use_ng_mappings / gic_nonsecure_priorities 这批「内联泄漏」导入 =
.81 树的 PREEMPT / RCU_STRICT_GRACE_PERIOD / ARM64 头内联配置 ≠ 运行
内核。用运行内核真 config（/proc/config.gz）重建可整批消失——比逐符号
源码改更治本。

## 4. bootstrap 可行性（本次核验 ✓）
`kallsyms_lookup_name @0xffffffc0082acaf8`、`register_kprobe
@0xffffffc0082f3e50` 均在运行 kallsyms 有名 → kprobe bootstrap 成立。
前提待确认：register_kprobe 是否真被导出（54/32 划分名单仍待现场归档）。

## 5. 分级加载协议（每级失败 = 干净拒绝 = 免费取证）
| 级 | 操作 | 预期 | 取证价值 |
|---|---|---|---|
| L0 | finit_module flags=0 | vermagic 拒绝 | check_modinfo 的确切 UTS_RELEASE（另：现场 `uname -r` 同步归档） |
| L1 | flags=3（当前无 resolver 的 ko） | Unknown symbol 拒绝，init 永不跑（安全） | 32 符号名单精确归档 + 模块签名强制与否一并暴露 |
| L2 | flags=3（resolver 完成 + 基线重建后） | 真加载 | **唯一危险时刻**：需用户授权 + struct module 布局核对 |

- L0/L1 由 mt84/85 链在 E5v3 窗口内的 privileged child 自动执行
  （flags 0→3 顺序）——属使用 root 权限，仍在 HUNT_ALLOW_KO 授权门内。
- ★终局：android12-5.10.209 common 基线 + 运行 config 重建 → vermagic
  可精确匹配 → flags=0 直载（bypass 退役）。但 MODVERSIONS=OFF 意味着
  vermagic 匹配也不校验逐符号 ABI——**结构安全靠基线，不靠加载器**（§2）。

## 6. 现场任务清单（并入 RESOLVER_TASK.md）
1. `kernelsu_prep/` 全套入库（ko + Bionic shim + build config）——已催。
2. `uname -r` + `/proc/config.gz` 归档（重建 config 的真值来源，治 R3）。
3. resolver 改造：硬失败 + 豁免白名单（R1）；数据符号宏别名 ×13（R2）。
4. 基线切换：android12-5.10.209 common + KSU v0.9.5 源码；.81 树降级
   为 vendor 结构差参照（R3 + §2）。
5. 54/32 导出划分名单归档（register_kprobe 导出态确认）。
