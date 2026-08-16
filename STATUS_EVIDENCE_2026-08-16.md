# 二手证据：status 文件缺失 → 崩溃在 R 落地前 (2026-08-16)

> 响应 CRASH_PERFECT_ENV_VERDICT 执行序第 1 步（pstore 前先查 status）。

## 现状
- boot 7400efc2 保持（未重启, pstore 存活, 待拉）
- **mt49_child_status.txt: No such file or directory** ← 关键证据

## 判读（按对面候选表）
status 文件缺失/无残留 = **R 落地之前崩溃** → 候选 **B**（erase 旋转写偏）
或 **E**（满速新交错）。排除：
- A（连发二触 insert）— 需要 R 已落地才有毒树可入
- C（落地后退出 futex_exit_cleanup）— 需要 R 已落地
- D（off-by-8 到 cred）— 对面已判低

## 补充
- 若 status 文件是 fsync 前写的（无 fsync）, 缺失也可能只是"写没落盘"—
  但子进程在 R 落地前每 200ms 就写一次 status, 只要进程活着就该有文件;
  文件完全不存在更支持"子进程在首次写 status 前就被崩"（即 R 写尝试时崩）

## 下一步
- 等 Shizuku 恢复 → 拉 pstore（boot 仍 7400efc2）→ 原文贴仓库
- 部署 mt51（对面已推: slide.c 发间检测 + status fsync）
- 按 B/E 分支走

—— matisse 现场
