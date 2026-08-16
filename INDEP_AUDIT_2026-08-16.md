# 独立审计：对面叙事逐条重验（2026-08-16 深夜·第二班）

> 监工指示：**不要被对方一些想法误导。**
> 方法：不采信任何一方的结论性表述，把对面最近三轮提交
> （`82f5625`/`3faad4c`/HUNT_RESULT/PROBE_RESULT）里的每个说法当作
> 待证伪命题，用代码（git diff v30 快照 vs HEAD）、仓库日志
> （logs_raw/mt26_selinux.txt、mt26x_SUCCESS）、脚本（test_mt26/47/49）
> 和反汇编档案重新过一遍。
>
> **总账：事实层面对面基本诚实（数据都能对上），但有三处叙事框架在
> 系统性带偏方向；另外我自己昨夜也有两处表述过头，本轮一并修正。**
> 代码交付：mt54（`PSELECT_PTR_RIGHT` + `PSELECT_WAIT_SECONDS`）已推。

---

## 一、对面说法逐条裁定

### 1. "ENF 命中是多轮概率（mt26 第 4 轮才中）→ 多跑总会中"
**裁定：误导性归纳（半真）。**
- 全项目 ENF 总账：**12 轮 1 中**。唯一胜局 mt26 round4（08-15 晨窗）；
  其后 8 轮 0 中（13:15 mt47 四轮 + 今晚四轮）。
- 该框架隐含假设"单轮命中率 p 跨二进制/跨环境不变"。用 mt26 自己估
  p̂=1/4，之后 8 轮全 miss 概率 0.75⁸≈**10%**——不致命但可疑； pooled
  p̂=1/12 则是 50%——无法区分。**数据本身区分不了"低 p"和"环境杀"，
  对面把"多轮概率"说成既定事实是在给自己壮胆。**
- 反例就在对面自己的日志里没被承认：**今晚 round1=1.8GHz 满速，也没中**。
  "低频全 miss 符合预期"的解释对 round1 不成立。

### 2. "rc=255 = sleep 70 到期退出（不是崩溃）"
**裁定：结论对，机制错，且掩盖了一个真差异。**
- `sleep 70` 正常退出是 rc=0；124=timeout 击杀。**mt26 胜局那轮恰恰是
  rc=124**（挂满 220s 被杀，logs_raw/mt26_selinux.txt:13）。
- rc=255 = 进程自己以 -1 退出。源码 grep 无 `exit(-1)`（只有 util.c:397
  `exit(0)` 和 mt47 流程注释里的成功 `exit(42)`）→ **出处未定位**。
- 真正证明"没崩"的是 boot_id 未变 + 子进程活着——这个对面做对了，但
  "sleep 到期"这个机制解释是编的。**账本里应以 boot_id 为准，rc 只做
  旁证。**
- 已自查排除的方向：rc=255 早退**不**缩短比赛窗口——RUNLOG 里 6 发
  全记录在案（futex 0-5 errno=110），说明消费周期完整跑完才退。

### 3. "perflock 压不住 → 降级仪式；冷启动+满电+充电器=唯一实证窗口"
**裁定：前半句事实成立（4 轮 350-1250M 实测，无争议）；后半句 n=1 仪式化。**
- "晨窗"的全部证据 = mt26 那一次 boot 上的 1/4。可以照做，但别当定律。
  若明早满速核实后仍全 miss，**下一步是嫌疑转移（见 §三），不是再调
  充电姿势**。
- 顺带：mt26 当时是否插着充电器，账本里没有记录——"满电+充电器"是
  事后补忆的条件，不是当时记录的观测。

### 4. "探针存活 = cred 机制无罪、假说 v2 加强"（PROBE_RESULT 判读 1）
**裁定：膨胀回潮。**
- 我在 PROBE2_REPLY 已明确修正过：**miss 轮没有树手术、没有毒树、没有
  审计可谈**。探针证明的只是"机制（fork/perf/poll）不会独立弄死一轮
  miss"——这是有价值的排除项，但和 v2 的核心主张（win 后审计时的
  owner 状态决定生死）**无关**。对面的判读又把"v2 加强"写回去了。
  v2 的证据基础仍然是 n=1（mt26 活）对 n=2（mt48/49 死），没有任何增加。

### 5. "TREE_PC=ffffff8002a41b90 写死地址跨 boot 复用"
**裁定：这个对面（无意中）是对的，我本轮撤销此疑点。**
- 独立推导链：`tree_pc = enforcing-8`（mt26x_SUCCESS 原文）；
  `ffffff8002a41b90` 是**线性映射别名**（common.h:122
  `P0_DATA_ALIAS_CONST = P0_PAGE_OFFSET | (image - KIMAGE_TEXT + phys_delta)`）。
  arm64 KASLR 只滑动内核映像 VA，线性映射基址不动 → **跨 boot 稳定**。
  mt26（08-15 boot）与今晚（7400efc2）共用同值是合法的。

### 6. "mt53 之后 win 即静默"
**裁定：不完全——这是我自己的 spec2 漏的，不是对面的错。**
- 消费线程静默了 ✓；owner 线程永不解锁 f_pi_target（slide.c:467
  `for(;;) sleep(1)`）✓。
- **但 waiter 的 30s WAIT_REQUEUE_PI 超时是 win 前就上膛的内核侧定时器**：
  到期 → remove_waiter → 对毒树 double-erase + prio_chain walk。
  mt26 胜局那轮 30s 超时走毒树活了下来，属 n=1 运气。mt53 管不到它。
- **今晚 mt54 修掉**：`PSELECT_WAIT_SECONDS` 把超时抬到进程寿命之上，
  清理只走进程退出路径（futex_exit_release，0 断言，不走 waiters 树）。

---

## 二、我自己昨夜的两处过头表述（自我修正）

1. **"6 all-miss → trigger-chain degradation suspicion" 说重了。**
   git diff（v30 快照 `1461276` vs HEAD）实证：自 mt26 胜局以来，纯 ENF
   触发路径只改了两处——mt51 发间状态文件读（纯 ENF 下 open 必 ENOENT，
   ~10μs×5）和 mt53 胜后跳 UNLOCK（miss 轮零影响）。**且 13:15 那 0/4
   的 mt47 二进制连 mt51 都没有**——它的触发路径与 mt26 胜局版几乎逐
   字节一致，仍全 miss。⇒ 代码退化对纯 ENF 而言**降为低嫌疑**；0/8 的
   主解释回到环境+概率。明早满速纯 ENF 复刻是正确的判别实验。
2. **"morning ENF 4/4" 的统计我已经修了，但 spec2 里 v2 的措辞仍偏强。**
   "owner 活=EDEADLK 出口不审"是反汇编推导，未经满速现场验证；
   mt26 的存活既可以是 EDEADLK 出口，也可以是当次 walk 根本没走到
   审计分支。修复轮的存活预期应表述为"受控首测"，不是"已设防"。

---

## 三、明早 runbook 收紧版（不推翻 spec2，只收紧）

spec2 的主体（静默纪律、雷区表、win 后父 shell 观察）维持。改动四点：

1. **6 轮预算拆 3+3**：
   - **前 3 轮 = 纯 ENF 复刻**：`PSELECT_SLIDE_TRIGGER=1 PSELECT_RETRY=1
     PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0`，**其他一概
     不加**（无 CRED/无 GEOM_KEEP/无机制）——与唯一胜局的 env 逐字段
     一致，唯一变量 = 晨窗环境本身。
   - **后 3 轮 = ENF+机制**（v2 网格需要的数据）。
   - 理由：原计划"ENF+机制"一步到位，全 miss 时环境和机制两头都学
     不到东西；拆开则前 3 轮直接回答"现二进制在满速下还中不中"。
2. **老二进制 A/B（若可）**：`ls /sdcard/Documents/matisse_backup_essentials/*.so`。
   若 mt26 时代的 .so 还在，加跑 2 轮同 env 老二进制——代码轴一次判死。
   （仓库里只有 preload_mt46.so 一份历史件。）
3. **每轮记录起止时间戳**（`date +%s` 打头尾）+ logenv 照旧。rc 值照记
   但判活以 boot_id 为准。
4. **win 后 60s 观察 by 父 shell**（getenforce / 子进程 CapEff 轮询），
   触发进程能退就退——进程退出不走毒树（spec2 已证），比进程挂着被
   观察更安全。

**判读表**：前 3 轮满速出现 win → 环境故事成立，转修复轮；前 3 满速
全 miss + 老二进制命中 → 代码轴定罪（再 bisect mt51 或机制）；前 3 满
速全 miss + 无老件 → p 重估（p̂<1/12），预算改加轮而非改仪式。

---

## 四、mt54 交付（已在仓库，默认行为逐字节不变）

| env | 作用 | 修复轮取值 |
|-----|------|-----------|
| `PSELECT_PTR_RIGHT` | 覆盖 PTR 模式写死的 init_cred dmap 别名（main.c 原 :820）；GEOM_KEEP 救不了 PTR 轮（pc 必须来自运行时 perf 泄露，外部不可预知），故只放行 right 单项 | `spray_base+0x3800`（十六进制） |
| `PSELECT_WAIT_SECONDS` | 覆盖 waiter 30s 默认超时，把 remove_waiter 定时炸弹抬出进程寿命 | `120`（> sleep 70s） |

**修复轮 env 终版预览**（win+存活后同 boot 解冻）：
```
PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
PSELECT_PTR_STRICT=1 \
PSELECT_PTR_RIGHT=<spray_base+0x3800> \
PSELECT_WAIT_SECONDS=120
```
**落地前必核对 RUNLOG**：`mt48: PTR ... right=... [PTR_RIGHT override]`
——没有 override 标记 = 静默回落 init_cred = 2/2 致死几何，立即停。

---

## 五、待现场三件小事（都是分钟级）

1. 一份今晚 RUNLOG 的**尾 3 行**（定位 rc=255 出处，纯账本卫生）。
2. `mt47_root.txt` 里 13:15 四轮的 **rc 值**（若也是 255，说明早退是
   mt47 起的行为，与 mt26 的挂死不同源——记录在案即可）。
3. 旧 .so 清单：`ls -l /sdcard/Documents/matisse_backup_essentials/*.so`。
4. （沿用未结项）mt26 round4 原始 futex 行：仓库里的 mt26_selinux.txt
   是摘要无 futex 行；若设备上 RUNLOG 已被覆盖就明说，win 签名维持
   代码推导版（ret=0 = win，errno=110 = miss）。

—— 评审（deepseek 名义）· 不代表对面结论 · 数据可复核
