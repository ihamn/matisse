# PTR 轮崩溃报告 — 写 init_cred 又崩了 (2026-08-16)

> 请求外部评审分析。c 方案修复生效，R0/ENF 全过，但 PTR 第 1 轮写执行时设备崩溃重启。

## 前置成果（都成功了）
1. R0 判活：df92cbd0 → df92cbd0-0485-4381（bytes[3..10] 清零，3 轮版 round 2 命中）
2. ENF：round 2 → **Permissive**（mt26 配方成功，SELinux 已关）
3. c 方案 pin：**mt47-c: leak pin via SCM_RIGHTS OK (fd=517)** — 修复生效

## PTR 轮日志（崩溃前最后几行）
```
mt28c: perf task=0xffffff821270b780 (154/256 votes)
mt39: cred_cand=ffffff827fb98e40 votes=28
mt47: PTR_MODE task=ffffff821270b780 pc=ffffff821270bef8 right=ffffff80027b0ae0
mt28m: cred write attempt 1/1 fake_cred=ffffff80027b0ae0
mt33: child pid=24372 task=ffffff821270b780 blocking-for-cred-write
```
→ 日志在此戛然而止 = 写执行瞬间内核 panic → 重启

## 事实
- pc=ffffff821270bef8（末位 8 = 偶数 ✓ 无 rebalance 理论成立）
- right=ffffff80027b0ae0（init_cred dmap）
- STORE(a) 写 [task+0x780]=init_cred 的瞬间崩
- **无 root_alive、无 ksu_done**（写没落地就崩）
- 新 boot 704bd84c

## 与 mt32-36 崩溃模式的关联
历史：mt32-36 写 task->cred=init_cred 崩 6 次，当时解释为 __put_cred BUG_ON。
您的裁定：STORE(b) 副作用把 usage 抬到 1.5e9 → BUG_ON 免疫。
**但实测又崩了** — 崩溃时机在"写执行瞬间"（子进程刚 blocking），
不像 __put_cred（那需要进程退出时才触发）。更像写本身触发了 panic。

## 请求裁定
1. 崩溃点在 STORE(a) 还是 STORE(b)？（rb_erase 的两个写，哪个落非法内存？）
2. pc=task+0x778（ffffff821270bef8）→ STORE(a) 写 [pc+8]=[task+0x780]。
   task+0x778 落在 task_struct 内部？还是 slab 边界？写 init_cred 别名会不会
   触及只读页（init_cred 在 .data 段，可能 RO）？
3. init_cred 别名 0xffffff80027b0ae0 是**只读**的吗？写只读页 → 直接 panic。
   这能同时解释 mt32-36 的 6 次崩溃 + 这次崩溃 — 而且不是 __put_cred，
   是**写只读页**！请用 ELF 确认 init_cred 所在段的权限位。
4. 若确认 RO：STORE(b) 写 [init_cred]=pc 是否也落在 RO 页 → 整个 PTR_MODE
   结构性写 RO → 必崩。那路线 B 需要改写法（如先改页权限？或换目标对象？）

## 设备侧可补的实验（等裁定后）
- pstore/dmesg 崩溃栈（需 rish + root，稍后补）
- 若 RO 确认：改 PTR_MODE 写一个可写对象（如当前进程的 cred 副本）再试

—— matisse 现场 (2026-08-16 11:50)
