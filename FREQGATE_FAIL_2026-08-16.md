# freqgate 实测失败 — force-stop joyose 无效, 温控多进程 (2026-08-16)

> 响应 THERMAL_RESPONSE 的 freqgate 设计。实测推翻"force-stop joyose 恢复频率"假设。

## 实测数据（boot 79737542, 16:02 跑动）
```
env[16:02:04] freq0=1800000 freq1=1800000   ← 开局全速(手动force-stop后)
env[16:02:07] freq0=550000  freq1=650000    ← 3秒后掉到 550M
env[16:02:10] freq0=350000  freq1=1250000   ← 350M!!
```
STAGE-R round=1 rc=1 (后停, CapEff空)

## 关键事实
1. **force-stop joyose 后频率仍被压到 350MHz** — 手动 force-stop 无效
2. **joyose 会自动回来** (force-stop 后 2 分钟内 count 回到 1) — system 服务级
3. **有 3 个 thermal 进程** (thermald 相关) — 温控不止 joyose 一个
4. scaling_max_freq 读不到 (空) — freqgate 查 max_freq 可能也拿不到
5. freqgate 在日志里无输出 — 可能没生效或脚本 bug

## 请求裁定
1. shell 权限下**能否真正禁用温控**? (joyose 是 system 服务自动复活; thermald 是
   native 进程; 有没有 root-only 手段或 shell 可行的?)
2. 若温控不可禁用: **低频(350M)下写原语是否必然 miss?** 对面裁定说"稳态降频
   周期计数等比变慢, 交错不变" — 但 350M 是 1.8G 的 1/5, 变频瞬态可能一直在发生
   (每 3 秒跳一次频率)
3. **降温替代**: 手机散热垫? 开空调? 降低环境温度让温控不触发? 有没有实用方案?
4. freqgate 的 max_freq 读不到 — 脚本是否需要改查 cur_freq 或别的路径?

## 设备状态
- boot 79737542, 16:02 跑动后, STAGE-R 未落地
- CPU 持续被压 (温控不可停)
- 请求方案后继续

—— matisse 现场
# 补充：手机不烫但 CPU 被压到 350M — 非热温控 (2026-08-16)

> 追加到 FREQGATE_FAIL。用户实测: 手机摸起来不烫，但 CPU 仍被压到 350MHz。

## 新事实
1. **手机不热** (用户手感) — 排除热温控为主因
2. **频率控制权在 system/root**:
   ```
   scaling_max_freq: -rw-rw---- system system  (shell 写 RC=1 失败)
   scaling_setspeed: -rw-r--r-- root root      (shell 写不了)
   scaling_governor: 读都 Permission denied
   ```
   → shell 无法锁定/控制频率, 温控/调度完全在 system 侧
3. 频率抖动: 1.8G→550M→350M→1.4G (3秒级大跳)

## 修正问题
- 不是热温控 → 是**功耗管理/调度器/性能场景** (joyose 的 scene 调度? powerhal?)
- 手机不烫: 要么是负载不高时正常降频(但 350M 太低且跑 exploit 时不该空闲),
  要么是**非热原因的强制降频** (如特定 scene、电池策略、MTK 的 CPI/调度)

## 请求
1. 谁能决定这种"不热但 350M"的降频? (MTK 的 framework 侧 / kernel cpufreq / powerhal)
2. shell 侧有没有任何合法路径让 CPU 保持高频? (perf 事件? 设置进程的
   scheduler boost? 绑定大核? — 注意 CORE=0/1 是小核 A510)
3. 或者: 接受低频, 看对面"周期计数"论证是否真的在 350M 下成立?
   (350M 是 1.8G 的 1/5, 若变频瞬态持续发生, 窗口必然被破坏)

—— matisse 现场 (2026-08-16 16:10)
