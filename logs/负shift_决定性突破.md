# ★★★ 决定性突破: 负 shift 从未试过! (2026-08-15 23:2x)

## 发现 (读原项目 ghostlock + Linux 文档)
1. ghostlock 支持 shift=-14 到 +14 (fops.c:104)
2. OnePlus 13 明确需要 shift=-2 (README)
3. 负 shift 语义: 把 waiter 布局整体前移 (task@w6 -> w4), 让 task/lock 落在 fd_set 可控区更早位置
4. 我们 slide.c:138 硬编码拒绝负 shift (pshift<0 -> 0)
   - mt 系列只扫过 0-7, 负 shift 从未试过!

## 为什么这是答案
- waiter 在 W 内核栈槽 (编译期帧布局决定, 不随 boot 变 - 回答了用户问题)
- shift 补偿 pselect fd_set vs waiter 栈槽的偏移
- matisse 的 waiter 可能落在 task@w0-5 位置 -> 需要负 shift
- shift=0 (task@w6) 对不上 -> futex trigger 110 (walk 读不到假 waiter)
- mt26 成功 = 偶然对齐; mt44 失败 = 没对齐

## 修正
1. slide.c 允许负 shift (-14 到 14, 同 ghostlock)
2. 扫 shift -14 到 +7 (重点负值)
3. OBS_ONLY 观察哪个 shift 命中

## 教训
- learn-from-original-projects 的价值: ghostlock 的负 shift 支持 + OnePlus 13 用 -2
- fresh-eyes 该抓: "我们只扫了正 shift" 是思维定势

