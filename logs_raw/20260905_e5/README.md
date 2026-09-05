# E5 field result (2026-09-05)

## Result
- mt74 E5 round ran with full 6-shot storm (t=12.5s into 20s window).
- `mt74: SELINUX_ENF write pc=ffffff8002a41b90` printed.
- After the round, `/sys/fs/selinux/enforce` read **0** -> E5 write landed, SELinux permissive.
- Immediately/soon after, device black-screened (system-level instability).
- dsh web task-board corruption was repaired separately by user; this archive is for the exploit output.

## Evidence
- `E5.out`: full round log showing E5 marker and storm.
- Device status file at end: task=ffffff828cc6ca00 uid=2000 euid=2000 CapEff=0.
- enforce file read 0 in local console after E5.

## Notes for external review
- E5 appears to work (enforce=0) but the system black-screened after/around it.
- Need determine whether black screen is caused by setting selinux_state+0=0 (framework expects different layout/order) or by unrelated load/instability.
