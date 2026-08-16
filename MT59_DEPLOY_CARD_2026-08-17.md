# mt59 开工卡（明早唯一要看的一张纸）

> ⚠️ 状态变更 2026-08-16：对端已切换为无推理模式。执行以
> `MT59_GRUNT_CARD_1_2026-08-16.md` 为准（机器自判、零判断设计）。
> 本卡留档备查，判读表仅评审侧使用。

## 部署（2 分钟）
```
cp bin/mt59/preload.so /data/local/tmp/preload.so
sha256sum /data/local/tmp/preload.so
# 必须等于: 1064e413aa9eb5113ccb50ac9e160aeae9c160cbe9f145f90ca0f0b5ae2bd45f
```
su_daemon 不动。其余文件全部照旧。

## 执行
R 直打序列 = 总册 §二 原样（Enforcing、胜局配方、纪律不变）。
预算已重置：dirty 0/2，freeze 0/2。

## 新判读（只加三条，其余照总册表）
| 看到什么 | 意思 | 动作 |
|---|---|---|
| `mt59: owner armed` → `requeue fired ret=0` | 竞态已锁进 R1 形态 | 走原表 |
| 进程 12 秒退出，rc=3，尾行 `mt59: STALL` | 残余哑轮自弃（安全） | 立即重跑，不耗预算 |
| rc=124 且无 STALL 行 | 真挂死 | 停，推 .out |

## 预期
哑轮应近零。每轮都是 R1 形态，剩两件老事：
打歪（dirty→停5分钟查系统）和 落地（CapEff 满→收割流程，总册 §三）。

## 硬规则（不变）
T+75 硬停；freeze 1 次即收工；3 轮干净 miss 停；
结果推仓库即可，无需对话——判读表已覆盖全部走向。
