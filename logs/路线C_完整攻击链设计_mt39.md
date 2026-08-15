# 路线 C 完整攻击链设计 (mt39) - 2026-08-15 纯本地

## 关键认知修正
- 之前 mt32-36 全崩 = 我们在写 task+0x780 (cred 指针) -> __put_cred BUG
- 正确做法: 写 *(task+0x780) 指向的 cred 内容 (uid/caps 字段), 不改指针

## 完整链
1. perf 采样 setresuid (x19=cred 全程可见, 反汇编 974 行 ldr x19,[x25,#0x780])
   - 需要修改 perf_find_task 返回 cred 候选 (不只是 task)
2. 识别 cred: 
   - setresuid 反汇编给 cred 字段偏移: +0x4, +0x14, +0x1c, +0xc (uid/gid/euid/suid)
   - cred 特征: 候选里非 task 的稳定地址, 且 +0x14 处值 = 2000 (我们的 uid)
   - 但无读原语... 用"候选出现次数/地址关系"推断
3. 写 cred 内容: PSELECT_W 链
   - WPC = cred_addr + 0x14 - 8 (写目标: parent->rb_right = cred+0x14 = uid)
   - WRIGHT = 0 (uid=0)
   - WLEFT = 0 (Case-1)
4. 验证: getuid()==0 且不崩 (改内容不动指针/usage)

## 待设备验证
- setresuid 采样是否真的泄露 cred (cand 里出现 task+~0x780 或相关地址)
- cred 候选的识别逻辑 (哪些是 cred)
- 写 cred+0x14=0 后 getuid 是否变 0 且不崩

## 风险
- setresuid(0,0,0) 非 root 会 EPERM 返回, 但 cred 已加载到 x19 (采样仍有效)
- 采样窗口: x19 从 974 到 fa88+ (约 50 条指令), 命中率高
- 写 cred 内容: uid 字段是普通数据, 改它不影响 usage/magic -> 应该安全

