# 栈几何静态定标 (外部评审 P0-1) - 2026-08-16

## 单函数帧 (kernel_with_symbols.elf 反汇编)
- futex_wait_requeue_pi @ 0xffffffc008294d68:
  sub sp, #0x1a0; x29 = sp+0x140
  rt_waiter 零初始化区: [x29-0x60]..[x29-0x20] => sp+0xe0 .. sp+0x120
- core_sys_select @ 0xffffffc00856e2d4:
  sub sp, #0x1c0; x29 = sp+0x160
  stack_fds: x21 = sp+0x50

## 相对偏移
waiter (rt_waiter) 相对 futex 帧顶: +0xe0
fd_set (stack_fds) 相对 select 帧顶: +0x50
差: 0x90 (144B = 18 words) + 两个 syscall 入口帧差 (待补)

## 待完成
- sys_pselect6 -> core_sys_select 完整帧链
- sys_futex -> futex_wait_requeue_pi 完整帧链
- 同线程 overlay 假设验证 (waiter 与 pselect 是否同线程栈)
