# 路线 C 研究: perf 泄露 cred 地址 + 改内容 (2026-08-15 19:2x, 纯本地)

## 目标
写 cred 指针路线 (A/B) 在 5.10 结构性不可行 (6 次崩溃, __put_cred BUG)。
路线 C: 改 cred 内容不改指针 - 需要 cred 地址 (无读原语, 之前认为难)。

## 研究发现 (有依据)
1. perf_find_task 采样 32 个寄存器, 收集 dmap 范围候选 (slide.c:723-726)
   - 但只返回"出现最多的" (task_struct), 其他候选丢弃 (slide.c:739-751)
2. geteuid/getuid syscall 内部调用 current_cred() (kernel/sys.c:380/442/949-953)
   - current_cred() 返回值会留在寄存器 (x19 等被保存)
   - **采样寄存器可能泄露 current->cred 地址!**

## 修改方案 (待设备验证)
1. perf_find_task 增加"cred 候选"收集: 采样 syscall 从 getpid 换 geteuid
2. 保留所有候选, 分析:
   - task_struct 特征: 出现最多, 地址范围稳定
   - cred 特征: 在 task 附近 (task+0x778/0x780 指向), 或与其他候选相关
   - 可通过"地址 = task + ~0x780 的关系"交叉验证
3. 拿到 cred 地址后: 改写 cred 内容 (uid/caps 字段, 反汇编真值:
   uid@+0x14, gid@+0x18, cap@+0x30) - 不改指针, 避开 __put_cred BUG

## 验证方法 (设备, 下次)
1. 部署观察版 (只泄露不写): 打印所有候选 + 标出疑似 cred
2. 若确认 cred 地址: 写 uid=0 (PSELECT_W 链, WPC=cred+0x14-8)
3. 验证: getuid()==0 且不崩

## 风险
- 采样里可能没有 cred 指针 (geteuid 内联优化, 寄存器未保留)
- 若有多个候选, 区分 task vs cred 需要特征分析
- 写 cred 内容也可能有副作用 (需观察)

