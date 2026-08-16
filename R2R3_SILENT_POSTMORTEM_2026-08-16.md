# R2/R3 哑轮尸检 + mt59（2026-08-16 深夜，离线完整版）

现场已按规则 (a) 收工。本文是承诺的离线尸检：用 R2/R3 完整原文 +
源码逐行追链，把"哑轮"钉死到具体竞态，并交付 mt59 修复 + 明日 runbook。

## 一、卡点定位（源码逐行，非推测）

R2/R3 日志形态：`mt28m` → `mt33` → **直接进入 alive poll**，此后直到
harness 击杀（rc=124）零输出。

父进程路径（main.c:896→899）：mt28m 打印 → `slide_child_leak_stext()`
（slide.c:608）→ 三个 pthread_create → 就绪自旋 → CMP_REQUEUE_PI →
**route_done 等待（slide.c:625，无超时无打印）**。

哑轮 = 父进程泊在 :625，waiter 泊在 WAIT_REQUEUE_PI（:503），
consumer 因 consume_go 从未置 1 而全程空转（:293-299）——三方静默互等，
每一步都是合法阻塞，没有任何东西出错，所以一行日志都没有。

## 二、根因：owner 排队与 requeue 开火之间的微秒窗

编舞时序（slide.c:474-538, 608-630）：

```
waiter: LOCK_PI(chain) → ready=1 → 等 owner_started
owner : LOCK_PI(target) → 等 waiter_ready → owner_started=1  ← :532
                                                        ↓ 微秒窗 ← ★竞态★
owner : LOCK_PI(chain)  ← :533 (设计上泊到 waiter 放锁, 构造深 PI 链)
main  : 就绪自旋过 → CMP_REQUEUE_PI                      ← :622
waiter: WAIT_REQUEUE_PI 泊入 f_wait                       ← :503
```

**赢（R1 形态）**：owner 先在 :533 排进 chain 的 waiters 树 → requeue 把
waiter 挂上 target 树 → PI 环成形（waiter→target[owner=owner]，
owner→chain[owner=waiter]）→ 内核 PI-walk 检出环 → **EDEADLK 快路径**：
waiter 带错误立即返回 → :505 放 chain → :512 stack_copy（几何 fdset +
canary + consume_go=1）→ consumer 开火 → trigger ret=0 = WIN。
R1 的尾弹 errno=35（=EDEADLK）正是环存在的直接物证。

**输（R2/R3 形态）**：requeue 抢在 owner 排队落地之前 → 环不存在 →
requeue "成功"但无人死锁 → waiter 在 target 树上**泊满 200s**（mt54 的
PSELECT_WAIT_SECONDS）→ consumer 永远等不到 consume_go → harness 先一步
击杀 → 六十余行沉默。

今晚 3 轮 1 赢 2 输 ≈ 竞态窗 vs 线程调度延迟的自然命中率。同二进制同
env（R1/R2/R3 全部 mt58）证明这是**固有竞态**，不是 mt56/mt57 回归
——mt57 canary 第三重排除：canary 埋在 stack_copy 阶段（slide.c:240），
哑轮根本没走到那一步，canary 在因果链下游。

## 三、哑轮的安全性（重要，别白怕）

哑轮的树**从未毒化**：毒化来自 stack_copy 的几何 fdset 与 consumer 的
trigger 写——哑轮两者都没发生。waiter 200s 超时清理走的是**普通未毒树**
的 remove_waiter，安全。R2/R3 后 boot 存活、getenforce 正常，与此自洽。

## 四、mt59 修复（已实现+已编译，默认生效）

四处小编辑，全部在 slide.c，赢路径行为不变：

1. **chain-armed 握手**：owner 在 :533 排队前先亮
   `slide_owner_chain_armed` + 打印 `mt59: owner armed`
2. **开火延迟**：main 等 armed 后再 `usleep(20ms)` 才发 requeue——
   把"owner 已排队"从运气变成前提，R1 形态确定性复现
3. **EAGAIN 重试**：另一半竞态（main 快过 waiter 泊入）——requeue 返回
   EAGAIN 时重试至多 5 次（10ms 间隔），不再让整轮哑掉
4. **12s 看门狗**：route_done 12 秒不到（合法路径 ≤ pselect 2s + 风暴
   数秒）→ 打印 `mt59: STALL ... rc=3` → `_exit(3)` 快速弃轮。
   哑轮从"泊到 harness 击杀"变成 12 秒自弃，且**留下死因行**

编译验证：NDK r29 / API 35 / 同 Makefile 配方，零错误（仅 fops.c 一个
项目固有 warning）。产物 `bin/mt59/preload.so`，
SHA256 `1064e413aa9eb5113ccb50ac9e160aeae9c160cbe9f145f90ca0f0b5ae2bd45f`。
二进制内六组防护标记齐全（mt59 armed/requeue/STALL + canary +
PTR_RIGHT auto + skip UNLOCK_PI）。

## 五、明日 runbook 增量

- **新 rc 语义**：`rc=3` = mt59 看门狗自弃（哑轮，安全，立即重跑下一轮，
  不耗 dirty/freeze 预算）；`rc=124` 保留原语义（真挂死，查）
- 部署：`cp bin/mt59/preload.so /data/local/tmp/preload.so` +
  核对 SHA256（见上），su_daemon 不变
- R 直打序列照旧（Enforcing、胜局配方、mt53/54/55 纪律全保留）；
  预算重置：dirty 0/2、freeze 0/2
- 判读表新增一行：`mt59: owner armed` 后接 `requeue fired ret=0` =
  竞态已按 R1 形态锁定，之后走原表
- 预期变化：哑轮概率从今晚的 ~2/3 压到近零（ armed+延迟消掉主竞态，
  EAGAIN 重试消掉副竞态，残余窗口由看门狗兜底成 12s 自弃）

## 六、今晚净账

- R1：walk ✓ 静默窗 ✓ Enforcing 直打路线 ✓ 落地 ✗（dirty 打歪）
- R2/R3：哑轮 ×2（竞态输，零消耗）
- 根因闭环 + mt59 交付：明天的每一轮都该是"R1 形态"——剩下的问题
  只有打歪（几何）与落地（假 cred 消费）两件老事

—— 评审 · 离线尸检 · mt59 已编译待部署
