# 突破：借用 5.10.209 同类 PoC 的两个关键技术 (2026-09-10 晚)

## 参考资产 (联网核实)
- **Cxyofficial/K50G-POCOF4GT-CVE-2026-43499-PoC**: Redmi K50G/POCO F4 GT (SM8450), Android14, **内核 5.10.209-android12**, 实机验证临时 root 成功。
  链路: GhostLock UAF -> 内核锚点 root(cred uid/gid=0+全caps+**kernel SID**) -> `libksud.so late-load --kmi 5.10.209-android12` 装 KernelSU 3.3.0 -> ksud 三阶段 -> KSU 模块保持 permissive(每2s写 enforce=0)+修网。
  关键脚本 ksu_loader.sh 已抓取 (late-load + post-fs-data/services/boot-completed + 模块安装)。
- **yakidango-official/GhostLock-H80GT**: Honor 80 GT, **5.10.209 多版本实机验证**, 全源码: exploit/src(slide.c/sysctl.c/util.c/kernelsnitch/targets/*/target.h) + ksu/(自编 ko 构建管线 + 加载驱动 + 工具源码)。
- JingMatrix/pixel-ksu-root (adb 驱动, 签名匹配 ko late-load), yijiacloud/ghostlock-4.19-k40 (LD_PRELOAD 旧内核)。

## 关键技术 1: `empty_versions` —— 免 CRC / 免 vermagic 版本串
5.10.x + CONFIG_MODVERSIONS=y + CONFIG_MODULE_FORCE_LOAD 未开时:
- 无 __versions 段 -> try_to_force_load -> -ENOEXEC (必须存在)
- 段存在但符号未列出 -> pr_warn_once + **PASS**
- 符号列出但 CRC 不符 -> FAIL
=> 把 __versions 段头保留、`sh_size=0` -> 所有 CRC 检查变 warn-once PASS; 且 same_magic() 认为 has_crcs=true
   -> **vermagic 的 release 串也跳过**(只比 flags)。
我们的 ko 生效: 4096 -> 0 (sha 3d830698), preflight 128 -> 0 (9cd5cc38)。

## 关键技术 2: 用 kallsyms 把 SHN_UNDEF 改写成 SHN_ABS (load_ko.c 思路)
- .ko 的未定义符号不再依赖内核 __ksymtab 解析(未导出符号也能用): 读 /proc/kallsyms(列出**全部**符号, 不只导出) ->
  按名字取运行时地址 -> st_shndx=SHN_ABS, st_value=addr -> `init_module(buf,len,flags=0)` 直接按绝对地址重定位。
- kasan_flag_enabled 特例: 别名到 empty_zero_page(KASAN 关的内核上避免碰未映射 shadow)。
- 不能用 IGNORE_MODVERSIONS/IGNORE_VERMAGIC(flags=1/2): 无 FORCE_LOAD 时**静默 -ENOEXEC**, 是陷阱。

## 本机落地 (已完成, 全部离线)
1. `~/ko_patch.py`  : 离线版(用归档 kallsyms 批量改写); 产出 ko_patched/*
2. `~/ko_load.c/.  ko_load` : C 版加载器(读 /proc/kallsyms + 改写 + init_module), 支持 --dry-run 本地测试
   - 自测: 我们 ko 55/63 解析(剩 8 个是**我们归档 dump 丢失**的符号: __rcu_read_lock/__stack_chk_fail/__list_add_valid/__arch_copy_to_user/__check_object_size 等;
     设备 config 明确 DEBUG_LIST=y/PREEMPT_RCU=y/STACKPROTECTOR=y -> **运行时 kallsyms 必然全部存在**), preflight 1/1, 官方 v3.3.0 180/206。
   - 修正过一个解析 bug: 我们的 dump 第二列是 ASCII 数字(84='T'), 不是字母。
3. `ko_patched/`: ksu_v2_emptyver.ko(3d830698) / preflight_emptyver.ko(9cd5cc38) / v330_emptyver.ko(5ca70d23) / v330_patched.ko(SHN_ABS 版)

## 下轮设备侧计划
R(落地) -> C(拿到 kernel-SID root 锚点) -> E5(permissive) -> 锚点内: ko_load 路径(或 exploit 内嵌修补器) init_module -> ksud 阶段 -> 验证 /proc/modules。
两条可选: (a) 用 kernelsu_gki209_v2 + empty_versions(最简, 63 导入设备全导出, 只需空 CRC 段)
           (b) 官方 v3.3.0 + empty_versions + kallsyms 修补(180 已解析, 26 待运行时解析) -- 若 (a) 失败再上
持久化借鉴: KSU 模块 service.sh 在 ksu 域每 2s 写 enforce=0; 重置 ro.boot.flash.locked/verifiedbootstate 并重启 netd 修网。
