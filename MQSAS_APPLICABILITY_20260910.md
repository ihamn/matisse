# mqsas/IMQSNative 免解BL Root 适用性 (research agent 补充, 2026-09-10)

## 关键
- 公开免解BL方案中 mqsas root 调用本身 + 需先 SELinux permissive; 拿 permissive 的公开前置
  (fastboot ABL cmdline androidboot.selinux=permissive / Adreno GPU 漏洞) 全是 Qualcomm 专属;
  matisse = MTK/LK 引导, 无此入口 -> Enforcing 下 mqsas 够不够(尤其 insmod) 全看本机 sepolicy, 必须上机实证
- ★ Redmi Note 13 Pro+ (MTK, HyperOS 3.0.2.0 Global): 普通 adb shell 直接 service call IMQSNative 21
  成功 root 执行 (setprop/ctl.restart) — MTK+HyperOS 上该 root 确存在且 shell 可达
  https://github.com/ukriu/HyperUnlocked/issues/34
- 媒体 (XiaomiTime 2026-03-13): 影响 HyperOS 1~3 / 160+ 机型 (Redmi K 系在内), "BL 锁也可 root 级执行",
  ★官方修复 = 2026-03 安全补丁; 无公开 CVE 号; 无 matisse/HyperOS2.0/A14/MTK 直接验证记录
- mqsas 执行域 = uid0 + u:r:hypsys_ssi_default:s0; mi_nobl_root 日志显示其操作有 avc denied 靠 permissive 放行
  -> Enforcing 下 insmod/setenforce 大概率被拒 (推断, 需查本机 sepolicy)
- IHypSysSsi (#338/339): 公开信息零命中, 只能本地取证

## 上机最小探测序列 (rish 恢复后, 按序)
1. getprop ro.build.version.security_patch  (若 >=2026-03 -> mqsas 大概率已封, 直接走 exploit)
2. service call miui.mqsas.IMQSNative 21 ... -> id / getenforce / echo (验执行+域)
3. 尝试 insmod kernelsu_gki209_v2.ko + dmesg 看 AVC; ★不要先跑 setenforce 0
refs: github.com/mrdong916/mi_nobl_root ; github.com/h1code2/xiaomi_14_root_ksu_lsp (QC permissive 前置示范) ;
github.com/ukriu/HyperUnlocked/issues/34 (MTK 实证) ; ximitime.com 二手媒体稿
