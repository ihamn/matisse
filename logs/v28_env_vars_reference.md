# v28 fd_set 环境变量参考 (基于 x-spy/CVE-2026-43499-popsicle 适配 matisse)

## 可用 env vars (fops.c prepare_pselect_fdsets)

### tree_entry
  PSELECT_TREE_PC     — __rb_parent_color (默认 OFF|RED)
  PSELECT_TREE_RIGHT  — rb_right (PathC: page+0x3000 scratch)
  PSELECT_TREE_LEFT   — rb_left  (PathC: page+0x180 fake_fops)

### pi_tree_entry
  PSELECT_PI_PARENT   — __rb_parent_color (默认 FOPS-8|RED)
  PSELECT_PI_RIGHT    — rb_right (默认 fake_fops=page+0x180)
  PSELECT_PI_LEFT     — rb_left  (默认 0 = Path A)

### 模式
  PSELECT_PAT_C=1     — 强开 Path C (默认)
  PSELECT_PAT_C0=1    — 关 Path C 退回 v27
  PSELECT_TPC_SAFE=1  — 全部清零安全模式

## 之前错误: PSELECT_WRIGHT/WLEFT → 不影响 fd_set, 只改 SKB payload!
