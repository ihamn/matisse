"""Try ALL data source combinations to find the correct one that produces a valid gzip kernel"""
import struct, os, lzma, zlib, bz2

PAYLOAD_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

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

BLOCK_SIZE = 4096

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
    
    # Try different strategies for data source
    strategies = [
        # (name, {op_type: data_start})
        ("ALL from data_start_bz", {0: data_start_bz, 1: data_start_bz, 8: data_start_bz}),
        ("ALL from data_start_raw", {0: data_start_raw, 1: data_start_raw, 8: data_start_raw}),
        ("REPLACE_RAW + REPLACE_BZ_BZ + BROTLI_BZ", {0: data_start_raw, 1: data_start_bz, 8: data_start_bz}),
        ("REPLACE_BZ + REPLACE_BZ_RAW + BROTLI_BZ", {0: data_start_bz, 1: data_start_raw, 8: data_start_bz}),
        ("REPLACE_BZ + REPLACE_BZ_BZ + BROTLI_RAW", {0: data_start_bz, 1: data_start_bz, 8: data_start_raw}),
        ("REPLACE_RAW + REPLACE_BZ_RAW + BROTLI_BZ", {0: data_start_raw, 1: data_start_raw, 8: data_start_bz}),
    ]
    
    for strategy_name, strategy in strategies:
        print(f"\n\n=== Strategy: {strategy_name} ===")
        
        boot_img = bytearray(total_size)
        
        for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
            ds = strategy.get(op_type, data_start_bz)
            
            if op_type == 0:  # REPLACE - raw
                data_offset = op_dict.get(2, [("varint", 0)])[0][1]
                data_length = op_dict.get(3, [("varint", 0)])[0][1]
                chunk = payload[ds + data_offset:ds + data_offset + data_length]
                for s, n in dst_extents:
                    off = s * BLOCK_SIZE
                    ln = n * BLOCK_SIZE
                    boot_img[off:off + ln] = chunk[:ln]
                    chunk = chunk[ln:]
            
            elif op_type == 1:  # REPLACE_BZ
                data_offset = op_dict.get(2, [("varint", 0)])[0][1]
                data_length = op_dict.get(3, [("varint", 0)])[0][1]
                compressed = payload[ds + data_offset:ds + data_offset + data_length]
                try:
                    decompressed = bz2.decompress(compressed)
                except:
                    decompressed = compressed
                for s, n in dst_extents:
                    off = s * BLOCK_SIZE
                    ln = n * BLOCK_SIZE
                    boot_img[off:off + ln] = decompressed[:ln]
                    decompressed = decompressed[ln:]
            
            elif op_type == 4:  # ZERO
                for s, n in dst_extents:
                    off = s * BLOCK_SIZE
                    ln = n * BLOCK_SIZE
                    boot_img[off:off + ln] = b'\x00' * ln
            
            elif op_type == 8:  # BROTLI_BSDIFF
                data_offset = op_dict.get(2, [("varint", 0)])[0][1]
                data_length = op_dict.get(3, [("varint", 0)])[0][1]
                compressed = payload[ds + data_offset:ds + data_offset + data_length]
                try:
                    decompressed = lzma.decompress(compressed)
                except:
                    try:
                        decompressed = bz2.decompress(compressed)
                    except:
                        decompressed = compressed
                for s, n in dst_extents:
                    off = s * BLOCK_SIZE
                    ln = n * BLOCK_SIZE
                    boot_img[off:off + ln] = decompressed[:ln]
                    decompressed = decompressed[ln:]
        
        # Check for ANDROID! header
        pos = boot_img.find(b"ANDROID!")
        if pos >= 0:
            header = boot_img[pos:pos+4096]
            kernel_size = struct.unpack_from("<I", header, 8)[0]
            print(f"  ANDROID! at offset {pos}, kernel_size={kernel_size}")
            
            kernel_data = boot_img[4096:4096 + kernel_size]
            print(f"  Kernel data: {len(kernel_data)} bytes")
            print(f"  First 10: {kernel_data[:10].hex()}")
            
            # Try to decompress
            if kernel_data[:2] == b"\x1f\x8b":
                # Try raw deflate
                try:
                    dobj = zlib.decompressobj(-15)
                    data = kernel_data[10:]
                    result = dobj.decompress(data[:2093056])  # Up to the boundary
                    result += dobj.flush()
                    print(f"  Deflate decompressed: {len(result)} bytes so far")
                    print(f"  First 20 as hex: {result[:20].hex()}")
                    if b"Linux version" in result:
                        idx = result.find(b"Linux version")
                        print(f"  >> {result[idx:idx+200].decode('utf-8', errors='replace')}")
                except Exception as e:
                    print(f"  Deflate failed: {str(e)[:80]}")
                
                # Also try gzip
                try:
                    import gzip
                    decomp = gzip.decompress(kernel_data)
                    print(f"  Gzip decompressed: {len(decomp)} bytes")
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        print(f"  >> {decomp[idx:idx+200].decode('utf-8', errors='replace')}")
                except Exception as e:
                    print(f"  Gzip failed: {str(e)[:80]}")
        else:
            print("  No ANDROID! header found")

    break

print("\n\nDone!")