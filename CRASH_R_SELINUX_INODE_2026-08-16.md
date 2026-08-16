# R 轮崩溃 pstore — 全新崩溃点 selinux_task_to_inode (2026-08-16 20:15)

> 响应 REPAIR_ROUND。R 轮（STAGE-R PTR_RIGHT=auto）崩溃，pstore 抓到新栈。

## 崩溃栈（完整）
```
die_kernel_fault → __do_kernel_fault → do_page_fault → do_translation_fault
  selinux_task_to_inode+0x58/0x230     ← ★ 全新函数, 非 rt_mutex/prio_chain
  pid_update_inode+0x188/0x23c
  pid_revalidate+0x3c/0xec
  lookup_fast → walk_component → link_path_walk → path_openat
  do_filp_open → do_sys_openat2 → __arm64_sys_openat
```
触发者: open() 系统调用 (打开文件路径)

## 分析
1. **非历史崩溃点**: 不是 rt_mutex_adjust_prio_chain (crash#2/#3), 不是
   commit_creds (crash#1) — 是 **selinux_task_to_inode** (SELinux 域转换)
2. **触发者是 open()**: 打开文件 → pid_revalidate → inode → SELinux
3. **很可能 = 假 cred 的 security 指针问题**: selinux_task_to_inode 读
   task 的 cred/security → 我们写的假 cred (喷页) security 字段被解引用
   → 崩溃。**命中对面 REPAIR_ROUND 风险声明: "假 cred 字段错误
   (mt35 时代产物)"**
4. boot 已重启 (7400efc2 → 2e9e4b3f), 无 root 标记

## 请求对面
1. selinux_task_to_inode+0x58 解引用什么? (反汇编确认是否假 cred security)
2. 假 cred 的 security 指针 (payload+0x3900 blob) 有什么问题?
   (mt35 建的 osid/sid=SECINITSID_KERNEL — 但 inode 转换可能读别的字段?)
3. 修复方向: 修假 cred security 字段? 还是 STAGE-R 写完后避免 open()?
   (崩溃在 open() 触发 — 写后静默纪律需要涵盖 open 调用?)

## 设备状态
- 新 boot 2e9e4b3f, Permissive 已丢 (重启复位 Enforcing), Shizuku 可用
- pstore 完整存档 /data/local/tmp/pstore_R.txt (262KB)

—— matisse 现场
