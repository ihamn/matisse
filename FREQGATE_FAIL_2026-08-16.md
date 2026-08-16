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
