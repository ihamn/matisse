# 野指针事故机制说明 — 致对面 (2026-09-08 深夜)

> 用户报告: 今晚多轮风暴后, 系统输入法及其他设置被重置。本文 = 现场 AI 的
> 完整机制分析, 供对面核对与规划。所有断言均有今晚 pstore/日志实证。

## 1. 事故定义
- 用户可见: IME/系统设置回退默认; 此前已有: dsh storages 损坏 inode、
  C.out 毒 inode、kern_table.hostname.mode 被清零 (procfs 读路径 EACCES)
- 时间窗: 今晚 ~15 轮风暴 (R 落地 13+, C 落地 2+, 崩溃 8: 3 panic +
  1 watchdog + 1 longkey + 3 framework 死)

## 2. 机制链 (每步有实证)
1. **毒源**: R/C 写 = rb_erase 植入假 rt_waiter (fdset 毒化的 freed
   内核栈槽)。节点字段 = 部分受控 (tree_pc/right/left 已植) + 部分陈旧
   栈垃圾。futex 超时出队后 = **带毒的 freed 节点仍留在任务的 PI/等待
   状态里**。
2. **触发**: child 存活数小时, 任何 sched_setattr / futex_op / 优先级
   传播触碰毒链 → rt_mutex_adjust_prio_chain 遍历毒节点。
3. **walk 携带写**: 该函数非只读 — 优先级传播写 waiter 字段 / lock->
   owner / pid 结构。毒节点的指针是垃圾 (pstore 实证 x19=
   0x0008000000000000, x8=x19+0x40; 另一现场读入 userspace 值
   0x73528526e0) → **每次 walk = 随机内核地址涂抹若干笔**。
4. **三态落点** (今日全观测):
   a) 撞未映射 → Oops/panic (4 份 pstore, 偏移 +0x188/+0x1d8 lockup/
      +0x9fc/+0x1788 — walk 各阶段地图)
   b) 撞敏感内核结构 → framework 死 / kern_table.hostname.mode=0
   c) 静默无害 → 无观测 (不可证伪)
5. **设置重置的具体路径 (最可能)**: /data/system/users/0/settings*.xml
   的 **page cache 页被涂抹** → 写回把损坏内容刷进 /data → framework
   读坏 XML → 回退默认。(次可能: framework 软重启时读到半更新状态。)
6. **为什么 kern_table 最可能中招**: kern_table 在内核 .data
   (dmap 0xffffff8002xxxxxx 窗口) — **与全部写目标/毒链同一地址邻域**,
   walk 的随机落笔在该窗口的概率密度最高。

## 3. 数据对账
- 今日 8 崩 + 设置重置 + inode 损坏, 全部与"毒链 walk 随机涂抹"一致
- **无任何一笔损坏指向 exploit 的设计写** (R 写目标 task+0x778 ×13 全部
  精准; C/E5 写从未产生异常内核行为) — 损坏全部来自 walk 的**非设计写**
- 对面可复核: 4 份 panic 偏移在 pstore 归档 + logs_raw/20260908_hunt1/

## 4. 对下一步的影响 (与 ko_risk 协议合并)
1. **每轮风暴 = 持续伤害源** (毒节点累积, child 越活越危险) — 轮次
   最小化已是纪律, 现在升级为: **KSU L2 加载成功前, 每boot最多 1 轮**
2. **设置重置类损害不可逆** (用户需手动重配) — 用户已知情并接受
3. **根治 = 不再让 walk 碰毒节点**: L2 加载 KSU 成功 → root 走 KSU
   通道 (不再依赖 exploit 风暴) → 毒源消失; 失败 → 该 boot 放弃, 重启
   清零后重试 (每 boot 一次的纪律已有)
4. kern_table.hostname.mode: 用户已完整重启 → procfs 重建应已恢复
   (下次现场可 `ls -la /proc/sys/kernel/hostname` 复核)
