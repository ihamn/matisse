# CHECKPOINT v34 — v30稳定架构 + shape=1 selinux直写 (2026-07-16 晚)

## 当前状态
- **v34 v2 测试完成 ✅ 手机没崩！但 selinux 没被写**
- 二进制: `preload_mtk_v34.so` SHA256=a3be512c (166KB)
- 日志: `logs/v34_test1.txt`
- 结果摘要:
  - attempt1: ret=72 calls=1 success=1 ← GhostLock 触发
  - attempt2-5: ret=72 calls=0 ← 衰减
  - selinux-check: enforcing=1 ← 未被清零
  - 架构稳定，deep PI chain 没崩 ✅

## ret 为何从 193 降到 72？
- v30 tree_pc=OFF|RED: rb_erase 执行 → 写 name_ptr → 内核读损坏的 name_ptr 字符串 → 级联错误 → ret=193
- v34 tree_pc=selinux-8|RED: GhostLock 触发（consumer 跑了）但 rb-tree 遍历不使用此 parent → rb_erase 未执行 → 无级联 → ret=72
- **结论: GhostLock 触发 (calls=1) ≠ rb_erase 执行。tree_pc 决定能否走到 rb_erase。**

## 核心矛盾（不可逾越）
rb_erase 机制中，parent 同时决定:
A) 能否触发 rb_erase（OFF 能、selinux-8 不能）
B) 写到哪里（parent+8 = target）

两个属性不可解耦 → 能触发的 parent 写不到有用地址，能写有用地址的 parent 不触发。

## v34 v1 → v2 修复
- 错误: "CANNOT LINK EXECUTABLE: cannot locate symbol root_child_done"
- 原因: root.c 不在 Makefile CORE_SRCS 中
- 修复: CORE_SRCS 加 `$(call pick_src,root.c)`，撤销 main.c 的 `int root_child_done` stub
- 副作用: 引入 root.c 的其他符号 (selinux_before, physrw_* 等)，但不影响执行（try_cfi_stage永远不成功时这些函数不被调用）

## 路线重组逻辑

### v30 为什么稳定（不崩）？
- **deep PI chain**: block_holder → owner → waiter 创建3层PI链
- waiter 调用 FUTEX_LOCK_PI → 真正阻塞在 f_pi_target
- pselect_thread 在waiter阻塞时跑 → GhostLock攻击**真实阻塞的waiter**
- 内核在合法PI链上下文中处理损坏 → 可以handle，不崩

### fusion_release / v31-v33 为什么崩？
- waiter 用 FUTEX_WAIT_REQUEUE_PI（不阻塞！立刻返回）
- pselect 在 waiter_thread 自己跑 → GhostLock攻击凭空伪造的waiter
- 内核面对无上下文的假waiter → undefined behavior → 崩
- v31-v33 额外多了 fops.c word映射错 (prio插在rb_node之间)

### v34 = v30骨架 + shape=1直写
改动这5处：

1. **fops.c prepare_pselect_fdsets**: shape=1时
   - parent = target-8 → tree_pc|RED → word 0 (offset 0x00)
   - right = value → tree_right → word 1 (0x08)
   - left = 0 → tree_left → word 2 (0x10)
   - pi_parent/pi_right/pi_left 同样设
   - task = text_addr(INIT_TASK) (v30验证过的，不崩)

2. **main.c run_exploit**: FOPS prepare后设:
   - pselect_custom_target = data_addr(SELINUX_ENFORCING)
   - pselect_custom_value = 0
   - pselect_custom_shape = 1
   - 跑完后读 /sys/fs/selinux/enforce 验证

3. **common.h**: 补 DIRECT_MAP_BASE/END, LOCK_OFF, W0_OFF, FAKE_TASK_OFF

4. **util.c**: canon_addr→P0_DATA_ALIAS_CONST (v33修复)

5. **common.h/util.c/main.c**: 加 pselect_custom_target/value/shape 全局变量

## 理论 (what should happen)
- shape=1 → tree_pc = (selinux_dmap - 8)|RED
- rb_erase Path A (left=NULL, right!=NULL): child = right = 0
- parent = (target-8) & ~3 = selinux_dmap - 8
- csel: parent->rb_left == node? *(target+8) == sprayed_page? → 几乎肯定 false
- → parent->rb_right = child = 0 → 写0到 (target-8)+8 = target = selinux_dmap
- 写8字节：清零 selinux (4B) + 相邻4B

## 风险
1. **(selinux_dmap-8)|RED 能触发 rb_erase 吗？** 
   v22/v23证明FOPS-8|RED→ret=0，但R8证明bootid-8|RED→成功。
   selinux-8|RED？只能实测。
2. **写8字节覆盖相邻字段** → 可能kernel panic
3. **这是本次重启的第2次测试** (v30是第1次) → 若MTK slab扛不住可能崩

## 若v34失败的方向
- 换target: init_cred (data_addr(INIT_CRED))
- 换write方式: shape=0 (用OFF|RED触发，接受name_ptr写入)
- 把deep PI chain移植到R8的cred/selinux写序列 (per-write fork → thread-based)

## v35 状态 (2026-07-16 晚)
- 已编译: `preload_mtk_v35.so` SHA256=734cd11e
- 改动: target=ASHMEM_MISC_FOPS, value=fake_fops, shape=1
- 逻辑: parent=FOPS-8=OFF+0x08，仅距OFF 8字节
- ⚠️ 本次重启第3次 (v30, v34已跑)，slab可能不够
- 待部署测试

## v35 FOPS直写 — 测试完成 ❌
- 二进制: `preload_mtk_v35.so` SHA256=734cd11e
- 日志: `logs/v35_test1.txt`
- target=ASHMEM_MISC_FOPS, value=fake_fops, shape=1
- 结果: ret=1 calls=1 success=1 → **FOPS未改写**
- parent=FOPS-8 距OFF仅8字节 → 仍不触发rb_erase
- 3次测试(v30/v34/v35)均未崩，架构稳定 ✅

## 最终结论 (2026-07-16)
rb_erase parent触发条件极苛刻：OFF能触发(ret=193)，FOPS-8距8字节不能(ret=1)。
FOPS覆写不可行。v30的判断是对的。

留存资产: deep PI chain架构 + shape=1框架 + 正确word映射 + canon_addr修复
