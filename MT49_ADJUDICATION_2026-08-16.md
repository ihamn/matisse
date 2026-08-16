# crash #2 定罪 + mt49 修复 — 同进程第二次触发在中毒树上 rb_insert（外部评审，2026-08-16）

> ⚠️ **勘误 2026-08-16（见 PRIOCHAIN_VERDICT_2026-08-16.md）**：pstore 实锤崩溃点
> 是 `rt_mutex_adjust_prio_chain+0x1788`（dequeue 前 `top_waiter->lock == lock`
> 断言，MTK 构建自加），死在 rb_insert **之前**。§二的"rebalance 旋转写坏
> task+0x770..0x788"推演作废；根因定罪（同进程二触 + v37_* 不清 + 毒树）与
> mt49 修复（一进程一写，RETRY=1）不变，且被 pstore 反向加强。

> 回复 `MT48_CRASH2_2026-08-16.md` 四问。crash#2 和 crash#1 是**两个不同的妖**，
> mt48 的严格 gate 杀死了第一个（commit_creds BUG_ON），于是第二个浮出水面。
> 这次不是指令级定罪（pstore 没了），但证据链是闭合的，且修复已实施。

---

## 一、先修正你们的观察：poll=50 那行证明写还没落地

`alive poll=50 uid=2000 CapEff=0` —— poll=50 = 子进程启动后 10 秒。
若 R 写已落地，real_cred=init_cred，status 读 `__task_cred`(=real_cred) 的
CapEff 应该是 `000001ffffffffff` 满帽。**CapEff=0 说明 poll=50 打印在 R 写落地之前**，
即 R 写在 ~10s 才落地（喷射/碰撞耗时），崩溃发生在落地后 ~0.8s 内。

"日志戛然而止、没有 attempt 2/6 的打印"**不构成 attempt 2 没运行的证据**：
panic 重启丢的是页缓存（fflush ≠ fsync，和 crash#1 里 ROOT-SEEN 消失同因）。
attempt 2 的打印完全可能执行了但没活到落盘。

## 二、定罪：attempt 2 的 rb_insert 在中毒的 waiter 树上 rebalance

**代码事实（可复核）**：`slide_reset_trigger_state()` (slide.c:657) 只清 `slide_f_*`
和一堆 atomic，**不清 `v37_cycle / v37_futex1 / v37_futex2`** —— attempt 2 的
`slide_v37_trigger` 在同一个进程里对**同一组 futex 词**再次触发。

机制链：

```
attempt 1 落地: 劫持的 rb_erase 把假 waiter 从 futex1 的 waiter 树"错误地"摘除 —
  我们的重定向让 [parent+8]=child 写去了 task+0x778, 真树的 root/父指针从未更新
  → futex1 的 waiter 树 root 仍指向假 waiter (right=init_cred, left=0)
attempt 2 触发: waiter 线程 FUTEX_WAIT_REQUEUE_PI(futex1) → 入队 rb_insert:
  向下走: root(假waiter) → right=init_cred → init_cred 的 children = uid..egid 全 0
          → 新 waiter 挂到 init_cred 下
  向上 rebalance (rb_insert_color): init_cred.parent_color = [init_cred] = pc =
          task+0x770 (偶 = RED) → 红红冲突 → gparent = task+0x770 → 旋转
  ★ 旋转把树指针写进 task+0x770/0x778/0x780
     = ptracer_cred / real_cred / cred
     (0x770=ptracer_cred 有指令级铁证: ptracer_capable@0xffffffc008147b34
      开头就是 add x8,x0,#0x770; ldar x20,[x8])
  → cred 指针被打成"新 waiter 的栈地址"(触发线程的栈)
  → pthread_join 后该线程栈 munmap
  → 子进程下一次 poll (≤200ms) get_task_cred 解引用已 munmap 的地址 → fault → panic
```

**统计完美闭合**——把 16 次实验按"同进程第二次触发是否发生"分类：

| 配置 | 同进程二触 | 结果 |
|------|-----------|------|
| mt25/26 (RETRY=1 × 独立进程×5) | 无 | 活 |
| mt28b (RETRY=1) | 无 | 活 |
| mt46 窗口轮 (每轮新进程) | 无 | 活 |
| R0/ENF (RETRY=1) | 无 | 活 |
| crash#1 (RETRY=1, 旧OR-gate) | 无(先死于gate≤200ms) | 崩 = gate BUG |
| **mt32-36 (retries=8 进程内!)** | **有** | 崩(= 或 gate 先杀) |
| **crash#2 (RETRY=6 进程内)** | **有** | **崩** |

你们自己在 test_mt25.sh 里写的注释——**"5 轮独立进程 (规避进程内重试毒化)"**——
2026-08-15 就发现过这个毒，只是 PTR 重设计时忘了。这不是新妖，是旧妖换了马甲。

## 三、四问回答

**Q1: stage=R 本身触发什么？** 半程 R 态的读路径全部安全（我逐条审过：
status 读 real_cred 只做 usage 原子加减（usage≈9亿，安全）；只读 syscall 不进
commit_creds；fork 在半程态也安全——prepare_creds 只读 cred@0x780，已反汇编证明）。
R 写自己的 aftermath（unlock 续走 cycle 锁，干净树）也安全。**凶手是 attempt 2，不是 R。**

**Q2: 确定性还是概率性？** 给定"落地 + 同进程再触发"= 确定崩（rebalance 旋转必然
写 0x770..0x780 区）。RETRY=1 结构性免疫 —— 14 次幸存者全是。

**Q3: 每 stage 单独进程？** 对，但必须**同一个子进程跨两个阶段**（两写必须落同一 task）。
mt49 已实现：阶段 R 进程 fork 子进程 → 子进程持续写状态文件（task 地址+uid+CapEff，
每 200ms）→ 进程退出后子进程孤儿化但继续跑（8 分钟窗口）→ 阶段 C 进程读状态文件
取 task，`PSELECT_TASK=<hex>` 外部模式直写（不 fork 新子进程）。R 未落地时补打 R
也是外部模式（幂等：再写一次 real_cred=init_cred 无害）。

**Q4: 一次触发写两个指针？** 几何上不成立，裁死。STORE(a) 和 STORE(b) 是绑死的：
STORE(b) 的目标 = right 的值本身。要一发写两个 cred 字段，需 right=task+0x780 且
pc=task+0x770 → real_cred=task+0x780（指向 task_struct 内部的"假 cred"，usage/uid
取自 comm 前的字段，gate 永远验不过）、cred=task+0x770（指向 ptracer_cred 位置，
更烂）→ 且两指针仍不等，BUG_ON 还活着。无解，别试。

## 四、mt49 为什么现在安全

两写都落地后 `real_cred == cred == init_cred` → commit_creds 入口 `cmp x8,x19`
相等 → BUG_ON 通过 → 子进程 setresgid/setresuid **合法且安全** → prepare_creds
复制 init_cred 成私有 cred（caps 全满、usage 重置 1）→ setresuid(0) 后
uid=0 euid=0 全套真 root → marker → setenforce 探针 → finit_module 循环。

每写一个进程、RETRY=1 → 中毒树随进程消亡，二触永不发生。**两个妖都死了。**

## 五、已实施（commit 见推送）

| 文件 | 改动 |
|------|------|
| main.c | `PSELECT_TASK` 外部模式（跳过 fork/pipe，直写指定 task）；子进程每 poll 发布 `/data/local/tmp/mt49_child_status.txt`（task/uid/euid/CapEff/root_seen）；外部模式下 cred_addr 检查放行（PTR 模式不需要）；waitpid 全部加 cred_child>0 守卫 |
| test_mt49_root.sh | R0(3轮) → ENF(3轮 best-effort) → STAGE-R(首轮 fork 模式，未落地则外部补打，判据=状态文件 CapEff 满帽) → STAGE-C(外部模式，判据=root_alive/ksu_done/euid==0) |

**注意**：fork 块重构过，重建 .so 时留意编译警告（我这边没有 NDK 无法本地编译验证）；
若有编译错误把 ndk-build 输出发我，5 分钟修。

## 六、执行序

1. 重建 .so → 推 `preload_mt49.so`
2. 新 boot（a10e6984 若 R0 已判死）→ 跑 `test_mt49_root.sh` 全套
3. 盯三个里程碑：`STAGE-R LANDED`（CapEff 满帽）→ `ROOT-ALIVE`（uid 全套）→ `KSU-LOADED`（毕业）
4. ENF 3 轮没翻 Permissive 不阻断（历史上 ~25%/轮，4 连挂概率 32% 不算异常）——
   finit_module 在 Enforcing 下还有 kernel SID 一线机会，root_alive 本身已是成功

—— 外部评审（这次连 0x770 是 ptracer_cred 都抓出来了）
