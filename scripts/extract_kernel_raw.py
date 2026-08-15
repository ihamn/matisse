"""Extract raw kernel data from boot_correct.img and try various decompression methods"""
import struct, os, zlib, gzip, lzma

BOOT_IMG = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_correct.img"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(BOOT_IMG, "rb") as f:
    boot = f.read()

# Parse header
header = boot[:4096]
kernel_size = struct.unpack_from("<I", header, 8)[0]
page_size = 4096

print(f"kernel_size = {kernel_size} ({kernel_size/1024/1024:.1f} MB)")

kernel_offset = page_size
kernel_data = boot[kernel_offset:kernel_offset + kernel_size]

# Save raw kernel
raw_path = os.path.join(OUTPUT_DIR, "kernel.raw.gz")
with open(raw_path, "wb") as f:
    f.write(kernel_data)
print(f"Saved raw kernel to: {raw_path}")

# Check the data around the failure point
# The decompression fails at position 1048586 in the compressed data
# That's boot offset 4096 + 10 + 1048586 = 1052692
fail_offset = 1052692
print(f"\nData at failure point (offset {fail_offset}):")
nearby = kernel_data[fail_offset-32:fail_offset+64]
for i in range(0, len(nearby), 16):
    hex_str = " ".join(f"{nearby[i+j]:02x}" for j in range(min(16, len(nearby)-i)))
    print(f"  {hex_str}")

# Check if there's a block boundary issue
# The boot image is reconstructed from operations. Let's check block boundaries
# near the failure point.
# Block 1052692 / 4096 = block 257
block = 1052692 // 4096
print(f"\nFailure at block {block}, offset within block: {1052692 % 4096}")
print(f"Block {block} is in Op 0 (blocks 0-511)")

# The XZ decompressed data for Op 0 is 2MB. Let's verify the data at the failure point
# is correct by checking the XZ decompressed output directly.

# Let me try a completely different approach: try to decompress with pigz or gzip system command
# But first, let me try to find the actual kernel Image by looking for kernel magic bytes

# Linux kernel Image magic bytes
# ARM64 kernel Image starts with specific bytes
# Let me try to scan for patterns

# Try to decompress with different strategies
print("\n\n=== Strategy 1: Try to decompress as concatenated gzip streams ===")
# Some kernels are compressed with multiple gzip members
try:
    result = bytearray()
    pos = 0
    while pos < len(kernel_data):
        # Try to decompress from current position
        if kernel_data[pos:pos+2] == b"\x1f\x8b":
            try:
                # Use gzip module to decompress one member
                buf = kernel_data[pos:]
                decomp = gzip.decompress(buf)
                result.extend(decomp)
                print(f"  Decompressed gzip member at {pos}: {len(decomp)} bytes")
                # Find where this member ends
                # gzip.decompress consumes the entire buffer, we need to find how many bytes were consumed
                # This is tricky with Python's gzip module
                break  # For now, just try once
            except Exception as e:
                print(f"  gzip at {pos} failed: {e}")
                break
        pos += 1
    if result:
        print(f"  Total: {len(result)} bytes")
        print(f"  First 50: {result[:50]}")
except Exception as e:
    print(f"  Failed: {e}")

print("\n\n=== Strategy 2: Try deflate without the gzip header, process in 64KB chunks ===")
# Maybe the issue is with the chunk size
try:
    dobj = zlib.decompressobj(-15)  # raw deflate
    result = bytearray()
    # Skip 10-byte gzip header
    data = kernel_data[10:]
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
            print(f"  Decompressed so far: {len(result)} bytes")
            break
        pos += chunk_size
    try:
        result.extend(dobj.flush())
    except Exception as e:
        print(f"  Flush error: {e}")
    print(f"  Result: {len(result)} bytes")
    print(f"  First 50: {result[:50]}")
    if b"Linux version" in result:
        idx = result.find(b"Linux version")
        print(f"  >> {result[idx:idx+200].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"  Failed: {e}")

print("\n\n=== Strategy 3: Try to find the actual kernel Image in the boot image ===")
# The kernel might be at a different offset
# Let's search for ARM64 Linux kernel magic
# ARM64 kernel Image starts with: 0x14000008 (uncompressed) or specific patterns
# Actually, let's search for the string "Linux version" in the entire boot image
# after trying to decompress every gzip-like chunk

# Let's also check: is the kernel actually at a different offset?
# Maybe the kernel_size is correct but the kernel starts at a different position
for offset in range(0, min(65536, len(boot)), 4096):
    if boot[offset:offset+2] == b"\x1f\x8b":
        if boot[offset+2] == 0x08:
            print(f"  gzip magic at offset {offset}")
            try:
                decomp = gzip.decompress(boot[offset:])
                print(f"    Decompressed: {len(decomp)} bytes")
                print(f"    First 32: {decomp[:32].hex()}")
                if b"Linux version" in decomp:
                    idx = decomp.find(b"Linux version")
                    print(f"    >> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
            except Exception as e:
                print(f"    Failed: {str(e)[:80]}")

# Also check for XZ magic
for offset in range(0, min(65536, len(boot)), 4096):
    if boot[offset:offset+6] == b"\xfd\x37\x7a\x58\x5a\x00":
        print(f"  XZ magic at offset {offset}")
        try:
            decomp = lzma.decompress(boot[offset:])
            print(f"    Decompressed: {len(decomp)} bytes")
            print(f"    First 32: {decomp[:32].hex()}")
            if b"Linux version" in decomp:
                idx = decomp.find(b"Linux version")
                print(f"    >> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
        except Exception as e:
            print(f"    Failed: {str(e)[:80]}")

print("\nDone!")