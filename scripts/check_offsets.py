import struct

payload = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin", "rb").read()

# Check header details
magic = payload[:4]
version = struct.unpack_from(">Q", payload, 4)[0]
manifest_size = struct.unpack_from(">Q", payload, 12)[0]
print(f"Magic: {magic}")
print(f"Version: {version}")
print(f"Manifest size: {manifest_size}")

# Check bytes at offset 20-23 (manifest_signature_size)
b20 = payload[20:24]
print(f"Bytes at 20-23: {b20.hex()}")
print(f"  as big-endian uint32: {struct.unpack_from('>I', payload, 20)[0]}")
print(f"  as little-endian uint32: {struct.unpack_from('<I', payload, 20)[0]}")

# Try data_start = 24 + manifest_size (no sig)
data_start_no_sig = 24 + manifest_size
print(f"\ndata_start (no sig) = {data_start_no_sig}")

# Op 1: data_offset=6295908, data_length=2097152
chunk = payload[data_start_no_sig + 6295908:data_start_no_sig + 6295908 + 64]
print(f"Op 1 data at {data_start_no_sig + 6295908}: {chunk[:32].hex()}")
printable = bytes(b for b in chunk[:32] if 32 <= b < 127)
print(f"  printable: {printable}")

# Also try with signatures_offset from manifest
data_start_with_sig = 24 + 1748337472
print(f"\ndata_start (with sig) = {data_start_with_sig}")
chunk2 = payload[data_start_with_sig + 6295908:data_start_with_sig + 6295908 + 64]
print(f"Op 1 data at {data_start_with_sig + 6295908}: {chunk2[:32].hex()}")
printable2 = bytes(b for b in chunk2[:32] if 32 <= b < 127)
print(f"  printable: {printable2}")

# Check if the extracted boot.img REPLACE chunk looks right
boot = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_full.img", "rb").read()
chunk3 = boot[2097152:2097152+64]
print(f"\nboot_full.img at offset 2097152: {chunk3[:32].hex()}")
printable3 = bytes(b for b in chunk3[:32] if 32 <= b < 127)
print(f"  printable: {printable3}")

# Check Op 10 REPLACE_BZ data at both offsets
# Op 10: data_offset=24758484, data_length=27596
chunk4 = payload[data_start_no_sig + 24758484:data_start_no_sig + 24758484 + 32]
print(f"\nOp 10 data at {data_start_no_sig + 24758484}: {chunk4[:32].hex()}")

chunk5 = payload[data_start_with_sig + 24758484:data_start_with_sig + 24758484 + 32]
print(f"Op 10 data at {data_start_with_sig + 24758484}: {chunk5[:32].hex()}")

# Check bytes at offset 24 (start of manifest)
print(f"\nManifest start at 24: {payload[24:36].hex()}")
print(f"Manifest start text: {payload[24:48]}")

# Try to find where the manifest actually ends
# Look for 'ANDROID!' or other patterns near the expected data start
for offset in [data_start_no_sig, data_start_with_sig, 1748337496]:
    nearby = payload[offset:offset+64]
    print(f"\nData at {offset}: {nearby[:32].hex()}")
    # Check if it looks like boot image data
    if b"ANDROID" in nearby:
        print(f"  FOUND ANDROID!")
    if nearby[:2] == b"\x1f\x8b":
        print(f"  Looks like gzip!")
    if nearby[:4] == b"\xfd\x37\x7a\x58":
        print(f"  Looks like XZ!")