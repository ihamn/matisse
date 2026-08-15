"""Debug: parse each operation's protobuf fields in detail"""
import struct

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

with open(PAYLOAD_PATH, "rb") as f:
    payload = f.read()

version = struct.unpack_from(">Q", payload, 4)[0]
manifest_size = struct.unpack_from(">Q", payload, 12)[0]
manifest_offset = 24
manifest_data = payload[manifest_offset:manifest_offset + manifest_size]
manifest = parse_protobuf(manifest_data)

data_start_bz = manifest_offset + manifest_size + struct.unpack_from(">I", payload, 20)[0]
data_start_raw = manifest_offset + manifest.get(14, [("varint", 0)])[0][1]

print(f"data_start_bz = {data_start_bz}")
print(f"data_start_raw = {data_start_raw}")

for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name != "boot":
        continue
    
    ops = p_dict.get(8, [])
    
    for op_idx, op_raw in enumerate(ops[:10]):  # First 10 ops
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        
        print(f"\n=== Op {op_idx} ===")
        for fn, values in sorted(op_dict.items()):
            for wt, val in values:
                if wt == "varint":
                    print(f"  field {fn}: varint = {val}")
                elif wt == "bytes":
                    if len(val) <= 64:
                        print(f"  field {fn}: bytes[{len(val)}] = {val.hex()}")
                    else:
                        print(f"  field {fn}: bytes[{len(val)}] = {val[:32].hex()}...")
                elif wt == "fixed64":
                    print(f"  field {fn}: fixed64 = {val}")
                elif wt == "fixed32":
                    print(f"  field {fn}: fixed32 = {val}")
        
        # Parse extents
        for fn in [4, 6]:
            if fn in op_dict:
                print(f"  field {fn} extents:")
                for ext in op_dict[fn]:
                    ext_dict = parse_protobuf(ext[1])
                    start = ext_dict.get(1, [("varint", 0)])[0][1]
                    num = ext_dict.get(2, [("varint", 0)])[0][1]
                    print(f"    ({start}, {num})")
        
        # For Op 0, check data at both data_start values
        if op_idx == 0:
            op_type = op_dict.get(1, [("varint", 0)])[0][1]
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            print(f"\n  Op 0: type={op_type}, data_offset={data_offset}, data_length={data_length}")
            
            # Check at data_start_raw
            off_raw = data_start_raw + data_offset
            print(f"  data_start_raw + data_offset = {off_raw}")
            print(f"    Data: {payload[off_raw:off_raw+32].hex()}")
            
            # Check at data_start_bz
            off_bz = data_start_bz + data_offset
            print(f"  data_start_bz + data_offset = {off_bz}")
            print(f"    Data: {payload[off_bz:off_bz+32].hex()}")
            
            # Check at data_start_bz (no sig)
            off_bz_nosig = (manifest_offset + manifest_size) + data_offset
            print(f"  (manifest_offset + manifest_size) + data_offset = {off_bz_nosig}")
            print(f"    Data: {payload[off_bz_nosig:off_bz_nosig+32].hex()}")
            
            # Check if data_offset is absolute (from file start)
            print(f"  Absolute offset {data_offset}:")
            print(f"    Data: {payload[data_offset:data_offset+32].hex()}")
    
    break