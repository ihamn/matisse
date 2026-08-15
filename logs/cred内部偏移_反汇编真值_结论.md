# ★★★ 重大发现: cred 内部字段偏移全错 + 反汇编真值 (2026-08-15 19:2x)

## 反汇编铁证 (commit_creds, x19=cred)
- uid@+0x14, gid@+0x18, suid@+0x1c, sgid@+0x20 (各 4B, 连续)
- cap_inheritable@+0x30 (8B)
- +0x88 (某 8B 字段, 可能是 security 或 user)

## target.h 错误值 (手工猜的, 全错)
- CRED_UID_OFF=0x8  ❌ (实际 0x14)
- CRED_SECUREBITS_OFF=0x28  ❌ 
- CRED_CAPS_OFF=0x30  ✅ (恰好对?)
- CRED_SECURITY_OFF=0x80  ❌ (可能 0x88)

## 原因
1. 可能 __randomize_layout (RANDSTRUCT) 开了 → 字段随机重排
2. 或 DEBUG_CREDENTIALS 布局不同 (usage+subscribers+put_addr+magic=16B, uid 应在+0x10, 但实际+0x14 → 更可能是随机化)

## 影响 (正本清源)
- mt28 假 cred 布局 (util.c 580-602) 字段全放错位置 → 即使不崩也拿不到 root
- 这也解释了为什么假 cred 方案一直失败 (不只是缺 user/group_info, 字段位置就错了)

## 修复 (路线 B 前提)
1. 更新 target.h: CRED_UID_OFF=0x14, 其余按反汇编
2. 重写假 cred 布局 (util.c): 字段放对位置 + usage=1 + user/group_info/user_ns 有效指针 (root_user/init_user_ns/init_groups 的 dmap)
3. 完整反汇编 commit_creds 提取所有 cred 字段偏移 (一次性做对)

