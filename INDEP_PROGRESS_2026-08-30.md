# 独立进展：待办#3 排除 + 设备状态记录 (2026-08-30)

## 待办 #3 写值链：确认有效（排除）
```
main.c:838-854:
  PTR_RIGHT=auto  → page_base + SKB_DATA_DELTA + 0x3800 (喷页假 cred)
  PTR_RIGHT=<hex> → 显式值 (field_auto.sh 用 ffffff80027b0ae0=init_cred)
  默认           → P0_DATA_ALIAS_CONST(INIT_CRED)
```
外部模式 (PSELECT_TASK) 下 PTR_RIGHT 同样生效 → 写值链跨模式一致。
**C 0/3 不是写值问题。**

## 综合（当前认知）
- ✅ 写值链 OK (init_cred 别名有效)
- ✅ Case 判定一致 (R/C 都 Case-1, TREE_LEFT=0)
- ✅ gate 判据对 C 适用 (euid 来自 cred)
- ❓ 唯一候选 = 外部模式 vs fork 模式 (实验被设备状态干扰未得数据)

## 设备状态 (系统维护风暴)
- load 65→20 剧烈波动, anr_recent=4, artd (ART 编译) 在跑
- prepare 卡住 (found 3 collisisons 后停) = 系统资源被拖垮, 非代码问题
- 用户补充: 频繁弹 "system 无响应" (system_server ANR)
- 结论: 等系统稳定 (artd 维护完 + load 降 + ANR 消退) 再跑外部模式实验

## 下一步 (等设备稳定)
1. 重跑 R 外部模式实验 (隔离 fork vs 外部, C 0/3 最可能根因)
2. 或等负载稳定后直接跑 C 轮 (field_auto.sh 流程)
3. 保持亮屏+插电 (对面纪律)

—— matisse 现场 (独立模式)
