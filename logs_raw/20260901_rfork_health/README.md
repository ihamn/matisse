# 2026-09-01 R-fork 健康检查

## 结果
- mt70 R fork 标准 20s 窗口也出现 consumer 被饿出窗口：
  `pselect returned ret=0 t=20018ms` 后 `mt19b t=20019ms`，0 发。
- 与 Rext3 相同形态，说明当前环境（负载/调度/cgroup）不适合跑触发实验，
  不是外部模式独有。
- 之后 Shizuku 再次变为 `Server is not running`，现场实验停止。

## 证据
- `Rfork1_starved.out`：完整日志，显示 R fork 同样 0 发。
