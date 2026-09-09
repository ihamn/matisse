# rish 层加固 (2026-09-10) — 用户实测报错后的修复

## 用户报错
    rish 自检失败: id -u 返回 [Terminated ] (期望 2000)
    手动 cd ~ && ./rish -c "id -u"  → 2000   (好的)

## 根因 (不是 rish 用法错)
ShizukuShellLoader 通过广播向 Shizuku app 要 binder, **5s 没响应就打
"Request timeout" 并 exit 1**; 冷启动/Doze 时首调很容易超时.
我原来的自检只试 1 次 (且 timeout 20s), 一旦赶上冷启动就误判成 "rish 不可用".
手动再跑就好, 是因为 Shizuku 已经被唤醒了.

## 修复 (抄 ksu_hunt.sh 的成熟做法 + 加固)
1. 冷启动自检: 两种模式 (./rish -c / stdin) x 5 轮, 每轮间隔 10s → 最多 10 次尝试
2. 所有 rish 调用统一重试, 匹配 "Request timeout|blocked by your system|Terminated"
3. -c 调用统一 </dev/null (防 stdin 挂住); timeout -k 5 强制收尸
4. 二次自检: 除 id -u=2000 外, 还必须能读到 boot_id (证明输出通道真通)
5. rpush 走同一套重试

## 验证 (用户要求 "做好检查")
- **mock rish 场景1** (前 2 次失败后成功): 第1轮两种模式都失败 → 10s → 第2轮成功 ✓
- **mock rish 场景2**: 一直失败 → 干净退出并打印排查步骤 ✓
- **真实设备** (截断到开火前): 第1轮即成功, 期间一次真实闪断被自动重试后成功,
  三个 payload SHA 全部核对通过 ✓

## 现状
直接 bash ~/ksu_load.sh 即可; 不再需要重启 (uptime 门已按用户要求删除).
