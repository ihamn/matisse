# R6 判读 + 系统性 bug 定位（评审侧）2026-08-17

## 总判决

R6 与 R5 逐行同构 = 链路确定性 ✓。R 写连续第三次未落地（R1/R5/R6）
**不是随机，是系统性 bug**：mt57 canary 的埋入顺序使 pselect 必然 EBADF
秒退，关闭了 consumer 风暴窗口——**自 mt57 起，写路径从未被武装过**。
修复 = 现有二进制内建开关 `PSELECT_NO_CANARY=1`，零改动、零重编译。
卡 4 = R7 带此开关，其余与 R6 一字不差。

## 证据链（三段互锁）

### 1. 对照样本（A 系列 vs R 系列的 pselect 行）

| 轮 | 版本 | pselect 行 | 窗口 | 风暴 |
|---|---|---|---|---|
| A1_2 (mt56) | 无 canary | `ret=6 errno=0 calls=1 sched_ok=1` | held | 打了 1 发 |
| R5/R6 (mt60) | mt57 canary | `ret=-1 errno=9 calls=0 sched_ok=0` | **EBADF 秒退** | **0 发** |

A1_1（真 WIN 轮，翻 Permissive）同代码同流程，日志被清但 rc=124
（pselect 挂满窗口被 harness 击杀）= 窗口 held 的旁证。

### 2. 代码顺序（slide.c:225-270）

```
225  prepare_slide_pselect_fdsets()   ← 几何字
226  open_slide_selected_fds()        ← dup read_fd 到所有已置位 fd
238  if (!getenv("PSELECT_NO_CANARY"))
       ... canary 埋入 ex 末词        ← 【bug】在 dup 之后！
270  pselect(...)                     ← do_select 扫到 canary 位 fd 未打开 → EBADF
```

canary 魔数 0x5CA7AB1E5CA7AB1E 低位全有 bit → 置位 fd 落在
NFDS 扫描范围内 → do_select 逐 fd fcheck 失败 → `-EBADF` 立即 break。

mt57 注释自述 "pselect 只读 ceil(nfds/64) 词, 内核永不触碰 ex 末词" —
**几何算错了**：wps = ceil(NFDS/64)，ex 末词 = 第 3*wps-1 词，
恰在 pselect 读取范围**之内**（3 个 set 各读满 wps 词）。作者意图
（藏在读取范围外）在数学上不成立——任何非零 64 位魔数都会被扫到。

### 3. 机制后果（为什么 EBADF = 写路径死火）

- pselect 的 fdset 拷贝落在 waiter 线程**内核栈**复用帧上（CVE 栈驻
  rt_waiter UAF 的本体）——几何只要写进去就在毒树节点里。
- 但 erase 触发者是 **consumer 风暴**（sched_setscheduler →
  rt_mutex_adjust_prio → 走毒树 → dequeue → rb_erase → STORE(a)）。
  它只在 pselect **窗口内**（go=1 期间）开火。
- EBADF 秒退 → go 立即归零 → consumer 2000-yield 自旋还没走完窗口
  就没了（calls=0）→ **窗口内零触发**。
- 窗口后 waiter 线程自己跑 mt19b sched + mt25 trigger——这些 syscall
  的栈帧覆写同一区域，erase（若有）读到的是被覆写的几何 → 写去随机
  地址。R1/R5/R6 无崩无 canary 命中 = 这些盲写恰好都落无害处（运气），
  **不代表写路径工作**。

trigger 0 ret=0 的旧解释（"WIN 签名"）同步降级：A 系列真窗口流里
trigger 是 errno=110（窗口内、由 consumer 打）；R 系列的 ret=0 是
窗口后盲走。mt53 的 ret=0 检测继续保留（skip UNLOCK_PI 仍对），但
它不再是"写已武装"的证据。

## 为什么三个旧疑点同时关闭

1. "R 写从未落地 vs C 写历史 7 次落地"——PTR 判读表实证历史落地全是
   pc=task+0x778（C 式几何）；mt48 的 R 式 pc=task+0x770 **从未在
   canary 存活的窗口里被试过**。R 几何本身无罪，死于窗口。
2. R1 的 "trigger 0 ret=0 = WIN 签名" 误判来源 = 同一 EBADF 盲走。
3. bad leaked pointer 噪声判定不变。

## 修复方案

- **立即（零构建）**：R7 配方加 `PSELECT_NO_CANARY=1`（slide.c:238
  已有此开关，mt60 二进制内已编译）。窗口恢复 → 风暴恢复 → 写路径
  首次在 mt48 几何下武装。
- **下版（mt61）**：canary 埋点移到 dup 之前（既保 canary 又保窗口），
  另修 main.c:896 mt28m 打印用错变量（打的是 init_cred 别名而非
  right_env，纯 cosmetic）。

## 风险声明（canary 关闭的代价）

mt57 canary 是错位轮杂散写的绊线。关闭后回到 mt56 时代暴露面
（错位轮 6 发杂散写）。缓释：PTR_STRICT + RETRY=1 单发已限写；
freeze 预算 0/2 未动；卡 4 限 2 轮。R7 若 R_LANDED，canary 任务
完成，mt61 恢复；若 R_MISS 且系统干净，也只是回到 stochastic
落点问题（A 系列证明窗口开时落点可达）。
