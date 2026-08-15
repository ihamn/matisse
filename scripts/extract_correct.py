"""Correct extraction: BROTLI_BSDIFF data at data_start_bz is XZ compressed target data"""
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

# KEY INSIGHT: 
# REPLACE (type 0) data → data_start_raw (1748337496)
# BROTLI_BSDIFF (type 8) data → data_start_bz (227285) - XZ compressed target data
# REPLACE_BZ (type 1) data → data_start_bz (227285) - bzip2 compressed
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
    
    max_block = 0
    op_info = []
    for op_idx, op_raw in enumerate(ops):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        extents = get_extents(op_dict, 6) or get_extents(op_dict, 4)
        for s, n in extents:
            if s + n > max_block:
                max_block = s + n
        op_info.append((op_type, op_dict, extents))
    
    total_size = max_block * BLOCK_SIZE
    print(f"Boot: {max_block} blocks = {total_size} bytes ({total_size/1024/1024:.1f} MB)")
    
    boot_img = bytearray(total_size)
    
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        if op_type == 0:  # REPLACE - data at data_start_raw
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload[data_start_raw + data_offset:data_start_raw + data_offset + data_length]
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = chunk[:ln]
                chunk = chunk[ln:]
            print(f"  Op {op_idx}: REPLACE {data_length}B -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type == 1:  # REPLACE_BZ - data at data_start_bz, bzip2
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                decompressed = bz2.decompress(compressed)
            except:
                decompressed = compressed
                print(f"  Op {op_idx}: REPLACE_BZ bz2 FAILED, using raw")
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
        
        elif op_type == 8:  # BROTLI_BSDIFF - data at data_start_bz, XZ compressed target
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                decompressed = lzma.decompress(compressed)
                print(f"  Op {op_idx}: BROTLI_BSDIFF (XZ) {data_length}B -> {len(decompressed)}B")
            except Exception as e:
                print(f"  Op {op_idx}: BROTLI_BSDIFF XZ decompress FAILED: {e}")
                decompressed = compressed
            
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = decompressed[:ln]
                decompressed = decompressed[ln:]
            print(f"    -> {[(s,n) for s,n in dst_extents]}")
        
        elif op_type in (2, 3, 7, 9):  # Other source-dependent
            for s, n in dst_extents:
                print(f"  Op {op_idx}: type={op_type} NEED SOURCE at {s*BLOCK_SIZE}")
    
    # Save
    outpath = os.path.join(OUTPUT_DIR, "boot_correct.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"\nSaved: {outpath} ({len(boot_img)} bytes)")
    
    # Parse ANDROID! header
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        print(f"\n*** ANDROID! at offset {pos} ***")
        header = boot_img[pos:pos+4096]
        
        # Parse header based on version
        header_version = struct.unpack_from("<I", header, 40)[0]
        print(f"Header version: {header_version}")
        
        if header_version >= 4:
            # v4 header
            kernel_size = struct.unpack_from("<I", header, 8)[0]
            ramdisk_size = struct.unpack_from("<I", header, 16)[0]
            page_size = 4096  # v4 fixed
            print(f"kernel_size={kernel_size} ({kernel_size/1024/1024:.1f} MB)")
            print(f"ramdisk_size={ramdisk_size} ({ramdisk_size/1024/1024:.1f} MB)")
            print(f"page_size={page_size} (v4 fixed)")
        else:
            kernel_size = struct.unpack_from("<I", header, 8)[0]
            page_size = struct.unpack_from("<I", header, 36)[0]
            print(f"kernel_size={kernel_size}, page_size={page_size}")
        
        # Extract kernel
        kernel_offset = page_size
        kernel_data = bytes(boot_img[kernel_offset:kernel_offset + kernel_size])
        print(f"\nKernel at offset {kernel_offset}, size {len(kernel_data)}")
        print(f"Kernel first 16 bytes: {kernel_data[:16].hex()}")
        
        # Try to decompress kernel
        for magic_name, magic, decomp_func in [
            ("gzip", b"\x1f\x8b\x08", lambda d: gzip.decompress(d)),
            ("XZ", b"\xfd\x37\x7a\x58\x5a\x00", lambda d: lzma.decompress(d)),
        ]:
            if kernel_data[:len(magic)] == magic:
                print(f"\nKernel compressed with {magic_name}!")
                try:
                    decomp = decomp_func(kernel_data)
                    print(f"Decompressed: {len(decomp)} bytes ({len(decomp)/1024/1024:.1f} MB)")
                    
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1: end = idx + 300
                        print(f"\n>> {decomp[idx:end].decode('utf-8', errors='replace')}")
                    
                    # Save kernel
                    outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                    with open(outpath, "wb") as f:
                        f.write(decomp)
                    print(f"Saved kernel to {outpath}")
                    
                    # Also save as Image (raw kernel)
                    outpath2 = os.path.join(OUTPUT_DIR, "kernel.Image")
                    with open(outpath2, "wb") as f:
                        f.write(decomp)
                    print(f"Saved kernel Image to {outpath2}")
                    
                    break
                except Exception as e:
                    print(f"Decompress failed: {e}")
        
        # Also check for LZ4
        if kernel_data[:4] == b"\x02\x21\x4c\x18":
            print("Kernel is LZ4 compressed (legacy)")
        elif kernel_data[:4] == b"\x04\x22\x4d\x18":
            print("Kernel is LZ4 compressed")
    else:
        print("\nNo ANDROID! header found")
    
    break

print("\nDone!")