"""Analyze boot image header and find kernel correctly"""
import struct, os

BOOT_IMG = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_correct.img"

with open(BOOT_IMG, "rb") as f:
    boot = f.read()

print(f"Boot image size: {len(boot)} bytes ({len(boot)/1024/1024:.1f} MB)")

# Dump first 256 bytes of header
print("\n=== Header hex dump (first 256 bytes) ===")
for i in range(0, 256, 16):
    hex_str = " ".join(f"{boot[i+j]:02x}" for j in range(16))
    ascii_str = "".join(chr(boot[i+j]) if 32 <= boot[i+j] < 127 else "." for j in range(16))
    print(f"  {i:04x}: {hex_str}  {ascii_str}")

# Parse v0-v3 style header
print("\n=== V0-V3 Header Parsing ===")
magic = boot[0:8]
print(f"magic: {magic}")
kernel_size_v3 = struct.unpack_from("<I", boot, 8)[0]
kernel_addr = struct.unpack_from("<I", boot, 12)[0]
ramdisk_size_v3 = struct.unpack_from("<I", boot, 16)[0]
ramdisk_addr = struct.unpack_from("<I", boot, 20)[0]
second_size = struct.unpack_from("<I", boot, 24)[0]
second_addr = struct.unpack_from("<I", boot, 28)[0]
tags_addr = struct.unpack_from("<I", boot, 32)[0]
page_size_v3 = struct.unpack_from("<I", boot, 36)[0]
header_version = struct.unpack_from("<I", boot, 40)[0]
os_version = struct.unpack_from("<I", boot, 44)[0]

print(f"kernel_size (v3 offset 8): {kernel_size_v3} ({kernel_size_v3/1024/1024:.1f} MB)")
print(f"kernel_addr: 0x{kernel_addr:08x}")
print(f"ramdisk_size: {ramdisk_size_v3} ({ramdisk_size_v3/1024/1024:.1f} MB)")
print(f"ramdisk_addr: 0x{ramdisk_addr:08x}")
print(f"second_size: {second_size}")
print(f"second_addr: 0x{second_addr:08x}")
print(f"tags_addr: 0x{tags_addr:08x}")
print(f"page_size: {page_size_v3}")
print(f"header_version: {header_version}")
print(f"os_version: {os_version}")

# V4 header: kernel_size is at offset 8, ramdisk_size at offset 12
# but the format is different
# Actually, for v4:
# offset 0: magic (8 bytes)
# offset 8: kernel_size (4 bytes)
# offset 12: ramdisk_size (not kernel_addr for v4)
# (v4 removed kernel_addr, ramdisk_addr, second_addr, tags_addr)
print(f"\n=== V4 Interpretation ===")
kernel_size_v4 = struct.unpack_from("<I", boot, 8)[0]
ramdisk_size_v4 = struct.unpack_from("<I", boot, 12)[0]
print(f"kernel_size: {kernel_size_v4} ({kernel_size_v4/1024/1024:.1f} MB)")
print(f"ramdisk_size: {ramdisk_size_v4} ({ramdisk_size_v4/1024/1024:.1f} MB)")

# For v4, the page size is fixed at 4096
page_size = 4096
kernel_offset = page_size  # kernel starts after 1 page

print(f"\n=== Kernel Search ===")
print(f"Expected kernel offset: {kernel_offset} (page_size)")

# Check what's at the expected kernel offset
kdata = boot[kernel_offset:kernel_offset + 64]
print(f"\nData at offset {kernel_offset}: {kdata[:64].hex()}")
print(f"As text: {kdata[:64]}")

# Check for gzip magic
if kdata[:2] == b"\x1f\x8b":
    print("GZIP MAGIC FOUND!")
    # Parse gzip header
    flags = kdata[3]
    mtime = struct.unpack_from("<I", kdata, 4)[0]
    xfl = kdata[8]
    os_type = kdata[9]
    print(f"  compression method: {kdata[2]}")
    print(f"  flags: 0x{flags:02x}")
    print(f"  mtime: {mtime}")
    print(f"  extra flags: {xfl}")
    print(f"  OS: {os_type}")
    
    # If FNAME flag is set, there's a filename
    if flags & 0x08:
        hdr_pos = 10
        fname_end = kdata.find(b"\x00", hdr_pos)
        if fname_end > 0:
            fname = kdata[hdr_pos:fname_end]
            print(f"  filename: {fname}")
            hdr_pos = fname_end + 1
        else:
            hdr_pos = 10
    else:
        hdr_pos = 10
    
    print(f"  Deflate data starts at gzip offset: {hdr_pos}")
    print(f"  Kernel data at offset {kernel_offset + hdr_pos}")

# Scan for all gzip magic bytes in the first 2MB
print("\n=== Scanning for gzip magic bytes in first 2MB ===")
for i in range(0, min(2*1024*1024, len(boot)-2)):
    if boot[i:i+2] == b"\x1f\x8b":
        # Check if it looks like a valid gzip header
        cm = boot[i+2]
        if cm == 0x08:  # deflate
            print(f"  Offset {i} (0x{i:x}): 1f8b08 - valid gzip header")
            # Check next 20 bytes
            print(f"    Data: {boot[i:i+32].hex()}")
        elif cm in [0x01, 0x02, 0x03, 0x04, 0x08]:
            print(f"  Offset {i} (0x{i:x}): 1f8b{cm:02x} - CM={cm}")

# Also scan for XZ magic
print("\n=== Scanning for XZ magic ===")
for i in range(0, min(2*1024*1024, len(boot)-6)):
    if boot[i:i+6] == b"\xfd\x37\x7a\x58\x5a\x00":
        print(f"  Offset {i} (0x{i:x}): XZ magic found!")
        print(f"    Data: {boot[i:i+32].hex()}")

# Also scan for bzip2 magic
print("\n=== Scanning for bzip2 magic ===")
for i in range(0, min(2*1024*1024, len(boot)-3)):
    if boot[i:i+3] == b"BZh":
        print(f"  Offset {i} (0x{i:x}): BZh found!")
        print(f"    Data: {boot[i:i+32].hex()}")

# Check if kernel might be at a different offset
# Try to find "Linux version" string in raw boot image
print("\n=== Searching for 'Linux version' in raw boot ===")
pos = boot.find(b"Linux version")
if pos >= 0:
    print(f"  Found at offset {pos}: {boot[pos:pos+200]}")
else:
    print("  Not found in raw boot")

print("\nDone!")