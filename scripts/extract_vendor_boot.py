"""Extract vendor_boot with REPLACE_BZ handling"""
import os, struct, gzip, lzma, bz2, sys

PAYLOAD_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358"
PAYLOAD_PATH = os.path.join(PAYLOAD_DIR, "payload.bin")
OUTPUT_DIR = os.path.join(PAYLOAD_DIR, "extracted")

BLOCK_SIZE = 4096

def parse_varint(data, pos):
    result = 0
    shift = 0
    while pos < len(data):
        byte = data[pos]
        result |= (byte & 0x7f) << shift
        pos += 1
        if not (byte & 0x80):
            return result, pos
        shift += 7
    return None, pos

def parse_protobuf(data):
    result = {}
    pos = 0
    while pos < len(data):
        tag, pos = parse_varint(data, pos)
        if tag is None: break
        field_number = tag >> 3
        wire_type = tag & 0x7
        if wire_type == 0:
            value, pos = parse_varint(data, pos)
            result.setdefault(field_number, []).append(("varint", value))
        elif wire_type == 2:
            length, pos = parse_varint(data, pos)
            if length is None: break
            value_bytes = data[pos:pos + length]
            pos += length
            result.setdefault(field_number, []).append(("bytes", value_bytes))
        elif wire_type == 1:
            value = struct.unpack_from("<Q", data, pos)[0]
            pos += 8
            result.setdefault(field_number, []).append(("fixed64", value))
        elif wire_type == 5:
            value = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            result.setdefault(field_number, []).append(("fixed32", value))
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

# Read payload
with open(PAYLOAD_PATH, "rb") as f:
    payload_data = f.read()

version = struct.unpack_from(">Q", payload_data, 4)[0]
manifest_size = struct.unpack_from(">Q", payload_data, 12)[0]
manifest_offset = 24 if version == 2 else 20
manifest_data = payload_data[manifest_offset:manifest_offset + manifest_size]
manifest = parse_protobuf(manifest_data)

data_start = manifest_offset + manifest_size
if 14 in manifest:
    sig_offset = manifest[14][0][1]
    if sig_offset:
        data_start = manifest_offset + sig_offset

print(f"Data section starts at: {data_start}")

# Process vendor_boot
for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "vendor_boot":
        continue
    
    operations = p_dict.get(8, [])
    
    # First pass: determine size
    max_block = 0
    op_info = []
    for op_idx, op_raw in enumerate(operations):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        
        if op_type in (0, 1, 6, 4):
            extents = get_extents(op_dict, 6)
        else:
            extents = get_extents(op_dict, 4)
            if not extents:
                extents = get_extents(op_dict, 6)
        
        for start_block, num_blocks in extents:
            if start_block + num_blocks > max_block:
                max_block = start_block + num_blocks
        
        op_info.append((op_type, op_dict, extents))
    
    total_size = max_block * BLOCK_SIZE
    print(f"vendor_boot: {max_block} blocks = {total_size} bytes ({total_size/1024/1024:.1f} MB)")
    
    vendor_boot = bytearray(total_size)
    
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        if op_type == 0:  # REPLACE
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                vendor_boot[dst_offset:dst_offset + dst_len] = chunk[:dst_len]
                chunk = chunk[dst_len:]
            print(f"  Op {op_idx}: REPLACE {data_length}B -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 1:  # REPLACE_BZ
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            try:
                decompressed = bz2.decompress(compressed)
                decomp_method = "bz2"
            except:
                decompressed = compressed
                decomp_method = "raw"
            
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                vendor_boot[dst_offset:dst_offset + dst_len] = decompressed[:dst_len]
                decompressed = decompressed[dst_len:]
            print(f"  Op {op_idx}: REPLACE_BZ {data_length}B ({decomp_method}) -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 6:  # REPLACE_XZ
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            try:
                decompressed = lzma.decompress(compressed)
            except:
                decompressed = compressed
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                vendor_boot[dst_offset:dst_offset + dst_len] = decompressed[:dst_len]
                decompressed = decompressed[dst_len:]
            print(f"  Op {op_idx}: REPLACE_XZ {data_length}B -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 8:  # BROTLI_BSDIFF
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                print(f"  Op {op_idx}: BROTLI_BSDIFF (skip) at {dst_offset} len {dst_len}")
    
    # Save
    outpath = os.path.join(OUTPUT_DIR, "vendor_boot_full.img")
    with open(outpath, "wb") as f:
        f.write(vendor_boot)
    print(f"\nSaved: {outpath} ({len(vendor_boot)} bytes)")
    
    # Check for VENDOR_BOOT header or kernel
    pos = vendor_boot.find(b"VNDRBOOT")
    if pos >= 0:
        print(f"Found VNDRBOOT header at offset {pos}")
    
    # Search for kernel
    for magic_name, magic_bytes in [("gzip", b"\x1f\x8b"), ("XZ", b"\xfd\x37\x7a\x58")]:
        pos = vendor_boot.find(magic_bytes)
        if pos >= 0:
            print(f"Found {magic_name} at offset {pos}")
            if magic_name == "gzip":
                try:
                    decomp = gzip.decompress(vendor_boot[pos:])
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1: end = idx + 200
                        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
                        outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                        with open(outpath, "wb") as f:
                            f.write(decomp)
                        print(f"Saved kernel to {outpath}")
                except Exception as e:
                    print(f"gzip failed: {e}")
    
    break

print("\nDone")