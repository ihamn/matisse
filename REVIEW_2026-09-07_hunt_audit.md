# 审计 (2026-09-07): 对面 hunt/KSU-build 阶段更新 (e135eda..f9bd3f5, 11 提交)

> 结论先行：**这波没有幻觉——撤回声明规范、判据体系正确、matisse 树构建
> 能力实证（kernelsu.ko 112872B 真编出来了）。但 hunt v5 有一个实测复现的
> 致命 bug（C 轮 100% 空转）+ 两个 KO 致命伤 + 三处纪律缺口。已直接修成
> v6 推回。hunt 尚未开火（仓库无任何 hunt 运行日志）。**

## 1. 判定总表
| 项 | 判定 | 依据 |
|---|---|---|
| 撤回 ROOT_EVIDENCE 判定 + 规范注记 | ✅ 优秀 | 引用我方指令级证据，标注保留为第13次R铁证 |
| 五层有效 C 判据体系 | ✅ 正确 | 全部读主观 cred 或落盘，弃用 status Uid |
| c-strike 修正（gate15/心跳新鲜度/去 no-op CHILD_POLLS） | ✅ 落实 | run_c_strike.sh diff 逐条核实 |
| matisse 树 Termux 原生构建 kernelsu.ko 112872B | ✅ 可信 | Bionic host 修复细节（shim.o bcmp/sorttable 摘除等）全是真问题的真解法 |
| E5v3 默认值语义（hunt E5 轮不传 VALUE） | ✅ 无恙 | main.c:940 unset→SPRAY→E5v3，且 page_base/byte0/byte2 三重运行时守卫 |
| mt84→mt85 落地链（gate→setresuid→root_alive→finit_module） | ✅ 代码在 | BUILD_INFO + 此前 diff |
| **hunt fire() C 轮命令拼接** | ❌ **致命** | 见 §2，实测复现 |
| **kernelsu_matisse.ko 可装载性** | ❌ **两个死结** | 见 §3 |
| hunt 纪律 | ⚠️ 三缺口 | 见 §4（v6 已修） |
| hunt 是否已开火 | 未开火 | 仓库无 hunt_forensic/ksu_hunt 日志，11 提交全是代码/文档 |

## 2. 致命 bug：hunt C 轮 100% 空转（实测复现）
fire() 原把 `PSELECT_TASK=$task` **追加在 `> $name.out 2>&1` 之后**：
```
... /system/bin/sleep 180 > /data/local/tmp/C1.out 2>&1 PSELECT_TASK=12345
```
shell 语法：重定向后的词是 **sleep 的 argv** 而非环境变量。沙盒实测：
```
sleep: invalid time interval 'PSELECT_TASK=12345'  → rc=1，命令立即失败
```
即 C 轮触发器**从未运行**——hunt 全链走完只会产出：R 落地 + E5v3 两次写
（enforce 0→1）+ 一个报错的 C1.out。f9bd3f5 修的 case/花括号是另一个 bug，
这个漏了。c-strike 的正确写法（line 58 `PSELECT_TASK=$TASK` 内联 env 块）
证明对面知道正确形态，纯疏忽。**v6 已修**：tskenv/koflag 并入 env 块，
修复后实测 rc=0、env 正确传递。

## 3. KO 两个死结（即使 fire 修好也到不了 ★★★）
1. **ko 尚无 kprobe-resolver**——对面自己标注待做（RESOLVER_TASK.md）。
   32 个未导出符号 → finit_module 必 Unknown symbol。hunt 却已把无 resolver
   的 ko 武装进 PSELECT_KO。
2. **2 个符号在运行内核根本不存在**（86 导入 vs 设备 kallsyms 142091 名单
   逐一比对）：`_cond_resched`、`rcu_read_unlock_strict`。
   - `_cond_resched`：连 `cond_resched` 也无 = 运行内核 PREEMPT 全内联。
     **resolver 救不了**（kallsyms 无名）。PREEMPT 内核下本就是 no-op，
     **源码级删调用是语义正确解**。
   - `rcu_read_unlock_strict`：5.10 PREEMPT_RCU 用 `__rcu_read_unlock`。
     `rcu_read_unlock` 在 kallsyms 有名（0xffffffc0089f8744）→ **源码改名
     后 resolver 可解析**。
   → 最终任务应扩为「32 resolver + 2 源码改」。
3. 待对面确认：54/32 导出划分**具体名单未归档**；`register_kprobe` 是否在
   32 内决定 bootstrap 可行性（在 → 计划成立；不在 → 需用户态 tracefs
   kprobe_events 取址 + module param 传址方案）。

## 4. 纪律缺口（v6 已全部修复）
| 缺口 | 后果 | v6 修复 |
|---|---|---|
| hunt 缺 E5→C 心跳新鲜度校验（c-strike mt86 有，hunt 忘移植） | E5 轮 ~4min 内 child 死亡 → 对死任务二次击打（11:29 panic 同款） | hb_fresh()（stat %Y，30s 阈）门控 C 击 |
| 体检 load「仅记录」不拦截 | 违反 09-06「>15 不跑」铁律（软重启发生在 16.7） | load>15 exit 6 |
| KO 无授权自动装填 | 违反用户既定规则「insmod/KSU 需另行授权」 | HUNT_ALLOW_KO=1 显式门，默认仅取 C 证据 |
| kernelsu_matisse.ko 未入 git + rpush 静默失败 | 现场克隆重置即丢构建产物；推送失败无感知 | 推送结果检查 + 落机 ls 验证 + 未入库警告 |

## 5. 现在的正确打法（按序）
1. **现场先归档**：kernelsu_prep/ 全套（ko + Bionic shim 补丁 + build
   config）推入 git——现在构建能力只活在现场机一台克隆里。
2. **hunt v6 无 KO 模式跑一轮**（无需授权）：唯一目标 = C 落地五层证据
   首次落袋（root_alive.txt + ROOT-SEEN + uname）。E5v3 首秀风险自担
   （v1 黑屏根因仍开放，pstore 已在 hunt v3 部署覆盖）。
3. KO 侧静态作业（不开火）：32 名单归档 → register_kprobe 导出态确认 →
   2 个不存在符号源码改 → resolver 补丁 → 重编 → 再谈授权装填。
4. 用户授权门不变：**HUNT_ALLOW_KO=1 之前任何 finit_module 不发生**。
