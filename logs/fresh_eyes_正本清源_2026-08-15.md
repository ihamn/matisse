# Fresh-Eyes 正本清源报告 — matisse GhostLock 项目 (2026-08-15 17:0x)

> 目的：只做一件事——理清脉络、正本清源。对抗性复核"继承的结论"，逐条对质一手证据。

## 一、项目目标（从未变过的锚点）
锁 BL 的 Redmi K50 Pro (matisse, MTK 5.10.209) 上装 KernelSU。
路线：CVE-2026-43499 (rtmutex UAF) 拿临时 root → insmod kernelsu.ko。
**注意：目标不是"关 SELinux"，不是"翻 Permissive"——是 root + insmod。**

## 二、时间线（一手证据锚定）

### 阶段 0：7 月 — 两条死路（但攒下工具链）
- v 系列 (v1-v36)：deep PI chain + pselect，rb_erase 永远写 parent+8 (name_ptr)，碰不到 fops → **死路**
- R 系列 (R1-R11)：shape=1 直写 cred，但 shape=0 读 per-cpu 必崩 → **关闭**
- 资产：KASLR=0 绕过、MM_STRUCT_SZ=0x3C0、deploy.sh 哈希铁律、INIT_TASK 替代 fake_task

### 阶段 1：8-14 深夜 — 写原语从"不可能"到"成立"
- kallsyms 全量提取 (142102 符号) → 地址数学证实正确，唯一未知 Δ
- oracle 阴性 → 发现 FOPS 路线**结构性无 UAF**（mt1-17 全白测）
- 真触发 = SLIDE 路线 v37 EDEADLK + 同线程 overlay + **futex_lock_pi 补触发**（JoinChang 对比得出）
- **mt22 (02:2x)：写原语实证成功**（boot_id 被改写 + 自发持续写）

### 阶段 2：8-15 早晨 — 第一次 Permissive
- **mt25 (08:26)：写 boot_id 成功**（boot_before=97ae8367 干净 → 写入后 00778a02-80ff-ffff...）
- **mt26 (08:43)：写 enforcing 成功 → round4 Permissive**（tree_pc=enforcing-8）
- 关键：mt25 先写 boot_id 激活悬垂链 → mt26 接力翻 enforcing（间隔 3 分钟）

### 阶段 3：8-15 下午 — 复现 + 破案（我们接手）
- **15:04-15:16 复现成功**：mt25x round1 WRITE CONFIRMED → mt26x round2 PERMISSIVE
- **Δ=0 证明**：boot_id + enforcing 两个不同地址都写中 ⇒ 地址公式无偏移
- **权限验证**：Permissive ≠ root（uid 2000, cap 全 0, 不能 insmod）
- **mt28o 崩溃 = Case-2 写【触发】确认**（回答了 mt28 悬案）
- **破案**：TASK_CRED_OFF 0x820 错误 → 应为 0x780（commit_creds 反汇编铁证）
- **mt29**：修正偏移后 ks+perf 全通，但写假 cred 页 → attempt 3/4 崩
- **mt30**：改写 init_cred（ghostlock W2 经验）→ 不崩了，但 futex trigger 全 errno=110（写未落地）

## 三、正本清源：被证伪/修正的结论清单

| # | 继承的结论 | 真相（一手证据） |
|---|---|---|
| 1 | "MTK Case 3b 无条件写 rb_left" | ❌ 假（rbtree.c 对称写，fresh-eyes 已否，源码再确认） |
| 2 | "写不落地 = 地址数学错" | ❌ 假（oracle 阴性→walk 早退；mt22 后证明地址对） |
| 3 | "Δ 未知导致失败" | ❌ 假（Δ=0 已被双目标命中证明） |
| 4 | "成功率 30-50%" | ❌ 虚高（实测 10-25%，mt22 后 16 次不中） |
| 5 | "TASK_CRED_OFF=0x820" | ❌ 错（0x780，commit_creds 反汇编铁证） |
| 6 | "假 cred 页方案" | ❌ 崩（mt29 attempt3 panic；应写 init_cred） |
| 7 | "Permissive 是目标" | ❌ 误（Permissive≠root，只是安全网/中间步骤） |
| 8 | "两段式必须 mt25 热身" | ⚠️ 不完整（mt26 单跑也成功过 round4；热身提高成功率但非必须） |

## 四、当前真实状态（一手证据）
- 设备：Enforcing, boot_id=d686e098, /data/local/tmp/preload.so = mt30 (7bf01365, 写 init_cred 版)
- 主线卡点：**mt30 写 init_cred 不崩了（vs mt29 崩），但 futex trigger 全 errno=110 → 写未落地**
- 未解决：为什么 mt30 的 Case-2 写"触发但没写进去"（futex trigger 超时 = walk 没到 rb_erase，或写位置仍不对）

## 五、真·未试维度（fresh-eyes 行动清单）
1. **mt30 写 init_cred 的落点验证**：现在写 target=task+0x780（cred 指针），但没验证"写进去后 cred 指针到底变没变"。需要 boot_id 观测法（tree_left=boot_id 可观测）确认 Case-2 在 CRED 单词下是否真触发
2. **futex trigger errno=110 的根因**：6 连发全超时 = walk 没执行 rb_erase。这是"写未落地"的直接原因，但 mt29 假 cred 时也这样却能崩（说明 walk 到了）——需要搞清楚 trigger 时序
3. **写值对齐**：ghostlock W2 写的是 child_task 的 cred 指针（专门子进程），我们写 perf 泄露的 task。可能 target 进程不对
4. **触发时序**：mt30 的 futex_lock_pi 触发（50ms）是否真的在 walk 期间执行——需要加时间戳验证

## 六、下一步（一句话）
主线 = **让 mt30 的 Case-2 写真正落地**（验证写值 + 修 trigger 时序），而非继续刷 Permissive 或纠结 Δ。

