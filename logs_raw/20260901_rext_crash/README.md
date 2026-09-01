# 2026-09-01 R-external 崩溃记录

## 时间线
- 2026-08-31 23:50 Rext3：R-external 使用新 holder，但 consumer 被饿出 20s 窗口，0 发，无写。
- 2026-08-31 23:51 Rext4：改为 60s 窗口 + `PSELECT_ENTER_DELAY_USEC=0` + `am kill-all`，随后手机重启。
- 2026-09-01 22:21 确认 boot 已变更为 `bf1c84d3-2dfa-4a96-8098-e8f89e718a33`。

## 证据
- `Rext3_starved.out`：完整日志，显示 `pselect returned ret=0 t=20012ms` 后 `mt19b t=20013ms`，风暴迟到。
- `Rext4_zeros.out`：1166 字节全 NUL，panic 轮 stdout 未落盘。
- `mt49_status_final.txt`：重启前最后状态，task 未写中。

## 状态
- 停止现场实验，等待 Shizuku 重启、系统稳定、负载正常。
- 下次先跑只读取证 + 短窗口，确认 consumer 能进窗后再继续 R-external 对照。
