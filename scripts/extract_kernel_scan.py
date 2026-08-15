"""Extract boot partition data from REPLACE ops and scan for kernel"""
import os, struct, gzip, lzma, bz2

PAYLOAD_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358"
PAYLOAD_PATH = os.path.join(PAYLOAD_DIR, "payload.bin")
OUTPUT_DIR = os.path.join(PAYLOAD_DIR, "extracted")
BLOCK_SIZE = 4096

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

data_start_bz = manifest_offset + manifest_size + manifest_sig_size  # 227285
data_start_raw = manifest_offset + manifest.get(14, [("varint", 0)])[0][1]  # 1748337496

print(f"data_start_bz = {data_start_bz}")
print(f"data_start_raw = {data_start_raw}")

for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "boot":
        continue
    
    ops = p_dict.get(8, [])
    
    # Find max block
    max_block = 0
    op_info = []
    for op_idx, op_raw in enumerate(ops):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        extents = get_extents(op_dict, 6)
        if not extents:
            extents = get_extents(op_dict, 4)
        for s, n in extents:
            if s + n > max_block:
                max_block = s + n
        op_info.append((op_type, op_dict, extents))
    
    total_size = max_block * BLOCK_SIZE
    print(f"Boot: {max_block} blocks = {total_size} bytes ({total_size/1024/1024:.1f} MB)")
    
    boot_img = bytearray(total_size)
    
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        if op_type == 0:  # REPLACE
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = chunk[:ln]
                chunk = chunk[ln:]
            print(f"  Op {op_idx}: REPLACE {data_length}B -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 1:  # REPLACE_BZ
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                decompressed = bz2.decompress(compressed)
            except:
                decompressed = compressed
                print(f"  Op {op_idx}: REPLACE_BZ bz2 FAILED")
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = decompressed[:ln]
                decompressed = decompressed[ln:]
            print(f"  Op {op_idx}: REPLACE_BZ {data_length}B -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 4:  # ZERO
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = b'\x00' * ln
            print(f"  Op {op_idx}: ZERO")
        
        elif op_type in (2, 3, 7, 8, 9):  # Need source
            for s, n in dst_extents:
                print(f"  Op {op_idx}: type={op_type} NEED SOURCE at {s*BLOCK_SIZE} len {n*BLOCK_SIZE}")
    
    # Save the partial boot image
    outpath = os.path.join(OUTPUT_DIR, "boot_partial.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"\nSaved partial boot: {outpath} ({len(boot_img)} bytes)")
    
    # Now scan for kernel signatures in the available data
    # Check first 4MB (blocks 512-1535 are covered by REPLACE)
    # This is where the kernel typically is (after the header)
    
    print("\n=== Scanning for kernel in available REPLACE data ===")
    
    # Scan for common compressed kernel signatures
    for magic_name, magic, min_len, decomp_func in [
        ("gzip", b"\x1f\x8b\x08", 3, lambda d: gzip.decompress(d)),
        ("XZ", b"\xfd\x37\x7a\x58\x5a\x00", 6, lambda d: lzma.decompress(d)),
        ("LZ4 legacy", b"\x02\x21\x4c\x18", 4, None),
        ("LZ4", b"\x04\x22\x4d\x18", 4, None),
        ("ZSTD", b"\x28\xb5\x2f\xfd", 4, None),
    ]:
        pos = 0
        while True:
            pos = boot_img.find(magic, pos)
            if pos == -1:
                break
            # Check if it's in a non-zero region (not in a BROTLI_BSDIFF gap)
            region_start = max(0, pos - 16)
            region_data = boot_img[region_start:region_start + 32]
            if any(b != 0 for b in region_data[:8]):
                print(f"\nFound {magic_name} magic at offset {pos} (0x{pos:x})")
                print(f"  Context: {boot_img[pos:pos+32].hex()}")
                
                if decomp_func:
                    try:
                        # Try to decompress
                        decomp = decomp_func(boot_img[pos:pos + 50*1024*1024])
                        print(f"  Decompressed: {len(decomp)} bytes")
                        # Search for Linux version
                        if b"Linux version" in decomp:
                            idx = decomp.find(b"Linux version")
                            end = decomp.find(b"\n", idx)
                            if end == -1: end = idx + 200
                            print(f"  >> {decomp[idx:end].decode('utf-8', errors='replace')}")
                            # Save
                            outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                            with open(outpath, "wb") as f:
                                f.write(decomp)
                            print(f"  Saved kernel to {outpath}")
                        else:
                            # Check first 500 bytes
                            print(f"  First 200 bytes: {decomp[:200]}")
                    except Exception as e:
                        print(f"  Decompress failed: {e}")
            pos += 1
    
    # Also check the REPLACE_BZ data (blocks 5120+)
    print("\n=== Scanning in REPLACE_BZ data (blocks 5120+) ===")
    for magic_name, magic in [("gzip", b"\x1f\x8b\x08"), ("XZ", b"\xfd\x37\x7a\x58\x5a\x00")]:
        pos = boot_img.find(magic, 5120 * BLOCK_SIZE)
        if pos >= 0:
            print(f"Found {magic_name} at offset {pos} in REPLACE_BZ region")
    
    # Check what's at the beginning of REPLACE data (block 512 = offset 2097152)
    print(f"\n=== Data at offset 2097152 (block 512, first REPLACE) ===")
    print(f"  Hex: {boot_img[2097152:2097152+64].hex()}")
    print(f"  ASCII: {boot_img[2097152:2097152+64]}")
    
    # Check if the first non-zero block might be the kernel header
    # The kernel typically starts at page_size after the ANDROID! header
    # If ANDROID! header is at block 0 (missing), kernel might start at block 1 (offset 4096)
    # But block 1 is at offset 4096, which is within the BROTLI_BSDIFF range (blocks 0-511)
    # So the kernel likely starts somewhere in block 512 (offset 2097152)
    
    break

print("\nDone")