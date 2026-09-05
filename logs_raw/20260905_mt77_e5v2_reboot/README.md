# mt77 + E5v2 reboot record (2026-09-05)

## Result
- mt77 R round with PSELECT_CONSUMER_CPU=6 **landed**: full storm, CapEff full.
- E5v2 external round started right after; output file is all NUL, phone rebooted.
- New boot after reboot: ab549482-55e6-4024-b5a4-0f7d951d09fd.

## Evidence
- R_mt77_landed.out: R success with consumer CPU6 (mt77 anti-starvation works).
- E5v2_mt77_zeros.out: 1089 bytes all NUL, panic/reboot before flush.

## Notes
- mt77 CPU knob successfully fixed R starvation.
- E5v2 still causes reboot/hang even with initialized=1 kept (value=0x10000).
- Need external review; stop E5-family field tests until root cause found.
