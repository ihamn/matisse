#!/usr/bin/env python3
"""dump_task_fields.py — dump raw init_task bytes with symbol annotation.

Usage:
  python3 scripts/dump_task_fields.py            # 0x760..0x7a0
  python3 scripts/dump_task_fields.py 0x760 0x7b0

Provenance (CHECKPOINT_C_stage_paradox_20260901.md §四): established that
  +0x778 real_cred -> init_cred, +0x780 cred -> init_cred,
  +0x788 = 0 (unknown 8-byte MTK-vendor field), +0x790 comm = "swapper".
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mt_elf import KernelELF


def main():
    lo = int(sys.argv[1], 0) if len(sys.argv) > 1 else 0x760
    hi = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x7a0
    k = KernelELF()
    addr, size = k.get_symbol("init_task")
    if addr is None:
        print("init_task not found")
        return 1
    print(f"init_task @ {addr:#x} size={size:#x}")
    sec = k.section_of(addr)
    print(f"section: {sec[0] if sec else '?'}")
    for anchor in ("init_cred", "init_nsproxy", "init_pid_ns"):
        a, s = k.get_symbol(anchor)
        if a:
            print(f"anchor {anchor} @ {a:#x}")
    blob = k.read_vaddr(addr + lo, hi - lo)
    if blob is None:
        print("read failed")
        return 1
    print(f"\ninit_task+{lo:#x} .. +{hi:#x}:")
    for i in range(0, len(blob), 8):
        off = lo + i
        w = int.from_bytes(blob[i:i + 8], "little")
        txt = "".join(chr(c) if 32 <= c < 127 else "."
                      for c in blob[i:i + 8])
        tag = ""
        if w > 0xffffff0000000000:
            s = k.sym_at(w)
            if s:
                tag = f"  -> {s[0]}" + (f"+{s[1]:#x}" if s[1] else "")
        print(f"  +{off:#05x}: {w:#018x}  |{txt}|{tag}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
