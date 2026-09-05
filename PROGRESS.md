# Matisse 项目进度看板

> 自动维护，最新更新：2026-09-04

## 当前主目标
CVE-2026-43499 临时 root → KernelSU。

## 当前状态（2026-09-04 晚）
C 悖论已解（检测致盲假象，见 `CHECKPOINT_detection_artifact_20260904.md`）；
mt73 检测重造已交付；**mt74 E5 几何指令级验证完毕，补丁已入 main.c，待构建+现场执行**。
全链序列与判据：`CHECKPOINT_e5_geometry_20260904.md` §三（行动 runbook）。

## mt74 执行序列（现场按序，细节见 CHECKPOINT_e5 §三）
1. E5 轮 `PSELECT_SELINUX_ENF=1` → 验证 `cat /sys/fs/selinux/enforce`==0
2. R 轮 `PC_OFF=0x770` → CapEff 满（permissive 下全可见）
3. C 轮 `PC_OFF=0x778 + PSELECT_TASK=<R-child>` → ROOT-SEEN + hostname=glroot
4. `PSELECT_KO` → finit_module → ksu_done

## E5 关键静态事实（2026-09-04 指令级）
- **enforcing@selinux_state+0**（avc_denied+0x1c `ldarb [state]; tbz #0`，Android
  重排，非 upstream +1）；avc@+0x48 → 8 字节零写不碰指针
- **RB_RED=0/RB_BLACK=1**：fops.c 老注释"RED已置位"是反的；TREE_PC 必须 `&~3`
  （`|1`+child=0 会进 __rb_erase_color 旋转 = 致命）
- CASE_A child=0：STORE(b) 有 `cbz` 守卫（@0x29c）→ E5 是单条 8 字节零写
- 走主树（R 7/7 同款 store 路径），不碰 pi_tree

## 已完成的对照实验（保留判读）
| 实验 | 结果 | 现判读 |
|---|---|---|
| E1 off770（R 基线） | CapEff 满 7/7 | real_cred 写落地 + 检测通道活着（SID 未变）|
| E1 off788（写 comm） | comm 污染，子进程存活 | STORE(a) 对 pc≥0x778 几何确实执行 |
| off778b（写 cred） | status euid=2000 零心跳 | **status 是 t=0 陈旧快照；子进程被致盲非死亡；写已落地** |
| E4a（pi_tree 写 cred） | "失败" | 判据结构性永不可见（同一致盲），极可能成功 |

## 现场前置条件
- Shizuku 运行中
- 屏幕常亮 + 插电
- 部署 mt72：`bash termux/deploy_mt72.sh`（SHA256 校验部署）
- 环境教训：consumer 被饿出窗口时（连续 0 发）不要硬跑，先等调度恢复

## 最近交付
- mt69：`PSELECT_PTR_PC_OFF`
- mt70：`PSELECT_PTR_PC_OFF` + `PSELECT_HOLDER`
- mt71：stage-aware mt51 abort（C 轮 euid==0 信号）
- mt72：**E4 pi-tree 几何** `PSELECT_PTR_PI` + PI 词清零 bug 修复 + PI 轮 stage=C（见 bin/mt72/BUILD_INFO.txt）
- 插件：`@dhicoc/dsh-reverse-skill`、`@linxin666/dsh-client-ui-task-board`

## ⚠️ 2026-09-01 崩溃记录
- 昨晚自动跑 R-external 隔离实验时，Rext4（60s 窗口、PSELECT_ENTER_DELAY_USEC=0）导致手机重启。
- 新 boot：`bf1c84d3-2dfa-4a96-8098-e8f89e718a33`
- `/data/local/tmp/Rext4.out` 为全 NUL（panic 前未 flush 或页缓存丢失），无法从该文件定位崩溃点。
- Rext3 记录完整：consumer 风暴被饿出 20s 窗口（`pselect returned t=20012ms` 后 `mt19b t=20013ms`），0 发。
- Shizuku 重启后未运行，当前停止一切现场实验。
- 教训：不要在 consumer 已连续饿出窗口的环境下加长窗口硬试；应先等负载/调度恢复，或先跑只读取证确认无残留。

## ⚠️ 2026-09-01 追加：R-fork 健康检查也饿窗
- 恢复 Shizuku 后跑了一次标准 R fork（mt70，20s 窗口），同样 consumer 被饿出窗口：0 发。
- 说明当前环境不适合跑触发实验，不是外部模式独有。
- Shizuku 随后又变为未运行，现场实验再次停止。

## 🎯 2026-09-01 C 几何决定性结论
- R fork 默认 pc=0x770（写 real_cred）：全风暴落地 ✅
- C external pc=0x778（写 cred）：全风暴 0/6 ❌
- C fork pc=0x778：全风暴 0/6 ❌
- **结论：C 写不落不是外部模式/时序，而是 pc=0x778 / 写 task+0x780 cred 的几何本身不落地。**
- GeomB（R fork + PC_OFF=0x778）本次饿窗未判定，后续可补一次交叉确认。

## 🔬 2026-09-01/02 mt72：C 悖论指令级证明 + E4 pi-tree 备用几何

### C 悖论（详证见 `CHECKPOINT_C_stage_paradox_20260901.md`）
- 逐指令反汇编 `rb_erase` CASE_A（`ref/rb_erase.asm`）证明主树 C 几何必然写 0x780：
  C(pc=0x778) 查 `*(0x788)` → 0x788 是未知 8 字节字段（**非 comm**，comm 在 0x790，`scripts/dump_task_fields.py` init_task dump 实证），初值 0、全内核无访问者（`scripts/find_offset_access.py` 扫 .kernel 全符号）→ 必 ne → 必写 0x780。指令级 C 应成功，实测 0/N —— **结构性矛盾**。
- 附带取证：Cfork 子进程 ~10s 内死亡且无心跳（`logs_raw/20260901_mt71_cfork/`）。

### E4 pi-tree 几何（mt72 已构建，`bin/mt72/BUILD_INFO.txt`）
- 原理：fake waiter 的 **pi_tree_entry**（word3-5）走同一 `rb_erase`，但走"继承色"STORE(b) 分支：`PI_PC=写值(init_cred 别名)`、`PI_RIGHT=task+0x780`、`PI_LEFT=0` → child≠0 无 rebalance → `*(init_cred+8)=target`（无害）→ **`*(task+0x780)=init_cred`（cred 写）**。
- 主树无害化：TREE_PC=fake_lock 喷页零区、RIGHT=LEFT=0 → CASE_A child=0 只写零区自身。
- **三处代码改动（全部在 main.c，构建后逐条验证）**：
  1. E4 块 `PSELECT_PTR_PI=1`（fork 隔离 / external 两用法，crash#2 教训：一进程一写）；
  2. 修复：attempt 循环原本无条件把 PI 词清零 → E4 静默失效，现加 `if (!getenv("PSELECT_PTR_PI"))` 守卫；
  3. 修复：PI 轮显式 `PSELECT_PTR_STAGE=C`（euid==0 中止信号），否则 external E4 轮在 R 已打满 CapEff 后会被 R 语义误停成单发。
- 部署：`bash termux/deploy_mt72.sh`（SHA256 7f74af2dd6766c5b794e9a8efc789c7f5a72a355495d34b46fae1182c3bcf78d）。

### 现场实验顺序（环境恢复后）
1. `run_E4a_test.sh`（PI 隔离，最干净的单变量判定）；
2. `run_E4b_chain.sh`（R→E4 两轮链，全 root 判定）；
3. `run_E1_gradient.sh`（梯度测绘，判别 H2 "erase 未执行" vs H3 "写后被中和"——无论 E4 成败都值得跑）。

## 🛑 2026-09-03 系统异常停止
- E1 梯度实验出现 off788 污染 comm（证明主树 erase 对 pc≥0x778 会执行 store）。
- 但随后系统出现短暂连续软重启/高负载（loadavg 一度 186/1166/767），
  用户报告应用未清除。
- **已停止一切现场实验。** next 等系统恢复、负载正常后再跑 off778/后续。

## 2026-09-03 对面裁定（低余额，只记要点）
- 本轮 off778 0 发 = 触发链没到 erase/write，C 几何一行没执行，非逻辑 bug。
- E1 off788 comm 污染结论不受影响。
- 饿窗是自诱导负载（D-state slab/skb/回收），不是新 bug；对进机时系统状态敏感。
- 下次进机先清点：`ps -ef | grep -c "sleep 1"`（E2 sampler 孤儿泄漏），有就 kill。
- 已给 `run_E1_gradient.sh` / `run_E4a_test.sh` / `run_E4b_chain.sh` 加 load gate：
  1 分钟 loadavg >10 拒跑。
- 根治方向（不急）：consumer 绑大核 + 风暴留小核，需单独 env knob 实验，不动默认。

## 2026-09-04 off778 full-storm result
- off778 full 6-shot, euid remains 2000 -> cred@0x780 write not persisting.
- off788 comm corruption + E4a fail -> H3/cred-slot neutralization or consistency constraint.
- **软重启线索**：用户观察到短暂连续软重启但应用未清除，疑似 system_server/zygote 级；请对面重点看是否 cred 不一致触发软重启保护/回滚。

## 2026-09-04 mt73 detection rework (code only, not field-tested)
- sticky CapEff-full flag + sethostname("glroot") beacon.
- Solves SELinux kernel-SID blinding after cred swap.
- Next field test: deploy mt73, run E4a, then check `cat /proc/sys/kernel/hostname` for "glroot".

## 2026-09-05 E5 field result
- mt74 E5 selinux zero-write landed: `/sys/fs/selinux/enforce` = 0.
- System black-screened after E5; dsh web task-board got corrupted inode (repaired by user).
- Archive: `logs_raw/20260905_e5/`, binary `bin/mt74/`.
