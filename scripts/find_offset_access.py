#!/usr/bin/env python3
"""find_offset_access.py — find kernel functions accessing a task_struct offset.

Scans every FUNC symbol for load/store instructions whose memory-displacement
immediate equals the given offset, e.g.:

  python3 scripts/find_offset_access.py 0x778 0x780 0x788

Use case (CHECKPOINT_C_stage_paradox_20260901.md §四): prove no function in
the kernel touches task+0x788 (the unknown MTK-vendor field between cred and
comm), hence the C-geometry rb_erase branch check *(task+0x788)==node is
always 'ne'.
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mt_elf import KernelELF
import capstone


def scan(k, off):
    print(f"== offset {off:#x} accessors ==")
    hits = 0
    for addr, size, name in k.funcs:
        size = k.func_size_or_derived(addr, size)
        try:
            for ins in k.disasm(addr, size):
                if ins.mnemonic not in ("ldr", "str", "ldur", "stur",
                                        "ldrsw", "ldp", "stp", "ldar", "stlr",
                                        "ldxr", "stxr", "ldrsh", "ldrsh"):
                    continue
                for op in ins.operands:
                    if op.type == capstone.arm64.ARM64_OP_MEM and \
                       op.mem.disp == off:
                        print(f"  {name} +{ins.address - addr:#x} "
                              f"@{ins.address:#x}: {ins.mnemonic} {ins.op_str}")
                        hits += 1
                        break
        except Exception:
            continue
    print(f"  -> {hits} instruction(s) total\n")
    return hits


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    k = KernelELF()
    total = 0
    for a in sys.argv[1:]:
        total += scan(k, int(a, 0))
    print(f"TOTAL: {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
