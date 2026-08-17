# 卡 3 附录 · LOAD_WAIT 裁定 + ANR 替代通道（评审裁定，零判断照抄）2026-08-17

> 裁定人：评审。现场停点合规，三问裁定如下，全部转成机器指令。

## 裁定理由（给记录，不需要执行）

- **LOAD_WAIT 不是安全闸**。安全闸 = boot 未变 + Enforcing，两者双绿。
  load>3 只影响竞态质量（owner 排队 vs requeue 的 20ms 窗口）。
- mt60 之后，竞态输了的哑轮 = 12s 自弃 rc=3，**零预算消耗**（R4 已实证）。
  重掷成本极低，不值得无限等。
- 落点错位（dirty）风险由堆布局决定，不由调度负载决定 → load 高不增加 dirty 风险。
- 裁定：**最多再等 20 分钟，仍高就照打**。ANR 走 dropbox。

---

## A 块 · load 再检查（最多 2 次，每次隔 10 分钟）

```sh
top -n 1 -q | head -12
awk '{print ($1<3)?"LOAD_GO":"LOAD_WAIT"}' /proc/loadavg
grep MemAvailable /proc/meminfo
```

规则（照字面）：
- `LOAD_GO` → **直接跳回卡 3 第 2 步开火 R6**（top/mem 输出随本附录末尾一起推）。
- `LOAD_WAIT` → `sleep 600` 后重跑 A 块（最多再 1 次）。
- 第 2 次仍 `LOAD_WAIT` → **评审覆盖裁定：照打**。直接跳卡 3 第 2 步。
  （哑轮代价 = 12s rc=3；这比再等一小时便宜。boot+enforce 绿就是安全。）

## B 块 · ANR 替代通道（dropbox，shell 可读，替代卡 3 第 0 步）

```sh
dumpsys dropbox 2>/dev/null | grep -E "data_app_anr|system_app_anr" | tail -6
dumpsys dropbox --print data_app_anr > /data/local/tmp/anr_extract.txt 2>/dev/null
dumpsys dropbox --print system_app_anr > /data/local/tmp/anr_extract_sys.txt 2>/dev/null
ls -la /data/local/tmp/anr_extract*.txt
tail -80 /data/local/tmp/anr_extract.txt
```

五行输出原样贴回；两个 extract 文件推仓库原文（大就大着推）。
`ls: No such file` 就贴回错误行，不用管。

## C 块 · 顺序

A 块 → （GO 或第 2 次 WAIT）→ 卡 3 第 2 步 R6 → 卡 3 第 3/4/5 步照旧。
B 块随末尾推送一起。其余禁止事项同卡 3。

## rc 语义（再贴一遍，防翻旧消息）

| rc | 含义 |
|---|---|
| 0 | 父进程干净走完 |
| 42 | **子进程 ROOT** |
| 2 | 子进程 8 分钟窗口耗尽 |
| 255 | 跑完未 root（正常未中） |
| 3 | 哑轮 12s 自弃（零预算，立即重跑下一轮） |
| 124 | harness 击杀真挂 |
