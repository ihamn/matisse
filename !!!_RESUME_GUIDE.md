# 恢复指南 — 重启后如何继续

---

## ⚠️ 0. 先留档！(Termux 弹退保护)

**任何操作前，先确保状态文档已更新：**
- 更新 `!!!_AI_READ_THIS_FIRST.md` 中的「上次运行」状态
- 如果有新的测试输出，先保存到 `logs/RXX_testN.txt`
- 编译新 .so 后，先 `cp` 到 matisse_backup_essentials 目录再部署

**铁律: 运行 .so 前后必须留档，Termux 弹退时不能丢失进度！**

---

## 1. 开启 Shizuku
  - 打开 Shizuku app → "启动" (无线调试方式, 需要配对)
  - 或者: 通知栏 → Shizuku → 启动

## 2. 恢复 Termux
  - 打开 Termux
  - Shizuku 的 rish 之前修好了 (dex 在 /data/local/tmp/rish_shizuku.dex)
  - 验证: 在 Termux 里跑:
    /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
    # 输入 id 回车, 应该看到 uid=2000(shell)

## 3. 编译和部署
  cd /sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
  make clean && make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
  cp build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_RXX.so

  # 通过 Shizuku 部署:
  RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
  # 然后输入:
  cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_R4.so /data/local/tmp/preload.so

## 4. 运行测试
  # ⚠️ 运行前: 确保不自动息屏! 确保文档已更新!
  RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
  # 然后输入:
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/RXX_testN.txt
  # ⚠️ 运行后: 立即更新 CHECKPOINT 和 AI_READ_THIS_FIRST.md!

## 5. WiFi adb 备选方案:
  手机 Termux:
    su -c "setprop service.adb.tcp.port 5555 && stop adbd && start adbd"
  电脑:
    adb connect 192.168.3.33:5555
    adb shell "LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1

## 关键文件位置
  /sdcard/Documents/matisse_backup_essentials/
  ├── preload_mtk_RXX.so          ← R 系列最新二进制
  ├── bin_v_archive/              ← v 系列全部旧 .so
  ├── logs/                       ← 全部测试输出
  ├── ref/                        ← 反汇编/符号表/trigger
  ├── images/                     ← boot/kernel 镜像
  ├── scripts/                    ← Python 分析脚本
  ├── !!!_AI_READ_THIS_FIRST.md   ← 项目上下文 + TERMUX警告
  ├── !!!_LESSONS_LEARNED.md      ← 经验教训 + 死路清单
  ├── !!!_RESUME_GUIDE.md         ← 本文件
  ├── CHECKPOINT_*.md             ← 各版本断点详情
  └── CyberMeowfia/IonStack/CVE-2026-43499/exploit/  ← 源码

## 当前状态 (2026-07-16 — R11 已部署 + v系列重新评估)

  v 系列 (v1-v30): rb_erase → fops 覆写 **不一定死路！**
    → v30 结论只覆盖 rb_erase 路径，遗漏了 R 系列 GhostLock 直接写 FOPS 的可能
    → 新发现: v 系列崩是因为 fake_task，slide 不崩是因为 init_task

  R 系列:
    R1-R7: MM_STRUCT_SZ/部署/slab 问题 → bruteforce 失败
    R8: ★ test4 首次 bruteforce 成功 + GhostLock 触发！但 pselect 期间 kernel panic
      → 根因定位: fake_task 无效 → 内核访问 panic
    R9: 父进程 prepare → 崩 (已废弃)
    R10: page holder — 从未部署 (仍是 R8 在 /data/local/tmp)
    ★ R11: page holder + fflush + pipe timeout + DIRECT_PCPU_DELTA 逃生舱
      → 已编译已部署, 待测试
    ★ R12 计划 (未编译):
      路线 A: fops.c 1行改动 fake_task→init_task, 修复 GhostLock crash
      路线 B: v+R 混合 — GhostLock 直接写 FOPS, 不需要 per-CPU delta

  ⚠️ 编译后必须验证运行输出中 prepare=272（不是200）！
  ⚠️ 每次重启后最多跑 2 次测试！MTK slab 扛不住！
  ⚠️ 从 rish 运行！Termux 直跑 = untrusted_app_27 → Permission denied
