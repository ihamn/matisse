# AI 留档快照 — 2026-07-18 KernelSU 安装计划 + 5.10 策略调研

> 会话背景: 用户要求 (1) 调研 5(5.10) 系列是否有公开利用策略 (2) 评估提权丢数据风险 (3) 安装 KernelSU (4) 尝试 Shizuku adb（跑之前需告知用户）
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM (API 34)
> 内核: **5.10.209-android12-9-00019-g4ea09a298bb4-ab12 292661** → KMI = 5.10-android12-9

---

## 一、网络环境实测（中国网络）

| 目标 | 结果 |
|------|------|
| github.com | ❌ 不可达 (HTTP 000, 连接失败) |
| raw.githubusercontent.com | ❌ 超时 (8s) |
| kernelsu.org | ✅ HTTP 200 |
| 本机 adb 客户端 | ❌ 未安装 (`which adb` 为空，需 `pkg install android-tools`) |

→ GitHub 资源（aristotle 仓库、KernelSU APK/Release）需走镜像（ghproxy.com / gh-proxy.com / gitee 镜像）。

## 二、5.10 系列公开策略调研结论 ★

**确认：存在针对 MediaTek 5.10 的公开移植 — `soralis0912/CVE-2026-43499-aristotle`**

- 目标: au/KDDI Xiaomi XIG04 (aristotle), MediaTek, Android 12, **内核 5.10.136-android12-9-00020-gc9f59ef34367-ab9585114**（与我们的 5.10.209-android12-9-00019 同一条 android12-9 分支）
- 上游: `x-spy/CVE-2026-43499-popsicle`（小米17, 骁龙, Android 16, 内核 6.12.23）→ 即本项目 "poplicle/popsicle fork" 的来源
- 原始: `NebuSec/CyberMeowfia`（IonStack/CVE-2026-43499, Apache-2.0）→ 本项目 CyberMeowfia/ 目录的上游
- 其他系列对照: 4 系列 = `yijiacloud/ghostlock-cve-2026-43499-4.19-k40`（骁龙 4.19, 不可用）; 6 系列 = `No-22-Github/UnPlus`（GKI 6.6）

### 与本地实测常量的一致性（aristotle PORT 文档 vs 本项目）
| 项 | aristotle (5.10.136) | 本项目 (5.10.209) | 一致 |
|----|---------------------|-------------------|------|
| rt_mutex_waiter 布局 | 扁平 10 word: tree(0)/pi_tree(0x18)/task(0x30)/lock(0x38)/prio(0x40)/deadline(0x48) | trigger_stamp.c 10 word 映射 | ✅ |
| MM_STRUCT_SZ | 0x3c0 | 0x3c0 (prepare=272) | ✅ |
| P0_PAGE_OFFSET | 0xFFFFFF8000000000 (VA=39) | 0xFFFFFF8000000000 | ✅ |
| P0_PHYS_OFFSET | 0x40000000 (XIG04 DTB) | 0x80000000 (matisse) | ⚠️ 设备相关，保留各自值 |
| KASLR | 开（slide.c 动态 leak boot_id→nfulnl_logger→_stext） | 0（已硬编码绕过） | 我们更简单 |
| 加固 | MTE+CFI+SCS+KFENCE (kernelsnitch 猜 tag) | 无 | 我们更简单 |

### 可复用资产（后续克隆对照）
- `generate_target.py` / `gen_aristotle_target.py`: 从 boot.img 生成 target.h 的方法学
- `ARISTOTLE_CVE43499_PORT.md`: 完整移植记录（符号 RVA、结构体偏移、物理常量替代方案）
- `scratchpad/`: adjust_prio_chain_requeue.txt、rtmutex_syms.txt（PI chain walk 反汇编分析）
- `source/src/slide.c`: KASLR 动态泄露实现（fops.c 的 word[6] 仍用 fake_task —— 与本项目 R8 panic 根因相关的分歧点，需对照）

## 三、提权丢数据风险评估（GhostLock）

**结论: 丢数据风险低但非零；主要风险是 kernel panic 重启，不是数据擦除。**

| 风险项 | 等级 | 说明 |
|--------|------|------|
| 数据擦除/格式化 | 无 | 利用只写内核内存（fops/cred/selinux 标志），完全不碰存储 |
| kernel panic → 重启 | 高概率 | 项目历史已多次发生；手机重启本身不丢用户数据 |
| panic 撞上写盘窗口 → 脏页丢失 | 低 | 极端情况个别文件损坏；f2fs/ext4 有 journal，重启后 fsck 可恢复；历史 panic 后均正常重启 |
| MTK slab 耗尽（连续测试第3次必崩） | 高概率 | 增加 panic 频率 = 增加上述窗口概率 |
| Termux 弹退 → 未存档进度丢失 | 高概率 | 项目已知风险（v31 源码丢失教训），非手机数据 |
| SELinux 关闭后 | 无 | 只是安全策略放松，不删数据 |

**建议**: 测试/刷机前备份重要数据（尤其 Documents 下的项目文件），测试时避免大文件写入/同步，保持充电。

## 四、KernelSU 安装计划（进行中，待用户确认）

### 官方文档要点（kernelsu.org/zh_CN）
- KernelSU 是 **GKI 方案**；**v1.0 起放弃非 GKI 官方支持**（非 GKI 最后支持 v0.9.5，kprobe 集成或手动改源码）
- 设备内核 `5.10.209-android12-9-00019` → **KMI = 5.10-android12-9**（GKI 风格命名；SubLevel 209 不属于 KMI）
- 装法: ① Manager APK 显示"未安装"= 官方支持（LKM 模式优先）; ② 显示"不支持" = 需自己编译内核或非官方内核
- LKM 模式优点: 不替换原厂内核、OTA 友好、**临时 root 也可加载 LKM、不触发 AVB**
- 刷机风险警告（官方）: 必须先备份原厂 boot.img；KMI 不一致/SPL 更旧 → 无法开机
- 小米设备 boot 通常 gz 或不压缩

### 路线决策树（需要先探测 BL 状态）
```
[探测 BL 状态: ro.boot.verifiedbootstate / ro.boot.flash.locked / ro.boot.vbmeta.device_state / ro.boot.warranty_bit]
 ├─ 已解锁 → 装 Manager APK（GitHub Releases, 走镜像）
 │    ├─ Manager 显示"未安装" → LKM 模式: 修补原厂 boot → fastboot flash → 重启
 │    └─ 显示"不支持"(android12-5.10 可能) → KernelSU Next / 自行集成 v0.9.5 / 社区内核（列表无 matisse）
 └─ 未解锁 → 不能刷 boot 分区
      ├─ 选项1: 小米 BL 解锁流程（有等待期/政策限制）
      └─ 选项2: GhostLock 提权 → 临时 root → 加载 KernelSU LKM（官方文档确认可行，不触发 AVB）
           ↑ 与本项目目标天然衔接（woshimaniubi8/CVE-2026-43499-root-KernelSU 也是此思路: 越狱模式）
```

### KernelSU 安装丢数据风险评估
- 刷 boot/init_boot 分区**不碰 /data** → 无丢数据风险
- 真实风险 = bootloop（刷错镜像/KMI/SPL 回滚）→ **可逆**：fastboot 刷回原厂 boot.img 即恢复（前提: 已备份原厂 boot + BL 已解锁）
- 未解锁 BL 时无法刷写 → 无 bootloop 风险，但也装不上（只能走 exploit 路线）
- 结论: KernelSU 环节几乎无丢数据风险，有"临时变砖需救砖"风险（可逆）

## 五、待办（下一步，需用户确认）

1. **安装 adb 客户端**: `pkg install android-tools`（Termux 内）
2. **只读探测设备状态**（不改任何东西）:
   ```bash
   adb connect 192.168.3.33:5555   # 或 127.0.0.1:5555
   adb devices
   adb shell getprop ro.boot.verifiedbootstate ro.boot.flash.locked ro.boot.vbmeta.device_state ro.boot.warranty_bit ro.boot.slot_suffix ro.build.version.release
   adb shell uname -a
   adb shell ls /vendor/lib/modules 2>/dev/null   # 判断 GKI/LKM 可行性
   ```
3. **克隆 aristotle 仓库**（走 GitHub 镜像）对照分析
4. **下载 KernelSU Manager APK**（走镜像）→ 装到手机看支持状态
5. 用户确认电脑上后续推进的文件位置，一并对比

## 六、本次会话其他记录
- 未运行任何 exploit/.so；未对手机做任何写操作
- 测试环境: Termux + 本目录；网络: GitHub 不可达，kernelsu.org 可达
- 项目此前最后状态: trigger_stamp_v41 已编译未测试（2026-07-18 00:21），v39/v40 显示 chain walk 提前退出（lock 校验不过）

---

## 七、会话更新 2026-08-14 — rish 恢复成功 + 重大发现（7-21 设备端活动）

### 1. rish 已恢复 ✅（方法已掌握，Shizuku 重启即可用）
- 用户提示的隐藏备份: `/storage/emulated/0/360/1111111/shizuku/` 含 `rish` + `rish.bak` + `rish_shizuku.dex` (6828B)
- 关键发现: Termux home (`/data/data/com.termux/files/home/rish_shizuku.dex`) **7-16 就有 0400 权限的 dex**（之前会话部署的）——rish 从 home 直接可跑
- Android 14 铁律（rish 脚本内置）: app_process **不能加载可写 dex**，必须 chmod 400；/sdcard 的 FUSE 上 chmod 无效 → 必须放 Termux 私有目录
- 实测: `app_process -Djava.class.path=$HOME/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader -c "id"` → **uid=2000(shell), context=u:r:shell:s0** ✅
- ⚠️ 随后 Shizuku 服务随机停止（MIUI 已知问题），需用户在 Shizuku app 重新启动

### 2. 重大发现: /data/local/tmp 有 7-21 的未记录文件（项目 7-18 搁置之后!）
| 文件 | 大小 | 时间 | SHA256 | 身份 |
|------|------|------|--------|------|
| preload.so | 79136 | 07-21 22:17 | 57625ce2... | **GhostLock DIRECT root 版**（strings: GHOSTLOCK_DIRECT, install_cred_then_selinux_zero, root-enter, direct per-cpu entry, direct boot_id read）— 与项目存档任何版本都对不上（R11=111KB, v36=164KB） |
| binder.so | 142128 | 07-21 00:02 | db3ca637... | 小工具（C++: assert/printf/log）用途待查 |
| pstore.log | 262132 | 07-21 21:41 | - | MTK 内核 console log（头部是充电/CCCI 噪声；**崩溃信息应在尾部**）→ pstore 存在 = 7-21 可能发生过 kernel panic |

- 来源待确认: 用户说"电脑上后来也推进了一点"——可能相关；也可能 7-21 手机端另有会话
- 文件复制被 Shizuku 停止打断（需重启后从 rish cp 到项目目录 `device_recovered_2026-07-21/`，目录已建好）

### 3. 环境实测记录
- 本 bash 以 u0_a474 (untrusted_app_27) 运行 = Termux 本体；/data/local/tmp 对 Termux 不可见（Permission denied），只能经 rish 访问
- 设备状态（Termux getprop 直接可读）: verifiedbootstate=green / flash.locked=1 / vbmeta=locked / Android 14 / SPL 2025-04-01 / BL 锁定 ✅
- GitHub 直连不通；可用镜像: gh-proxy.com / ghfast.top / ghproxy.net（f-droid、ghproxy.com 不通）
- Termux adb 客户端已装 (35.0.2) 但无线调试端口未监听；不走 adb，走 rish

### 4. 下一步（待 Shizuku 重启）
1. 用户重启 Shizuku → 我立即用 home dex 验证 rish
2. rish 内复制 3 个 7-21 文件到 device_recovered_2026-07-21/
3. 分析 pstore.log 尾部（panic 信息）+ preload.so 反汇编确认路线版本
4. 确认这些文件与"电脑上推进"是否同源
5. 之后: exploit 推进 → root → KernelSU LKM（路线 B）

---

## 八、会话更新 2026-08-14（续）— 资料已克隆，进入"用资料"阶段

### 1. 克隆完成（gh-proxy.com 镜像）
- `_research/CVE-2026-43499-aristotle` — 5.10 MTK 移植（XIG04, 5.10.136-android12-9-00020）
- `_research/CVE-2026-43499-Poc-Analysis` — Linuxoid-cn 通用适配框架（**7-21 手机上跑的 preload 就是它编译的**）

### 2. 关键分析结论
- 7-21 preload_direct.so 身份: Linuxoid-cn 框架产物（sched_setattr 触发 + slide pselect 喷假 waiter + direct root）
- 7-21 崩溃: NULL deref @ rt_mutex_adjust_prio_chain+0x188（sched_setattr 触发）; 崩溃时 **KASLR slide=0x26d2400000（KASLR 是开的！）** — 项目"KASLR=0"假设可能只在特定启动成立; direct-map 地址不受影响
- rt_mutex_adjust_prio_chain 本机偏移 ≈0x1eae38 ≈ aristotle 0x1e78bc（同代内核确认）
- **框架自身疑点（7-21 崩溃可疑根因）**: ① MM_STRUCT_SZ=0x500（项目 R7 铁证应为 0x3C0）② 13-word waiter 布局（6.12 风格, task=word10/lock=word11）→ matisse 5.10 需 10-word 扁平（task=+0x30/lock=+0x38）③ 用 fake_task（R8 panic 教训）→ 应改用 init_task
- aristotle 已做正确 5.10 适配（10-word, MM_STRUCT_SZ 0x3C0, 实测偏移）— **修复参照**

### 3. 本地资产清单（都在手边）
- boot.img: `images/boot_final.img` (64MB, 7-12) + kernel.Image + vendor_boot_full.img
- matisse 常量: `ref/target_matisse.h`（P0_PAGE_OFFSET=0xffffff8000000000, P0_PHYS_OFFSET=0x80000000, P0_KERNEL_PHYS_LOAD=0x80000000, INIT_TASK_OFF=0x279bec0）
- 工具链: Termux clang 21.1.8 + llvm-objdump + make + python3 + git ✅
- rish: 已恢复可用（home dex + Shizuku 运行中）
- 7-21 证据: `device_recovered_2026-07-21/`（preload_direct.so + binder.so + pstore.log）

### 4. 进行中
- 用 Linuxoid-cn generate_target.py + boot_final.img + matisse profile 生成 target.h，与已知常数比对验证
- 下一步: 按 aristotle 5.10 适配修正框架（MM_STRUCT_SZ 0x3C0 / 10-word 布局 / init_task）→ Termux 编译 → rish 部署测试（需用户许可 + 留档）

---

## 九、会话更新 2026-08-14（续）— 构建成功！待测试

### 1. 实证结论（反汇编内核验证）
- matisse rt_mutex_waiter = **扁平 10-word**（lock@+0x38, prio@+0x40 u32, deadline@+0x48）✅ 与 aristotle/trigger_stamp 一致
  → 项目 ref/target_matisse.h 的 WAITER_PRIO_OFF=0x44 / WAKE_STATE 是 6.x 模板错误值
- matisse task_struct: **real_cred@0x778, cred@0x780**（commit_creds 反汇编实证）
  → 项目 fusion_release/target_matisse.h 的 0x818/0x820 **是错的**（解释了 R 系列 direct root 一直失败）
- pi_lock@0x86c / pi_waiters@0x880 / pi_blocked_on@0x898（chain 反汇编实证）与 aristotle 一致
- 7-21 崩溃根因: Linuxoid-cn 框架 13-word 布局（task@0x50）+ fake_task → chain walk 读错偏移 → NULL deref @ rt_mutex_adjust_prio_chain+0x188 (`ldar w8,[x27]`, x27=waiter->lock)
- **KASLR 确实开启**（CONFIG_RANDOMIZE_BASE=y + 7-21 崩溃 Kernel Offset=0x26d2400000）→ 项目"KASLR=0"假设只对 direct-map 目标成立
- matisse 内核**无 BTF**（与 aristotle 同）

### 2. 生成器适配（已完成 3 处补丁，Linuxoid-cn generate_target.py）
- image_size < 文件大小 → 警告不失败（保留真实 image_size）
- kallsyms 固定点增加 `_text,_head,pe_header`(0,0,0x40) 签名（项目提取漏了 _head）
- offsets 表搜索起点改 0（MTK 5.10 布局: offsets 在 names/token 之前）
- 已用 aristotle gen_aristotle_target.py + matisse 参数生成 target.h（46 macros）
  **所有锚点与项目 kallsyms 验证值一致** ✅（INIT_TASK 0x279bec0, ENTRY_TASK 0x27562f8, PER_CPU_OFFSET 0x278a558, SLIDE_* 全对）
- kernel.Image 尾部 2.2MB 是提取 junk（_edata.._end 全零= bss；_end 后非零垃圾）

### 3. 构建完成 ✅
- **aristotle 源码 + matisse target.h + Termux clang → preload.so**
- SHA256: **f12467a2** → 已存档 `preload_aristotle_mtk_v1.so` (93848B)
- 身份确认: slide_leak_kernel_base / kaslr_slide / sched_setattr / direct root 管线完整
- 编译: `make CC=clang`（Makefile 自动加 -DANDROID_APP_NO_LKM -llog）

### 4. ⚠️ 环境: Shizuku 停止原因 = 用户在**移动数据**下（无线调试依赖 WiFi，切网后服务掉线）
- 等用户回 WiFi/重启 Shizuku 后再测试
- 对策: 命令合并成单次 rish 调用

### 5. 待办: 测试（需用户许可 + Shizuku 在线）
1. 单次 rish 批量: 部署(rm+cp+sync+sha256 验证) + 运行 `LD_PRELOAD=... sleep 30 | tee logs/aristotle_v1_test1.txt`
2. 预期: slide 泄露 → direct root → su daemon → root summary；或 panic 重启（pstore 记录）
3. 成功后: KernelSU Manager APK → 查 android12-5.10 支持 → LKM（路线 B）

---

## 十、v1 测试结果 + v2 修复（2026-08-14 17:10）

### v1 测试（SHA256 f12467a2）→ 手机重启（预期失败模式，无数据损失）
- 崩溃日志幸存: /data/local/tmp/aristotle_preload.log（已复制到 logs/aristotle_v1_preload.log）
- 失败定位: **slide 泄露阶段** — boot_id 未被覆写（读回原始 boot_id），leaked=原始 boot_id 前8字节
  → chain walk 的 lock 校验不过/提前退出 → rb_erase 未执行 → 无写入
- 前 2 次尝试(shift 1,2)只是失败不崩；**第 3 次尝试 slab 耗尽 → panic 重启**（MTK 铁律再验证）
- pstore 未更新（非标准 panic 或 mrdump 未触发）— aristotle 的文件日志机制立功

### v2 修复（SHA256 4dc385d3）
1. **移除 SIGALRM 信号竞争触发机制**（aristotle 为 XIG04 设计；matisse 上 fusion_release R8 实证 plain-timeout 即可触发，SIGALRM+setpriority 反而可能干扰）
2. **SLIDE_MAX_ATTEMPTS 20→2**（MTK slab 脆弱，v1 就是第 3 次尝试崩的；shift 1 是项目实测值优先）
- 依据: rt_mutex_init_waiter 反汇编铁证 matisse=10-word 布局(task@0x30)；fusion_release plain-timeout 触发在 matisse 成功过(R8)
- 测试: logs/aristotle_v2_test1.txt（等用户确认后跑，重启后第 1 次测试）

---

## 十一、mt2 结果 + mt3（2026-08-14 17:2x）

### 版本命名切换（用户要求）: v/R 系列已废弃 → **mt 系列**
- preload_mt1.so (原 v1, SIGALRM, 崩溃) / preload_mt2.so (原 v2, 无SIGALRM, 不崩但泄露失败)

### mt2 测试（SHA256 4dc385d3）→ 无崩溃 ✅ 但 slide 泄露仍失败
- boot_id 未被覆写 (leaked=原始 boot_id 前8字节), stext=0, exploit 干净退出
- sigalrm=0 pkill_ret=-1 确认 SIGALRM 移除生效 → **排除 SIGALRM 因素**
- /proc/kallsyms, kptr_restrict, dmesg 全部 SELinux 拒绝 → GhostLock KASLR 泄露不可绕过

### 关键分析结论
- R8 "phase6 leaked" 是 prepare_good_kernel_page 喷页泄露 (util.c phase0-9), 不是 KASLR 泄露!
  → boot_id→stext 泄露在 matisse 可能从未成功过
- rb_erase 写原语 (right==NULL 分支): ① node->rb_left->__rb_parent_color = node->__rb_parent_color
  ② parent->rb_right = node->rb_left;  +0x38(lock 字节) 在两成功案例中 = boot_id 地址
- **mt3 假设: slide 表改 13-word (R8 编码) → +0x38 = pi_left = boot_id 地址**

### mt3（SHA256 752da1df）
- slide.c: 10-word → **13-word** (fusion_release R8 编码: tree_prio@3, pi_tree@5-7, task@10=SLIDE_INIT_TASK, lock@11, wake_state@12)
- 保留: 无 SIGALRM + SLIDE_MAX_ATTEMPTS=2
- 测试: logs/mt3_test1.txt（本次重启第 2 次测试，之后需重启才能再测）

---

## 十二、mt4（2026-08-14）— GC sleep 缓解（免重启延长测试预算）

### 回答用户"是否可以不用重启手机"
- **轻量操作不需要重启**: EDEADLK 探测/读日志/boot_id 检查/静态分析 — 7-17 曾连跑 5 次 trigger 测试无重启
- **重活才需要**: prepare_good_kernel_page (clone 500+ + 喷堆 + SKB reclaim) 连续跑 → slab 耗尽 → panic
- 免重启缓解 (LESSONS_LEARNED R2/R3): ①重试间 sleep(2) 等内核 GC ②开原神压内存触发 shrinker/compaction ③减少克隆量

### mt4（SHA256 25f746ca）= mt3 + util.c 重试循环加 usleep(2s)
- 13-word slide 表 (R8 编码) + 无 SIGALRM + SLIDE_MAX_ATTEMPTS=2 + retry 间 GC sleep
- 目的: 本次开机 mt2 已跑过 (第1次), mt4 作为第2次更安全; 若还需更多测试, 可用 sleep+原神缓解或重启
- 测试: logs/mt4_test1.txt（待 Shizuku）

---

## 十三、mt4 测试结果（2026-08-14 17:2x）→ 手机重启（疑似 slab 累积损伤）

- mt4 (13-word, SHA256 25f746ca) 在 **fork slide 子进程后即崩**（日志止于 "slide child pid", 未到 CMP_REQUEUE_PI）
- 时间线: 本次开机 mt2(第1次, 2次重喷) → mt4(第2次) → 崩 → 重启
- **判断: 大概率是累积 slab 损伤**（fd_set 13-word 表还没被内核用到就崩了, 崩点与代码改动无关）
- "每次重启最多 2 次测试" 铁律再次验证
- 当前: 全新开机 (uptime ~217s), 有 2 次测试额度
- 计划: 干净环境下重测 mt4 (13-word) — 验证 13-word 假设是否成立

---

## 十四、mt4 二次崩溃分析（2026-08-14 17:2x）

- mt4 两次崩溃点相同: fork slide 子进程后 ~8ms（CMP_REQUEUE_PI 前）
- **关键推理: 13-word 表不可能导致此崩溃** — prepare_slide_pselect_fdsets 在 CMP_REQUEUE_PI 后 ~2s 才执行(子进程内), 8ms 窗口内只跑 clone×3 + FUTEX_LOCK_PI(waiter/owner)
- 崩溃窗口内的内核操作 = 线程创建 + rt_mutex PI 链操作 + 喷堆残留 slab 交互 → **疑似喷堆操作固有随机性**(mt2 同一代码跑完没崩, mt4 两次都崩)
- 结论: 13-word 假设尚未真正测试(从未到 pselect); 在干净开机再测 mt4
- 若再崩 → mt5 = 10-word + lock字段(boot_id地址) 验证 +0x38 假设

---

## 十五、暂停测试（2026-08-14 用户指令）

- **用户要求停止测试**: 每次崩溃都要重启 + 重新配置环境 (Shizuku 等), 成本高
- mt4 (13-word) 共崩 3 次, 均在 fork slide 子进程后 ~8ms (CMP_REQUEUE_PI 前)
- 已归档构建: mt1(崩) mt2(10-word, 稳定跑完但泄露失败) mt3(13-word, 未测) mt4(13-word+sleep, 3崩)
- 下一步(等用户许可后再测):
  - mt5 假设: 10-word + lock 字段(0x38) = SLIDE_RANDOM_BOOT_ID_DATA (R8 成功案例的字节值)
  - 或重新审视 slide 泄露的 tree_pc 值与 stext 推导逻辑 (静态分析中)
- 静态分析发现(待验证): aristotle slide 期望 leaked = nfulnl_logger TEXT 地址(含slide),
  但 rb_erase 写入值 = tree_pc = loggers dmap (0xffffff80027912c8) → stext 推导可能本身就有问题

---

## 十六、重大突破：泄露机制解密 + mt5（2026-08-14 17:5x）

### 核心发现（对照 popsicle/duchamp 原版 + 内核数据实证）
1. **fusion_release 的 fops main route（do_pselect_fake_lock_route + main.c 线程）才是 matisse 实证过的原始路径**（R8 的 direct-w64 就是它写的 boot_id）；slide route（fusion 和 aristotle 的）在 matisse 可能从未成功
2. **aristotle 的 off 常量是 XIG04 特有错误**:
   - 代码: off = p0_alias_image_offset(SLIDE_NFULNL_LOGGER) = 0x27913a0, stext = leaked - off
   - matisse 实证: nfulnl_logger (0xffffff80027913a0) 的**内容** = 0xffffffc00a065d50 = **RVA 0x2065d50 的指针**（max_tt_usecs 区域内, 疑为 name 字符串指针）
   - 正确推导: **stext = 读到的内容 - 0x2065d50**
3. loggers 数组 (0x27912c8) 全零 — 读 loggers 内容无意义; nfulnl_logger 的内容才是关键
4. r64 读原语语义（R8 实证）: shape=0 时 boot_id 收到 **Q 的内容**（entry_task 读回 task 指针 ffffff80734be180）

### mt5（SHA256 a71d5404）= aristotle + 替换 slide 泄露
- main(): slide_leak_kernel_base() → direct_read_shape0_exact64_once(SLIDE_NFULNL_LOGGER, &got)
- stext = got - 0x2065d50（matisse 常量）, 校验后设 kaslr_base/kaslr_slide
- 然后原样进 run_direct_root_stage（现在 KASLR 正确）
- 保留: 10-word fops 表 + 无 SIGALRM + GC sleep（mt2 基础）
- **待测试（需用户许可）** — 这是第一个"用对路径+用对常量"的版本

---

## 十七、mt5 结果 + mt6（2026-08-14 18:0x）

### mt5 测试（SHA256 a71d5404）→ 不崩, 但 oracle 失败
- ★ 首次触发: fops route `pselect attempt=2 calls=1 success=1` (写原语触发!)
- 但 boot_id 收到垃圾 (value=7a4960e1660f43c4 sidecar=752d26b02d7a8cac, 期望 [内容, b])
- 结论: sched_setattr success≠写落地; chain walk 在 lock 校验(+0x38)提前退出
- **+0x38 lock 字节假设坐实**: fusion fops 13-word 的 +0x38=pi_left=b; aristotle fops 10-word 的 +0x38=fake_lock

### mt6（SHA256 ad4c7bad）
- fops.c 表: 10-word → **13-word** (= fusion fops R8 编码, +0x38=b)
- task@10 = **SLIDE_INIT_TASK** (R8 fake_task panic 修复)
- 保留: direct-kaslr 泄露 (fops route 读 nfulnl_logger) + 无 SIGALRM + GC sleep
- **本次开机第 2 次测试**（之后需重启）

---

## 十八、mt6 结果 + mt7（2026-08-14 18:1x）

### mt6 测试（SHA256 ad4c7bad, 13-word fops）→ 手机重启
- 日志止于 direct-w64[0]（pselect 触发中崩溃）
- **分析: 13-word 的 +0x30(task) = word6 = pi_right = 0 → NULL task → chain walk 解引用崩溃**
- 对比 mt5 (10-word, lock=fake_lock): 触发成功但写入未落地 (lock 校验不过)

### ★ 证据链完整: 两个字段都要对
- **+0x38 (lock) = b (boot_id 地址)** → chain walk 校验通过 (R8 实证值)
- **+0x30 (task) = SLIDE_INIT_TASK** → 避免 NULL task 解引用 (R11 教训)
- 10-word 和 13-word 各只对一半 → 需要混合布局

### mt7（SHA256 8d01f3dc）= 10-word 表 + lock 字段 = SLIDE_RANDOM_BOOT_ID_DATA
- fops.c: {7, fake_lock, "lock"} → {7, SLIDE_RANDOM_BOOT_ID_DATA, "lock"}
- 保留: direct-kaslr 泄露 (fops route 读 nfulnl_logger) + 无 SIGALRM + GC sleep
- 新开机第 1 次测试

### 环境备注
- Shizuku "User is locked" = 开机早期/用户解锁前启动的瞬时报错 (CE 存储未解锁), 非 A/B 问题; 解锁后正常

---

## 十九、v 系列资产评估 + mt8（2026-08-14 18:2x）

### v 系列可用资产（回答用户）
1. ★ **OFF 强触发**（0xffffff80028e76d8, ashmem_misc）: v30 实证 matisse 唯一可靠触发 rb_erase 的 parent (ret 150-199); 其他 parent=弱触发 (ret=1, rb_erase 基本不执行) → mt5/7 失败根因
2. deep PI chain (v29/v30, 6 测试零崩溃) — 稳定性备份
3. canon_addr/word 映射/shape 框架 — 已融入
- 诚实结论: v 系列无成功读原语; R 系列读 boot_id 也未成功过; 但 OFF 写是唯一实证可靠的原语

### R8 真相（读完整日志）
- "slide-kaslr-mtk-hardcoded base=ffffffc008000000 slide=0" — R8 硬编码 KASLR=0, 从未读 boot_id
- "phase6 leaked=ffffff80734be180" = 喷页泄露 (spray mm_struct 页), 非 boot_id 读
- R8 无 oracle 行 → 读原语从未成功

### mt8（SHA256 a0c1ee1d）= 写原语验金石
- fops.c: tree_parent = ASHMEM_MISC_OFF|1 (v30 强触发), tree_right=1 (防 name_ptr=NULL), tree_left=boot_id (Write A 目标)
- 预期: boot_id 收到 OFF(0xffffff80028e76d8) → 写原语实证; 或 pristine → 强触发也不写; 或崩
- 保留: lock=b, task=SLIDE_INIT_TASK, 无 SIGALRM, GC sleep
- 本次开机第 2 次测试

---

## 二十、mt8 结果 + mt9（2026-08-14 18:3x）

### mt8 测试（SHA256 a0c1ee1d, OFF|RED 强触发）→ 不崩但 boot_id 仍 pristine
- value/sidecar 与 mt7 完全相同 (= 本次开机原始 boot_id) → OFF 强触发在此路由也不写 boot_id
- **v30 的"写 name_ptr"是反汇编推断, 从未实证** (/proc/misc 被 SELinux 封); ret=150-199 可能是 deep chain 调用数
- **matisse 上 rb_erase 写入从未被任何人实证过**

### 剩余最大嫌疑: overlay 对齐 (shift)
- pselect 内核栈帧 vs FWRQ 释放帧的地址差由 shift 补偿
- slide route 扫过 shift 但 SLIDE_MAX_ATTEMPTS=2 限制没扫完; fops route 只试过 shift=1
- R8 也是 shift=1 且未实证

### mt9（SHA256 c24aa448）= fops route 扫 shift 1-8
- fops.c: 还原 shape 逻辑 (parent=Q), 新增 fops_word_shift 全局, do_pselect_fake_lock_route 每次尝试扫 shift (0-7)
- task@word6 = SLIDE_INIT_TASK (替换 fake_task)
- 8 次尝试正好覆盖 8 个 shift; 日志打印每次的 shift
- **待测试: 本次开机 mt7+mt8 已用满 2 次额度, 需重启后才能跑**

---

## 二十一、电脑端数据 + rb_set_parent 根本限制（2026-08-14 用户提供）

### 电脑端 3 轮测试结果（7-21 附近）
| # | 环境变量 | 结果 |
|---|---------|------|
| 1 | 无 (Slide 模式) | pselect 触发成功; mm_struct 泄漏返回 d74c69a5ae3b8f7... (非指针, 泄漏失败; 电脑假设 KASLR=0) |
| 2 | GHOSTLOCK_DIRECT=1 | shape=0 读 percpu_offset → **panic 重启** |
| 3 | GHOSTLOCK_DIRECT=1 + PCPU_DELTA=0x1567000 + TASK=0xfffff800279bec0 | shape=1 写 cred → **panic 重启** |

### ★ rb_set_parent 根本限制（电脑端追踪 rb_erase 代码路径确认）
```
shape=1: child = node->rb_right = value
rb_set_parent(child, parent) → 写 parent 到 child+0x00 → 破坏 value 指向的内存前 8 字节!
parent->rb_right = child → 写 value 到 target ✓
```
- 写非零 value=V 到 target → **V+0 被破坏**（value=INIT_CRED 时 init cred 被破坏 → panic）
- **唯一安全写入: value=0 (NULL)** → child=NULL → rb_set_parent 跳过 → 可安全写 0 到任意内核地址
- 解释: "shape=1 write primitive never succeeded" = 原语根本限制, 不是 delta 问题

### 辩证分析（我们 vs 电脑）
- 电脑构建 = Linuxoid-cn 框架 (13-word: fake_task@10, fake_lock@11); 我们 = aristotle 基础
- **电脑的写确实落地了**（panic 证明 rb_erase 执行了）; 我们的 mt5-8 写不落地 → 表/路由编码差异
- 电脑 test3 的 GHOSTLOCK_TASK=0xfffff800279bec0 **少了两个 f** (应为 0xffffff800279bec0) → test3 panic 可能部分是错误地址
- 电脑 slide 泄漏也失败 (返回 boot_id 字节) → 与我们的发现一致

### 推论
1. **cred 指针覆写 (direct root) 在此原语下不安全** (value=INIT_CRED 必崩) → 需假 cred (喷页地址) 或只写 0
2. **写 0 到 SELINUX_ENFORCING dmap 0xffffff8002a41b99** (KASLR 无关!) → 关 SELinux → 再找其他提权路径
3. 前提: 写入必须落地 → 需复现电脑的写入编码

---

## 二十二、辩证修正 + mt10（2026-08-14 18:5x）

### 辩证修正（用户电脑数据 + 7-21 pstore 对照）
- 电脑 test2/3 的 panic 疑似 = 13-word shape=1 时 +0x38(left)=0 → **NULL lock 解引用** (7-21 pstore 同款), 未必是"写入落地后破坏目标"
- "电脑写入能落地"也存疑; **+0x38 必须有效可解引用** (mt7 用 boot_id 不崩是实证)
- matisse 上任意写仍未被人实证成功; 核心问题 = 写入不落地 (shift/overlay 对齐最大嫌疑)

### mt10（SHA256 cc7ace5a）= mt9 基础 + selinux-zero
- main(): 跳过 KASLR 泄露 → 直接 shape=1 写 0 到 SELINUX_ENFORCING dmap (0xffffff8002a41b99, KASLR 无关)
- value=0 → child=NULL → rb_set_parent 跳过 → 安全
- 保留 mt9: shift 扫描 1-8 + 10-word 表(lock=b, task=SLIDE_INIT_TASK)
- 验证: 脚本加 getenforce
- 内核配置已证可行: CONFIG_SECURITY_SELINUX_DEVELOP=y, 无 ALWAYS_ENFORCE
- **待测: 重启后 mt9 → mt10 连测**

---

## 二十三、mt11 = v30 技术提升型（2026-08-14 18:2x）

### 关键认识（反汇编 + v30 日志）
- **2 线程 sched_setattr 触发的 chain walk 在 matisse 永远到不了 rb_erase**（多重属主/循环检查在 +0x3bc+ 前退出）
- **v30 deep chain（3 级 PI 链, f_owner_block）+ OFF|RED + shift=0 → ret=193 强触发**（实证 rb_erase 执行!）
- v30 的 lock=fake_lock（wait_lock=0 → 过 +0x188 检查）; 我们 mt 系列的 lock=b(boot_id) 随机非零 → 自旋路径
- v30 源码在 CyberMeowfia/.../exploit/src/.bak_v30（用户要求不动原目录）

### mt11（v30 技术提升型）
- 工作区: _research/mt11_v30/（v30 源码 + matisse target + 补 LOCK_OFF/W0_OFF/DIRECT_MAP）
- 构建: SHA256 7d16b26d == 存档 v30 原版 ✅（忠实还原）
- **selinux-zero 测试（env 调参, 不改代码）**:
  PSELECT_TREE_PC=ffffff8002a41b91 (selinux-8), TREE_RIGHT=0, TREE_LEFT=0,
  PI_*=0, PAT_C0=1, SHIFT=0
- 原理: deep chain 触发 rb_erase → csel 写 tree_right(0) 到 parent+8 = selinux 区域 (8字节零含 enforcing 字节 b99)
- 测试脚本: scripts/test_mt11.sh（getenforce 前后对比）
- **待测: 本轮开机 mt9+mt10 已用满额度; 但前两次没崩, 可冒险第3次**

---

## 二十四、mt12 = v30 技术提升型（代码级, 2026-08-14 18:3x）

### mt12 改动（工作区 _research/mt11_v30/src/fops.c, 不动项目 v30 原目录）
1. **默认关 Path C** (v28 FOPS 死路) → tree 保持 Path A/B
2. **def_pi_parent = 0xffffff8002a41b91 (selinux-8|RED)** — pi_tree rb_erase (Call 2/3) 写目标 = parent+8 = selinux
3. **def_pi_right = 0** — 写值 0 (child=NULL → rb_set_parent 跳过, 安全; RED → 无颜色修正)
4. tree 保持: tree_pc=OFF|RED (ret=193 强触发), tree_right=fake_fops (写 name_ptr, 安全), tree_left=0

### 原理
- tree (Call 1): OFF 强触发 → 写 fake_fops 到 name_ptr (验证触发 + 无 NULL 崩溃)
- pi_tree (Call 2/3, deep chain 设计目标): 写 0 到 selinux (0xffffff8002a41b98 起 8 字节, 含 enforcing 字节 b99)
- getenforce 验证

### mt12 二进制: SHA256 ba9174fc (≠ v30 原版 7d16b26d ✅)
- 测试: scripts/test_mt11.sh (getenforce 前后)
- 本轮开机已跑 mt9+mt10 (2次), mt12 是第 3 次 (slab 风险; 用户选择直接跑)

---

## 二十五、mt12 结果 + mt13（2026-08-14 19:0x）

### mt12 测试（v30 技术提升型 + 测试脚本残留 env）→ 系统无响应(需重启)
- **发现1**: 测试脚本的 env（TREE_PC=selinux-8）覆盖了代码默认 → 实际跑的是 env 配置
- **发现2（关键）**: tree_pc=selinux-8 + deep chain → **4 次尝试全部 ret=36**（calls=1 success=1）
  → selinux-8 parent 在 deep chain 下可行（v30 时代其他 parent 都是 ret=1）!
- **发现3**: 重试循环 = PSELECT_CFI_ROUTE_ATTEMPTS(5次) × 全量喷堆 = slab 杀手
- getenforce 未捕获（运行中系统无响应）; 手机需重启恢复 slab

### mt13（SHA256 a573a041）= mt12 + PSELECT_ONE_SHOT=1
- main.c: PSELECT_ONE_SHOT env → 只跑 1 次 pselect（省 slab）
- 测试配置: TREE_PC=selinux-8, TREE_RIGHT=0, TREE_LEFT=0, PI_*=0, PAT_C0=1, SHIFT=0, ONE_SHOT=1
- 单次 pselect (ret=36 预期) → 立即 getenforce
- **待测: 手机重启后**（当前 slab 已耗尽）

---

## 二十六、免重启清 slab 实测（2026-08-14 19:2x, 用户要求）

### 方法: 内存压力触发 shrinker+compaction（免 root, drop_caches/compact_memory 被 SELinux 封）
- 工具: _research/mem_pressure.c / mem_pressure2.c（Termux 编译, rish 部署到 /data/local/tmp）
- 第1轮 (2GB): Slab 881→779MB, SUnreclaim 655→571MB (清84MB), MemAvailable 2.5→4.5GB ✅
- 第2轮 (4GB×4): SUnreclaim 574MB 纹丝不动 → **剩余为内核在用对象, 压力清不动**
- 系统扛过 4×4GB 压力未崩 → "无响应"缓解, 稳定性恢复

### 结论
- 压力回收有效但有限: 清可回收 slab + 触发 compaction; 清不动 in-use 对象
- exploit 需要的 mm_struct order-3 cache 恢复程度不可测 (slabinfo 被封)
- 系统已稳定, 可再战 mt13 (ONE_SHOT 单次轻量)

---

## 二十七、mt13 重跑失败 + v30 源码关键注释（2026-08-14 19:3x）

### mt13 重跑（压力回收后）→ 死在 warmup kernelsnitch 碰撞搜索
- 日志 10 行止于 "spray children done, setup KernelSnitch", 进程消失, 无报错
- 结论: 当前 slab 状态连喷页/kernelsnitch 都跑不了 → 内存压力恢复不了喷页所需 cache

### v30 slide.c 源码注释（重要自白）
1. **"pselect side-channel fails on MTK scheduler"** — v30 作者早就知道 boot_id/pselect 读在 MTK 不行（印证本 session 全程发现）
2. "kallsyms confirms _text == KIMAGE_TEXT_BASE at runtime, slide=0" — v30 的 KASLR=0 假设（7-21 崩溃显示 slide=0x26d2400000, 该假设存疑）
3. **"Warm up is CRITICAL for MTK — skipping causes KernelSnitch to fail and panic"** — warmup 喷页不可跳

### 结论
- 内存压力: 系统稳定 ✅ / 喷页 slab 恢复 ❌
- exploit 重跑需要**重启**（无替代）; mt13 (ONE_SHOT) 重启后跑是干净测试
- selinux 写目标为 dmap (KASLR 无关), 不依赖 KASLR 假设

---

## 二十八、mt13 完整跑通 + 定论（2026-08-14 19:4x）

### ✅ 用户"超级省电"思路验证: am kill-all 修复了喷页 stall!
- 杀后台应用 → 释放 mm_struct → warmup kernelsnitch 通过 (之前死在碰撞搜索)
- 免重启恢复喷页能力 = 杀后台应用 (am kill-all / 超级省电), 比内存压力更精准
- 内存压力 (mem_pressure.c): 清可回收 slab + 稳系统; am kill-all: 恢复喷页 cache

### ❌ 定论: matisse 上 rb_erase 写入从未落地 (mt1-13 + R + v + 电脑端 全部)
- mt13 完整流程: deep chain + selinux-8 parent + tree_right=0 → getenforce=Enforcing
- 触发有 (ret 36-193, calls 有时=1) 但写入永远不落地
- 根因 (反汇编): chain walk 在 rb_erase 前的 owner/top_task 检查 (+0x3bc+) 退出 — 假 waiter 无法满足
- 2线程触发: 过不了 +0x100 cbz; deep chain: 过得了但写不中
- v30 源码注释自认: "pselect side-channel fails on MTK"

### 项目状态
- KernelSU 路线B (exploit→root) 卡死在写原语
- 资产: mt13 ONE_SHOT + am kill-all 喷页修复 + 内存压力工具 + 27节分析文档
- 下一步候选: 深挖 chain walk 属主检查的可满足条件 / 评估其他方向

---

## 二十九、android12-5.10 源码定案 + mt15（2026-08-14 20:0x）

### ★ 源码级定案 (kernel/locking/rtmutex.c, android12-5.10)
- rt_mutex_adjust_pi 门: prio 不等才调 chain walk (我们的 130≠120 ✓)
- chain walk 检查: [3] next_lock==waiter->lock (自洽✓) / [5] wait_lock trylock (fake_lock=0✓) / [6] owner≠top_task (fake_task✓)
- **requeue=true 路径必执行 [7] rt_mutex_dequeue → rb_erase_cached(&waiter->tree_entry, &lock->waiters) (line 663)**
- dequeue 门: RB_EMPTY_NODE (tree_pc≠节点地址 ✓)
- **结论: 假值全过检查, rb_erase 必执行 → 写不落地 = overlay 未对齐 freed stack (读到残留, tree_pc 是真实树指针 → 写真实结构)**
- 破局 = 对齐 (shift) + 可验证目标 (boot_id)

### mt15（SHA256 f347d935）= v30 + shift 扫描 + boot_id 验证
- pselect_thread route 循环: PSELECT_SWEEP_SHIFTS=1 → 每次尝试 shift=(attempt-1)%8
- 每次 calls>0 后回读 boot_id, 变了 → "★★ WRITE PRIMITIVE CONFIRMED"
- 测试: scripts/test_mt15_sweep.sh (boot_id 前后对比)
- 源码: _research/rtmutex_src/ (rtmutex.c + rtmutex_common.h)

---

## 三十、mt15 卡死 + mt16（2026-08-14 20:2x）

### mt15 测试 → 卡死在 FOPS 阶段前 (warmup 后)
- 日志止于 "MTK cooldown after SLIDE warmup", 进程死, 无扫描结果
- 原因: warmup 喷堆又搞坏 slab (SUnreclaim 504MB)
- 对策: 跳过 warmup 省一次重喷

### mt16（SHA256 5a6a699e）= mt15 + PSELECT_SKIP_WARMUP=1
- slide.c: getenv("PSELECT_SKIP_WARMUP") → 跳过 warmup prepare
- 测试: scripts/test_mt15_sweep.sh (已改指向 mt16 + SKIP_WARMUP=1)
- 待测: Shizuku 恢复 + am kill-all + 压力后跑

---

## 三十一、mt16 穷尽性 shift 扫描 = 最终定论（2026-08-14 20:1x）

### mt16 结果（8 shift 全扫, boot_id 验证, 跳过 warmup）
- shift 0-7: 触发普遍成功 (calls=1 success=1), **bootid_changed=0 全部**
- 跳过 warmup 成功 (warmup=0), 跑完未崩

### ★ 穷尽性结论
- 16 版本 (mt1-16) + 全部触发 (2线程/deep chain/OFF/selinux-8) + 全部 shift (0-7) + 全部目标 (selinux/boot_id)
- 源码确认: 检查[3][5][6]可过, [7] rb_erase 理论上必执行, 写目标=parent+8=boot_id
- **写入在任何配置下都不落地** → matisse 5.10.209 的 pselect-overlay 写原语 = 死区
- 最可能根因: overlay 无法到达悬垂 waiter 地址 (栈帧几何) 或 [5] wait_lock trylock 卡真实锁
- 该技术 4.x/6.x 可行 (几何不同), 5.10 MTK 特定死区

### 剩余选项 (诚实评估)
1. **换触发路径**: 源码显示 chain walk 还有 FUTEX_LOCK_PI/requeue 路径 (line 1002/1113 调用) — 但 overlay 机制相同, 概率低
2. **接受死区**: 该设备走 GhostLock 技术路线到头
3. **BL 解锁 + KernelSU 内核**: matisse 源码已下载 (sekaiacg, 5.10.81 同源), 可编 KernelSU 内核 — 需要解锁 BL
4. **Firefox 链**: 只解决投递, 不解决内核步
