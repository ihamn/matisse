"""Decompress kernel from boot_correct.img using raw deflate"""
import struct, zlib, os

BOOT_IMG = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_correct.img"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(BOOT_IMG, "rb") as f:
    boot = f.read()

# Parse ANDROID! header
pos = boot.find(b"ANDROID!")
if pos < 0:
    print("ERROR: ANDROID! not found")
    exit(1)

header = boot[pos:pos+4096]
header_version = struct.unpack_from("<I", header, 40)[0]
print(f"Header version: {header_version}")

if header_version >= 4:
    kernel_size = struct.unpack_from("<I", header, 8)[0]
    page_size = 4096
else:
    kernel_size = struct.unpack_from("<I", header, 8)[0]
    page_size = struct.unpack_from("<I", header, 36)[0]

print(f"kernel_size = {kernel_size} ({kernel_size/1024/1024:.1f} MB)")
print(f"page_size = {page_size}")

kernel_offset = page_size
kernel_data = boot[kernel_offset:kernel_offset + kernel_size]
print(f"Kernel at offset {kernel_offset}, size {len(kernel_data)}")
print(f"Kernel first 20 bytes: {kernel_data[:20].hex()}")

# The kernel starts with gzip magic 1f8b but gzip.decompress fails
# with "invalid code lengths set". This means the kernel is raw deflate
# with a gzip header. Try raw deflate first.

print("\n--- Trying raw deflate (zlib wbits=-15) ---")
try:
    # Skip the 10-byte gzip header
    deflate_data = kernel_data[10:]
    dobj = zlib.decompressobj(-15)  # raw deflate
    decompressed = dobj.decompress(deflate_data)
    decompressed += dobj.flush()
    print(f"SUCCESS! Decompressed: {len(decompressed)} bytes ({len(decompressed)/1024/1024:.1f} MB)")
    
    # Search for kernel version
    if b"Linux version" in decompressed:
        idx = decompressed.find(b"Linux version")
        end = decompressed.find(b"\n", idx)
        if end == -1:
            end = idx + 300
        version_str = decompressed[idx:end].decode('utf-8', errors='replace')
        print(f"\n>> {version_str}")
    
    # Save decompressed kernel
    outpath = os.path.join(OUTPUT_DIR, "kernel.Image")
    with open(outpath, "wb") as f:
        f.write(decompressed)
    print(f"\nSaved kernel Image to: {outpath}")
    
except Exception as e:
    print(f"Raw deflate failed: {e}")
    
    # Try with different wbits
    print("\n--- Trying different wbits ---")
    for wbits in [-15, -8, 15, 15+16, 31, 47]:
        try:
            dobj = zlib.decompressobj(wbits)
            decomp = dobj.decompress(kernel_data[:200000])
            print(f"wbits={wbits}: OK, {len(decomp)} bytes, first: {decomp[:50]}")
        except Exception as e2:
            print(f"wbits={wbits}: {str(e2)[:80]}")

# Also try: maybe the kernel is not gzip at all, maybe it's XZ/LZMA
print("\n--- Trying XZ/LZMA ---")
try:
    import lzma
    decomp = lzma.decompress(kernel_data)
    print(f"XZ OK: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        if end == -1: end = idx + 300
        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"XZ failed: {str(e)[:80]}")

# Try LZ4
print("\n--- Trying LZ4 ---")
try:
    import lz4.block
    decomp = lz4.block.decompress(kernel_data)
    print(f"LZ4 OK: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"LZ4 failed: {str(e)[:80]}")

print("\nDone!")