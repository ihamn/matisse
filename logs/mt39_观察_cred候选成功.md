# mt39 观察结果: setresuid 采样成功泄露 cred 候选! (2026-08-15 21:27)

## 结果 (一手数据)
- perf task=ffffff8025091280 (230/256 votes)  ← task_struct
- mt39: cred_cand=ffffff80f3f33d80 votes=26   ← ★ 非 task 稳定地址 (setresuid x19=cred 命中)
- 26/256 票 = ~10% 采样命中 cred 相关寄存器 (vs geteuid 的 2/256 = 0.8%, 提高 13 倍!)

## 关键发现
1. **setresuid 采样有效** - cred_cand 26 票证明 x19=cred 被大量采样到 (反汇编预测验证!)
2. **代码 bug**: mt39 的 PSELECT_PERF_CRED 返回 cred_cand 后, main.c 把它当 task 用
   - mt28m: task=ffffff80f3f33d80 (应是 ffffff8025091280!)
   - 导致后续写 cred_ptr = cred_cand+0x780 (错误目标)
3. cred_cand 与 task 差 3.2GB - 需确认 cred_cand 是否真是 cred (或 mm_struct 等)

## 下一步
1. 修 bug: main.c 应分开用 task (perf 默认) 和 cred_cand (PSELECT_PERF_CRED)
2. 验证 cred_cand 身份: 写 cred_cand+0x4=0 (getuid 读 real uid@+0x4) → 若 uid 变 0 = 是 cred
3. 写链: WPC = cred_cand+0x4-8, WRIGHT=0, WLEFT=0

