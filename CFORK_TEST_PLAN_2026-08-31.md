# C-stage fork-mode 隔离实验 (2026-08-31)

## 动机
- R 阶段 7/7 落地全部是 **fork 模式**（`PSELECT_TASK` 为空 → 父进程 fork 子进程，
  子进程泄漏自身 task 并阻塞轮询；父进程触发 rb_erase 写 real_cred）。
- C 阶段 0/6 落地全部是 **外部模式**（`PSELECT_TASK=<上一轮 R 子进程 task>` →
  新进程直接写给定 task 的 cred）。
- 现有分析已排除写值链（PTR_RIGHT=init_cred 别名有效）、Case 判定（TREE_LEFT=0
  都是 Case-1）、gate 判据（C 若落地 euid 必为 0）。
- 剩余最大嫌疑：**fork 模式 vs 外部模式的触发进程栈布局差异**，
  其次才是 pc 0x770 vs 0x778 的几何差异。

## 实验设计
跑 **C-stage fork 模式**：与 R 阶段完全相同的 fork 流程，仅把 `PSELECT_PTR_STAGE` 设为 `C`。
- 父进程 fork 新子进程 → 子进程泄漏 task 并进入 200ms 轮询
- 父进程在 PTR 模式下写 `task+0x780`（cred = init_cred）
- 若 C 几何在 fork 模式能落地：`mt49_child_status.txt` 应出现 `euid=0`，
  且 `CapEff=0000000000000000`（real_cred 未换）
- 若 C 几何本身有问题：状态保持 `uid=2000 euid=2000 CapEff=0 root_seen=0`

## 安全性
- 使用 `PSELECT_PTR_STRICT=1` AND-gate：`CapEff 满帽 && euid==0` 才触发
  setresuid/commit_creds。
- 本实验只有 cred 被换成 init_cred，real_cred 未换 → CapEff=0 → gate 不触发
  → 不会进入 commit_creds 的 `BUG_ON(task->cred != task->real_cred)`。
- 半程态（cred=init_cred, real_cred=原 cred）由 R 阶段反向半程态
  （real_cred=init_cred, cred=原 cred）证明可存活；子进程仅做 getresuid /
  读 status / 写状态文件，不执行特权操作。

## 判定树
| 结果 | 结论 | 下一步 |
|---|---|---|
| euid=0 出现 | C 几何能写；0/6 是外部模式问题 | 跑 R-external 对照；若 R-external 也失败则外部模式实锤 |
| euid 仍 2000 | C 几何（pc=0x778）本身写不落 | 做 geometry-swap：R 几何写 0x780 或 C 用 pc=0x770 对照 |

## 现场操作
1. 确认 Shizuku 运行、屏幕常亮、插电、负载稳定。
2. 部署当前 mt67（或与 field_auto 相同的 preload.so）。
3. 执行：
   ```sh
   bash ~/matisse/termux/run_Cfork_test.sh
   ```
   或在 rish 里逐条运行脚本内容。
4. 回传 `/data/local/tmp/Cfork.out` 和 `mt49_child_status.txt`。
