"""Try multiple decompression methods on kernel"""
import struct, subprocess, os, gzip, lzma, bz2

OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

boot = open(os.path.join(OUTPUT_DIR, "boot_correct.img"), "rb").read()
kernel_size = struct.unpack_from("<I", boot, 8)[0]
kernel = boot[4096:4096 + kernel_size]
print(f"Kernel size: {len(kernel)} bytes ({len(kernel)/1024/1024:.1f} MB)")

# Save for external tools
with open(os.path.join(OUTPUT_DIR, "kernel.gz"), "wb") as f:
    f.write(kernel)

# Try 1: gunzip via subprocess
print("\n--- Trying gzip CLI ---")
try:
    result = subprocess.run(
        ["gzip", "-d", "-c", os.path.join(OUTPUT_DIR, "kernel.gz")],
        capture_output=True, timeout=30
    )
    if result.returncode == 0:
        print(f"gunzip success: {len(result.stdout)} bytes")
        if b"Linux version" in result.stdout:
            idx = result.stdout.find(b"Linux version")
            end = result.stdout.find(b"\n", idx)
            if end == -1:
                end = idx + 200
            print(f">> {result.stdout[idx:end].decode('utf-8', errors='replace')}")
    else:
        print(f"gunzip failed: {result.stderr.decode()}")
except Exception as e:
    print(f"gunzip error: {e}")

# Try 2: Try first segment (up to second gzip header)
print("\n--- Trying first segment (0 to 12505350) ---")
try:
    decomp = gzip.decompress(kernel[:12505350])
    print(f"First segment decompressed: {len(decomp)} bytes")
    if b"Linux version" in decomp:
        idx = decomp.find(b"Linux version")
        end = decomp.find(b"\n", idx)
        if end == -1:
            end = idx + 200
        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
except Exception as e:
    print(f"First segment failed: {e}")

# Try 3: Try smaller chunks
print("\n--- Trying smaller chunks ---")
for size in [500000, 100000, 50000, 10000]:
    try:
        decomp = gzip.decompress(kernel[:size])
        print(f"Chunk {size}: OK, {len(decomp)} bytes")
    except Exception as e:
        print(f"Chunk {size}: {e}")

# Try 4: Check if the kernel is actually XZ or LZ4
print("\n--- Checking other formats ---")
if kernel[:6] == b"\xfd\x37\x7a\x58\x5a\x00":
    print("XZ magic found!")
    try:
        decomp = lzma.decompress(kernel)
        print(f"XZ decompressed: {len(decomp)} bytes")
    except Exception as e:
        print(f"XZ failed: {e}")

if kernel[:4] == b"\x02\x21\x4c\x18":
    print("LZ4 legacy magic found!")
if kernel[:4] == b"\x04\x22\x4d\x18":
    print("LZ4 magic found!")
if kernel[:4] == b"\x28\xb5\x2f\xfd":
    print("ZSTD magic found!")

# Try 5: Check if it's a concatenation of gzip members
# After the first gzip member, there should be another gzip header
print("\n--- Looking for gzip members ---")
pos = 0
members = []
while True:
    pos = kernel.find(b"\x1f\x8b\x08", pos)
    if pos == -1:
        break
    members.append(pos)
    print(f"  gzip member at offset {pos}")
    pos += 1

# Try to decompress each member individually
for i, start in enumerate(members):
    end = members[i + 1] if i + 1 < len(members) else len(kernel)
    member_data = kernel[start:end]
    print(f"\nMember {i} at {start}: {len(member_data)} bytes")
    try:
        decomp = gzip.decompress(member_data)
        print(f"  Decompressed: {len(decomp)} bytes")
        if b"Linux version" in decomp:
            idx = decomp.find(b"Linux version")
            end2 = decomp.find(b"\n", idx)
            if end2 == -1:
                end2 = idx + 200
            print(f"  >> {decomp[idx:end2].decode('utf-8', errors='replace')}")
        # Save
        with open(os.path.join(OUTPUT_DIR, f"kernel_member_{i}.bin"), "wb") as f:
            f.write(decomp)
    except Exception as e:
        print(f"  Failed: {e}")

print("\nDone")