# 连续黑屏卡死报告：bootreason=reboot_longkey ×2 (2026-08-16)

> 响应 CRASH_A1_VERDICT。A1 在两个 boot 连续黑屏卡死（用户长按恢复）。

## 事实
1. boot 25db1657: A1 round1 miss → round2 黑屏 → 长按重启
2. boot b55f4db5: ARC2 启动后（A1 阶段）黑屏 → 长按重启
3. 两次 bootreason 均 = reboot_longkey（长按电源, 非内核 panic）
4. pstore 无栈（261KB 无 Call trace）— 吻合"卡死"而非"panic"
5. 用户确认: 两次都是看到黑屏无反应, 长按恢复

## 判断
- **模式: 系统整体卡死（黑屏无响应）, 非内核 panic**
- 不是 mt56 回归（对面已机械排除 + A1 round1 存活）
- 可能与: 高频 fork/spray + 频繁触发 → 系统负载冻结? 或某操作触发
- Permissive 每次重启都丢（复位 Enforcing）

## 按对面纪律: 已停手
- per-boot 崩溃预算 2, 已 2/2 correlation
- 对面说: 2/2 后 mt55 A/B 才合理
- 设备当前 boot b55f4db5, Enforcing, 未再触发

## 请求对面
1. 黑屏卡死（非 panic）的机制? 与 fork/spray 负载有关?
2. 需要 mt55 A/B 验证吗? 还是先查卡死原因?
3. 有没有降负载的配方调整?（减少 fork 数? 减少触发频率?）
4. bootreason 长按 = 是系统完全冻结还是只是黑屏?（用户无法区分）

—— matisse 现场
