"""Try LZ4 decompression and search for different kernel formats"""
import struct, subprocess, sys, os

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]

print(f"Kernel size: {len(kernel)} bytes")

# Install lz4
try:
    import lz4.block
except ImportError:
    print("Installing lz4...")
    subprocess.run([sys.executable, "-m", "pip", "install", "lz4"], capture_output=True)
    import lz4.block

# Try LZ4 decompression
print("\n--- Trying LZ4 ---")
try:
    decomp = lz4.block.decompress(kernel)
    print(f"LZ4 block decompressed: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        if end == -1:
            end = idx + 200
        print(f">> {decomp[idx:end].decode()}")
except Exception as e:
    print(f"LZ4 block failed: {e}")

# Try LZ4 frame decompression
try:
    decomp = lz4.frame.decompress(kernel)
    print(f"LZ4 frame decompressed: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        if end == -1:
            end = idx + 200
        print(f">> {decomp[idx:end].decode()}")
except Exception as e:
    print(f"LZ4 frame failed: {e}")

# Try zstd
try:
    import zstandard as zstd
    dctx = zstd.ZstdDecompressor()
    decomp = dctx.decompress(kernel)
    print(f"ZSTD decompressed: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        if end == -1:
            end = idx + 200
        print(f">> {decomp[idx:end].decode()}")
except Exception as e:
    print(f"ZSTD failed: {e}")

# Search for all gzip members in the boot.img
print("\n--- All gzip locations in boot.img ---")
pos = 0
while True:
    pos = boot.find(b"\x1f\x8b\x08", pos)
    if pos == -1:
        break
    if pos + 10 <= len(boot):
        flags = boot[pos + 3]
        if flags < 32:
            print(f"  offset {pos} (0x{pos:x}): flags={flags:#010b}, OS={boot[pos+9]}")
    pos += 1

# Check the raw kernel data at the beginning
print("\n--- Kernel first 128 bytes ---")
for i in range(0, 128, 16):
    line = kernel[i:i+16]
    hex_str = line.hex()
    ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in line)
    print(f"  {i:04d}: {hex_str}  {ascii_str}")

# Check if maybe the kernel is actually starting at a different offset
# Sometimes the kernel_offset is header_size, not page_size
# For v3 header, header_size is at offset 20
header_size = struct.unpack_from("<I", boot, 20)[0]
print(f"\nheader_size from v3 header: {header_size}")
if header_size != 4096:
    kernel2 = boot[header_size:header_size + kernel_size]
    print(f"Kernel at header_size ({header_size}): first 16 bytes: {kernel2[:16].hex()}")

print("\nDone")