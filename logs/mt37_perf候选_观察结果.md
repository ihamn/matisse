# mt37 观察结果: perf 候选分布 (2026-08-15 20:23)

## 数据 (geteuid 采样, PSELECT_PERF_OBS=1)
- task = ffffffff81640d4a00 (246/256 票 = current->task_struct, SP_EL0 等)
- cand[4] = task+0x18 (task 内部字段)
- cand[1/2] = ffffffff8160d34c90 (非 task, 出现2次, diff=-54132080 ~54MB)
- cand[0/6] = ffffffff8021d98820/00 (低地址, ~-5.4GB)
- cand[8-37+] 几乎全是 task (diff=0)

## 分析
1. 采样寄存器主要持有 task_struct 指针 (SP_EL0 频繁), cred 指针没有明显出现
2. 可能原因: geteuid 的 current_cred() 被编译器内联优化, cred 指针未保留到采样寄存器
   或 cred 地址落在 dmap 范围但在 cands 里被 task 淹没 (只有 40 个被打印)
3. cand[1]=ffffff8160d34c90 是重要候选 (非 task 多次出现):
   - 可能是 task 的 pi_blocked_on/pi_waiters 等字段指向的对象
   - 或 slab 上另一个结构 (mm_struct? cred?)
   - 需要识别: cred 特征 = +0x14 处 uid=2000 (但我们无读原语)

## 下一步选项
A. 打印全部 256 候选 (当前只打印 40), 找 task+0x778/0x780 附近或 uid 相关
B. 分析 cand[1]: 用写原语探测 (写 0 到 cand[1]+0x14, 看 uid 变) - 但这是写不是观察
C. 换采样方法: 让 geteuid 在采样时把 cred 放寄存器 (如关优化/加 barrier)
D. 接受"cred 地址难直接泄露", 评估其他提权路径

