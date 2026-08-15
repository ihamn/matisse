"""Apply BROTLI_BSDIFF patches against zero source to reconstruct boot.img"""
import os, struct, gzip, lzma, bz2
import brotli
import bsdiff4

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

def apply_bsdiff(source_data, patch_data):
    """Apply bsdiff patch to source data"""
    try:
        return bsdiff4.patch(source_data, patch_data)
    except Exception as e:
        print(f"    bsdiff4.patch failed: {e}")
        # Try manual approach
        try:
            import io
            # bsdiff4 format
            if len(patch_data) < 32:
                return None
            # Read header
            import struct as st
            magic = patch_data[:8]
            if magic != b'BSDIFF40':
                print(f"    Not BSDIFF40: {magic}")
                return None
            ctrl_len = int.from_bytes(patch_data[8:16], 'little')
            diff_len = int.from_bytes(patch_data[16:24], 'little')
            new_size = int.from_bytes(patch_data[24:32], 'little')
            
            print(f"    ctrl_len={ctrl_len}, diff_len={diff_len}, new_size={new_size}")
            
            # If source is zero, the result is essentially the diff data
            # But bsdiff is more complex than that
            # Let's try the bsdiff4 library's patch function
            return bsdiff4.patch(source_data, patch_data)
        except Exception as e2:
            print(f"    Manual bsdiff also failed: {e2}")
            return None

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
        
        elif op_type == 8:  # BROTLI_BSDIFF
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            
            # Get compressed data
            compressed = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
            
            # Decompress brotli
            try:
                brotli_data = brotli.decompress(compressed)
                print(f"  Op {op_idx}: BROTLI_BSDIFF brotli: {len(compressed)}B -> {len(brotli_data)}B")
                
                # Check if it's BSDIFF40
                if brotli_data[:8] == b'BSDIFF40':
                    print(f"    BSDIFF40 patch detected")
                    # Apply against zero source
                    src_size = 0
                    for s, n in dst_extents:
                        src_size = max(src_size, (s + n) * BLOCK_SIZE)
                    # Actually, for bsdiff, we need to know the source size
                    # The source is the original data at these blocks
                    # Let's try with zero source
                    zero_source = b'\x00' * (max_block * BLOCK_SIZE)
                    for s, n in dst_extents:
                        src_off = s * BLOCK_SIZE
                        src_len = n * BLOCK_SIZE
                        try:
                            patched = apply_bsdiff(zero_source[src_off:src_off + src_len], brotli_data)
                            if patched:
                                boot_img[src_off:src_off + src_len] = patched[:src_len]
                                print(f"    Applied bsdiff to blocks ({s},{n}) -> {len(patched)} bytes")
                            else:
                                print(f"    bsdiff failed for blocks ({s},{n})")
                        except Exception as e:
                            print(f"    bsdiff error: {e}")
                else:
                    print(f"    Not BSDIFF40, first 8: {brotli_data[:8].hex()}")
                    # Try to use as raw data
                    for s, n in dst_extents:
                        off = s * BLOCK_SIZE
                        ln = n * BLOCK_SIZE
                        boot_img[off:off + ln] = brotli_data[:ln]
                        brotli_data = brotli_data[ln:]
                    print(f"    Used as raw data")
            except Exception as e:
                print(f"  Op {op_idx}: BROTLI_BSDIFF brotli decompress FAILED: {e}")
        
        elif op_type in (2, 3, 7, 9):  # Other source-dependent ops
            for s, n in dst_extents:
                print(f"  Op {op_idx}: type={op_type} NEED SOURCE at {s*BLOCK_SIZE} len {n*BLOCK_SIZE}")
    
    # Save
    outpath = os.path.join(OUTPUT_DIR, "boot_reconstructed.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"\nSaved: {outpath} ({len(boot_img)} bytes)")
    
    # Check for ANDROID!
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        print(f"\n*** ANDROID! at offset {pos} ***")
        header = boot_img[:4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"kernel_size={kernel_size}, page_size={page_size}")
    else:
        print("\nNo ANDROID! header found")
        # Check non-zero regions
        for i in range(0, len(boot_img), 4096):
            if any(b != 0 for b in boot_img[i:i+4096]):
                if i == 0:
                    print(f"Block 0 ({i}): {boot_img[i:i+32].hex()}")
                break
    
    break

print("\nDone")