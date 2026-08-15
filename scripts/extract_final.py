"""Extract boot.img with two data_start values"""
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

# Two data_start values
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
    
    # First pass: find max block
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
    need_source = 0
    applied = 0
    
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        data_offset = op_dict.get(2, [("varint", 0)])[0][1]
        data_length = op_dict.get(3, [("varint", 0)])[0][1]
        
        if op_type == 0:  # REPLACE - data at data_start_raw
            chunk = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = chunk[:ln]
                chunk = chunk[ln:]
            print(f"  Op {op_idx}: REPLACE {data_length}B -> {[(s,n) for s,n in dst_extents]}")
            applied += 1
        
        elif op_type == 1:  # REPLACE_BZ - data at data_start_bz
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                decompressed = bz2.decompress(compressed)
            except:
                # Maybe not actually bzip2? Try raw
                decompressed = compressed
                print(f"  Op {op_idx}: REPLACE_BZ bz2 failed, using raw")
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = decompressed[:ln]
                decompressed = decompressed[ln:]
            print(f"  Op {op_idx}: REPLACE_BZ {data_length}B -> {[(s,n) for s,n in dst_extents]}")
            applied += 1
        
        elif op_type == 6:  # REPLACE_XZ
            compressed = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
            try:
                decompressed = lzma.decompress(compressed)
            except:
                decompressed = compressed
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = decompressed[:ln]
                decompressed = decompressed[ln:]
            print(f"  Op {op_idx}: REPLACE_XZ {data_length}B")
            applied += 1
        
        elif op_type == 4:  # ZERO
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = b'\x00' * ln
            print(f"  Op {op_idx}: ZERO")
            applied += 1
        
        else:
            for s, n in dst_extents:
                print(f"  Op {op_idx}: type={op_type} (NEED SOURCE) at {s*BLOCK_SIZE} len {n*BLOCK_SIZE}")
            need_source += 1
    
    print(f"\nApplied: {applied}, Need source: {need_source}")
    
    outpath = os.path.join(OUTPUT_DIR, "boot_full.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"Saved: {outpath} ({len(boot_img)} bytes)")
    
    # Check for ANDROID!
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        print(f"\n*** ANDROID! at offset {pos} ***")
        header = boot_img[:4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"kernel_size={kernel_size}, page_size={page_size}")
        
        kernel_data = bytes(boot_img[page_size:page_size + kernel_size])
        print(f"Kernel at {page_size}, size {kernel_size}, first 16: {kernel_data[:16].hex()}")
        
        for magic_name, magic, func in [
            ("gzip", b"\x1f\x8b", lambda d: gzip.decompress(d)),
            ("XZ", b"\xfd\x37\x7a\x58", lambda d: lzma.decompress(d)),
        ]:
            if magic in kernel_data[:16]:
                print(f"Compressed with {magic_name}")
                try:
                    decomp = func(kernel_data)
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
                    print(f"Decompress failed: {e}")
                break
    else:
        print("\nNo ANDROID! header")
    break

print("\nDone")