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
# 补充证据：黑屏卡死 ≠ panic → dsh 未被污染 (2026-08-16)

> 追加到 CRASH_BLACKSCREEN。用户敏锐观察：这次黑屏重启后 dsh web 正常。

## 事实
1. 之前 3 次崩溃（crash#1/#2/#3, 内核 BUG/panic）→ 每次 dsh web 都起不来
   (session_projcache.json 污染, 需隔离 storages)
2. **这次黑屏卡死（长按重启, 非 panic）→ dsh web 完全正常** (HTTP 200,
   session_projcache.json 正常 3648B)

## 独立证据价值
- **支持对面 ASK2 归因修正**: dsh 污染 = panic 未清盘导致的 FS 元数据损伤
  （写原语不碰用户文件）
- 这次非 panic → 文件系统干净 → dsh 无污染 → **归因链再加一环**
- 也说明: 黑屏卡死没有走到内核 panic 那一步（系统冻结但内核未崩）,
  与 pstore 无栈 + bootreason=longkey 三方吻合

## 推论
- "卡死"与"panic"是**两种不同的事故模式**:
  a. panic (crash#1/2/3): 内核 BUG → 重启 → dsh 污染
  b. 卡死 (本次): 系统冻结 → 长按 → dsh 干净
- 我们过去一直把"崩溃"当一种现象, 实际有两种, 处置不同

—— matisse 现场
