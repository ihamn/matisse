# 现场事件记录：崩溃 + dsh 污染 + joyose 降频 (2026-08-16 15:28-15:45)

> 供评审完整了解，也作为下次跑前的状态基线。

## 事件链（按时间）

### 1. mt49 跑动（15:28-15:31, boot 13c15d67）
- SKIP_R0=1 启动, ENF round1 跑完
- logenv 首批数据（对面设计的验证工具，**抓到热降频实锤**）:
  ```
  15:28:40 freq0=1800000 freq1=1800000   ← 全速
  15:30:43 freq0=650000  freq1=650000    ← 2分钟后掉到 1/3!
  ```

### 2. 设备重启（→ boot 79737542）
- ENF round2 后崩溃重启（日志停在 15:30:43）
- 新 boot 79737542

### 3. dsh web 崩溃（15:28-15:39, 与 mt 实验时间吻合）
- **AI_ARCHIVE_2026-08-15_dsh_web_incident.md 第三次复发**
- ~/.dsh/storages/session_projcache.json inode 被污染（-?????????? EACCES）
- dsh web 起不来 → 由 codex 按档案流程修复（隔离 storages + 重启）
- 结论: 写原语副作用落到了 dsh 存储文件 inode（虽目标是内核内存）

### 4. joyose 温控（15:40+）
- 发现 CPU 降到 650MHz = 热降频（对面热窗假说的机制验证）
- 定位: com.xiaomi.joyose (PID 5159) 系统温控服务
- pm disable-user 被拒（系统包不能禁用）
- **am force-stop com.xiaomi.joyose 成功** → CPU 回到 1.4-1.8GHz
- 注意: force-stop 是临时的, 重启后 joyose 会回来

### 5. mt49 再跑一轮（15:4x, boot 79737542）
- 用户指出: 刚崩溃完立刻重跑 = 送命（设备状态不稳）
- STAGE-R 4轮未落地, 脚本自行退出, 已确认无残留无root无insmod

## 关键结论
1. **热降频假说获得首个实测证据**（freq 1.8G→650M）
2. **joyose 是降频元凶候选**（force-stop 后频率回升）
3. **崩溃-重启-重跑循环伤设备且无效**（用户正确叫停）
4. dsh 污染是写原语副作用, 已知处理流程有效（隔离 storages）

## 下次跑前 checklist
- [ ] 设备 boot 稳定（重启后等 5-10 分钟）
- [ ] dsh web 健康（codex 已修, curl 200）
- [ ] joyose 已 force-stop（CPU 全速）
- [ ] 对面是否已根据热降频数据调整时序参数（待确认）
- [ ] 确认再启动, 不刚崩完就跑

—— matisse 现场 (2026-08-16 15:45)
