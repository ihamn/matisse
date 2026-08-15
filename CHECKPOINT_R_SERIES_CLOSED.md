# 🏁 R 系列关闭 — 经验提取

> 日期: 2026-07-16
> 范围: R1 — R11
> 决策: 封存 R 系列，转入 v31

---

## R 系列做了什么

R 系列的目标是 **Direct Root**: 直接用 GhostLock 写原语覆写当前进程的 cred 指针为 init_cred，
跳过 FOPS 覆写/configfs 阶段，一步到位提权。

### 架构演进

| 版本 | 改动 | 结果 |
|------|------|------|
| R1-R7 | MM_STRUCT_SZ 错误 (0x500→0x3C0) / 部署问题 / slab 耗尽 | bruteforce 全部失败 |
| R8 | MM_STRUCT_SZ=0x3C0, KASLR=0, cooldown 5s | ★ test4: bruteforce 首次成功, GhostLock 触发, kernel panic |
| R9 | 父进程直接 prepare (融合同进程) | kernel panic 更快 |
| R10 | Page Holder 分离 (fork 子进程 prepare) | 未部署 |
| R11 | fflush/超时/DIRECT_PCPU_DELTA/FOPS reprepare | 已部署, 待测试 |

### 累积测试: 54+ 次

---

## ★ 从 R 系列提取的宝贵经验

### 1. GhostLock 写原语确实能触发 ✅

R8_test4 铁证:
```
direct-w64[0] target=ffffff80028a77d0 value=ffffffc00a78a590 shape=0 workspace=ffffff80734b8000
```
- rb_erase 确实被执行了 (没有 retry/fatal 消息)
- 写操作确实发生了 (日志在 pselect 前打印, pselect 后无返回)

### 2. shape=0 vs shape=1 的区别

| shape | parent 来源 | rb_erase 写什么 | 用途 |
|-------|------------|----------------|------|
| 0 | value (源地址) | child=0 → 破坏源 | 读原语 (通过 boot_id 侧信道泄漏) |
| 1 | target-8 | child=value → 覆写目标 | 写原语 (直接覆写) |

shape=0 是 "读" 原语但本质上是破坏性写入 — 写 0 到源地址附近。用在 per-CPU offset 表上立刻崩。

shape=1 是真正的 "写" 原语 — 写 value 到 target 附近。

### 3. 为什么 R 系列一直崩

**根因**: shape=0 读 per-CPU offset 时，写入目标是 percpu_slot 区域 → 破坏 per-CPU 变量寻址 → 立即 kernel panic。

v 系列 shape=0 从不崩的原因: 写入目标是 miscdevice 的 name_ptr → 只影响设备名显示 → 无害。

**教训: 永远不要用 GhostLock 写 per-CPU offset 表或任何关键内核数据结构。**

### 4. Page Holder 分离方案 (R10/R11)

虽然 R10 从未测试, 但这个架构设计是对的:
- Fork 子进程做 543-clone prepare
- Pipe 传回 page_base/fake_lock/fake_w0/fake_task
- 子进程 pause() 保持 memfd 打开 (钉住 slab page)
- 父进程 + write 子进程复用 (0 clone)

**这个方案应该保留到 v31。**

### 5. DIRECT_PCPU_DELTA 逃生舱 (R11)

环境变量跳过危险读原语的设计思想是对的。v31 不需要, 因为不碰 per-CPU offset。

### 6. fflush 纪律 (R11)

page holder fork 前后、每次关键路径之前强制 fflush(stdout)。管道缓冲在 kernel panic 时全部丢失。
**必须保留到 v31。**

### 7. 部署验证铁律

- R8: Shizuku cp 写全零文件 → 实际跑的是旧 v 系列 .so
- R10: 从未部署 → 实际跑的是 R8
- R11: 正确部署 (哈希验证)

**每次部署必须 sha256sum 对比。**

### 8. MTK slab 脆弱性

- 每次重启后最多 2 次测试
- prepare 543 clone + bruteforce 8CPU 严重消耗 slab
- 第三次必 kernel panic

### 9. bruteforce 成功条件

- MM_STRUCT_SZ = 0x3C0 (不是 0x500)
- prepare = 272 (mm_objs_per_slab = ORDER3_SIZE/0x3C0)
- SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS = 1 (不需要多次重试)
- retry 之间 usleep(500000)
- 5s cooldown 在 main stage 前

---

## v31 继承清单

从 R 系列搬到 v31 的:

| 项目 | 说明 |
|------|------|
| Page Holder | fork 子进程 prepare, pipe 传回地址 |
| fflush 纪律 | 所有关键路径前 fflush(stdout) |
| Pipe 超时 | read() 120s 超时保护 |
| 哈希部署 | deploy.sh + sha256sum 验证 |
| Shape 1 写原语 | 覆写 FOPS, target=ASHMEM_MISC_FOPS |
| INIT_TASK 安全 | waiter->task 用 init_task (不是 fake_task) |
| KASLR=0 | 硬编码, 跳过 slide |
| MM_STRUCT_SZ=0x3C0 | 已验证 |
| FOPS reprepare | 写 child 中调用 prepare_skb_payload(FOPS) |

从 R 系列丢弃的:

| 项目 | 原因 |
|------|------|
| shape=0 读原语 | 破坏性太强, 崩 |
| DIRECT_PCPU_DELTA | v31 不需要 per-CPU |
| Direct cred overwrite | 改为 FOPS 覆写 → configfs |
| fake_task | 改为 init_task (安全) |

---

## v31 设计概要

```
Phase 1: Page Holder prepare (同 R11)
  → fork 子进程 → prepare_good_kernel_page(SLIDE)
  → pipe 传回 page_base, fake_lock, fake_w0, fake_task

Phase 2: GhostLock write (shape=1, init_task)
  → target = ASHMEM_MISC_FOPS
  → value = page_base + fake_fops_offset
  → 覆写 ashmem miscdevice 的 fops 指针

Phase 3: Configfs 后利用
  → open/read/write configfs → 假 fops 回调
  → 任意内核 R/W → 修改 cred
```
