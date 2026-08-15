# v29 Test 3 Preflight — 2026-07-15 12:00
## 二进制
- preload_mtk_v29.so, SHA256: b36060c8, md5: e5311ff3
- 已确认含 deep chain (block_holder_thread + f_owner_block)
- 已部署到 /data/local/tmp/preload.so ✓

## 预期行为
1. SLIDE 阶段通过
2. FOPS 阶段: block_holder 先 lock f_owner_block
3. owner lock f_pi_target → block on f_owner_block (deep chain)
4. waiter lock f_pi_target → rt_mutex_adjust_prio_chain 走 2 级 chain
5. Call 2/3: rb_erase pi_tree_entry(pi_parent=FOPS-8|RED) → 写 FOPS
6. try_cfi_stage 验证 FOPS 是否被 fake_fops 覆写

## 执行方式
- Shizuku rish + 脚本文件 (避免 heredoc 管道输出混乱)
