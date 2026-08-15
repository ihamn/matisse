import re, gzip, lzma, bz2

PAYLOAD = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin"

print("Reading payload...")
with open(PAYLOAD, "rb") as f:
    data = f.read()

print(f"Payload size: {len(data)} bytes")

# Search for "Linux version" in the payload
found = False
for m in re.finditer(b"Linux version", data):
    end = data.find(b"\x00", m.start())
    if end == -1:
        end = m.start() + 150
    chunk = data[m.start():end]
    printable = bytes(b for b in chunk if 32 <= b < 127 or b == 10)
    print(f"Found at offset {m.start()}: {printable.decode('ascii', errors='replace')[:200]}")
    found = True
    break

if not found:
    print("No plaintext 'Linux version' found in payload")
    print("Trying to find compressed kernel strings...")
    
    # Try to scan for gzip headers
    gzip_count = 0
    pos = 0
    while pos < len(data) - 2 and gzip_count < 20:
        pos = data.find(b"\x1f\x8b", pos)
        if pos == -1:
            break
        try:
            decomp = gzip.decompress(data[pos:pos+10*1024*1024])
            if b"Linux version" in decomp:
                idx = decomp.find(b"Linux version")
                end = decomp.find(b"\x00", idx)
                if end == -1:
                    end = idx + 200
                print(f"Found in gzip at offset {pos}: {decomp[idx:end]}")
                found = True
                break
        except:
            pass
        pos += 1
        gzip_count += 1

if not found:
    # Try to find kernel version in boot partition REPLACE chunks
    print("\nTrying boot partition REPLACE chunks...")
    # We know the boot partition REPLACE operations are at offsets relative to data_start
    # data_start = 1748337496
    # Op 1: offset=6295908, length=2097152
    # Op 2: offset=8393060, length=2097152
    # etc.
    
    data_start = 1748337496
    replace_offsets = [
        (6295908, 2097152),
        (8393060, 2097152),
        (10490212, 2097152),
        (12587364, 2097152),
        (16777404, 2097152),
    ]
    
    for roff, rlen in replace_offsets:
        chunk = data[data_start + roff:data_start + roff + rlen]
        # Try gzip decompression
        for i in range(0, len(chunk) - 2, 256):
            if chunk[i:i+2] == b"\x1f\x8b":
                try:
                    decomp = gzip.decompress(chunk[i:])
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\x00", idx)
                        if end == -1:
                            end = idx + 200
                        print(f"Found in boot REPLACE chunk at data_offset {roff}, chunk_offset {i}:")
                        print(f"  {decomp[idx:end]}")
                        found = True
                        break
                except:
                    pass
        if found:
            break

if not found:
    print("Could not find kernel version string in the OTA package.")
    print("This is an incremental OTA - the kernel is in BROTLI_BSDIFF operations that need the source image.")
    print("Recommendation: Download the Fastboot ROM (7.7GB) to get the full boot.img.")

print("\nDone")