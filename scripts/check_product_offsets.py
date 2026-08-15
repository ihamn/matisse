"""Check data_offsets for boot and product partitions"""
import struct

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

payload = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin", "rb").read()
version = struct.unpack_from(">Q", payload, 4)[0]
manifest_size = struct.unpack_from(">Q", payload, 12)[0]
manifest_offset = 24
manifest_data = payload[manifest_offset:manifest_offset + manifest_size]
manifest = parse_protobuf(manifest_data)

for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    if name not in ("boot", "product"):
        continue
    
    ops = p_dict.get(8, [])
    print(f"=== {name} ({len(ops)} ops) ===")
    for op_idx, op_raw in enumerate(ops):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        data_offset = op_dict.get(2, [("varint", 0)])[0][1]
        data_length = op_dict.get(3, [("varint", 0)])[0][1]
        
        type_names = {0:"REPLACE",1:"REPLACE_BZ",2:"SOURCE_COPY",3:"SOURCE_BSDIFF",
                      4:"ZERO",5:"DISCARD",6:"REPLACE_XZ",7:"PUFFDIFF",8:"BROTLI_BSDIFF"}
        tname = type_names.get(op_type, str(op_type))
        
        # Get extents
        extents = op_dict.get(6, [])
        if not extents: extents = op_dict.get(4, [])
        ext_str = ""
        for e in extents[:3]:
            ed = parse_protobuf(e[1])
            s = ed.get(1, [("varint",0)])[0][1]
            n = ed.get(2, [("varint",0)])[0][1]
            ext_str += f"({s},{n})"
        
        print(f"  Op {op_idx}: {tname:15s} data_off={data_offset:10d} data_len={data_length:10d} ext={ext_str}")
    print()

# Now check: what data is at 227285 + 24758484?
data_start = 24 + manifest_size + struct.unpack_from(">I", payload, 20)[0]
print(f"data_start_bz = {data_start}")
print(f"Data at {data_start} + 24758484 = {data_start + 24758484}: {payload[data_start + 24758484:data_start + 24758484 + 16].hex()}")

# Check all partitions' first data_offset to find the data section boundaries
all_offsets = []
for p_raw in manifest.get(13, []):
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    ops = p_dict.get(8, [])
    for op_raw in ops:
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        data_offset = op_dict.get(2, [("varint", 0)])[0][1]
        if data_offset > 0:
            all_offsets.append((name, op_type, data_offset))

# Find the min data_offset
min_off = min(o[2] for o in all_offsets)
print(f"\nMin data_offset across all partitions: {min_off}")
print(f"data at {data_start} + {min_off} = {data_start + min_off}: {payload[data_start + min_off:data_start + min_off + 16].hex()}")