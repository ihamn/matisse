#!/usr/bin/env python3
"""2026-09-07 对面更新核验:
1) /proc/PID/status (task_state) 的 cred 来源 — get_task_cred 读 task+?
2) ksymtab 导出数 / register_kprobe 是否导出
3) KSU 计划声称的未导出符号是否在 kallsyms(符号表)有名字
4) 模块签名强制 (sig_enforce / module_sig_check) 是否存在
"""
from elftools.elf.elffile import ELFFile
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN

ELF = "ref/kernel_with_symbols.elf"
f = open(ELF, "rb")
elf = ELFFile(f)

syms = {}
symtab = elf.get_section_by_name(".symtab")
for s in symtab.iter_symbols():
    if s.name and s["st_value"]:
        syms.setdefault(s.name, s["st_value"])

secs = {}
for sec in elf.iter_sections():
    secs[sec.name] = sec

def disasm(name, count=24):
    if name not in syms:
        print(f"  [!] symbol {name} NOT FOUND"); return
    addr = syms[name]
    # find containing section
    for sec in elf.iter_sections():
        if sec["sh_addr"] <= addr < sec["sh_addr"] + sec["sh_size"] and sec["sh_addr"]:
            off = addr - sec["sh_addr"]
            data = sec.data()[off:off + count * 4]
            break
    else:
        print(f"  [!] {name} addr {addr:#x} not in any section"); return
    md = Cs(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN)
    print(f"  --- {name} @ {addr:#x} ---")
    for i in md.disasm(data, addr):
        print(f"  {i.address:#x}:  {i.mnemonic:<8} {i.op_str}")

print("=== [1] get_task_cred 反汇编 (status 的 cred 来源) ===")
disasm("get_task_cred", 20)

print("=== [1b] task_state 是否存在/其调用 get_task_cred ===")
if "task_state" in syms:
    addr = syms["task_state"]
    md = Cs(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN)
    for sec in elf.iter_sections():
        if sec["sh_addr"] and sec["sh_addr"] <= addr < sec["sh_addr"] + sec["sh_size"]:
            data = sec.data()[addr - sec["sh_addr"]: addr - sec["sh_addr"] + 0x400]
            break
    tgt = syms.get("get_task_cred")
    for i in md.disasm(data, addr):
        if i.mnemonic == "bl":
            op = i.op_str
            try:
                dest = int(op, 16) if not op.startswith("#") else int(op[1:], 16)
            except ValueError:
                continue
            if dest == tgt:
                print(f"  task_state @ {addr:#x}: bl get_task_cred @ {i.address:#x}  ✓")
else:
    print("  task_state 符号不存在(可能内联)")

print("=== [2] ksymtab 导出统计 ===")
n_exp = 0
reg_kprobe_exported = False
for sec in elf.iter_sections():
    if sec.name.startswith("__ksymtab") and sec.name == "__ksymtab":
        # entries are 8 bytes on 64-bit (relative)
        n_exp = sec["sh_size"] // 8
# fallback: count __kstrtab names via ksymtab strings section
kstr = secs.get("__kstrtab")
if kstr is not None:
    names = kstr.data().split(b"\x00")
    names = [n.decode() for n in names if n]
    n_exp = len(names)
    reg_kprobe_exported = "register_kprobe" in names
    print(f"  __kstrtab 导出符号总数: {n_exp}")
    print(f"  register_kprobe 导出: {reg_kprobe_exported}")
else:
    print(f"  __ksymtab 条目: {n_exp}")
print(f"  (对面声称 __ksymtab_ 7179 条)")

print("=== [3] KSU 依赖符号在 kallsyms(本表)中是否存在 ===")
want = ["commit_creds", "kallsyms_lookup_name", "prepare_creds", "override_creds",
        "revert_creds", "__put_cred", "security_context_to_sid", "path_mount",
        "path_umount", "ksys_unshare", "selinux_state", "register_kprobe",
        "finit_module", "load_module", "module_sig_check", "sig_enforce",
        "may_mount", "get_task_cred", "task_state"]
for w in want:
    mark = "✓ kallsyms有名" if w in syms else "✗ 不在符号表"
    print(f"  {w:<28} {mark}")

print("=== [4] 模块签名强制检查 ===")
for s in ("module_sig_check", "sig_enforce", "mod_verify_sig", "is_module_sig_enforced"):
    print(f"  {s}: {'存在' if s in syms else '无此符号'}")
f.close()
