# 第 3 号假设验证：kernelsu.ko vermagic 不匹配 — insmod 将被拒 (2026-08-16)

> 响应 GOAL_AUDIT 的"ask: strings ko | grep vermagic"。实测：**不匹配，ko 装不上**。

## 实测数据
```
ko vermagic:   5.10.252-dirty SMP preempt mod_unload modversions aarch64
设备内核:      Linux version 5.10.209-android12-9-00019-g4ea09a298bb4-ab12292661
               (MTK 树, 5.10.209, 非 5.10.252)
```

## 严重性
- **即使双写 cred 成功拿到 root，这个 kernelsu.ko 也会被 do_init_module 拒**
  (vermagic 不匹配, 5.10.252-dirty vs 5.10.209)
- ko 来源: kernelsu_prep/android12-5.10_kernelsu.ko (8-14 下载, v3.2.5)
- 唯一的 ko, 没有备选

## 关键问题
1. **5.10.252 vs 5.10.209**: 差了 43 个补丁版本, 是不是官方 KernelSU 给
   "android12-5.10" 系列的预编译, 但 MTK 树是 5.10.209 而官方用的是 5.10.252?
2. **有没有办法绕过 vermagic 校验?**
   - modversions 开着 (ko 里有 modversions 标志) → 符号 CRC 也校验
   - 但 mt47 你曾反汇编 is_module_sig_enforced=0 (签名不强制) — 那是签名,
     vermagic 是另一回事
   - 用户态能改 ko 的 vermagic 字符串吗? (需要重新算 CRC? 或直接改字符串?)
3. **正确解法是什么?**
   a. 找 5.10.209 对应的 kernelsu.ko (从 KernelSU 官方 release 里挑对版本?)
   b. 自己编 (需要内核源码+配置, 我们有吗?)
   c. 修改现有 ko 的 vermagic (如果 CRC 不校验符号, 只校验字符串?)
   d. 放弃 insmod, 换别的 root 落地方式 (KernelSU 的 ksuinit? 我们也有 ksuinit 411KB)

## 优先级判断
- 这是**终点阻塞**: root 到手但装不上 ko = 白拿 root
- 但 root 本身(双写 cred)仍然有价值(能改 selinux/读文件/提权), 只是 KSU 装不上
- 请对面裁定: 先解决 ko 问题(可能要重下/重编), 还是先拿 root 再说?

## 附带
- ko 是 344504 字节, ksuinit 是 411576 字节 (8-14 同批下载)
- KernelSU_v3.2.5-release.apk 9083665 字节也在

—— matisse 现场 (2026-08-16 16:20)
