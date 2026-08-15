# ★★★ 决定性发现: mt30 写不落地的根因 (2026-08-15 17:4x)

## 一句话
**mt30 的 CRED 模式用错了写路径** —— 它用 PSELECT_TREE_LEFT=cred_ptr (Case-2 successor 路径),
但项目里早有成熟的 "fake_parent 写链" (v20 caiman + v30 Path C), mt26 成功就是走这条 (Case-1 主树写)。

## 证据 (util.c 源码)
1. util.c:464: fake_parent = write_target - 8 → &parent->rb_right = write_target (成熟链)
2. util.c:540/544: RIGHT_OFF/LEFT_OFF 的 rb_node parent = fake_parent (target-8)
3. util.c:505-512: v30 Path C: parent->rb_right = child → [target] = fake_fops 值
4. util.c:478-483: PSELECT_WPC/WRIGHT/WLEFT 环境变量可覆盖 write_pc/write_right/write_left!
5. util.c:488-490: SLIDE 模式默认 write_pc=SLIDE_LOGGERS_0_1, write_right=0, write_left=SLIDE_RANDOM_BOOT_ID_DATA (硬编码给 boot_id 观测)
6. main.c CRED 模式: setenv PSELECT_TREE_LEFT=cred_ptr → 走 Case-2 successor (错误路径!)

## 对比
| | mt26 (成功) | mt30 (失败) |
|---|---|---|
| 写路径 | Case-1 主树写 (tree_left=0) | Case-2 successor (tree_left=cred_ptr) |
| 写值 | tree_pc 派生 (enforcing) | init_cred (值对但路径错) |
| 结果 | Permissive ✅ | 写不落地 ❌ |

## 修正方案 (纯代码, 不需要新诊断)
CRED 模式改设 PSELECT_WPC/WRIGHT/WLEFT (不是 TREE_LEFT):
- PSELECT_WPC  = cred_ptr - 8  (写目标 = task+0x778 的 parent, rb_right → task+0x780)
- PSELECT_WRIGHT = data_addr(INIT_CRED)  (写入值 = init_cred dmap)
- PSELECT_WLEFT = 0  (Case-1, 不崩)
- 保留 PSELECT_TREE_PC=0/LEFT=0 (主树无害)

## 注意 (待验证)
- 需要确认 fake_parent 链在 PAGE_PAYLOAD_SLIDE 模式下是否可用 (util.c 的 FOPS 分支用 fake_parent, SLIDE 分支可能不同)
- write_pc 在 SLIDE 模式下被硬编码, 需确认 env 覆盖是否生效

