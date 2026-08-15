"""Analyze the partially decompressed kernel data"""
import struct, os, zlib

BOOT_IMG = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_correct.img"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(BOOT_IMG, "rb") as f:
    boot = f.read()

kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel_data = boot[4096:4096 + kernel_size]

# Decompress as much as possible
print("Decompressing kernel data...")
dobj = zlib.decompressobj(-15)  # raw deflate
result = bytearray()
data = kernel_data[10:]  # skip gzip header
chunk_size = 65536
pos = 0
while pos < len(data):
    chunk = data[pos:pos + chunk_size]
    if not chunk:
        break
    try:
        result.extend(dobj.decompress(chunk))
    except Exception as e:
        print(f"  Error at compressed pos {pos}: {e}")
        break
    pos += chunk_size

print(f"Decompressed: {len(result)} bytes ({len(result)/1024/1024:.1f} MB)")

# Save decompressed data
outpath = os.path.join(OUTPUT_DIR, "kernel_partial_decompressed.bin")
with open(outpath, "wb") as f:
    f.write(result)
print(f"Saved to: {outpath}")

# Analyze the MZ/PE header
print("\n=== PE Header Analysis ===")
if result[:2] == b"MZ":
    print("MZ header found - this is a PE/DOS executable!")
    
    # PE signature offset is at MZ offset 0x3C
    pe_offset = struct.unpack_from("<I", result, 0x3C)[0]
    print(f"PE signature offset: 0x{pe_offset:x} ({pe_offset})")
    
    if pe_offset < len(result):
        pe_sig = result[pe_offset:pe_offset+4]
        print(f"PE signature: {pe_sig}")
        
        if pe_sig == b"PE\x00\x00":
            print("Valid PE header!")
            
            # COFF File Header
            coff = result[pe_offset+4:pe_offset+24]
            machine = struct.unpack_from("<H", coff, 0)[0]
            num_sections = struct.unpack_from("<H", coff, 2)[0]
            size_of_optional_header = struct.unpack_from("<H", coff, 16)[0]
            
            machine_names = {
                0x014c: "x86",
                0x0200: "IA-64",
                0x8664: "x64",
                0xAA64: "ARM64",
                0x01C0: "ARM",
                0x01C2: "ARM Thumb",
                0x01C4: "ARM Thumb-2",
            }
            print(f"Machine: 0x{machine:04x} ({machine_names.get(machine, 'Unknown')})")
            print(f"Number of sections: {num_sections}")
            print(f"Size of optional header: {size_of_optional_header}")
            
            # Optional header (PE32+)
            if size_of_optional_header >= 112:  # PE32+
                opt = result[pe_offset+24:pe_offset+24+size_of_optional_header]
                magic = struct.unpack_from("<H", opt, 0)[0]
                if magic == 0x020b:  # PE32+
                    print("\nPE32+ optional header:")
                    size_of_code = struct.unpack_from("<I", opt, 4)[0]
                    size_of_image = struct.unpack_from("<I", opt, 56)[0]
                    entry_point = struct.unpack_from("<I", opt, 16)[0]
                    base_of_code = struct.unpack_from("<I", opt, 20)[0]
                    print(f"  Size of code: {size_of_code}")
                    print(f"  Size of image: {size_of_image}")
                    print(f"  Entry point: 0x{entry_point:x}")
                    print(f"  Base of code: 0x{base_of_code:x}")
                    
                    # Data directories
                    num_data_dirs = struct.unpack_from("<I", opt, 108)[0]
                    print(f"  Number of data directories: {num_data_dirs}")
                    
                    # Check for specific sections
                    for i in range(num_data_dirs):
                        dir_offset = 112 + i * 8
                        if dir_offset + 8 <= len(opt):
                            va = struct.unpack_from("<I", opt, dir_offset)[0]
                            size = struct.unpack_from("<I", opt, dir_offset + 4)[0]
                            if va > 0 or size > 0:
                                dir_names = ["Export", "Import", "Resource", "Exception", "Security", "Base Reloc", "Debug", "Architecture", "Global Ptr", "TLS", "Load Config", "Bound Import", "IAT", "Delay Import", "CLR Header", "Reserved"]
                                name = dir_names[i] if i < len(dir_names) else f"Unknown({i})"
                                if va > 0:
                                    print(f"  Data dir {i} ({name}): VA=0x{va:x}, Size={size}")
    
    # Check if this is an EFI stub
    print("\n=== Looking for Linux kernel signatures ===")
    # Search for "Linux" in the decompressed data
    linux_pos = result.find(b"Linux")
    if linux_pos >= 0:
        print(f"Found 'Linux' at offset {linux_pos}: {result[linux_pos:linux_pos+100]}")
    else:
        print("No 'Linux' string found in decompressed data")
    
    # Search for ARM64 kernel magic
    # ARM64 kernel Image starts with specific bytes
    # The actual kernel might be embedded in the PE file
    # Look for common kernel compression signatures
    for sig_name, sig_bytes in [
        ("gzip", b"\x1f\x8b\x08"),
        ("XZ", b"\xfd\x37\x7a\x58\x5a\x00"),
        ("LZ4 legacy", b"\x02\x21\x4c\x18"),
        ("LZ4", b"\x04\x22\x4d\x18"),
        ("Zstd", b"\x28\xb5\x2f\xfd"),
        ("bzip2", b"BZh"),
        ("LZMA", b"\x5d\x00\x00"),
        ("ARM64 Image magic", b"\x00\x00\x00\x14"),  # ARM64 kernel image magic (little endian)
    ]:
        pos = result.find(sig_bytes)
        if pos >= 0:
            print(f"Found {sig_name} at offset {pos} (0x{pos:x})")
            print(f"  Context: {result[pos:pos+32].hex()}")
    
else:
    print("Not a PE file")

# Also check: what if the kernel data is not compressed at all?
# Try to interpret the kernel data directly
print("\n\n=== Raw kernel data analysis ===")
print(f"First 64 bytes: {kernel_data[:64].hex()}")
print(f"  as ASCII: {kernel_data[:64]}")

# What if the kernel is just a raw Image (not compressed)?
# ARM64 Linux kernel Image starts with a branch instruction
# Check for ARM64 instruction patterns
# The first 4 bytes of an ARM64 kernel Image are typically:
# - 0x14000008 (branch to stext) or similar

# Let's also check what's at different offsets in the boot image
print("\n\n=== Boot image structure analysis ===")
# Check ramdisk location
ramdisk_size = struct.unpack_from("<I", boot, 12)[0]  # v4 ramdisk_size at offset 12
print(f"ramdisk_size: {ramdisk_size} ({ramdisk_size/1024/1024:.1f} MB)")

# Calculate ramdisk offset
kernel_end = 4096 + kernel_size
ramdisk_offset = ((kernel_end + 4095) // 4096) * 4096
print(f"Kernel offset: 4096")
print(f"Kernel end: {kernel_end}")
print(f"Ramdisk offset: {ramdisk_offset}")

# Check ramdisk data
ramdisk_data = boot[ramdisk_offset:ramdisk_offset + min(ramdisk_size, 128)]
print(f"Ramdisk first 64 bytes: {ramdisk_data[:64].hex()}")
print(f"  as ASCII: {ramdisk_data[:64]}")

# Check if ramdisk is gzip compressed
if ramdisk_data[:2] == b"\x1f\x8b":
    print("Ramdisk is gzip compressed!")
    try:
        import gzip
        decomp = gzip.decompress(boot[ramdisk_offset:ramdisk_offset + ramdisk_size])
        print(f"Ramdisk decompressed: {len(decomp)} bytes")
        # Check for cpio magic
        if decomp[:6] == b"070701":
            print("Ramdisk is cpio archive (new format)")
        elif decomp[:6] == b"070707":
            print("Ramdisk is cpio archive (old format)")
    except Exception as e:
        print(f"Ramdisk decompress failed: {e}")

print("\nDone!")