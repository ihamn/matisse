#!/usr/bin/env python3
"""dump_selinux_state.py — static boot image of struct selinux_state.

Goal: confirm which bytes in selinux_state+0..+0x60 are bools vs pointers.
E5 zeroes +0..+7; if any pointer lives there, the write is a NULL deref ->
kernel panic -> matches the hang-with-no-recovery signature.
"""
import sys
sys.path.insert(0, "scripts")
from mt_elf import KernelELF

elf = KernelELF()
addr, _ = elf.get_symbol("selinux_state")
print(f"selinux_state @ {addr:#x}")
blob = elf.read_vaddr(addr, 0x60)
for i in range(0, len(blob), 8):
    w = int.from_bytes(blob[i:i+8], "little")
    txt = "".join(chr(c) if 32 <= c < 127 else "." for c in blob[i:i+8])
    tag = ""
    if w > 0xffffff8000000000:
        s = elf.sym_at(w)
        if s:
            tag = f"  -> {s[0]}" + (f"+{s[1]:#x}" if s[1] else "")
    print(f"  +{i:#04x}: {w:#018x} |{txt}|{tag}")
