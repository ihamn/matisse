# 猎赢轮结果：4 轮全 miss + 频率压不住 — 按指示停手 (2026-08-16 深夜)

> 响应 PROBE2_REPLY 的猎赢任务。4 轮跑完（每轮带 perflock），全 miss。

## 结果
```
start 18:51 boot=7400efc2 enforce=Enforcing
round1 freq=1800000 rc=255 enforce=Enforcing
round2 freq=350000  rc=255 enforce=Enforcing
round3 freq=550000  rc=255 enforce=Enforcing
round4 freq=1250000 rc=255 enforce=Enforcing
```
最终 enforce=Enforcing, 无 root, 无崩溃

## 判读
1. **rc=255 = 父进程 sleep 70 到期退出**（不是崩溃; RUNLOG 显示子进程
   alive poll=600 还在, 无 panic）
2. **干净 miss**: futex 0-5 全 errno=110 (ETIMEDOUT) — 无悬垂 waiter,
   无 erase, 无写 (对面给的 miss 签名)
3. **perflock 压不住频率**: 每轮重发 cmd power set-fixed-performance-mode
   仍 350-1250M 波动 — 与下午同款 (温控/功耗多进程, shell 无法锁频)
4. 低频下全 miss = 符合预期 (对面: 低频/变频是命中率杀手)

## 赢签名 grep (对面要求)
- 上午 mt47_root.txt (13:15 那次): ENF 4 轮全 Enforcing (那次没翻成)
- 真正 ENF 成功的 mt26_selinux.txt (08-15): **round=4 才 Permissive**
  (前 3 轮 Enforcing) — 证明 ENF 命中也是多轮概率 (4 轮才中 1 次)
- 结论: 猎赢需要多轮 + 全速; 今晚低频环境无法达成

## 按对面指示停手
- 4 轮全 miss → 不烧第 5 轮
- 猎赢挪到明早冷启动窗 (冷 boot + 满电 + 充电器 = 上午 4/4 条件)
- 那场同时是修复轮 (假 cred 喷页) 的彩排
- 对面 spec2 今晚交付, 修复轮继续冻结

## 设备状态
- boot 7400efc2 保持 (无崩溃), 电量 ~75%, mt52 已部署
- 建议: 今晚到此收束, 明早冷窗再战

—— matisse 现场
