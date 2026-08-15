"""Debug kernel gzip decompression - find exact error location"""
import struct, gzip, zlib, io, os

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]

print(f"Kernel size: {len(kernel)} bytes")

# Try streaming decompression with detailed error reporting
print("\n--- Streaming decompression with error location ---")
dobj = zlib.decompressobj(wbits=15 + 16)  # gzip format
pos = 0
chunk_size = 4096
decompressed = b""
try:
    while pos < len(kernel):
        chunk = kernel[pos:pos + chunk_size]
        pos += chunk_size
        try:
            decompressed += dobj.decompress(chunk)
        except zlib.error as e:
            print(f"Error at input byte offset ~{pos - chunk_size} (0x{pos - chunk_size:x}): {e}")
            print(f"  Data around error: {kernel[pos - chunk_size:pos - chunk_size + 32].hex()}")
            # Try to find the exact byte
            dobj2 = zlib.decompressobj(wbits=15 + 16)
            for i in range(pos - chunk_size, pos):
                try:
                    dobj2.decompress(kernel[i:i+1])
                except zlib.error as e2:
                    print(f"  Exact error at byte {i} (0x{i:x}): {e2}")
                    print(f"  Data at {i}: {kernel[i:i+16].hex()}")
                    break
            break
        if dobj.eof:
            decompressed += dobj.flush()
            print(f"Success! Decompressed {len(decompressed)} bytes")
            break
    else:
        print(f"Reached end of kernel data without EOF. Decompressed so far: {len(decompressed)} bytes")
        try:
            decompressed += dobj.flush()
            print(f"After flush: {len(decompressed)} bytes")
        except Exception as e:
            print(f"Flush error: {e}")
except Exception as e:
    print(f"Unexpected error: {e}")

# Check if the kernel is actually a "broken" fat gzip with multiple members
# that need to be concatenated
print("\n--- Trying to find gzip member boundaries ---")
# Search for gzip footer pattern (last 8 bytes of each member)
# The footer is CRC32 (4 bytes) + ISIZE (4 bytes)
# But we can't easily find it without knowing the data

# Let's try to find the gzip members by looking for gzip headers
import re
# Find all gzip header positions
positions = [m.start() for m in re.finditer(b'\x1f\x8b\x08', kernel)]
print(f"Gzip headers at: {positions}")

# Try to decompress each member
for i, start in enumerate(positions):
    end = positions[i + 1] if i + 1 < len(positions) else len(kernel)
    member = kernel[start:end]
    print(f"\nMember {i}: offset {start}, size {len(member)}")
    # Try to decompress with different sizes
    for size_pct in [100, 75, 50, 25, 10, 5, 1]:
        size = len(member) * size_pct // 100
        try:
            decomp = gzip.decompress(member[:size])
            print(f"  {size_pct}% ({size} bytes): OK, {len(decomp)} bytes decompressed")
            if b"Linux version" in decomp:
                idx = decomp.find(b"Linux version")
                end2 = decomp.find(b"\n", idx)
                if end2 == -1: end2 = idx + 200
                print(f"  >> {decomp[idx:end2].decode('utf-8', errors='replace')}")
            break
        except Exception as e:
            if size_pct == 1:
                print(f"  {size_pct}% ({size} bytes): {e}")

print("\nDone")