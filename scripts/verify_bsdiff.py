"""Verify BROTLI_BSDIFF operations - check if XZ decompression is correct or if we need actual bsdiff patching"""
import struct, os, lzma, bz2

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
    
    for op_idx, op_raw in enumerate(ops):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        
        if op_type == 8:  # BROTLI_BSDIFF
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            dst_extents = get_extents(op_dict, 6) or get_extents(op_dict, 4)
            
            print(f"\n=== Op {op_idx}: BROTLI_BSDIFF ===")
            print(f"  data_offset={data_offset}, data_length={data_length}")
            print(f"  dst_extents={[(s,n) for s,n in dst_extents]}")
            
            # Check data at data_start_bz
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            print(f"  Data at data_start_bz: first 32 bytes: {compressed[:32].hex()}")
            
            # Check data at data_start_raw
            raw_data = payload[data_start_raw + data_offset:data_start_raw + data_offset + min(data_length, 64)]
            print(f"  Data at data_start_raw: first 32 bytes: {raw_data[:32].hex()}")
            
            # Try XZ decompression
            print(f"  Trying XZ decompress...")
            try:
                decomp = lzma.decompress(compressed)
                print(f"  XZ OK: {len(decomp)} bytes")
                print(f"    First 32 bytes: {decomp[:32].hex()}")
                print(f"    as ASCII: {decomp[:64]}")
                # Check for common patterns
                if b"ANDROID" in decomp[:64]:
                    print(f"    Contains ANDROID!")
                if b"\x1f\x8b" in decomp[:64]:
                    print(f"    Contains gzip magic!")
                if decomp[:2] == b"MZ":
                    print(f"    Starts with MZ (PE executable?)")
            except Exception as e:
                print(f"  XZ FAILED: {e}")
            
            # Try to check if it's brotli-compressed
            try:
                import brotli
                decomp = brotli.decompress(compressed)
                print(f"  Brotli OK: {len(decomp)} bytes")
                print(f"    First 32 bytes: {decomp[:32].hex()}")
            except:
                print(f"  Brotli FAILED")
            
            # Try bzip2
            try:
                decomp = bz2.decompress(compressed)
                print(f"  Bzip2 OK: {len(decomp)} bytes")
                print(f"    First 32 bytes: {decomp[:32].hex()}")
            except:
                print(f"  Bzip2 FAILED")

    break

print("\n\n=== Also check REPLACE op data ===")
for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "boot":
        continue
    
    ops = p_dict.get(8, [])
    
    # Check Op 1 REPLACE data
    for op_idx in [1]:  # Just check Op 1 which is REPLACE
        op_raw = ops[op_idx]
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        data_offset = op_dict.get(2, [("varint", 0)])[0][1]
        data_length = op_dict.get(3, [("varint", 0)])[0][1]
        dst_extents = get_extents(op_dict, 6)
        
        print(f"\nOp {op_idx}: type={op_type}, data_offset={data_offset}, data_length={data_length}")
        print(f"  dst_extents={[(s,n) for s,n in dst_extents]}")
        
        raw_data = payload[data_start_raw + data_offset:data_start_raw + data_offset + 64]
        print(f"  Data at data_start_raw: {raw_data[:64].hex()}")
        print(f"  as ASCII: {raw_data[:64]}")
        
        bz_data = payload[data_start_bz + data_offset:data_start_bz + data_offset + 64]
        print(f"  Data at data_start_bz: {bz_data[:64].hex()}")
        print(f"  as ASCII: {bz_data[:64]}")

    # Check REPLACE_BZ operations
    print("\n=== REPLACE_BZ operations ===")
    for op_idx in [10, 11, 31]:
        if op_idx >= len(ops):
            continue
        op_raw = ops[op_idx]
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        data_offset = op_dict.get(2, [("varint", 0)])[0][1]
        data_length = op_dict.get(3, [("varint", 0)])[0][1]
        dst_extents = get_extents(op_dict, 6)
        
        print(f"\nOp {op_idx}: type={op_type}, data_offset={data_offset}, data_length={data_length}")
        print(f"  dst_extents={[(s,n) for s,n in dst_extents]}")
        
        bz_data = payload[data_start_bz + data_offset:data_start_bz + data_offset + min(data_length, 64)]
        print(f"  Data at data_start_bz: {bz_data[:64].hex()}")
        
        try:
            decomp = bz2.decompress(bz_data)
            print(f"  Bzip2 decomp: {len(decomp)} bytes, first: {decomp[:32].hex()}")
        except Exception as e:
            print(f"  Bzip2 FAILED: {e}")

print("\nDone!")