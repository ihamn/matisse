# CHECKPOINT — mt78/E5v3 交付 + R 轮 STORE(b) 污染抽查 (2026-09-05 深夜)

## 1. mt78 (E5v3) 已构建
- preload.so SHA256: a8e5d7b89483b8cbbe118c74b906f276a7607febf1895ef16d364be0d0cfab83
- 位置: bin/mt78/{preload.so,su_daemon,BUILD_INFO.txt} + 工作区 preload_mt78.so
- VALUE 语义: SPRAY(默认)=fake_lock / SPRAY1=fake_lock+1(E5R) / 0=v1对照 / 其它=ABORT
- 运行时打印 enforcing/checkreqprot/initialized 三 byte 供现场核对

## 2. R 轮 STORE(b) 对 init_cred+0 污染 — 抽查通过, 无新影响
rb_erase @0xffffffc008a71228 反汇编复核 (scripts/disasm.py, pyelftools 已重装):
- CASE_A child≠0 路径全程恰好 2 个 store:
  0x1298 str x8,[x11]  = STORE(a) *(parent+8)=child   → [task+0x778]=init_cred
  0x12a4 str x9,[x8]   = STORE(b) *(child+0)=pc       → [init_cred+0]=task dmap+0x770
  0x129c cbz x8 不跳(child≠0) → 0x1360 rebalance 判定(sbfx pc bit0)完全跳过
  → 0x137c autiasp;ret 干净返回, 无第三处写。
- 污染范围 = init_cred+0..+7 恰好 8 字节: usage@+0 ← low32(task dmap+0x770)
  ≈ 0x02xxxxxx(数千万, 恒正) = 防释放护身符; uid@+0x4 ← 0xffffff80 垃圾
  (子进程 setresuid(0) 自愈, 7/7 实证); euid@+0x14 / caps ≥+0x20 不在窗口, 完好。
- E5v3 同构推论: SPRAY 时 STORE(b) 落 [fake_lock+0]=pc → 只污染牺牲喷页零区;
  SPRAY1 时 child=fake_lock+1 奇地址, arm64 非对齐写合法, STORE(b) 落
  [fake_lock+1]=pc → 污染喷页 byte1.. 起的 8 字节, 同样牺牲区。✓
- 附带确认: E5v3 pc=(selinux_alias-8)&~3=0xffffff8002a41b90, bit0=0(RED) 正确;
  且 child≠0 时 RED/BLACK 判定根本不执行 —— 色位只在 child=0(v1 "0" 模式)时才有意义。
- E5v3 判别字 *(parent+0x10) = selinux_state+8(policycap 区, 随机内核数据)
  ≠ node 恒成立 → csel 选 parent+8 = enforcing 槽 ✓ 几何端到端成立。

## 3. 铁律重申
- E5v3 现场轮在 pstore 取证收到之前不跑 (HANDOFF §5.3/§6.2)。
- root 成功后不得用 root 权限对手机做任何操作; KSU 需用户另行授权。
