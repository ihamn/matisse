# E5 second black-screen record (2026-09-05)

## Timeline
- R round landed (task=ffffff817420a500, CapEff full).
- E5 external attempt: starved, 0 shots, enforce stayed 1.
- E5 fork attempt (E5_mt75b): full storm, mt51 abort (R semantics false on E5 child), enforce became 0.
- Phone black-screened again and would not auto-reboot; user force rebooted.

## Evidence
- E5_mt75b.out shows E5 marker, full in-window storm, enforce read 0 after.
- E5_mt75_external_starved.out shows external attempt 0 shots.

## Conclusion for review
- E5 reliably flips enforce to 0.
- E5 reliably triggers black screen / hang shortly after (two occurrences).
- Need pstore/kernel log to determine whether black screen is caused by raw selinux_state write/framework reaction, not just AVC flood (already statically unlikely).
