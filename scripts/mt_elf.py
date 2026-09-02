#!/usr/bin/env python3
"""mt_elf.py — shared ELF helpers for matisse kernel analysis.

Target: ref/kernel_with_symbols.elf (boot bf1c84d3, ARM aarch64, not stripped).
Notes learned the hard way (2026-09-01 session):
  - The code lives in section `.kernel` (PROGBITS), not `.text`.
  - Many FUNC symbols have size==0; derive size = distance to next symbol
    (capped at 0x8000) or disassembly silently skips them.
  - Functions contain embedded literal pools -> capstone needs skipdata=True.
"""
import bisect
from elftools.elf.elffile import ELFFile
import capstone

DEFAULT_ELF = "ref/kernel_with_symbols.elf"


class KernelELF:
    def __init__(self, path=DEFAULT_ELF):
        self.path = path
        self.f = open(path, "rb")
        self.elf = ELFFile(self.f)
        self.sections = []  # (name, addr, offset, size)
        for s in self.elf.iter_sections():
            if s["sh_flags"] & 0x2:  # SHF_ALLOC
                self.sections.append(
                    (s.name, s["sh_addr"], s["sh_offset"], s["sh_size"]))
        # symbols: (addr, size, name); funcs kept separately
        self.symbols = []
        self.funcs = []
        for secname in (".symtab", ".dynsym"):
            sec = self.elf.get_section_by_name(secname)
            if sec is None:
                continue
            for sym in sec.iter_symbols():
                if not sym.name:
                    continue
                st = sym["st_info"]["type"]
                if st == "STT_FUNC":
                    self.funcs.append((sym["st_value"], sym["st_size"], sym.name))
                self.symbols.append(
                    (sym["st_value"], sym["st_size"], sym.name))
        self.funcs.sort()
        self.symbols.sort()
        self.func_addrs = [a for a, _, _ in self.funcs]
        self.sym_addrs = [a for a, _, _ in self.symbols]
        self.md = capstone.Cs(capstone.CS_ARCH_ARM64,
                              capstone.CS_MODE_LITTLE_ENDIAN)
        self.md.skipdata = True
        self.md.detail = True

    # ---------- symbol helpers ----------
    def get_symbol(self, name):
        """Return (addr, size) or (None, None)."""
        for a, s, n in self.symbols:
            if n == name:
                return a, s
        return None, None

    def sym_at(self, addr):
        """Best symbol containing addr -> (name, offset) or None."""
        i = bisect.bisect_right(self.sym_addrs, addr) - 1
        if i < 0:
            return None
        a, s, n = self.symbols[i]
        if a <= addr < a + max(s, 0x1000000):
            return (n, addr - a)
        return None

    def func_size_or_derived(self, addr, size):
        """Derive size from next symbol when size==0 (capped at 0x8000)."""
        if size:
            return size
        i = bisect.bisect_right(self.func_addrs, addr)
        nxt = self.funcs[i][0] if i < len(self.funcs) else addr + 0x8000
        return min(nxt - addr, 0x8000)

    # ---------- memory ----------
    def section_of(self, vaddr):
        for name, va, off, sz in self.sections:
            if va <= vaddr < va + sz:
                return (name, va, off, sz)
        return None

    def read_vaddr(self, vaddr, size):
        sec = self.section_of(vaddr)
        if not sec:
            return None
        name, va, off, sz = sec
        if vaddr + size > va + sz:
            size = va + sz - vaddr
        self.f.seek(off + (vaddr - va))
        return self.f.read(size)

    # ---------- disassembly ----------
    def disasm(self, vaddr, size):
        """Yield capstone instructions starting at vaddr."""
        blob = self.read_vaddr(vaddr, size)
        if blob is None:
            return
        for ins in self.md.disasm(blob, vaddr):
            yield ins

    def annotate(self, ins):
        """Resolve branch/call targets to symbol names.
        capstone reports AArch64 branch immediates as signed 64-bit;
        mask to unsigned before resolving."""
        if ins.group(capstone.arm64.ARM64_GRP_CALL) or \
           ins.mnemonic in ("b", "bl", "cbz", "cbnz", "tbz", "tbnz"):
            for op in ins.operands:
                if op.type == capstone.arm64.ARM64_OP_IMM:
                    imm = op.imm & 0xFFFFFFFFFFFFFFFF
                    s = self.sym_at(imm)
                    if s and s[1] == 0:
                        return f"  ; -> {s[0]}"
                    elif s:
                        return f"  ; -> {s[0]}+{s[1]:#x}"
                    else:
                        return f"  ; -> {imm:#x}"
        return ""
