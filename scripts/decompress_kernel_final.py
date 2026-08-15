"""Decompress entire kernel with raw deflate and find version"""
import struct, zlib, os

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]

# Skip 10-byte gzip header, decompress raw deflate
deflate_data = kernel[10:]

print(f"Deflate data: {len(deflate_data)} bytes")
print("Decompressing...")

dobj = zlib.decompressobj(-15)  # raw deflate
decompressed = dobj.decompress(deflate_data)
decompressed += dobj.flush()

print(f"Decompressed: {len(decompressed)} bytes ({len(decompressed)/1024/1024:.1f} MB)")
print(f"First 128 bytes:")
for i in range(0, 128, 16):
    line = decompressed[i:i+16]
    hex_str = line.hex()
    ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in line)
    print(f"  {i:04d}: {hex_str}  {ascii_str}")

# Search for kernel version
if b"Linux version" in decompressed:
    idx = decompressed.find(b"Linux version")
    end = decompressed.find(b"\n", idx)
    if end == -1:
        end = idx + 300
    print(f"\n=== Kernel Version ===")
    print(f">> {decompressed[idx:end].decode('utf-8', errors='replace')}")

# Search for additional version info
print("\n=== Additional Info ===")
for pattern in [b"Linux version", b"GCC:", b"clang version", b"Android", b"PREEMPT", b"SMP"]:
    if pattern in decompressed:
        idx = decompressed.find(pattern)
        end = decompressed.find(b"\n", idx)
        if end == -1:
            end = idx + 200
        print(f">> {decompressed[idx:end].decode('utf-8', errors='replace')}")

# Save
outpath = os.path.join(OUTPUT_DIR, "kernel.Image")
with open(outpath, "wb") as f:
    f.write(decompressed)
print(f"\nSaved kernel Image to {outpath}")

print("\nDone!")