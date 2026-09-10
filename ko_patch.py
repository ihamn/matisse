#!/usr/bin/env python3
# ko_patch.py - offline prep of a kernelsu .ko for locked-KSU late-load
#  1) resolve every SHN_UNDEF symbol against a kallsyms dump -> SHN_ABS (like H80GT load_ko.c)
#  2) optionally empty __versions (sh_size=0) -> every CRC check becomes warn-once PASS,
#     and same_magic() sees has_crcs=true so the vermagic release string is skipped
import struct, sys, io

def load_kallsyms(path):
    d = {}
    with open(path, 'r', errors='replace') as f:
        for ln in f:
            p = ln.split()
            if len(p) < 3: continue
            try: a = int(p[0], 16)
            except Exception: continue
            n = p[2]
            if a == 0: continue
            if n not in d: d[n] = a
    return d

def patch(inp, out, ks, empty_versions=True, alias_kasan=True):
    data = bytearray(open(inp,'rb').read())
    assert data[:4] == b'\x7fELF', 'not ELF'
    assert data[4] == 2 and data[5] == 1, 'need ELF64 LE'
    e_shoff = struct.unpack_from('<Q', data, 0x28)[0]
    e_shentsize = struct.unpack_from('<H', data, 0x3A)[0]
    e_shnum = struct.unpack_from('<H', data, 0x3C)[0]
    e_shstrndx = struct.unpack_from('<H', data, 0x3E)[0]
    shstr_off = struct.unpack_from('<Q', data, e_shoff + e_shstrndx*e_shentsize + 0x18)[0]
    symtab = None; strtab_off = None; vers = None
    for i in range(e_shnum):
        sh = e_shoff + i*e_shentsize
        nmoff = struct.unpack_from('<I', data, sh)[0]
        end = data.index(b'\0', shstr_off+nmoff)
        name = data[shstr_off+nmoff:end].decode()
        typ = struct.unpack_from('<I', data, sh+4)[0]
        if typ == 2 and symtab is None:   # SHT_SYMTAB
            symtab = sh
            link = struct.unpack_from('<I', data, sh+0x28)[0]
            strtab_off = struct.unpack_from('<Q', data, e_shoff+link*e_shentsize+0x18)[0]
        if name == '__versions': vers = sh
    assert symtab is not None, 'no symtab'
    so = struct.unpack_from('<Q', data, symtab+0x18)[0]
    ss = struct.unpack_from('<Q', data, symtab+0x20)[0]
    nsyms = ss // 24
    resolved = miss = 0; missing = []
    for i in range(nsyms):
        e = so + i*24
        st_name, st_info, st_other, st_shndx, st_value, st_size = struct.unpack_from('<IBBHQQ', data, e)
        if st_shndx != 0 or st_name == 0: continue
        end = data.index(b'\0', strtab_off+st_name)
        nm = data[strtab_off+st_name:end].decode('utf-8','replace')
        if not nm: continue
        key = nm
        if alias_kasan and nm == 'kasan_flag_enabled': key = 'empty_zero_page'
        a = ks.get(key)
        if a is None:
            miss += 1; missing.append(nm); continue
        struct.pack_into('<H', data, e+6, 0xfff1)      # st_shndx = SHN_ABS
        struct.pack_into('<Q', data, e+8, a)           # st_value = runtime addr
        struct.pack_into('<Q', data, e+16, 0)          # st_size = 0
        resolved += 1
    note = ''
    if empty_versions and vers is not None:
        old = struct.unpack_from('<Q', data, vers+0x20)[0]
        struct.pack_into('<Q', data, vers+0x20, 0)
        note = '__versions sh_size %d -> 0' % old
    elif empty_versions:
        note = 'no __versions section (vermagic release WILL be compared)'
    open(out,'wb').write(bytes(data))
    print('== %s -> %s' % (inp.split('/')[-1], out.split('/')[-1]))
    print('   resolved SHN_UNDEF -> SHN_ABS: %d ; unresolved: %d' % (resolved, miss))
    if missing: print('   UNRESOLVED sample:', ', '.join(missing[:12]))
    print('   ', note)

ks = load_kallsyms('/storage/emulated/0/Documents/matisse_backup_essentials/_research/_extract/kallsyms.txt')
print('kallsyms symbols loaded:', len(ks))
H = '/data/data/com.termux/files/home'
W = H + '/ko_patched'
import os
os.makedirs(W, exist_ok=True)
patch(H + '/matisse/bin/ksu/kernelsu_gki209_v2.ko', W + '/ksu_gki209_v2_patched.ko', ks)
patch(H + '/ksu_lkm/v330.ko', W + '/v330_patched.ko', ks)
patch(H + '/matisse/bin/ksu/preflight_gki209.ko', W + '/preflight_patched.ko', ks)
