#!/usr/bin/env python3
"""find_callers.py — find callers of a kernel symbol/address.

Usage:
  python3 scripts/find_callers.py rb_erase
  python3 scripts/find_callers.py 0xffffffc008a71228

Scans every FUNC for b/bl (and cbz/cbnz/tbz/tbnz) instructions whose target
resolves into the given symbol. Used to map the rt_mutex erase trigger chain
(remove_waiter -> rb_erase, rt_mutex_adjust_prio_chain -> ...).
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mt_elf import KernelELF
import capstone


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    k = KernelELF()
    target = sys.argv[1]
    if target.startswith("0x") or target.isdigit():
        taddr = int(target, 0)
        tsize = 0x10
        tname = k.sym_at(taddr)
        tname = tname[0] if tname else f"{taddr:#x}"
    else:
        taddr, tsize = k.get_symbol(target)
        if taddr is None:
            print(f"symbol not found: {target}")
            return 1
        tsize = k.func_size_or_derived(taddr, tsize)
        tname = target
    print(f"== callers of {tname} @ {taddr:#x} (size {tsize:#x}) ==")
    hits = 0
    for addr, size, name in k.funcs:
        if addr == taddr:
            continue
        size = k.func_size_or_derived(addr, size)
        try:
            for ins in k.disasm(addr, size):
                if ins.mnemonic not in ("b", "bl", "cbz", "cbnz", "tbz", "tbnz"):
                    continue
                for op in ins.operands:
                    if op.type == capstone.arm64.ARM64_OP_IMM and \
                       taddr <= (op.imm & 0xFFFFFFFFFFFFFFFF) < taddr + tsize:
                        print(f"  {name} +{ins.address - addr:#x} "
                              f"@{ins.address:#x}: {ins.mnemonic} {ins.op_str}")
                        hits += 1
                        break
        except Exception:
            continue
    print(f"  -> {hits} call site(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
