# CHECKPOINT v31 — [已归档] 新路线设计参考

> 时间: 2026-07-15 14:30 (现已归档)
> 上一条: CHECKPOINT_FINAL_v30_CLOSED.md (rb_erase 死路关闭)
> **⚠️ v31 为废稿，已删除废弃。v 系列终结于 v30。本文档仅保留设计思路供 R 系列参考。**

## 背景

v1-v30: GhostLock rb_erase → fops 覆写，MTK 5.10 只有 2 次 rb_erase 都写 name_ptr，死路。

新路线: CVE-2026-43499 trigger.c UAF → pselect 栈喷 → 直接内核读写 → cred 覆写。
不依赖 rb_erase/FOPS。

## 已有资产

### trigger.c 验证 (trigger_test1.txt)
- EDEADLK ✅
- UAF clean (没崩, 栈页可访问) ✅
- 结论: 可以用 heap spray 占领释放的栈页

### 新 exploit 源码
来源: /tmp/CVE-2026-43499-popsicle/ (为 popsicle/Xiaomi 17 Pro Max 适配)
已生成 matisse target.h: /tmp/CVE-2026-43499-popsicle/source/src/target.h
已编译: build/bin/preload.so → preload_mtk_v31_new.so (85352 bytes, SHA256: 08221290ef7b...)

### 编译成功 (Termux clang)
```
CC=clang API=34 make -C source preload
```
无错误无警告。

## 两棵树对比

### 旧树 (CyberMeowfia/IonStack)
- 目录: CyberMeowfia/IonStack/CVE-2026-43499/exploit/
- 结构: src/{main.c,preload.c,slide.c,fops.c,pipe.c,root.c,util.c} + targets/matisse-*/target.h
- 构建: Makefile 支持 PROJECT=matisse-OS2.0.6.0.ULKCNXM
- 版本: v1-v30 (30 个 binary)
- 攻击链: pselect ghostlock race → rb_erase type confusion → fops 覆写 → configfs pipe → root

### 新树 (popsicle fork)
- 目录: /tmp/CVE-2026-43499-popsicle/source/
- 结构: src/{main.c,preload.c,slide.c,fops.c,pipe.c,util.c,su_daemon.c,su_blob.S}
- 无 root.c (逻辑在 main.c::run_direct_root_stage)
- 构建: 简单 Makefile (无 PROJECT 参数, CC 直接指定)
- 攻击链: trigger UAF → pselect 栈喷 → boot_id oracle KASLR leak → direct task_struct cred write → root

### 关键差异
1. 新树无 GhostLock race 代码 (slide.c 更简洁，去掉了 rb_erase 相关逻辑)
2. 新树 main.c 包含完整的 direct root stage (旧树的 root.c 依赖 fops 覆写)
3. 新树 util.c 的 payload 构建逻辑不同
4. 新树 su_daemon.c 是独立的嵌入 su (旧树也有但实现不同)
5. 新树无 multi-target PROJECT 支持

## 状态: 已归档 → R 系列接力

v31 为废稿 (源码丢失于 /tmp)，v 系列正式终结于 v30。
本文档的设计思路（两棵树对比、攻击链差异）可供 R 系列参考，但不再作为执行文件。

**R 系列切入点**:
- 参考新树的 direct write 逻辑 → 移植到旧树 (CyberMeowfia) build 系统
- 旧树目录: `CyberMeowfia/IonStack/CVE-2026-43499/exploit/`
- 新二进制命名: `preload_mtk_R1.so`, `preload_mtk_R2.so` …
- ⚠️ 所有源码放项目目录 (`matisse_backup_essentials/`)，禁止放 `/tmp/`！

## ⚠️ Termux 教训 (2026-07-15)
v31 源码树放在 `/tmp/CVE-2026-43499-popsicle/`，Termux 弹退后 `/tmp/` 被清空，源码全部丢失。
**将来所有工作目录必须放在项目目录 (matisse_backup_essentials/) 下！**
