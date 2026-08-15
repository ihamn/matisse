"""Check vendor_boot partition for kernel"""
import struct, os, gzip, lzma, zlib

EXTRACTED = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

# Check vendor_boot_full.img
vb_path = os.path.join(EXTRACTED, "vendor_boot_full.img")
if os.path.exists(vb_path):
    with open(vb_path, "rb") as f:
        vb = f.read()
    print(f"vendor_boot_full.img: {len(vb)} bytes ({len(vb)/1024/1024:.1f} MB)")
    
    # Check for ANDROID! header
    pos = vb.find(b"ANDROID!")
    if pos >= 0:
        print(f"ANDROID! at offset {pos}")
        header = vb[pos:pos+4096]
        header_version = struct.unpack_from("<I", header, 40)[0]
        print(f"Header version: {header_version}")
        
        if header_version >= 3:
            kernel_size = struct.unpack_from("<I", header, 8)[0]
            ramdisk_size = struct.unpack_from("<I", header, 12)[0]
            header_size = struct.unpack_from("<I", header, 20)[0]
            print(f"kernel_size: {kernel_size} ({kernel_size/1024/1024:.1f} MB)")
            print(f"ramdisk_size: {ramdisk_size} ({ramdisk_size/1024/1024:.1f} MB)")
            print(f"header_size: {header_size}")
        else:
            kernel_size = struct.unpack_from("<I", header, 8)[0]
            page_size = struct.unpack_from("<I", header, 36)[0]
            print(f"kernel_size: {kernel_size}, page_size: {page_size}")
    else:
        print("No ANDROID! header")
        # Search for gzip magic
        for i in range(0, min(2*1024*1024, len(vb)-2)):
            if vb[i:i+2] == b"\x1f\x8b":
                if vb[i+2] == 0x08:
                    print(f"gzip magic at offset {i}")
                    print(f"  Data: {vb[i:i+32].hex()}")
else:
    print("vendor_boot_full.img not found")

# Also check boot.img
boot_path = os.path.join(EXTRACTED, "boot.img")
if os.path.exists(boot_path):
    with open(boot_path, "rb") as f:
        boot = f.read()
    print(f"\nboot.img: {len(boot)} bytes ({len(boot)/1024/1024:.1f} MB)")
    pos = boot.find(b"ANDROID!")
    if pos >= 0:
        print(f"ANDROID! at offset {pos}")
    else:
        print("No ANDROID! header")

# Try different decompression approaches on the kernel from boot_correct.img
print("\n\n=== Trying different decompression on kernel ===")
boot_correct = os.path.join(EXTRACTED, "boot_correct.img")
with open(boot_correct, "rb") as f:
    boot = f.read()

# Extract kernel data
kernel_size = 19610141
kernel_data = boot[4096:4096 + kernel_size]

# Try brotli
print("\n--- Brotli ---")
try:
    import brotli
    decomp = brotli.decompress(kernel_data)
    print(f"Brotli OK: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        print(f">> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
except ImportError:
    print("brotli library not available")
except Exception as e:
    print(f"Brotli failed: {str(e)[:80]}")

# Try zstd
print("\n--- Zstd ---")
try:
    import zstandard as zstd
    dctx = zstd.ZstdDecompressor()
    decomp = dctx.decompress(kernel_data)
    print(f"Zstd OK: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        print(f">> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
except ImportError:
    print("zstandard library not available")
except Exception as e:
    print(f"Zstd failed: {str(e)[:80]}")

# Try raw gzip (not using Python's gzip module, but manual decompression)
print("\n--- Manual gzip decompression ---")
# The gzip header is 10 bytes, then deflate data
# Try to decompress using zlib with different approaches
import zlib

# Approach 1: skip 10 bytes, use raw deflate
print("\nApproach 1: skip 10 bytes, raw deflate (-15)")
try:
    dobj = zlib.decompressobj(-15)
    # Process in chunks to handle large data
    result = bytearray()
    pos = 10  # skip gzip header
    chunk_size = 1024 * 1024
    while pos < len(kernel_data):
        chunk = kernel_data[pos:pos + chunk_size]
        if not chunk:
            break
        try:
            result.extend(dobj.decompress(chunk))
        except Exception as e:
            print(f"  Error at pos {pos}: {e}")
            break
        pos += chunk_size
    result.extend(dobj.flush())
    print(f"  Result: {len(result)} bytes")
    print(f"  First 50 bytes: {result[:50]}")
    if b"Linux version" in result:
        idx = result.find(b"Linux version")
        print(f"  >> {result[idx:idx+200].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"  Failed: {e}")

# Approach 2: try to find the actual gzip end and decompress just that
print("\nApproach 2: find gzip trailer and decompress")
# A gzip stream ends with CRC32 (4 bytes) + ISIZE (4 bytes)
# Try to find the gzip magic and decompress from there
for i in range(0, min(4096, len(kernel_data))):
    if kernel_data[i:i+2] == b"\x1f\x8b":
        # Try to decompress from this point
        try:
            decomp = gzip.decompress(kernel_data[i:])
            print(f"  Found gzip at {i}, decompressed: {len(decomp)} bytes")
            if b"Linux version" in decomp:
                idx = decomp.find(b"Linux version")
                print(f"  >> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
        except Exception as e:
            print(f"  gzip at {i} failed: {str(e)[:80]}")

# Approach 3: Try decompressing with wbits=31 (gzip auto) but process in chunks
print("\nApproach 3: wbits=31 (auto-detect gzip/deflate)")
try:
    dobj = zlib.decompressobj(31)
    result = bytearray()
    pos = 0
    chunk_size = 1024 * 1024
    while pos < len(kernel_data):
        chunk = kernel_data[pos:pos + chunk_size]
        if not chunk:
            break
        try:
            result.extend(dobj.decompress(chunk))
        except Exception as e:
            print(f"  Error at pos {pos}: {e}")
            break
        pos += chunk_size
    result.extend(dobj.flush())
    print(f"  Result: {len(result)} bytes")
    print(f"  First 50 bytes: {result[:50]}")
    if b"Linux version" in result:
        idx = result.find(b"Linux version")
        print(f"  >> {result[idx:idx+200].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"  Failed: {e}")

print("\nDone!")