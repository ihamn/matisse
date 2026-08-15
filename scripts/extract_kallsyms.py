"""Try to extract kallsyms from the kernel Image for offline symbol resolution"""
import struct, os, re

KERNEL_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\kernel.Image"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(KERNEL_PATH, "rb") as f:
    data = f.read()

print(f"Kernel Image: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")

# For Android kernels, kallsyms data is typically in the kernel's data section
# The PE .data section is at VA=0x2740000, raw=0x2740000
# Let's search for kallsyms patterns in the data

# kallsyms token table: starts with specific single-char tokens
# The standard token table is sorted by token value
# Let's search for the compressed kallsyms names

# First, look for kallsyms_addresses-like pattern
# This is an array of sorted addresses (uint64 on ARM64)
# The addresses would be in the kernel text range

# Kernel text range in PE: VA 0x10000 to 0x2740000 (approx)
# So addresses would be like 0xffffffXXxxxxxxxx or similar

# Search for the kallsyms marker in the binary
# The kallsyms_names and kallsyms_addresses are typically in .rodata
# Let's search for the token table

print(f"\n=== Searching for kallsyms token table ===")
# The token table starts with specific ASCII tokens
# Standard tokens: "TtWwDdRrAaBbCcEeGgHhIiJjKkLlMmNnOoPpQqSsUuVvXxYyZz"
# followed by numbers and special chars

# Look for the pattern of consecutive single-byte tokens
# The token table is typically a series of null-terminated strings

# Actually, let's search for the kallsyms_names data
# This is a compressed table of symbol names
# The compression uses indices into the token table

# Let's look for the kallsyms_num_scores value
# This is typically stored near the token table

# Alternative: search for the kernel symbol string table
# Look for symbol names in the expected format

# Let's search for some known Android kernel symbols
android_symbols = [
    b"sys_call_table",
    b"init_task",
    b"init_cred",
    b"modprobe_path",
    b"core_pattern",
    b"inet6_protos",
]

print(f"\n=== Known symbol string locations ===")
for sym in android_symbols:
    idx = 0
    while True:
        idx = data.find(sym, idx)
        if idx < 0:
            break
        # Check if it's a null-terminated string
        if data[idx + len(sym)] == 0:
            # This could be the actual symbol entry
            # Look at the surrounding data
            ctx_before = data[max(0, idx-16):idx]
            ctx_after = data[idx+len(sym)+1:idx+len(sym)+17]
            print(f"  '{sym.decode()}' at {idx} (0x{idx:x})")
            print(f"    Before: {ctx_before.hex()}")
            print(f"    After:  {ctx_after.hex()}")
            break
        idx += 1

# Also try to find the kernel's compressed kallsyms
# The kallsyms_names uses a specific compression format
# Each symbol is stored as a sequence of token indices

# Let's search for the kallsyms marker bytes
print(f"\n=== Searching for kallsyms num_scores ===")

# The num_scores is typically a uint32 value
# It's followed by the kallsyms_names array
# Look for the pattern: a small uint32 followed by compressed data

# Search for the kallsyms token table
# Tokens are typically: 0x54 ('T'), 0x74 ('t'), etc.
# The token table has a specific format

# Let's search for the string "Tt" which is the start of the token table
idx = data.find(b"Tt")
if idx >= 0:
    print(f"'Tt' found at {idx} (0x{idx:x})")
    # Check if it looks like the token table
    nearby = data[idx:idx+200]
    print(f"  Nearby: {nearby[:100]}")
    # Count null bytes (tokens are null-terminated)
    null_count = nearby[:100].count(0)
    print(f"  Null bytes in first 100: {null_count}")

# One more approach: try to find the .init.data or .rodata section
# in the PE file by looking for data patterns

# The PE sections are:
# .text: raw=0x10000, size=41091072
# .data: raw=0x2740000, size=2392576

# The .data section likely contains the kernel's data (including kallsyms)
data_section = data[0x2740000:0x2740000 + 2392576]
print(f"\n=== Analyzing PE .data section ===")
print(f"Size: {len(data_section)} bytes ({len(data_section)/1024/1024:.1f} MB)")
print(f"First 32 bytes: {data_section[:32].hex()}")

# Search for kallsyms patterns in .data section
for sym in [b"kallsyms", b"Tt", b"sys_call_table"]:
    idx = data_section.find(sym)
    if idx >= 0:
        print(f"'{sym.decode(errors='replace')}' at .data + {idx} (0x{0x2740000+idx:x})")
        print(f"  Context: {data_section[max(0,idx-32):idx+len(sym)+32].hex()}")

# Also search for the kernel config in .data
# Many Android kernels have the config embedded
print(f"\n=== Searching for CONFIG_ in .data section ===")
config_idx = data_section.find(b"CONFIG_ARM64")
if config_idx >= 0:
    print(f"CONFIG_ARM64 at .data + {config_idx}")
    end = data_section.find(b"\x00\x00\x00\x00", config_idx + 1000)
    config_text = data_section[config_idx:end].decode('latin-1', errors='replace')
    for key in ["CONFIG_FUTEX_PI", "CONFIG_KALLSYMS", "CONFIG_RT_MUTEXES",
                "CONFIG_KASLR", "CONFIG_RANDOMIZE_BASE"]:
        if key in config_text:
            # Find the value
            start = config_text.find(key)
            line_end = config_text.find("\n", start)
            if line_end < 0: line_end = start + 80
            print(f"  {config_text[start:line_end]}")

print("\nDone!")