# 探针命令 + 喷页规格第一部分 + 假说 v2（外部评审，2026-08-16 深夜）

> 回复 `FIELD_FEEDBACK_WALL` 三问。
> **一句话：探针命令在下面（但需要先部署 mt52 补丁 —— env 直接组合会被
> setenv 覆盖跑成错误几何，这个坑是我审代码时发现的）；规格第一部分今晚
> 交付（审计的完整入口条件 + 两个逃生口）；同时两件事：我的喷页转向假说
> 被今晚的反汇编判死（v2 替换），以及 —— 喷页里 mt35 时代就建好的假 cred
> 被我重新发现，路线修复比预想近得多。**

---

## Q1：探针的确切命令（先部署 mt52，再跑）

**⚠️ 为什么不能直接 env 组合**：`main.c:849-851`（原）的 `setenv(..., 1)`
会**覆盖**外部传入的 `PSELECT_TREE_PC/RIGHT/LEFT` —— 直接把 ENF 配方和
`PSELECT_CRED=1` 拼在一起，实际跑的是 cred 窗口扫描几何（pc=cred-8），
根本不是 ENF 写入。**这个探针原本无法用 env 跑**，我今晚加了
`PSELECT_GEOM_KEEP=1` 守卫（mt52，已在仓库）跳过覆盖，保留外部几何。

**步骤**：
1. pull + 重编 .so（改动只有 main.c 三行守卫，行为默认不变）
2. 在**当前 boot 7400efc2**（闲置未动，正合适）跑一次：

```sh
timeout 120 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 \
  PSELECT_GEOM_KEEP=1 \
  PSELECT_TREE_PC=ffffff8002a41b90 \
  PSELECT_TREE_LEFT=0 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 70 > /data/local/tmp/probe.out 2>&1
echo "enforce=$(getenforce)"   # 判读点
```
（`TREE_RIGHT` 不设 = 默认 fake_lock 喷页 —— 与上午 ENF 4/4 成功的几何
**逐字段一致**，唯一新变量 = cred 机制本身：fork 子进程 + perf 泄露 + 状态
文件轮询。）

**判读**：
- **存活 + `getenforce` 变 Permissive** → cred 机制无罪，ENF/PTR 分裂
  归因几何，假说 v2 的"几何→退出路径"链条加强
- **崩溃** → cred 机制（fork/时序）是分裂变量 → pstore 立即拉，把
  `console-ramoops-0` 原文贴仓库
- 每轮照旧 pstore。

## Q2：喷页偏移规格 — 第一部分今晚交付（审计地图）

### 审计块的完整语义（+0x14c0，今晚反汇编）

```
入口（唯一来源 +0x0a18 b.ls）:
  前置: [x27+0x18] <= 1        ← x27=当前walk的锁, +0x18=owner 字段
                                 owner == NULL(0) 或 1(RT_MUTEX_HAS_WAITERS,
                                 无主但有等待者) → 走审计分支
  对照另一条: +0x040c b.eq (owner&~1 == current task) → EDEADLK 路径
              (+0x14b8: w27=-0x23=-EDEADLK) → 解锁退出, ★不经过审计★

审计体:
  +0x14c0: ldr x8,[x27,#0x10]   ← waiters.rb_leftmost
  +0x14c4: cbz x8 → 跳过        ← ★逃生口1: 树空(leftmost=NULL)则整段跳过★
  +0x14c8: ldr x9,[x8,#0x38]    ← leftmost_waiter->lock (我们的 w7!)
  +0x14cc: cmp x9,x27
  +0x14d0: b.ne → brk#0x800     ← 不等 = panic
```

### 由此得出的三条硬结论

1. **喷页转向假说（v1）判死**：审计比较的是 `waiter->lock == 当前锁`，
   与 w1 指向喷页还是 init_cred **无关** —— [w1+0x38] 无论放什么都不可能
   等于真锁地址（用户态不可知）。喷页内容救不了审计。自我修正 #3。
2. **ENF 存活的真正解释（假说 v2）：退出路径分裂**。EDEADLK 路径
   （owner==current，GhostLock 拓扑设计的环）**不经过审计**；只有
   owner==NULL/1（**owner 线程已退出/被清理**）才进审计。上午 ENF 四轮：
   owner 存活、走 EDEADLK 出口 → 不审 → 活。PTR 两崩：owner 已死（fork
   机制/窗口时序把 walk 推进了 owner-NULL 清理路径）→ 审计毒树 → 崩。
   **可检验推论**：两次崩溃的 pstore 若能确认 walk 的锁 owner 为空，即坐实。
3. **审计免疫 = 时序纪律而非内存内容**：写入必须发生在 owner 存活期间
   （walk 走 EDEADLK 出口）；owner 退出后的任何 walk（包括 futex 退出
   清理本身）若审计毒树即崩。这就是"一进程一写"之后还需要"写后即静默"
   的原因 —— 也是 crash#2 里 `Comm: sleep` 的死法候选。

### 路线修复的意外地基（重新发现）

`util.c:689-715`（mt35 时代写入）：**喷页 +0x3800 已经有完整假 cred** ——
usage=1、uid/gid/suid/... 全 0、五组 caps 全 0x1ffffffffff、+0x80 指向
+0x3900 的假 security blob（osid/sid=SECINITSID_KERNEL=1）、user=root_user、
user_ns=init_user_ns、group_info=init_groups。**当初为 content-write 路线
建的，全须全尾。**

修复形态（比我下午预告的更近）：`PSELECT_PTR_MODE` 的 `right_env` 从
init_cred 别名改成 `spray_base+0x3800` —— 一个 env/一行的改动，加上
"owner 存活窗口内开火"的纪律。**但在规格第二部分落地前不跑**（见下）。

## Q3：跑前准备 + 边界

1. **探针前**：重编 .so（mt52 三行守卫）。无新脚本 —— 命令即上面那条，
   可直接在 adb shell 里跑，或加进现有脚本 ENF 段落。
2. **PTR/fake-cred 修复轮：仍然冻结**。缺的那块 = 规格第二部分：
   **futex 退出清理路径**（`futex_exit_release`/`exit_rt_mutex` 在目标
   内核上的反汇编）—— 确认触发进程退出时毒树会不会被 exit 清理再走一遍
   （crash#2 的 `Comm: sleep` 可能正是死在这）。这块不出，修复轮的
   "写后静默"纪律就无从设计。我下一 session 交付。
3. 当前 boot 7400efc2 可用于探针；PTR 形状继续禁跑。

## 状态与分工小结

- 已交付：审计地图 + 逃生口 ×2（leftmost=NULL 跳过；EDEADLK 不审）、
  探针命令 + mt52 守卫、假说 v2、假 cred 重新发现
- 我欠的：规格第二部分（退出清理路径 + 修复轮最终几何 + 时序纪律 spec）
- 现场欠的：探针一次（判读如上）；两次崩溃 pstore 若有残留再拉一遍
  （v2 的 owner-NULL 检验）

—— 外部评审（今晚第三份修正报告：假说死了，但地基找到了）
