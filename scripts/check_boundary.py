"""Check if the gzip stream is continuous across operation boundaries"""
import struct, os, lzma

PAYLOAD_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin"

def parse_varint(data, pos):
    result = 0; shift = 0
    while pos < len(data):
        byte = data[pos]
        result |= (byte & 0x7f) << shift; pos += 1
        if not (byte & 0x80): return result, pos
        shift += 7
    return None, pos

def parse_protobuf(data):
    result = {}; pos = 0
    while pos < len(data):
        tag, pos = parse_varint(data, pos)
        if tag is None: break
        fn = tag >> 3; wt = tag & 0x7
        if wt == 0:
            v, pos = parse_varint(data, pos); result.setdefault(fn,[]).append(("varint",v))
        elif wt == 2:
            l, pos = parse_varint(data, pos)
            if l is None: break
            vb = data[pos:pos+l]; pos += l; result.setdefault(fn,[]).append(("bytes",vb))
        elif wt == 1:
            v = struct.unpack_from("<Q", data, pos)[0]; pos += 8; result.setdefault(fn,[]).append(("fixed64",v))
        elif wt == 5:
            v = struct.unpack_from("<I", data, pos)[0]; pos += 4; result.setdefault(fn,[]).append(("fixed32",v))
        else: break
    return result

def get_extents(op_dict, field_num):
    extents = op_dict.get(field_num, [])
    result = []
    for ext in extents:
        ext_dict = parse_protobuf(ext[1])
        start_block = ext_dict.get(1, [("varint", 0)])[0][1]
        num_blocks = ext_dict.get(2, [("varint", 0)])[0][1]
        result.append((start_block, num_blocks))
    return result

with open(PAYLOAD_PATH, "rb") as f:
    payload = f.read()

version = struct.unpack_from(">Q", payload, 4)[0]
manifest_size = struct.unpack_from(">Q", payload, 12)[0]
manifest_sig_size = struct.unpack_from(">I", payload, 20)[0]
manifest_offset = 24
manifest_data = payload[manifest_offset:manifest_offset + manifest_size]
manifest = parse_protobuf(manifest_data)

data_start_bz = manifest_offset + manifest_size + manifest_sig_size
data_start_raw = manifest_offset + manifest.get(14, [("varint", 0)])[0][1]

print(f"data_start_bz = {data_start_bz}")
print(f"data_start_raw = {data_start_raw}")

BLOCK_SIZE = 4096

for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "boot":
        continue
    
    ops = p_dict.get(8, [])
    
    # Process Op 0 (BROTLI_BSDIFF)
    op_raw = ops[0]
    op_data = op_raw[1]
    op_dict = parse_protobuf(op_data)
    data_offset = op_dict.get(2, [("varint", 0)])[0][1]
    data_length = op_dict.get(3, [("varint", 0)])[0][1]
    compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
    op0_decomp = lzma.decompress(compressed)
    print(f"\nOp 0: XZ decompressed: {len(op0_decomp)} bytes")
    print(f"  First 32: {op0_decomp[:32].hex()}")
    print(f"  Last 32: {op0_decomp[-32:].hex()}")
    
    # Process Op 1 (REPLACE)
    op_raw = ops[1]
    op_data = op_raw[1]
    op_dict = parse_protobuf(op_data)
    data_offset = op_dict.get(2, [("varint", 0)])[0][1]
    data_length = op_dict.get(3, [("varint", 0)])[0][1]
    op1_data = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
    print(f"\nOp 1: REPLACE raw: {len(op1_data)} bytes")
    print(f"  First 32: {op1_data[:32].hex()}")
    print(f"  Last 32: {op1_data[-32:].hex()}")
    
    # Check the boundary
    # The boot image has Op 0 data at offset 0-2097151 and Op 1 data at 2097152-4194303
    # The gzip stream starts at boot offset 4096
    # The gzip data at the boundary: boot offset 2097152-2097183
    
    boundary_offset = 2097152  # Start of Op 1 (block 512)
    
    print(f"\n\n=== Boundary Analysis ===")
    print(f"Boot offset {boundary_offset}: boundary between Op 0 and Op 1")
    print(f"  Op 0 last 32 bytes (at boot offset {boundary_offset-32}):")
    print(f"    {op0_decomp[boundary_offset-32:boundary_offset].hex()}")
    print(f"  Op 1 first 32 bytes (at boot offset {boundary_offset}):")
    print(f"    {op1_data[:32].hex()}")
    
    # The gzip stream data at the boundary
    # The gzip deflate stream starts at boot offset 4106 (4096 + 10)
    # The failure is at compressed position 2093056, which is boot offset 2097162
    # Let's look at the data around this point
    fail_boot_offset = 2097162
    print(f"\n  Gzip failure at boot offset {fail_boot_offset}")
    print(f"  This is in Op 1 at offset {fail_boot_offset - 2097152}")
    print(f"  Data at failure: {op1_data[fail_boot_offset - 2097152:fail_boot_offset - 2097152 + 32].hex()}")
    
    # Now, the key question: is the gzip stream continuous?
    # The gzip stream consists of bytes from boot offset 4106 to 4096+kernel_size
    # The boundary is at boot offset 2097152
    # So the gzip data at boot offset 2097152 is the first byte of Op 1 data
    # And the gzip data at boot offset 2097151 is the last byte of Op 0 data
    
    # Let me check if the gzip stream makes sense at the boundary
    # by looking at the surrounding bytes
    print(f"\n  Gzip data around boundary:")
    boundary_gzip_offset = 2097152 - 4106  # Position in the deflate stream
    print(f"  Deflate stream position: {boundary_gzip_offset}")
    
    # The deflate data at the boundary
    # Bytes 0 to 2093046 (2097152 - 4106) are from Op 0
    # Bytes 2093046 onwards are from Op 1
    
    # Check if the data looks like it could be part of a deflate stream
    # The first byte of Op 1 (at deflate position 2093046) is the continuation
    # of the deflate stream
    
    # Actually, let me look at this from a different angle.
    # The issue might be that the REPLACE data for Op 1 starts at the WRONG offset
    # Maybe the data_offset in Op 1 is relative to data_start_bz instead of data_start_raw?
    
    # Check Op 1 data at data_start_bz
    op1_at_bz = payload[data_start_bz + data_offset:data_start_bz + data_offset + 64]
    print(f"\n  Op 1 data at data_start_bz: {op1_at_bz[:32].hex()}")
    print(f"  Op 1 data at data_start_raw: {op1_data[:32].hex()}")
    
    # Check if data_start_bz data matches what we expect at the boundary
    # If the REPLACE data is actually at data_start_bz, then the 
    # boot image reconstruction is wrong
    
    # Let me also check: what if Op 1 is also at data_start_bz?
    # verifikasi data_start_raw checked and it matched boot_full.img
    # But maybe boot_full.img is wrong
    
    print(f"\n\n=== Checking if Op 1 data should be from data_start_bz ===")
    # Compare the first bytes of Op 1 data from both locations
    # with the expected continuation of the gzip stream
    
    # The gzip stream at the boundary should continue from Op 0's last bytes
    # Let me look at the last 32 bytes of the gzip stream from Op 0 and the
    # first 32 bytes from Op 1
    
    # The last 32 bytes of the deflate stream from Op 0 are at
    # boot offset 2097120-2097151 (Op 0)
    last_deflate_op0 = op0_decomp[2097120:2097152]
    # The first 32 bytes of the deflate stream from Op 1 are at
    # boot offset 2097152-2097183 (Op 1)
    first_deflate_op1 = op1_data[:32]
    
    print(f"  Last 32 bytes of deflate from Op 0: {last_deflate_op0.hex()}")
    print(f"  First 32 bytes of deflate from Op 1: {first_deflate_op1.hex()}")
    
    # Now, the question is: should these be continuous?
    # In a gzip stream, the data is continuous. The boundary between Op 0 and Op 1
    # is just a boot image boundary, not a gzip boundary.
    # The gzip data should be continuous across this boundary.
    
    # If the data is NOT continuous, then the boot image reconstruction is wrong.
    # One of the operations might be using the wrong data source.
    
    # Let me check: what if Op 1 REPLACE data is actually at data_start_bz?
    # Then the data at data_start_bz for Op 1 should be the correct continuation
    op1_data_bz = payload[data_start_bz + data_offset:data_start_bz + data_offset + min(data_length, 64)]
    print(f"\n  Op 1 first 32 at data_start_bz: {op1_data_bz[:32].hex()}")
    
    # Check if op1_data_bz looks like it could be the continuation of the gzip stream
    # Compare with the last bytes of the deflate stream from Op 0
    
    # Also check: what if ALL REPLACE operations use data_start_bz?
    # Let me check Op 2 data as well
    op_raw = ops[2]
    op_data = op_raw[1]
    op_dict = parse_protobuf(op_data)
    data_offset2 = op_dict.get(2, [("varint", 0)])[0][1]
    data_length2 = op_dict.get(3, [("varint", 0)])[0][1]
    op2_data_raw = payload[data_start_raw + data_offset2:data_start_raw + data_offset2 + 64]
    op2_data_bz = payload[data_start_bz + data_offset2:data_start_bz + data_offset2 + 64]
    
    print(f"\n  Op 2 first 32 at data_start_raw: {op2_data_raw[:32].hex()}")
    print(f"  Op 2 first 32 at data_start_bz: {op2_data_bz[:32].hex()}")
    
    # Also check verify_data_start.py output
    # It said data_start_raw matches the data in boot_full.img
    # But boot_full.img was extracted using only data_start_bz
    # So the "match" might be misleading
    
    # Let me also check: what if the verified match was because
    # boot_full.img was extracted with data_start_bz and the REPLACE
    # data at data_start_bz happens to match the expected data?
    
    # Actually, let me re-read verify_data_start.py logic:
    # It compared: data at data_start_raw + offset vs data at data_start_bz + offset vs boot_full.img
    # If boot_full.img was extracted with data_start_bz, then the comparison
    # "data_start_raw matches boot_full" is actually comparing data_start_raw
    # with data_start_bz data. They might happen to match at the checked position.
    
    print(f"\n\n=== Critical check: reconstruct boot image with data_start_bz for REPLACE ops ===")
    # Try using data_start_bz for ALL operations and see if the gzip stream is continuous
    
    break

print("\nDone!")