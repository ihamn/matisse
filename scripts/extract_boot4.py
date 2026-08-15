"""Extract boot.img with correct field parsing"""
import os, struct, gzip, lzma, sys

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
        if tag is None:
            break
        field_number = tag >> 3
        wire_type = tag & 0x7
        
        if wire_type == 0:
            value, pos = parse_varint(data, pos)
            result.setdefault(field_number, []).append(("varint", value))
        elif wire_type == 2:
            length, pos = parse_varint(data, pos)
            if length is None:
                break
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
        else:
            break
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

# Find data section
data_start = manifest_offset + manifest_size
if 14 in manifest:
    sig_offset = manifest[14][0][1]
    if sig_offset:
        data_start = manifest_offset + sig_offset

print(f"Data section starts at: {data_start}")

# Process boot partition
for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "boot":
        continue
    
    operations = p_dict.get(8, [])
    
    # First pass: determine the total size by examining all extents
    max_block = 0
    op_info = []
    
    for op_idx, op_raw in enumerate(operations):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        
        # For REPLACE (0) and REPLACE_XZ (6), field 6 contains the dst extents
        # For BROTLI_BSDIFF (8), field 6 is src_extents, field 4 should be dst_extents
        if op_type in (0, 6, 4):  # REPLACE, REPLACE_XZ, ZERO
            extents = get_extents(op_dict, 6)
        else:
            extents = get_extents(op_dict, 4)
            if not extents:
                # Fallback: use field 6 as src_extents
                extents = get_extents(op_dict, 6)
        
        for start_block, num_blocks in extents:
            if start_block + num_blocks > max_block:
                max_block = start_block + num_blocks
        
        op_info.append((op_type, op_dict, extents))
    
    total_size = max_block * BLOCK_SIZE
    print(f"Boot partition: {max_block} blocks = {total_size} bytes ({total_size/1024/1024:.1f} MB)")
    
    boot_img = bytearray(total_size)
    
    # Second pass: apply operations
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        if op_type == 0:  # REPLACE
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                boot_img[dst_offset:dst_offset + dst_len] = chunk[:dst_len]
                chunk = chunk[dst_len:]
            print(f"  Op {op_idx}: REPLACE {data_length} bytes -> blocks {[(s,n) for s,n in dst_extents]}")
        
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
                boot_img[dst_offset:dst_offset + dst_len] = decompressed[:dst_len]
                decompressed = decompressed[dst_len:]
            print(f"  Op {op_idx}: REPLACE_XZ {data_length} bytes")
        
        elif op_type == 4:  # ZERO
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                boot_img[dst_offset:dst_offset + dst_len] = b'\x00' * dst_len
            print(f"  Op {op_idx}: ZERO {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 1:  # REPLACE_BZ - need source
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                print(f"  Op {op_idx}: REPLACE_BZ (need source) at offset {dst_offset} len {dst_len}")
        
        elif op_type == 8:  # BROTLI_BSDIFF - need source
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                print(f"  Op {op_idx}: BROTLI_BSDIFF (need source) at offset {dst_offset} len {dst_len}")
    
    # Save boot image
    outpath = os.path.join(OUTPUT_DIR, "boot_full.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"\nSaved: {outpath} ({len(boot_img)} bytes)")
    
    # Check for ANDROID! header
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        print(f"\nFound ANDROID! header at offset {pos}")
        header = boot_img[:4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"kernel_size={kernel_size}, page_size={page_size}")
        
        kernel_offset = page_size
        kernel_data = bytes(boot_img[kernel_offset:kernel_offset + kernel_size])
        print(f"Kernel data at offset {kernel_offset}, size {kernel_size}")
        print(f"First 16 bytes: {kernel_data[:16].hex()}")
        
        for magic_name, magic_bytes, decomp_func in [
            ("gzip", b"\x1f\x8b", lambda d: gzip.decompress(d)),
            ("XZ", b"\xfd\x37\x7a\x58", lambda d: lzma.decompress(d)),
        ]:
            if magic_bytes in kernel_data[:16]:
                print(f"Kernel compressed with {magic_name}")
                try:
                    decomp = decomp_func(kernel_data)
                    print(f"Decompressed to {len(decomp)} bytes")
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1: end = idx + 200
                        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
                    
                    outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                    with open(outpath, "wb") as f:
                        f.write(decomp)
                    print(f"Saved to {outpath}")
                    break
                except Exception as e:
                    print(f"Decompress failed: {e}")
    else:
        print("\nNo ANDROID! header found - checking for kernel in raw data...")
        for magic_name, magic_bytes in [("gzip", b"\x1f\x8b"), ("XZ", b"\xfd\x37\x7a\x58")]:
            pos = boot_img.find(magic_bytes)
            if pos >= 0:
                print(f"Found {magic_name} at offset {pos}")
                try:
                    if magic_name == "gzip":
                        decomp = gzip.decompress(boot_img[pos:])
                    else:
                        decomp = lzma.decompress(boot_img[pos:])
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1: end = idx + 200
                        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
                        outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                        with open(outpath, "wb") as f:
                            f.write(decomp)
                        print(f"Saved to {outpath}")
                        break
                except:
                    pass
    break

print("\nDone")