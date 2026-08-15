# v29 Test 5 — 验证 tree_pc=FOPS-8|RED 能否触发 GhostLock
## 假设
- 如果 tree_pc=FOPS-8|RED 能触发 (ret>0): Call 1 parent=FOPS-8 → parent->rb_right=FOPS → 直接写 FOPS!
- 如果 ret=0: FOPS-8 不触发，需要其他方案

## 命令
PSELECT_TREE_PC=ffffff80028e76e1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10
