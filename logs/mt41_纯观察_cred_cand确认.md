# mt41 纯观察结果: cred_cand 稳定识别 + 每进程独有 (2026-08-15 22:28)

## 数据 (OBS_ONLY 纯泄露, 零写入)
- perf task=ffffff805e161280 (221/256 票)
- mt39: cred_cand=ffffff80c62cfc00 votes=35 (diff=+1746332032)
- mt41: OBS task=ffffff805e161280 cred_cand=ffffff80c62cfc00

## 跨轮对比 (cred_cand 每轮不同)
- mt39 (21:22): ffffff811147b300
- mt39b (21:49): ffffff8108bae000
- mt41 (22:23): ffffff80c62cfc00
=> 每进程独有对象 - 符合 cred 特征 (每进程 cred_jar)
=> 不是共享全局 (init_cred/mm_struct 固定地址)

## 结论 (增强但非铁证)
cred_cand 是"每进程独有 + 稳定识别 + 采样命中" - 高度符合 cred
但 mm_struct 等也有此特征, 需写验证

## 下一步 (受控验证)
写 cred_cand+0x4=0 (real uid@+0x4, getuid 反汇编铁证)
- uid 变 0 = 铁证是 cred → root
- 崩 = 不是 cred 或写链问题
- PSELECT_RETRY=1 控制风险

