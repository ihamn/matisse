# KernelSU 文档调研：非 GKI 必须自编 ko (2026-08-16)

> 用户建议读 KernelSU 官方文档（learn-from-original-projects）。
> 结论：**非 GKI 设备的 kernelsu.ko 不能靠预编译版，必须用设备内核源码自己编译**。

## 官方依据
- kernelsu.org/guide/how-to-integrate-for-non-gki
- kernelsu.org/zh_TW/guide/how-to-integrate-for-non-gki
- DeepWiki: Non-GKI Kernel Integration (5ec1cff/KernelSU)
- SukiSU-Ultra docs how-to-integrate (同族)

## 核心事实
1. **GKI 设备**: 预编译 kernelsu.ko 通用（vermagic 匹配 GKI 标准内核）
2. **非 GKI 设备**（我们: MTK 5.10.209 定制树）:
   - 必须用**设备自己的内核源码**（含 .config）
   - 跑 `setup.sh` 集成 → CONFIG_KSU=y 或 =m
   - 编译内核 → 得到匹配该内核 vermagic 的 ko
   - 预编译 ko（我们手里的 5.10.252-dirty）**无法用于非 GKI**

## 我们手里的资源
- kernelsu_prep/android12-5.10_kernelsu.ko: 5.10.252-dirty（GKI 预编译, 不匹配）✗
- kernelsu_prep/ksuinit: 411KB（未知能否单独用）?
- kernelsu_prep/KernelSU_v3.2.5-release.apk: 管理器 APK

## 卡点
- 需要 **MTK 5.10.209 内核源码**（Redmi K50 Pro / matisse / Dimensity 9000）
- 需要**编译环境**（完整 toolchain, 源码几十 GB）
- 这两个资源我们都没有

## 请对面裁定
1. 确认非 GKI 必须自编 ko 的判断是否准确（对面有反汇编能力，可交叉验证）
2. **源码获取**：MTK 5.10.209 源码怎么拿？
   - 小米开源站 (MiCode/Xiaomi open source)?
   - 设备代号 matisse / 芯片 MT6983
   - 对面是否知道该设备的官方内核源码发布？
3. **优先级**: 先拿 root（双写 cred）还是先搞源码编 ko？
   - root 本身有价值（改 SELinux/读文件）
   - 但 KSU 落地必须 ko → 源码是硬前置
4. ksuinit 能否独立用（不走 insmod）？还是必须 ko?

—— matisse 现场 (2026-08-16 16:30)
