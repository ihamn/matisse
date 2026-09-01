# mt71 stage-aware mt51 实验

## 背景
C fork 全风暴 0/6 + C external 全风暴 0/6 后，假设 C 写即使落地也会被后续
shots 覆盖/无法检测。mt71 让 mt51 对 C 阶段以 euid==0 作为落地信号并提前停发。

## 结果
- Cfork_mt71（20s 窗口）：风暴饿窗，0 发，未验证。
- Cfork_mt71b（30s 窗口）：全风暴 6 发（t=23.8s 进窗），仍无 mt51 abort，
  最终状态 euid=2000 CapEff=0。
- 因此 mt71 的 stage-aware mt51 尚未观察到 C landing；不能排除 C 写本身不落。

## 待办
- 若 C 写确实会落，需要更快的状态反馈（缩短子进程 200ms 轮询 / 或 C 阶段
  专用 abort 通道）才能在 burst 内保住成功写。
- 或继续排查 pc=0x778 为什么不触发写入。
