# 官方 KSU LKM 工具包 解析结论 (2026-09-09 夜, 用户问"镜像解析ksu工具包")

## 做了什么
- 用 ghproxy.net 镜像拉取官方 KernelSU v3.3.0 release 的 LKM:
  lkm-aarch64-android12-5.10_kernelsu.ko (349936B, vermagic 5.10.252-dirty)
- 与已有的 v0.9.5 / v3.2.5 LKM 一起做完整解析 (modinfo/__versions/导入符号/CFI/BTI)
- 并从设备内核镜像 __ksymtab/__kcrctab 权威枚举导出表 (2846 non-GPL + 4325 GPL = 7171)

## 结论: 官方 LKM 在本设备无法加载 (与版本无关)
| LKM | 导入 | 设备未导出 | __versions | 判定 |
|---|---|---|---|---|
| v3.3.0 (5.10.252) | 206 | **71** | 空 (0 条) | 不可加载 |
| v0.9.5 (5.10.x) | 94 | 29 | 76 条 (CRC 与设备 64/64 一致) | 不可加载 |
| v3.2.5 | 206 | 71 | 无 | 不可加载 |

未导出的是核心内部符号: commit_creds / prepare_creds / override_creds / get_task_cred /
__put_cred / kallsyms_lookup_name / selinux_state / selinux_blob_sizes / security_hook_heads /
groups_* / avc_has_perm / avtab_* / policydb_* / path_mount / ksys_unshare ...
(设备导出表权威枚举, 非推测)

## 为什么官方 LKM 能"在别处工作"
1. KSU 作者 tiann 在 issue #928 亲口说: 做成模块会有未导出符号问题;
   "kallsyms_lookup_name 5.7 后不导出, register_kprobe 会被某些 OEM 的 GKI 裁掉"
2. 看雪 OnePlus12 案例: 标准 insmod 失败(内核未导出 SELinux 内部符号);
   KSU v3.x 实际靠 ksuinit 注入 init_boot, 不走标准模块加载路径 → 绕过符号限制
   → 本机 BL 已锁, 不能刷/改 init_boot, 这条路对我们彻底关闭

## 对我们项目的意义
- 官方工具包不能直接用 (无论哪个版本); 自编 ko + kprobe resolver 是唯一可行路径
- 官方 v0.9.5 LKM 的价值: 它的 __versions 与设备 __kcrctab **64/64 完全相同**
  → 独立证明我们的 CRC 提取正确 + GKI KMI CRC 稳定 (自编 ko 因此能用 flags=0 加载)
- 官方 LKM 用 LTO+CFI 编译 (有 __cfi_check/__cfi_jt_*), 我们的 ko 未插桩 → 用直通桩等价放行
- 设备内核 **导出 register_kprobe** ✓ (我们的 resolver 引导依赖它, 未被裁掉)
