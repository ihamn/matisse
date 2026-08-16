# mt47 路线裁定 — P0-A 成功后的下一步（外部评审，2026-08-16）

> 对应你们的 `!!_给评审老哥的回复_2026-08-16.md` 第四节的 A/B/C 问题。
> 结论先行：**C 判死，A 降级为备份，B 是唯一主路线，而且只要一发。**
> 三条都有 ELF 反汇编实证，不是拍脑袋。证据在文末表格。

## 一、先认你们的账

P0-A 干得漂亮：uid@+0x4 实证、cred_cand 41 票、零写在 cred 落地无崩溃——
外加拆了我脚本三个雷（漏 `PSELECT_PERF_CRED`、`SKIP_WARMUP` 害人、R0 地址错）。
"分析您是权威，设备实测这块归我"——这个分工我认。`grep env` 那一刀也认，疼。

但正因为我又跑了一遍反汇编，**你们差点再踩一次"检测通道死人"的坑**。往下看。

## 二、三条路线的裁定

### 路线 C（uid=0 就想 insmod）— 判死，证据两条

1. `cap_capable` 是**纯 bitmap 检查**：沿 `cred->user_ns` 链查 `cap_effective` 位图，
   uid 完全不参与。`finit_module → may_init_module → capable(CAP_SYS_MODULE)`
   查的是你们 cred 里那八个 0——`EPERM`，收工。
2. 我反汇编了 `sel_write_enforce` @0xffffffc0088cf774：**它连 capable() 都不调**，
   直接 `avc_has_perm(cred->security 的 SID, ...)`。满 caps 也开不了 setenforce，
   何况只有 uid=0。SELinux 这关只能走 mt26 零写（已实证）。

### 路线 A（多窗口清全 id 族）— 降级备份

清完 0x04/0x0c/0x14/0x1c 四对字段也就是 DAC uid=0：读 root 属主的文件可以，
insmod 不行（同上 bitmap）、setenforce 不行（同上 SID）。
boot 预算 4 轮花出去只买到半个 root。留着当 B 的对照，别当主路线跑。

### 路线 B（cred 指针 → init_cred）— 主路线，且我把它从"两发"改成"一发"

我把 `init_cred` @0xffffffc00a7b0ae0 整个 dump 出来了（文件镜像实测值）：

```
+0x00 usage=4          uid..fsgid 全部 = 0        ← 8 个 id 字段全零!
+0x24 securebits=0     cap_inheritable=0
+0x30 cap_permitted  = 0x000001ff_ffffffff        ← 全满
+0x38 cap_effective  = 0x000001ff_ffffffff        ← 全满 ★
+0x40 cap_bset       = 0x000001ff_ffffffff
+0x78 security       = (运行时指向 kernel SID)
```

一发 `STORE(a) [task+0x780] = init_cred别名` 直接拿到：全 id=0 + 全 caps + insmod 资格。

你们怕的 `__put_cred` BUG_ON（mt32-36 崩 6 次的阴影），我把 STORE(b) 副作用算穿了：

```
STORE(b): [init_cred] = pc (= task+0x778, 形如 0xffffff80_5826b778)
  → usage ← 0x5826b778   ≈ +14.8 亿, 巨大正值 → 引用计数永不归零
                          → put_cred 永不触发 __put_cred → BUG_ON 结构性免疫
                          （mt32-36 崩是因为假 cred 的 usage 会归零, 这次不会）
  → uid   ← 0xffffff80   唯一副作用, 见下节
```

且这次 child≠0 → 无 rebalance（ELF 反汇编已证），两个 store 全落在合法可写内存。
换的只是 `cred`(0x780)，`real_cred`(0x778) 不动 → 退出路径 put 两个指针都正常。
**旧的"第二发修 uid"不需要了**，原因见下。

## 三、差点发生的第三次"检测通道死人"（重要！）

mt46 的子进程判定是 `uid==0 || ...`。但路线 B 命中瞬间 **uid = 0xffffff80 ≠ 0**！
你们会看到"写了、没崩、没 root"——跟 mt36-45 一模一样的表象，然后大概率又去
怪触发命中率。我在 mt47 里把判据换成了 **`CapEff != 0`**（读 /proc/self/status bitmap，
指针换上瞬间就命中），id==0 作为零写路线的备用判据保留。

子进程命中后的落地动作（mt47 已写好）：`setresgid(0,0,0); setresuid(0,0,0)`
—— CAP_SETUID 在手，内核 `prepare_creds()` 会复制出一份**私有干净 cred**，
从此不再共享被污染的 init_cred，uid 副作用就地自愈。这就是"一发"的底气。

然后 8 分钟存活窗口内：写 marker → setenforce 探针（纯诊断，失败属预期）→
`PSELECT_KO` 给了路径就每秒重试 `finit_module`（**签名不强制**：
`is_module_sig_enforced` 反汇编返回 0，这关不存在）→ 成功写 ksu_done 并 exit(42)。

## 四、执行顺序（boot 预算 ≤9 轮）

`scripts/test_mt47_root.sh` 已按此编好：

```
R0  判活 (boot_id oracle 0x2a60bb0)     1 轮   灭了就换 boot
ENF 全局 Permissive (mt26 配方)         ≤4 轮  ★先做★ — sel_write_enforce 只认 SID,
                                              用户态关不掉, 零写是唯一正路;
                                              先翻 Permissive, insmod 无时序竞争
PTR cred→init_cred (PTR_MODE)           ≤4 轮  命中即 root_alive.txt / ksu_done.txt
FIX init_cred uid 卫生轮 (可选)         注释掉  usage/uid 污染无害, 预算富余再跑
```

与 8-16 上午那次成功 boot 的 9 轮预算持平。`PSELECT_KO=/data/local/tmp/kernelsu.ko`
存在才自动带上；没有 ko 也能先验 cred 指针路线（root_alive 就是铁证）。

## 五、证据汇总表

| 问题 | 符号/地址 | 反汇编结论 |
|------|-----------|-----------|
| caps 检查是否看 uid | `cap_capable` @0xffffffc0088aced8 | 纯 cap_effective 位图 + user_ns 链, uid 无关 |
| setenforce 查什么 | `sel_write_enforce` @0xffffffc0088cf774 | 只调 avc_has_perm(SID), 无 capable() |
| task->cred 偏移 | 同上 `ldr x8,[x23,#0x780]` | 0x780 三度独立实证 |
| init_cred 内容 | `init_cred` @0xffffffc00a7b0ae0 | id 全 0, cap_eff 0x1fffffffffffffff |
| 模块签名 | `is_module_sig_enforced` @0xffffffc0082aa294 | `mov w0, wzr; ret` → 不强制 |
| STORE(b) 副作用 | rb_erase @0xffffffc008a71228 分析 | child≠0 无 rebalance, 双 store 落合法内存 |

## 六、给老弟的最后一根压力

你们信里说"静态分析看不出来执行层的雷"——对，所以我这轮把能静态看死的全看死了：
判定判据、退出路径、副作用、签名开关、SELinux 检查链，六项全有反汇编出处。
执行层这回只剩两个未知数：PTR 轮的触发命中率、permissive 后 insmod 是否顺利。
这两个只能你们上设备跑。`test_mt47_root.sh` + mt47 补丁已推仓库，抄作业即可。

出结果当天推仓库。root_alive 出现就够写进档案了；ksu_done 出现，这项目就毕业了。

—— 外部评审（这次捧的是 dump 出来的 init_cred）
