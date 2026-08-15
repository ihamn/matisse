"""Byte-by-byte deflate decompression to find first error"""
import struct, zlib, gzip, os

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]

# Gzip header is 10 bytes
print("Gzip header:")
print(f"  Magic: {kernel[0:2]}")
print(f"  Method: {kernel[2]}")
print(f"  Flags: {kernel[3]:#010b}")
print(f"  Mtime: {struct.unpack_from('<I', kernel, 4)[0]}")
print(f"  Xfl: {kernel[8]}")
print(f"  OS: {kernel[9]}")

# Deflate starts at byte 10
deflate_data = kernel[10:]
print(f"\nDeflate data size: {len(deflate_data)} bytes")
print(f"First 32 bytes of deflate: {deflate_data[:32].hex()}")

# Try byte-by-byte decompression
print("\n=== Byte-by-byte raw deflate decompression ===")
dobj = zlib.decompressobj(-15)  # raw deflate
for i in range(min(1000, len(deflate_data))):
    try:
        result = dobj.decompress(deflate_data[i:i+1])
        if result:
            print(f"Byte {i}: produced {len(result)} bytes of output")
            if i < 20:
                print(f"  Output: {result[:50].hex()}")
        if dobj.eof:
            print(f"EOF at byte {i}")
            break
    except zlib.error as e:
        print(f"Error at byte {i}: {e}")
        print(f"  Data: {deflate_data[i:i+16].hex()}")
        print(f"  Prev 16 bytes: {deflate_data[max(0,i-16):i].hex()}")
        break
else:
    print(f"No error in first 1000 bytes")

# Try with different wbits
print("\n=== Trying different wbits ===")
for wbits in [-15, 15, 15+16, -8, 8, 31, 47]:
    try:
        dobj = zlib.decompressobj(wbits)
        decomp = dobj.decompress(deflate_data[:100000])
        print(f"wbits={wbits}: OK, {len(decomp)} bytes")
        print(f"  First: {decomp[:50]}")
        break
    except Exception as e:
        print(f"wbits={wbits}: {str(e)[:80]}")

# Check: maybe the kernel is not compressed with gzip but with something else
# and the 1f 8b at the beginning is just coincidence
# Let me check if the data at kernel offset 0 looks like an ARM64 Image
# ARM64 kernel Image starts with a branch instruction
# For an uncompressed Image, the first bytes should be:
# little-endian: 0x14000000 (branch) or similar
print(f"\nFirst 8 bytes as little-endian uint32 pairs:")
for i in range(0, 8, 4):
    val = struct.unpack_from("<I", kernel, i)[0]
    print(f"  [{i}:{i+4}]: {val:#010x}")

print(f"\nFirst 8 bytes as big-endian uint32 pairs:")
for i in range(0, 8, 4):
    val = struct.unpack_from(">I", kernel, i)[0]
    print(f"  [{i}:{i+4}]: {val:#010x}")

# Check if maybe the kernel is from vendor_boot
print("\n=== Checking vendor_boot ===")
vendor_boot = open(os.path.join(OUTPUT_DIR, "vendor_boot_full.img"), "rb").read()
print(f"vendor_boot size: {len(vendor_boot)} bytes")
# Search for gzip in vendor_boot
pos = 0
while True:
    pos = vendor_boot.find(b"\x1f\x8b\x08", pos)
    if pos == -1:
        break
    print(f"  gzip at offset {pos} (0x{pos:x})")
    if pos + 10 <= len(vendor_boot):
        try:
            decomp = gzip.decompress(vendor_boot[pos:pos + 20*1024*1024])
            print(f"    Decompressed: {len(decomp)} bytes")
            if b"Linux version" in decomp:
                idx = decomp.find(b"Linux version")
                end = decomp.find(b"\n", idx)
                if end == -1:
                    end = idx + 200
                print(f"    >> {decomp[idx:end].decode('utf-8', errors='replace')}")
        except Exception as e:
            print(f"    Failed: {str(e)[:80]}")
    pos += 1

print("\nDone")