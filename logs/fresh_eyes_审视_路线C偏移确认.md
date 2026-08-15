# Fresh-Eyes 审视结论: 路线 C 关键偏移确认 (2026-08-15 20:5x)

## 审视发现 (对抗性检查)
1. **getuid vs geteuid 读不同偏移** (反汇编铁证):
   - getuid: ldr w8, [x8, #0x4]  → real uid @ cred+0x4
   - geteuid: ldr w8, [x8, #0x14] → euid @ cred+0x14
   - 之前 target.h 猜 CRED_UID_OFF=0x8 是错的 (实际 real uid 在 +0x4)
2. **写 cred 内容的目标 = cred+0x4** (real uid, id -u 读它)
   - 写 8 字节 0 → uid+gid 清零 (相邻)
   - 不动 usage(+0x0)/指针 → 避开 __put_cred BUG
3. **未验证的假设**:
   - setresuid 采样是否真能泄露 cred (需设备观察 mt39)
   - cred 候选识别 (非 task 稳定地址) 是否误报

## 对攻击链的修正
- 路线 C 写目标: WPC = cred_cand + 0x4 - 8 (写 cred+0x4)
- WRIGHT = 0 (uid+gid 清零)
- 验证: getuid()==0 且不崩

## 下一步 (设备验证)
1. 部署 mt39, PSELECT_PERF_CRED=1 → 看 cred_cand 是否出现
2. 若出现 → 写 cred_cand+0x4=0 (需改 main.c 用 cred_cand 而非 task+0x780)
3. 验证 uid==0

