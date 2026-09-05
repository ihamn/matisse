# pstore 取证 — E5v2 重启根因 H-B 实锤 (2026-09-06 00:20, 取自 mt77 E5v2 重启后的当前 boot)

## 采集
- /sys/fs/pstore/console-ramoops-0 (ls 被拒但直读成功; dmesg/klogctl 对 shell 关闭)
- SHA256: 732940d6571411d916287ac190c2557a8e16125f2eb713c51076211c7f034086 (262132 bytes)
- getprop ro.boot.bootreason = **kernel_panic** ← 上一 boot 以内核 panic 告终
- console-ramoops 内容 = 上一 boot 尾段 (uptime 10584s+), 本 boot uptime 4386s

## panic 块 (L2443 起, 完整调用栈见文件)
```
[10598.262674] Unable to handle kernel paging request at virtual address 0000000000002710
  ESR=0x96000045, WnR=1 (写), pgd=0 (未映射)
  pc : rb_erase+0x7c/0x354   = 0x...712a4 = `str x9,[x8]` = STORE(b) 本尊
  lr : rt_mutex_adjust_prio_chain+0x4f4/0x1948
  x8  = 0x0000000000002710   ← child = TREE_RIGHT 写值 (非法小常数)
  x9  = 0xffffff8002a41b90   ← pc(word0) = E5 几何 selinux_alias-8
  x11/x13 = 0xffffff8002a41b98 = enforcing 槽 (STORE(a) 已执行, 写入 0x2710)
  x12 = *(selinux_state+8) = 0x0000000101000001 ≠ node → 判别字 ne → csel 选 parent+8 ✓
```

## 结论
1. **H-B 实锤**: E5v2 死因 = STORE(b) `*(child)=pc` 对非法 child(0x2710) 解引用 →
   同步异常 → panic → 整机重启。framework 反制 (H-A) 与 E5v2 无关。
2. **额外发现**: 0x2710 = 十进制 10000 ≠ 0x10000。现场传 VALUE=10000 (无 0x 前缀),
   被 strtoull(...,0) 按十进制解析。README 记录的 "value=0x10000" 与实际执行值不符。
   无论 0x2710 还是 0x10000, 机制相同 — mt78 语义重定义 (仅 0/SPRAY/SPRAY1, 其余
   ABORT) 把这类脚枪整个消灭。
3. **E5v2 的 STORE(a) 确实执行了**: enforcing 被写成 0x2710 (byte0=0x10, bit0=0 →
   tbz 视角短暂 permissive 化), 0.1s 后 STORE(b) panic。
4. **KASLR 新事实**: Kernel Offset: 0x27bc400000 ≠ 0 — 该 boot 内核 VA 有滑动!
   "KASLR slide=0 恒等" 仅对 VA 侧, 且并非每 boot 恒 0。但 dmap 线性映射别名
   (0xffffff8002a41b98 等) 在该 boot 依然有效命中 (R 落地同 boot + E5 寄存器全中)
   → 线性映射与 VA 滑动无关 (phys load 固定)。**dmap 别名写法安全; 任何
   KIMAGE_TEXT_BASE 相对 VA 常量 (per_cpu/entry_task 读取类) 需按 boot 重验。**

## 对 E5v3 的意义
- mt78 (E5v3, SPRAY=牺牲指针形态) 与 R 几何 (7/7 无事故) 结构同构, panic 类已根除。
- pstore 已收到 + mt78 已构建 → HANDOFF §5.3/§6.2 的 E5 停跑条件解除, E5v3 可上场。
- v1 黑屏根因 (H-A vs initialized=0) 仍是开放问题, E5v3 轮即判定实验。
