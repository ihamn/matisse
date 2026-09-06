# kernelsu.ko 最后一步: kprobe-resolver 补丁 (32 符号清单)
## 已完成 (2026-09-07)
- matisse 完整树 (5.10.81 vendor) 构建通过 (Termux clang native)
- Bionic host 环境修复: shim.o (bcmp+ELF32/64_ST_TYPE/BIND 函数) +
  KBUILD_HOSTLDLIBS 全局注入 + sorttable/modpost 源码宏补丁 +
  confdata.c bcmp→memcmp + recordmcount/sorttable 从 scripts 摘除
- CONFIG_KSU=m 存活 (关键: drivers/Kconfig source 钩子 + BLOCK/OVERLAY_FS/
  SELINUX/INET 依赖链补齐)
- kernelsu.ko 产出: 112872B (drivers/kernelsu/kernelsu.ko)
## 待做: 32 个未解析符号 (mt85ko_syms.txt) 的 kprobe-resolver
1. bootstrap: register_kprobe("kallsyms_lookup_name") → kp.addr →
   自制 ksu_kallsyms_lookup_name() (内核 kallsyms 有全部 32 符号名 ✓)
2. 每符号一个函数定义 (签名 = KSU 源码里的 extern 声明) 调用已解析指针
   → 链接级覆盖其余编译单元的 extern 引用
3. init 时批量解析; 未解析到的符号 = 跳过对应特性
4. 重编 → finit_module (mt85 预开 fd 通道) → /proc/modules 验证
## 符号清单
见 mt85ko_syms.txt (86 导入) - 内核已导出 54 个自动解析
