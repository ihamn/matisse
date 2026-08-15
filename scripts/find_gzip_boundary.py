"""Check if gzip member boundary is at Op 0/Op 1 transition"""
import struct, gzip, os

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]

# Error at kernel offset 2093056 (boot offset 2097152 = Op 0/Op 1 boundary)
# Check if this is a gzip member boundary
# gzip footer: CRC32 (4 bytes) + ISIZE (4 bytes) = last 8 bytes of member

# Test various possible member endings
print("=== Checking gzip member boundaries ===")
for end_offset in [2093056, 2093055, 2093054, 2093053, 2093052, 2093051, 2093050, 2093049, 2093048]:
    member = kernel[0:end_offset]
    try:
        decomp = gzip.decompress(member)
        print(f"  Member ending at {end_offset} ({len(member)} bytes): OK, {len(decomp)} bytes decompressed")
        if b"Linux version" in decomp:
            idx = decomp.find(b"Linux version")
            end = decomp.find(b"\n", idx)
            if end == -1:
                end = idx + 200
            print(f"    >> {decomp[idx:end].decode('utf-8', errors='replace')}")
        break
    except Exception as e:
        print(f"  Member ending at {end_offset}: {str(e)[:80]}")

# Also try progressively smaller chunks of the first member
print("\n=== Trying progressive decompression of member 1 ===")
for size in range(2093056, 0, -100000):
    try:
        decomp = gzip.decompress(kernel[:size])
        print(f"  Size {size}: OK, {len(decomp)} bytes")
        if b"Linux version" in decomp:
            idx = decomp.find(b"Linux version")
            end = decomp.find(b"\n", idx)
            if end == -1:
                end = idx + 200
            print(f"    >> {decomp[idx:end].decode('utf-8', errors='replace')}")
        break
    except Exception as e:
        if size <= 100000:
            print(f"  Size {size}: {str(e)[:80]}")

# Check if the kernel might be corrupted at a different point
# Let's try to find where the first valid gzip data ends
print("\n=== Binary search for valid gzip end ===")
lo, hi = 0, 2093056
while lo < hi:
    mid = (lo + hi + 1) // 2
    try:
        gzip.decompress(kernel[:mid])
        lo = mid
    except:
        hi = mid - 1

print(f"Last valid prefix: {lo} bytes")
if lo > 0:
    decomp = gzip.decompress(kernel[:lo])
    print(f"Decompressed: {len(decomp)} bytes")
    print(f"First 200 chars: {decomp[:200]}")

print("\nDone")