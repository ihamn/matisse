# Step 1 结论 — Case-2 触发确认 (2026-08-15 17:29)

## 结果
- mt31 (CRED_BOOTID 观测版): round1 rc=255 (exploit 退出, 未写), round2 崩溃重启
- 设备 uptime 16min = 17:13 重启 → 崩在 round2 期间
- pstore 空 (未抓到)

## 结论 (正本清源)
1. **Case-2 写确认触发**: mt28o (tree_left=boot_id) + mt31 (tree_left=boot_id) 两次都是写 boot_id 区域 → 崩溃
2. **写 boot_id 区域必崩**: 因为 boot_id 是随机数据, Case-2 写进去的是 tree_right 值, 破坏内核状态 → panic (符合预期, 观测手段本身的副作用)
3. **rc=255 ≠ 崩溃**: round1 rc=255 是 exploit 进程异常退出 (可能 perf/ks 失败), 不是内核崩

## 对主线的影响
- Case-2 机制活着 (能触发能写), 但"观测用 boot_id"会让系统崩
- 真正问题: 写 cred 指针 (task+0x780) 时, mt30 那轮 futex trigger 全 errno=110 → 写未落地
- 下一步: 不是再观测 boot_id (会崩), 而是解决"为什么 Case-2 写 cred 时 walk 不执行 rb_erase" (futex trigger 时序)

## 遗留
- 为什么 mt30 写 init_cred 不崩但也没写进 (uid 2000) — 需要查 trigger 时序
- 对照: mt26 (Case-1, tree_left=0) round4 成功 vs mt30 (Case-2, tree_left≠0) 不落地

