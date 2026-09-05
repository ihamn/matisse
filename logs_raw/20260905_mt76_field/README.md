# mt76 field attempts (2026-09-05)

R stage attempts with mt76 all starved (consumer arrives just after pselect returns):
- 20s window: mt19b at 20020-20035ms after pselect returned
- 30s window: mt19b at 30032ms after pselect returned
No R-landed child, so mt76 E5v2/C sequence could not start.

Next: wait for load/scheduling recovery or implement consumer big-core env knob.
