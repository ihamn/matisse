# v30 comm 验证测试
## 目标
验证 GhostLock rb_erase 是否真的写入
## 方法
写 init_task.comm (direct map: 0xffffff800279c6f0)
tree_pc = 0xffffff800279c6e9 (comm-8 | RED)
tree_right = 0x4141414141414141
读 /proc/1/comm 验证
