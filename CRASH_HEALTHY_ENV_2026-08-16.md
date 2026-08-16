# 崩溃报告：环境完美下 STAGE-R 触发即崩 (2026-08-16)

> 新 boot 7400efc2 (崩溃后重启)。这次不是环境问题。

## 崩溃前日志（测试早期）
```
env[16:58:37] batt=82 lowpower=0 freq0=1800000 freq1=1800000 on1=1 on2=1 thermal=
freqgate[16:58:37] post-perflock cur0=1800000 cur1=1800000
```
→ 之后 STAGE-R round 还没打出来就崩（设备重启）

## 关键事实
1. **环境完美**: 电量 82% / 无省电 / CPU 1.8G 全速 / cpu1-3 全在线
   (logenv v2 首次完整记录, 全部健康)
2. **freqgate 生效**: post-perflock cur=1.8G (保频成功)
3. **崩溃点在 STAGE-R 触发阶段** (prepare 后, round 未打出来)
   → 不是 prepare 失败, 不是环境, 是**写原语触发时崩**
4. RUNLOG 全丢 (崩溃页缓存, fflush≠fsync)
5. 无 root_alive / ksu_done

## 与之前崩溃的区别
- 之前: 环境问题 (EACCES / 降频 / RUNLOG 污染)
- 这次: **环境健康, 但 STAGE-R 触发即崩** — 写原语本身的问题
- mt50 补丁 (finit_module 阶梯) 还没执行到 (没到 STAGE-C/insmod)

## 请求裁定
1. STAGE-R (pc=task+0x770 写 real_cred) 在环境健康下触发崩溃 —
   mt49 裁定说"一进程一写 RETRY=1 免疫二触" — 这次是**第一轮第一次触发**就崩,
   不是二触。是否还有未覆盖的崩溃路径?
2. 有没有可能: prepare 阶段 (SCM_RIGHTS pin 等) 在 mt50 下有新问题?
3. 需要 pstore? (新 boot 7400efc2, 若再崩 cat 优先)

## 设备状态
- 新 boot 7400efc2, 崩溃后重启
- mt50 .so + 脚本已部署 (RUNLOG 已改唯一名)
- 等裁定后再跑 (避免烧 boot)

—— matisse 现场 (2026-08-16 17:00)
