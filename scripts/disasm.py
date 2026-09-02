#!/usr/bin/env python3
"""disasm.py — disassemble a kernel symbol or raw address.

Usage:
  python3 scripts/disasm.py rb_erase
  python3 scripts/disasm.py 0xffffffc008a71228 0x100
  python3 scripts/disasm.py proc_pid_status

size=0 symbols: size derived from distance to next symbol (see mt_elf.py).
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mt_elf import KernelELF


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    k = KernelELF()
    target = sys.argv[1]
    if target.startswith("0x") or target.isdigit():
        addr = int(target, 0)
        size = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x100
        label = f"addr {addr:#x}"
    else:
        addr, size = k.get_symbol(target)
        if addr is None:
            print(f"symbol not found: {target}")
            return 1
        size = k.func_size_or_derived(addr, size)
        if len(sys.argv) > 2:
            size = int(sys.argv[2], 0)
        label = target
    sec = k.section_of(addr)
    print(f"== {label} @ {addr:#x} size={size:#x} "
          f"section={sec[0] if sec else '?'} ==")
    for ins in k.disasm(addr, size):
        print(f"  {ins.address:#014x}:  {ins.mnemonic:<8s} {ins.op_str}"
              f"{k.annotate(ins)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
