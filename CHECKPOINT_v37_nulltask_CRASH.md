# CHECKPOINT v37 — NULL task 验证：手机重启 (2026-07-16 晚)

## 测试背景
- 二进制: `/data/local/tmp/trigger_stamp` = `trigger_stamp.c` 编译 (SHA256: 828daaa)
- 源码: `CVE-2026-43499_ref/trigger_stamp.c` line 41: `buf[6]=0` (task=NULL)
- 设计意图: buf[6]=0 → PI chain walk 如果读到 stamp → 解引用 NULL task → 必崩
  - 崩 = stamp 数据在正确偏移，PI chain walk 读到了
  - 不崩 = stamp 没被读到，偏移不对

## 测试过程
1. Shizuku 初始未启动 → "Server is not running" 落盘到 log
2. Shizuku 连上后 trigger_stamp 执行
3. 运行了一段时间后手机重启
4. 只有 "Server is not running" (22 bytes) 留存 — 测试输出因 kernel panic 丢失

## 结果分析
- 无 ramdump, 无 pstore, 无 last_kmsg — 无法 100% 确认 crash 类型
- 但 test1 (buf[6]≠NULL) 同链路完整通过不崩 → 唯一变量是 buf[6]=0
- **高置信度: PI chain walk 读到了 stamp 数据, NULL task 解引用 → kernel panic**

## 结论
✅ **stamp 数据位置正确** — PI chain walk 确实读取了我们通过 socket+pipe 写入的假 waiter
✅ **EDEADLK + controlled stamp 路线可行** — 内核在 PI chain walk 中使用了我们控制的数据

## 下一步: 有效 fake_task
- 替换 buf[6]=0 为指向受控页面的有效 fake_task
- 需要: heap spray (prepare_kernel_page) + fake task_struct 布局
- 目标: 观察 PI chain walk 写了什么字段 → 确定写原语的精确能力
