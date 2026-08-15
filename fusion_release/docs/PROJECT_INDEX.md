# 项目主索引 — CVE-2026-43499 GhostLock matisse

> 最后更新: 2026-07-16
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM / MTK 5.10.209

---

## 当前状态

| 系列 | 版本范围 | 状态 | 瓶颈 |
|------|---------|------|------|
| V 系列 | v1-v30 | **已关闭** | rb_erase csel 永远走错分支,差 8 字节够不到 fops |
| R 系列 | R1-R8 | **进行中** | 每次写操作重新 clone 543 进程 → slab 耗尽 → 重启 |
| 融合方案 | Page Reuse | **已实现** | 一次准备 kernel page,全部写操作复用 (clone 2715→543) |

---

## 目录结构

```
matisse_backup_essentials/
│
├── !!!_AI_READ_THIS_FIRST.md     ← [必读] AI 恢复上下文 — 当前状态/版本速查/编译命令
├── !!!_LESSONS_LEARNED.md        ← [必读] 经验教训 — 死路清单/历史 Bug/环境约束
├── PROJECT_INDEX.md              ← [本文件] 项目主索引
│
├── docs/                         ← 文档与检查点
│   ├── checkpoints/              ← 所有 CHECKPOINT_*.md (V/R 系列分析)
│   ├── archives/                 ← AI_ARCHIVE_*.md (状态快照)
│   └── guides/                   ← 操作指南/恢复指南/NEXT_STEPS
│
├── CyberMeowfia/IonStack/CVE-2026-43499/exploit/
│   ├── src/                      ← exploit 源码
│   │   ├── main.c                ← 主流程: KASLR→page准备→读写序列→root
│   │   ├── pipe.c                ← pselect 写原语: fork→PI chain 竞态
│   │   ├── fops.c                ← pselect 路由: fd_set→rb_erase 触发
│   │   ├── util.c                ← 工具: clone_memfd, prepare_kernel_page
│   │   ├── slide.c               ← KASLR 绕过: slab 喷射+内核基址泄漏
│   │   ├── common.h              ← 公共头文件: 全局变量/宏/结构体
│   │   ├── offset.h              ← 内核偏移量 (per_cpu/task/cred)
│   │   ├── preload.c             ← LD_PRELOAD 入口
│   │   ├── su_daemon.c           ← root daemon (嵌入式)
│   │   ├── targets/              ← 多设备 target.h 配置
│   │   └── kernelsnitch/         ← 内核信息泄漏头文件
│   ├── Makefile                  ← 构建系统 (已适配 Windows)
│   └── build/                    ← 编译产物
│
├── binaries/
│   ├── v_series/ (bin_v_archive/) ← V 系列归档 .so (v1-v30)
│   └── r_series/                  ← R 系列编译产物 .so (R1-R8)
│
├── logs/                         ← 测试日志
│   ├── v*.txt                    ← V 系列测试输出
│   └── R*.txt                    ← R 系列测试输出
│
├── scripts/                      ← 构建与部署脚本
│   ├── deploy.sh                 ← 部署脚本 (哈希验证+cp+sync)
│   ├── analyze_*.py              ← 内核镜像分析脚本
│   ├── extract_*.py              ← 内核提取脚本
│   └── check_*.py                ← 偏移量验证脚本
│
├── ref/                          ← 参考资料
│   ├── kallsyms.txt              ← 内核符号表
│   ├── kernel_with_symbols.elf   ← 带符号内核
│   ├── rb_erase.asm              ← rb_erase 反汇编
│   └── rt_mutex_chain.asm        ← rt_mutex 链反汇编
│
├── images/                       ← 内核/启动镜像
│   ├── kernel.Image              ← 内核镜像
│   ├── boot_final.img            ← boot 镜像
│   └── system.img                ← 系统镜像
│
├── ghostlock-project-overview/   ← 项目全览 HTML 文档
│   └── ghostlock-project-overview.html
│
├── src_patched/                  ← 修改后源码副本 (含 CHANGELOG)
│   ├── CHANGELOG.md              ← 变更记录 (diff 格式)
│   ├── Makefile                  ← 已适配 Windows
│   ├── common.h                  ← +1 行 (page_reuse_active)
│   ├── main.c                    ← +24 行 (fusion 逻辑)
│   ├── pipe.c                    ← +18 行 (reuse 分支)
│   ├── fops.c                    ← +1 条件 (retry 跳过)
│   ├── util.c / slide.c / ...    ← 未修改源码
│   ├── target.h                  ← matisse 设备配置
│   └── kernelsnitch/             ← 内核信息泄漏头文件
│
├── tools/                        ← Windows 构建工具
│   ├── sha256sum.cmd             ← sha256sum 兼容 wrapper
│   └── build_windows.cmd         ← 一键构建脚本
│
├── CVE-2026-43499_ref/           ← 漏洞 PoC 参考
│   ├── trigger.c                 ← 触发器源码
│   └── dmesg_crash.txt           ← 崩溃日志
│
└── IonStack/                     ← IonStack 原始仓库副本
```

---

## 关键文件速查

### AI 必读 (根目录)
| 文件 | 用途 |
|------|------|
| `!!!_AI_READ_THIS_FIRST.md` | 当前状态、版本速查、编译命令、部署流程 |
| `!!!_LESSONS_LEARNED.md` | 死路清单、历史 Bug、环境约束、R 系列教训 |
| `PROJECT_INDEX.md` | 本文件 — 项目主索引 |

### 融合方案相关
| 文件 | 位置 | 说明 |
|------|------|------|
| `CHECKPOINT_FUSION_page_reuse.md` | `docs/checkpoints/` | 融合方案详细文档 |
| `ghostlock-project-overview.html` | `ghostlock-project-overview/` | 项目全览 (含融合方案) |

### 源码 (修改过的文件)
| 文件 | 变更 | 说明 |
|------|------|------|
| `common.h` | +1 行 | `extern int page_reuse_active;` |
| `main.c` | +20 行 | 父进程一次准备 page,所有写复用 |
| `pipe.c` | +15 行 | 子进程 reuse 模式跳过 543-clone |
| `fops.c` | +1 条件 | retry 跳过重新 prepare |
| `Makefile` | +8 行 | Windows prebuilt 自动检测 + sha256sum 变量化 |

### R 系列二进制
| 文件 | 位置 | SHA256 (前8位) |
|------|------|---------------|
| `preload_mtk_R8.so` | `binaries/r_series/` | ce945969 (最新, 部署被破坏) |
| `preload_mtk_R7.so` | `binaries/r_series/` | ce945969 (=R8) |
| `preload_mtk_R6.so` | `binaries/r_series/` | e2289c64 |
| `preload_mtk_R5.so` | `binaries/r_series/` | cdac2d0d |
| `preload_mtk_R4.so` | `binaries/r_series/` | 40adc21d |
| `preload_mtk_R1-R3.so` | `binaries/r_series/` | 017fb8a6 (相同) |

### 关键日志
| 文件 | 位置 | 说明 |
|------|------|------|
| `R8_test4.txt` | `logs/` | ★ R 系列首次成功触发写原语 |
| `R7_test1.txt` | `logs/` | R7 输出异常分析 |
| `v23_11.txt` | `logs/` | V 系列最强触发 (ret=161) |

---

## 编译命令

### Termux (推荐 — 直接在设备上编译)

```bash
cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
rm -rf build/
make PROJECT=blazer-CP2A.260605.012 API=34 CC=clang

# 验证融合代码已编入
sha256sum build/blazer-CP2A.260605.012/bin/preload.so
strings build/blazer-CP2A.260605.012/bin/preload.so | grep "direct-fusion"

# 复制到项目根目录
cp build/blazer-CP2A.260605.012/bin/preload.so \
   /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so
```

详细步骤见 `docs/guides/TERMUX_BUILD_AND_TEST.md`

### Windows (NDK r29, 需 D 盘 ~3GB 空间)

```bat
tools\build_windows.cmd
```

## 部署与运行

```bash
# 进入 rish (Shizuku, uid=2000)
rish

# 部署 (强制哈希验证)
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh \
  /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so

# 运行 (rish 内)
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 30 2>&1 | \
  tee /sdcard/Documents/matisse_backup_essentials/logs/R9_test1.txt
```

---

## 关键地址 (不变)

```
KIMAGE_TEXT_BASE:    0xffffffc008000000
ASHMEM_MISC_OFF:     0xffffff80028e76d8
ASHMEM_MISC_FOPS:    0xffffff80028e76e8
ashmem_fops:         0xffffffc00a2acf58
init_task:           0xffffff800279bec0
```

## 环境约束

1. 每次重启后最多跑 2 次测试 (MTK slab 限制)
2. 必须通过 rish (uid=2000) 运行,Termux 直跑 SELinux 封锁
3. 编译后必须验证 SHA256 不同 (build 目录缓存陷阱)
4. 部署后必须验证哈希 (Shizuku cp 可能写入全零文件)
5. `make clean` 不可靠,用 `rm -rf build/`
