# off778 full-storm round (2026-09-04)

## Result
- PC_OFF=0x778, fork mode, full 6-shot storm (t=50ms)
- final: uid=2000 euid=2000 CapEff=0 root_seen=0
- no mt51 abort (C euid==0 signal not observed)
- off788 previously corrupted comm -> main-tree store does execute for pc>=0x778
- Combined with E4a pi-tree failure, supports H3 (cred@0x780 write neutralized/rolled back) or a cred-slot-specific consistency constraint.

## Soft-restart clue
- System earlier experienced user-observed "brief double soft reboot, apps not cleared" (system_server/zygote level).
- This is a mysterious clue worth external review: soft restart without full kernel reboot may be caused by cred/process inconsistency, not just load pressure.
