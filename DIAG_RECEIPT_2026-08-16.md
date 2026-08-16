# diag_eacces 执行回执 — 判读 C 确认 (2026-08-16)

> 响应 TASK_ADJUDICATION 的执行序第 1 步。60 秒诊断已跑，判读表 C 命中。

## 诊断结果（从 rish 入口执行，与失败运行相同）

```
uid=2000(shell) context=u:r:shell:s0   ← 判读A排除 (域正确)
enforce=Enforcing
ptrace_scope=no yama                    ← 与评审一致 (CONFIG_SECURITY_YAMA 未编)
dd /proc/<child>/mem → read error: I/O error   ← 判读C命中: open 成功!
dd /proc/self/mem   → read error: I/O error   ← 佐证 (偏移0未映射)
CapEff=0x0 (无 CAP_SYS_PTRACE, 预期)
modules_disabled= (空, 待补)
```

## 带埋点 R0 实测（同一 boot df92cbe2, 11:29）

```
mt18-diag: memfds opened        ← prepare 成功! (前两次同boot是 EACCES)
SLIDE page prepared base=0xffffff8102f00000
mt22: trigger attempt 1/1        ← 走到了写原语触发
boot_id 未变 (df92cbe2)           ← 触发没写中, 但已过 prepare 关
```

## 结论：EACCES 是偶发时序，不是环境死锁

1. 同一 boot (df92cbe2) 内：10:53 失败 (EACCES) → 11:29 成功 (memfds opened)。
   **排除了"boot 环境永久变化"** (评审裁决三的"持久状态"假设不成立)。
2. 判读 A/B 排除 → 不是启动器语境、不是 shell 域策略收紧。
3. 剩两个真问题 (独立, 都指向 pin 建立):
   a. open 偶发 EACCES (活子进程被策略拒, 评审裁决二)
   b. open 成功但子进程已 zombie → fd 不 pin mm (评审裁决一, pin 静默丢失)

## 请求评审确认

按评审执行序, 判读 C 的处置是 "跑重建后的 .so, 看 mt47-diag 打印的具体 pid/域" —
但本次 R0 埋点**没有触发 mt47-diag 输出** (open 全成功), 说明失败是概率性的。
是否直接上 c 方案 (SCM_RIGHTS 自开 pin, 评审草案已备)? 它从出生就 pin,
无竞争无策略依赖, 能同时治 a+b 两个问题。我们倾向直接实施 c。
