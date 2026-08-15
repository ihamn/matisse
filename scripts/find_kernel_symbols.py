"""Extract the actual Linux kernel Image from the PE/EFI wrapper and find symbols"""
import struct, os, gzip, zlib, re

KERNEL_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\kernel.Image"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(KERNEL_PATH, "rb") as f:
    data = f.read()

print(f"Total kernel data: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")

# Parse PE header
pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
print(f"PE offset: 0x{pe_offset:x}")

pe_sig = data[pe_offset:pe_offset+4]
print(f"PE sig: {pe_sig}")

# COFF header
machine = struct.unpack_from("<H", data, pe_offset+4)[0]
num_sections = struct.unpack_from("<H", data, pe_offset+6)[0]
size_opt_header = struct.unpack_from("<H", data, pe_offset+20)[0]
print(f"Machine: 0x{machine:04x}")
print(f"Sections: {num_sections}")
print(f"Opt header size: {size_opt_header}")

# Optional header offset
opt_header_offset = pe_offset + 24

# PE32+ magic
magic = struct.unpack_from("<H", data, opt_header_offset)[0]
print(f"Optional header magic: 0x{magic:04x}")

# SizeOfImage
size_of_image = struct.unpack_from("<I", data, opt_header_offset+56)[0]
print(f"SizeOfImage: {size_of_image} ({size_of_image/1024/1024:.1f} MB)")

# Section headers
section_offset = opt_header_offset + size_opt_header
print(f"\n=== PE Sections ===")
for i in range(num_sections):
    sec_off = section_offset + i * 40
    name = data[sec_off:sec_off+8].rstrip(b'\x00').decode('ascii', errors='replace')
    virtual_size = struct.unpack_from("<I", data, sec_off+8)[0]
    virtual_addr = struct.unpack_from("<I", data, sec_off+12)[0]
    raw_size = struct.unpack_from("<I", data, sec_off+16)[0]
    raw_offset = struct.unpack_from("<I", data, sec_off+20)[0]
    print(f"  [{i}] {name:12s} VS={virtual_size:10d} VA=0x{virtual_addr:08x} RS={raw_size:10d} RO=0x{raw_offset:08x}")

# Now search for the ARM64 kernel Image within the data
# The kernel Image is typically embedded in the .linux section or appended
# Let's search for the ARM64 kernel Image header pattern

print(f"\n=== Searching for ARM64 Kernel Image ===")

# ARM64 kernel Image starts with:
# 0x14000008 (b stext) or variants
# followed by specific patterns

# Look for the standard ARM64 kernel header
# Offset 0x00: b stext (0x14000008)
# Offset 0x04: 0x00000000 (padding)  
# Offset 0x08: image load offset (little-endian, typically 0x00080000)
# Offset 0x0C: 0x00000000 (image size, set by bootloader)

# Try various patterns
patterns = [
    (b"\x08\x00\x00\x14", "ARM64 b #0x8 (LE)"),
    (b"\x14\x00\x00\x08", "ARM64 b #0x8 (BE)"),
]

# Also look for the kernel directly
# Search for branch instruction patterns
for i in range(0, len(data) - 64, 4):
    instr = struct.unpack_from("<I", data, i)[0]
    # Check for unconditional branch (b/bl)
    if (instr & 0xFC000000) == 0x14000000:
        # Check if next 4 bytes are 0 (padding)
        next_word = struct.unpack_from("<I", data, i+4)[0]
        if next_word == 0:
            # Check for image load offset (typically 0x00080000 or 0x00000000)
            third_word = struct.unpack_from("<I", data, i+8)[0]
            if third_word in [0x00080000, 0x00000000, 0x00400000, 0x00800000]:
                fourth_word = struct.unpack_from("<I", data, i+12)[0]
                if fourth_word in [0, 0x00080000]:
                    print(f"\n  Potential kernel Image at offset {i} (0x{i:x})")
                    print(f"    Instructions: {data[i:i+16].hex()}")
                    print(f"    b offset: {instr & 0x03FFFFFF}")
                    print(f"    load offset: 0x{third_word:08x}")

# Also search for the Linux banner string
print(f"\n=== Searching for Linux version strings ===")
for m in re.finditer(rb'Linux version \d+\.\d+\.\d+', data):
    end = data.find(b"\n", m.start())
    if end < 0: end = m.start() + 300
    print(f"  Offset {m.start()}: {data[m.start():end].decode('utf-8', errors='replace')[:200]}")

# Search for common kernel symbols
print(f"\n=== Searching for key kernel function strings ===")
# These are the strings we might find in the kernel symbol table or kallsyms
key_symbols = [
    b"prepare_kernel_cred",
    b"commit_creds",
    b"prctl",
    b"modprobe_path",
    b"core_pattern",
    b"poweroff_cmd",
    b"selinux",
    b"init_cred",
    b"run_cmd",
    b"do_execve",
    b"kernel_init",
    b"futex",
    b"rt_mutex",
]

for sym in key_symbols:
    # Search for the symbol as a string in the kernel
    idx = data.find(sym)
    if idx >= 0:
        print(f"  '{sym.decode()}' found at offset {idx} (0x{idx:x})")
        # Show context
        ctx = data[max(0,idx-16):idx+len(sym)+16]
        print(f"    Context: {ctx.hex()}")

# Extract the actual kernel Image
# The kernel Image is typically in the .linux section or at a specific offset
# For ARM64 EFI, the kernel Image is often at offset 0x10000 or similar

# Let's check the .linux section if it exists
print(f"\n=== Looking for .linux section ===")
for i in range(num_sections):
    sec_off = section_offset + i * 40
    name = data[sec_off:sec_off+8].rstrip(b'\x00').decode('ascii', errors='replace')
    if 'linux' in name.lower() or 'kernel' in name.lower() or 'text' in name.lower():
        virtual_addr = struct.unpack_from("<I", data, sec_off+12)[0]
        raw_offset = struct.unpack_from("<I", data, sec_off+20)[0]
        raw_size = struct.unpack_from("<I", data, sec_off+16)[0]
        print(f"  Section '{name}': VA=0x{virtual_addr:x}, raw=0x{raw_offset:x}, size={raw_size}")
        
        # Extract section data
        section_data = data[raw_offset:raw_offset+raw_size]
        print(f"    First 32 bytes: {section_data[:32].hex()}")
        
        # Check for kernel Image header
        if section_data[:4] == b"\x08\x00\x00\x14" or section_data[:4] == b"\x14\x00\x00\x08":
            print(f"    *** ARM64 kernel Image found in this section! ***")
            kernel_out = os.path.join(OUTPUT_DIR, "kernel_linux.Image")
            with open(kernel_out, "wb") as f:
                f.write(section_data)
            print(f"    Saved to: {kernel_out}")

# Also check the data after SizeOfImage
print(f"\n=== Data after PE SizeOfImage ({size_of_image}) ===")
if len(data) > size_of_image:
    remaining = data[size_of_image:]
    print(f"  Size: {len(remaining)} bytes ({len(remaining)/1024/1024:.1f} MB)")
    print(f"  First 64 bytes: {remaining[:64].hex()}")
    
    # Check if this is the kernel Image
    if remaining[:4] == b"\x08\x00\x00\x14" or remaining[:4] == b"\x14\x00\x00\x08":
        print("  *** This is the ARM64 kernel Image! ***")
        kernel_out = os.path.join(OUTPUT_DIR, "kernel_linux.Image")
        with open(kernel_out, "wb") as f:
            f.write(remaining)
        print(f"  Saved to: {kernel_out}")
    
    # Check for gzip magic
    if remaining[:2] == b"\x1f\x8b":
        print("  gzip compressed!")
        try:
            decomp = gzip.decompress(remaining)
            print(f"  Decompressed: {len(decomp)} bytes")
            if decomp[:4] == b"\x08\x00\x00\x14":
                print("  *** Decompressed data is ARM64 kernel Image! ***")
                kernel_out = os.path.join(OUTPUT_DIR, "kernel_linux.Image")
                with open(kernel_out, "wb") as f:
                    f.write(decomp)
                print(f"  Saved to: {kernel_out}")
        except Exception as e:
            print(f"  gzip decompress failed: {e}")

print("\nDone!")