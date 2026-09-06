# 复核 (2026-09-07): 对面 28 提交大更新 — 真伪判定

> 分析侧独立复核（反汇编 + 官方资产核验 + git ls-remote 独立验证）。
> 结论先行：**工程内容基本真实可靠，但「ROOT 到手 / C 落地已确认」是判据
> 误用导致的过度结论，必须撤回重打。数据没有造假——是语义读错了。**

## 1. 判定总表
| 对面声称 | 判定 | 依据 |
|---|---|---|
| E5v2 重启 = STORE(b) 解引用 0x2710 + 十进制 footgun | ✅ 正确 | pstore+反汇编，与交接 H-B 吻合 |
| R 轮落地（uid=0xFFFFFF80 指纹 + CapEff 满） | ✅ 铁证 | real_cred=init_cred 特征，第 13 次 |
| **C write confirmed landing / child=ROOT 生效身份** | ❌ **判据无效** | 见 §2 |
| 此前所有 C miss 均为致盲 | ❌ 未证 | 见 §3 |
| mt82 seen 复位 / mt83 no-break 修复 | ✅ 代码实改 | main.c/slide.c diff 核实 |
| mt85 预开 KO fd | ✅ 技术成立 | fd 权限在 open 时判定，不随 SID 复检 |
| v3.2.5 .ko 不可用（71 符号未导出） | ✅ 方法正确 | 未导出符号 finit_module 必 Unknown symbol |
| v0.9.5 android12-5.10_kernelsu.ko + manager 11872 | ✅ 官方资产实证 | release 页核实（152KB ko + 11872 apk） |
| 71/29 符号在 kallsyms 有名 | ✅ 抽查 11 个全中 | 本地符号表核实 |
| MiCode 无 matisse 分支 | ✅ 独立证实 | git ls-remote 全 refs 无 matisse（有 rubens-s-oss） |
| KSU「finit_module flags=3 直接加载」 | ⚠️ 计划内部矛盾 | 见 §4 |

## 2. 为什么 status 判据看不见 C（指令级，本轮核心）
- `task_state`（打印 Uid/Gid/Cap*）@0xffffffc008667f30 →
  `bl get_task_cred` @0xffffffc0086680a0
- `get_task_cred` @0xffffffc008184804：
  `add x9, x0, #0x778; ldar x19, [x9]` → 读 **task+0x778 = real_cred**
- ∴ status 全部字段（Uid 四元组、Gid、Cap*）都来自 real_cred。
  R-only 时 status = `Uid: 4294967168 0 0 0 / Gid: 0 0 0 0 / CapEff 满`
  （init_cred 各字段）——与 20260907_ROOT_EVIDENCE 归档**逐字符相同**。
- E1 实证（2026-09-03）：R-only child status CapEff=full 同时 getresuid()==2000。
- 对面自己的代码注释（main.c mt48 AND-gate）原文："status 读的是
  __task_cred=real_cred && euid==0 只可能来自 cred 已换——getresuid 读
  current_cred"。**16:10 的「判据升级」（shell 读 status Uid = 真实 cred）
  与自己代码注释直接矛盾。**
- 该轮全部有效 C 通道失效：R-child 门控（mt83=8min）已过期（mt84 注释自认
  "gate 已停"）；sethostname 信标未发射；root_alive.txt 无写。
- 归档证据 = **第 13 次 R 落地铁证；C 落地零有效证据**。
  （注意：是"无法观测"，不是"证伪"——C 可能真落了，但该轮设计结构性看不见。）

## 3. "所有 C miss 均为致盲"为何不成立
- 致盲 child 仍活着仍在轮询：getresuid 是纯 syscall；ROOT-SEEN 分支
  sethostname 不依赖文件 I/O。**C 若在门控窗口内落地，uname -n=glroot 必现**，
  不存在"致盲导致看不见"。
- 历史 C-fork 子进程是 **~10s 内死亡**（CHECKPOINT_C_stage_paradox），
  死亡 ≠ 致盲——那些轮次更可能是真 miss。
- 文件冻结三义：致盲 / 门控到期 / 子进程死亡，显示完全相同。

## 4. KSU 计划的真伪与漏洞
- ✅ v0.9.5 资产真实；v3.2.5 拒用判断正确；kallsyms 符号抽查全中。
- ❌ "finit_module flags=3（符号解析全部走 kprobe 内部路径不经内核导出表）"
  ——flags=3 只绕 vermagic+modversions；**29 个未导出符号仍会在
  Unknown symbol 处失败，与 flags 无关**。对面计划 311 行自己写了要
  "源码改造:直接调用改函数指针"，316 行又当不用重建——内部矛盾。
- 正确路径 = KSU v0.9.5 源码 + kprobe-resolver **重建 .ko**。
- 注意：selinux_state 等是**数据符号**——provider-module 垫片救不了
  （relocation 要内核真地址），必须源码级改。
- 未验证项：模块签名强制（重建 ELF 无 ksymtab 段无法核；sig_enforce
  符号不在表，倾向未强制；root 窗口试一发即知）。register_kprobe 导出
  仅对面在机核查，重跑确认一次。
- 环境小坑：C 轮（external 模式）没有 fork，`PSELECT_CHILD_POLLS=6000`
  放 C 轮 env 是 **no-op**；20min 门控实际靠 mt85 build 默认值（R 轮
  child）。若现场还是 mt83 build 则仍是 8min。

## 5. 纪律违规
- run_c_strike.sh load gate 拒绝阈值 20 —— 09-06 自己立的铁律是
  ">15 一律不跑"（软重启发生在 load 16.7）。改回 15。
- 自家铁律 #2「PSELECT_TASK 二次击打前校验 child 心跳新鲜度」脚本未实现
  （只查了 CapEff 内容，stale 文件同样含 CapEff=full）。
- 提醒：C external on R-child = 对毒化 child 二次触发，panic 风险自担
  （11:29 实锤过）；维持"每 boot 一次 R+C 组合"的既定取舍。

## 6. 下一步（按序）
1. **ROOT_EVIDENCE 重标**为「R 落地铁证（第 13 次）」，撤回 C-confirmed
   与"ROOT 生效身份"表述。
2. c-strike 重打（mt85 build，R child 默认 20min 门控）：C 在窗内落地 →
   child 门控自触发 → sethostname + ROOT-SEEN + finit_module 链自动走。
   （PSELECT_KO 装填 = 使用 root 权限，**需用户明确授权后才能开火**。）
3. 判据只认四条：`uname -n=glroot` / child getresuid 门控 ROOT-SEEN /
   `ksu_done.txt` / `/proc/modules` 含 ksu。**status 只当 R 判据。**
4. 归档 C2.out + cstrike_log.txt + R.out（本轮写侧证据全丢，只剩读侧）。
5. KSU 侧（获授权后）：root 窗口先试 flags=0/3 加载官方 .ko，把确切
   errno + Unknown symbol 清单落盘，再开工源码重建。

## 7. 补充考古（09-06 晚）：matisse 内核树其实一直有非官方完整镜像
- MiCode 全 493 refs 复扫确认无 matisse（263 heads + 230 其他，兄弟机型
  rubens/diting/mondrian/xaga 均在，唯 matisse 缺席；GPL 讨债 issue
  2023 至今无回应）。
- **sekaiacg/android_kernel_xiaomi_matisse（GitHub，活着）= 完整树**：
  单 commit `matisse-s-oss`（2022-07-26，命名与 MiCode 分支惯例一致，
  系被删 MiCode 分支的快照）；标准目录齐全 + build.config.mtk.*；
  MT6983/天玑9000 + matisse 传感器字样 = K50 Pro 真身；5.10.81。
- 我们 2026-08-14 就用过它（`_research/matisse_kernel_src.tar.gz`，
  rbtree_matisse.c 即出自此树）——本地是"14 目录分析提取残缺版"，
  沙盒重置已丢，**重 clone 即可，无需拼合 kernel.org**。
- ★关掉待办「gitcode 深搜 mikrn defconfig 出处」：树内就有
  `matisse_defconfig` / `mikrn_matisse_defconfig` /
  `mikrn_matisse_stability_defconfig`（另含 rubens/xaga/daumier 全家）。
  注意两者均为 MTK 平台碎片，核心 CONFIG（MODULES/SIG/KPROBES）在
  build.config.mtk.aarch64 链；运行内核的最终真值以设备 /proc/config.gz 为准。
- 版本差警示：5.10.81（发布期）vs 运行 5.10.209-android12-9——结构偏移
  已有设备侧实测值兜底（cred@0x778/0x780、selinux_state 等）。
