#!/usr/bin/env python3
"""find_state_xrefs.py — all code references to selinux_state (and byte offsets).

Purpose (2026-09-05, E5 black-screen postmortem): E5 zeroes selinux_state+0..+7
(enforcing@+0, initialized@+2 confirmed). Device hangs 2/2 after the write.
Hypotheses:
  (a) OEM/vendor watchdog reads enforcing and reacts (reboot/panic/kill)
  (b) initialized=0 collateral in some !selinux_initialized() path
This script lists EVERY function that materializes &selinux_state, which byte
offsets it touches, and whether it calls anything reboot/panic-ish.
"""
import sys
sys.path.insert(0, "scripts")
from mt_elf import KernelELF

TARGET = None  # set from symbol
DANGEROUS = ("panic", "emergency_restart", "machine_restart", "kernel_restart",
             "orderly_poweroff", "orderly_reboot", "sys_reboot", "__request_key",
             "do_exit", "force_sig", "send_sig", "do_group_exit", "kernel_halt",
             "poweroff", "reboot_")

elf = KernelELF(sys.argv[1] if len(sys.argv) > 1 else "ref/kernel_with_symbols.elf")
addr, size = elf.get_symbol("selinux_state")
if not addr:
    raise SystemExit("no selinux_state symbol")
print(f"selinux_state @ {addr:#x} size={size:#x}")

hits = 0
for fa, fsz, fname in elf.funcs:
    sz = elf.func_size_or_derived(fa, fsz)
    regs = {}          # reg -> page base (adrp)
    found = {}         # offset_in_state -> [ins text]
    danger = []
    for ins in elf.disasm(fa, sz):
        m = ins.mnemonic
        if m == "adrp":
            try:
                regs[ins.operands[0].reg] = ins.operands[1].imm & 0xFFFFFFFFFFFFFFFF
            except Exception:
                pass
            continue
        # add xN, xN, #imm / ldr xN, [xN, #imm] / ldarb wN, [xN]
        try:
            ops = ins.operands
            if m == "add" and len(ops) == 3:
                base = ops[1].reg if ops[1].type == 1 else None
                if base in regs and ops[2].type == 2:
                    full = (regs[base] + ops[2].imm) & 0xFFFFFFFFFFFFFFFF
                    if addr <= full < addr + 8:
                        found.setdefault(full - addr, []).append(
                            f"{ins.address:#x} {m} {ins.op_str}  ;; &state+{full-addr:#x}")
            elif m in ("ldr", "ldrb", "ldarb", "strb", "str", "stlr", "ldar") and len(ops) == 2:
                if ops[1].type == 3:  # MEM
                    mem = ops[1].mem
                    if mem.base in regs:
                        full = (regs[mem.base] + mem.disp) & 0xFFFFFFFFFFFFFFFF
                        if addr <= full < addr + 8:
                            found.setdefault(full - addr, []).append(
                                f"{ins.address:#x} {m} {ins.op_str}  ;; state+{full-addr:#x}")
        except Exception:
            pass
        if m in ("b", "bl"):
            # annotate target via sym_at
            try:
                t = ins.operands[-1].imm & 0xFFFFFFFFFFFFFFFF
                s = elf.sym_at(t)
                if s and s[1] == 0 and any(d in s[0] for d in DANGEROUS):
                    danger.append(f"{ins.address:#x} -> {s[0]}")
            except Exception:
                pass
    if found:
        hits += 1
        offs = ",".join(f"+{o:#x}" for o in sorted(found))
        d = ("  *** CALLS: " + "; ".join(danger[:4])) if danger else ""
        print(f"{fname} [{fa:#x}]: {offs}{d}")
        for o in sorted(found):
            for line in found[o][:3]:
                print(f"    {line}")
print(f"\n{hits} functions reference selinux_state[0..8)")
