
# ⚠️⚠️ 撤回声明 (2026-09-07 对面复核后) ⚠️⚠️
本归档的 "ROOT 证据" 判定**无效**: /proc/PID/status 的 Uid 四元组全部读
task+0x778 (real_cred) — 指令级核验 get_task_cred @0xffffffc008184804
(add x9,x0,#0x778; ldar x19,[x9])。观测到的
Uid: 4294967168 0 0 0 / CapEff 满 = **第 13 次 R 落地铁证** (real_cred=
init_cred), 不能证明 cred(主观) 已换 → **不是 root**。
本文件保留为 R-landing 证据; C 落地判定需走 getresuid(主观) /
sethostname 信标 / root_alive.txt(仅 setresuid 后可写)。
详见 REVIEW_2026-09-07_opponent_update.md §2-3。
# ★ ROOT 证据 — CVE-2026-43499 matisse 提权成功 (2026-09-07 00:52 前夜锁存)

## 判据 (shell 直读 /proc/19735/status, readproc 组, 不可伪造)
Name:   sleep
Pid:    19735
PPid:   1
Uid:    4294967168  0  0  0   ← real=0xFFFFFF80 = init_cred.uid 被 STORE(b)
                              污染的指纹 (R 轮写路径绝对证明)
                          euid=0 suid=0 fsuid=0 = ROOT 生效身份
Gid:    0  0  0  0              ← 全 root 组
CapEff: 000001ffffffffff        ← 全部 39 项 capabilities
CapBnd: 000001ffffffffff        ← 全界限集
Seccomp: 0, NoNewPrivs: 0       ← 无沙箱
child-alive: /proc/19735/status 存在

## 链路
boot 4db5f922 → c-strike (mt83, RETRY=1 单写):
  R 轮 task=ffffff80d68c3780 落地 (CapEff 满, 第 13 次)
  → C 轮 PSELECT_TASK=<R child> 单写 → cred=init_cred 落地
  → child = euid 0 + 全 caps = ROOT
## 全天致盲假象澄清: 此前所有 "C miss" 均为致盲
  (status 文件冻结 + beacon 未验) — C 的落地从未缺过, 缺的是观测通道
## 红线执行: 未使用 root 权限对手机做任何操作; KSU 等用户另行授权
