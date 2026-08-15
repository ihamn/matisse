"""Extract boot.img from Android OTA payload.bin"""
import os
import struct
import sys

# Protobuf definitions for ChromeOS update_engine
# We'll parse the payload manually since the proto might be complex

PAYLOAD_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358"
PAYLOAD_PATH = os.path.join(PAYLOAD_DIR, "payload.bin")
OUTPUT_DIR = os.path.join(PAYLOAD_DIR, "extracted")

os.makedirs(OUTPUT_DIR, exist_ok=True)

def read_be_uint64(data, offset):
    return struct.unpack_from(">Q", data, offset)[0]

def read_le_uint64(data, offset):
    return struct.unpack_from("<Q", data, offset)[0]

def read_le_uint32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]

# Read the payload.bin
with open(PAYLOAD_PATH, "rb") as f:
    payload_data = f.read()

print(f"Payload size: {len(payload_data)} bytes ({len(payload_data)/1024/1024/1024:.2f} GB)")

# Check magic bytes - ChromeOS update payload magic
# The first 4 bytes should be the magic "CrAU"
magic = payload_data[:4]
print(f"Magic: {magic}")

# The payload format:
# Magic (4 bytes): "CrAU"
# Version (8 bytes, big-endian uint64)
# Manifest size (8 bytes, big-endian uint64)
# Manifest signature size (4 bytes, big-endian uint32, v2 only)
# Manifest (protobuf)
# Data blobs

version = read_be_uint64(payload_data, 4)
print(f"Payload version: {version}")

if version == 2:
    manifest_size = read_be_uint64(payload_data, 12)
    manifest_sig_size = read_le_uint32(payload_data, 20)
    manifest_offset = 24
elif version == 1:
    manifest_size = read_be_uint64(payload_data, 12)
    manifest_sig_size = 0
    manifest_offset = 20
else:
    print(f"Unknown payload version: {version}")
    sys.exit(1)

print(f"Manifest size: {manifest_size} bytes")
print(f"Manifest sig size: {manifest_sig_size} bytes")

manifest_data = payload_data[manifest_offset:manifest_offset + manifest_size]

# Parse the protobuf manifest
# We'll use a simple approach - extract field markers
# The delta_archive_manifest proto has:
# - partitions_metadata (field 13, repeated)
#   - partition_name (field 1, string)
#   - operations (field 8, repeated InstallOperation)
#     - type (field 1, enum)
#     - data_offset (field 2, uint64)
#     - data_length (field 3, uint64)
#     - src_length (field 5, uint64)
#     - dst_extents (field 4, repeated)
#       - start_block (field 1, uint64)
#       - num_blocks (field 2, uint64)
#     - src_extents (field 6, repeated)

# Actually, let's just use the protobuf library
try:
    from google.protobuf import descriptor_pb2, message
    import google.protobuf.internal.decoder as decoder
    import google.protobuf.internal.encoder as encoder
except ImportError:
    print("protobuf not available")
    sys.exit(1)

# Let's use a simpler approach: parse the protobuf manually
# We'll look for partition names and their operations

from google.protobuf.internal import decoder as _decoder
from google.protobuf.internal import wire_format

# Simple protobuf parser
def parse_varint(data, pos):
    """Parse a varint from data starting at pos. Returns (value, new_pos)"""
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

def parse_length_delimited(data, pos):
    """Parse a length-delimited field. Returns (value_bytes, new_pos)"""
    length, pos = parse_varint(data, pos)
    if length is None:
        return None, pos
    return data[pos:pos + length], pos + length

def parse_protobuf(data):
    """Parse a protobuf message into a dict. Returns dict."""
    result = {}
    pos = 0
    while pos < len(data):
        tag, pos = parse_varint(data, pos)
        if tag is None:
            break
        field_number = tag >> 3
        wire_type = tag & 0x7
        
        if wire_type == 0:  # Varint
            value, pos = parse_varint(data, pos)
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(('varint', value))
        elif wire_type == 2:  # Length-delimited
            value_bytes, pos = parse_length_delimited(data, pos)
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(('bytes', value_bytes))
        elif wire_type == 1:  # 64-bit
            value = struct.unpack_from('<Q', data, pos)[0]
            pos += 8
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(('fixed64', value))
        elif wire_type == 5:  # 32-bit
            value = struct.unpack_from('<I', data, pos)[0]
            pos += 4
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(('fixed32', value))
        else:
            print(f"Unknown wire type: {wire_type} at pos {pos}")
            break
    return result

manifest = parse_protobuf(manifest_data)

# Find partitions (field 13 in DeltaArchiveManifest)
partitions_raw = manifest.get(13, [])
print(f"\nNumber of partitions: {len(partitions_raw)}")

BLOCK_SIZE = 4096
data_start = manifest_offset + manifest_size

# Check for signatures_offset (field 14)
if 14 in manifest:
    signatures_offset = manifest[14][0][1]  # varint value
    if signatures_offset:
        data_start = manifest_offset + signatures_offset
        print(f"Signatures offset: {signatures_offset}")

print(f"Data section starts at offset: {data_start}")

for p_idx, p_raw in enumerate(partitions_raw):
    p_data = p_raw[1]  # bytes
    p_dict = parse_protobuf(p_data)
    
    name = ""
    if 1 in p_dict:
        name = p_dict[1][0][1].decode('utf-8', errors='replace')
    
    print(f"\n--- Partition: {name} ---")
    
    operations = p_dict.get(8, [])
    print(f"  Operations: {len(operations)}")
    
    extracted_data = bytearray()
    
    for op_idx, op_raw in enumerate(operations):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        
        op_type = op_dict.get(1, [('varint', 0)])[0][1]
        op_type_names = {
            0: "REPLACE", 1: "REPLACE_BZ", 2: "SOURCE_COPY",
            3: "SOURCE_BSDIFF", 4: "ZERO", 5: "DISCARD",
            6: "REPLACE_XZ", 7: "PUFFDIFF", 8: "BROTLI_BSDIFF",
            9: "REPLACE_ZSTD", 10: "REPLACE_LZ4DIFF"
        }
        op_name = op_type_names.get(op_type, f"UNKNOWN({op_type})")
        
        dst_extents = op_dict.get(4, [])
        total_dst_blocks = 0
        for ext in dst_extents:
            ext_dict = parse_protobuf(ext[1])
            num_blocks = ext_dict.get(2, [('varint', 0)])[0][1]
            total_dst_blocks += num_blocks
        
        if op_name == "REPLACE_XZ":
            print(f"  Op {op_idx}: {op_name}, dst_blocks={total_dst_blocks}")
        else:
            print(f"  Op {op_idx}: {op_name}, dst_blocks={total_dst_blocks}")
        
        if op_type == 0:  # REPLACE - raw data
            data_offset = op_dict.get(2, [('varint', 0)])[0][1]
            data_length = op_dict.get(3, [('varint', 0)])[0][1]
            
            chunk = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            extracted_data.extend(chunk)
            print(f"    data_offset={data_offset}, data_length={data_length}, extracted={len(chunk)}")
        
        elif op_type == 6:  # REPLACE_XZ
            data_offset = op_dict.get(2, [('varint', 0)])[0][1]
            data_length = op_dict.get(3, [('varint', 0)])[0][1]
            
            compressed = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            try:
                import lzma
                decompressed = lzma.decompress(compressed)
                extracted_data.extend(decompressed)
                print(f"    data_offset={data_offset}, data_length={data_length}, decompressed={len(decompressed)}")
            except Exception as e:
                print(f"    XZ decompress failed: {e}")
                extracted_data.extend(compressed)
        
        elif op_type == 4:  # ZERO
            # Fill with zeros
            extracted_data.extend(b'\x00' * (total_dst_blocks * BLOCK_SIZE))
            print(f"    zero fill: {total_dst_blocks * BLOCK_SIZE} bytes")
        
        elif op_type == 2:  # SOURCE_COPY
            # This copies from the source (old) partition - we don't have it
            # For incremental OTAs, this would need the source partition
            src_extents = op_dict.get(6, [])
            if src_extents:
                print(f"    SOURCE_COPY from old partition - need source image")
                extracted_data.extend(b'\x00' * (total_dst_blocks * BLOCK_SIZE))
            else:
                extracted_data.extend(b'\x00' * (total_dst_blocks * BLOCK_SIZE))
    
    if name == "boot":
        output_path = os.path.join(OUTPUT_DIR, "boot.img")
        with open(output_path, "wb") as f:
            f.write(extracted_data)
        print(f"\n  >> Saved boot.img: {len(extracted_data)} bytes to {output_path}")
    elif extracted_data:
        output_path = os.path.join(OUTPUT_DIR, f"{name}.img")
        with open(output_path, "wb") as f:
            f.write(extracted_data)
        print(f"  Saved {name}.img: {len(extracted_data)} bytes")

print("\n=== Extraction complete ===")