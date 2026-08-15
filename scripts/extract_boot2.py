"""Extract boot.img from OTA payload with proper extent handling"""
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
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(("varint", value))
        elif wire_type == 2:
            length, pos = parse_varint(data, pos)
            if length is None:
                break
            value_bytes = data[pos:pos + length]
            pos += length
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(("bytes", value_bytes))
        elif wire_type == 1:
            value = struct.unpack_from("<Q", data, pos)[0]
            pos += 8
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(("fixed64", value))
        elif wire_type == 5:
            value = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            if field_number not in result:
                result[field_number] = []
            result[field_number].append(("fixed32", value))
        else:
            break
    return result

def get_extents(op_dict, field_num):
    """Get extents (start_block, num_blocks) from an operation"""
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

# Parse header
version = struct.unpack_from(">Q", payload_data, 4)[0]
manifest_size = struct.unpack_from(">Q", payload_data, 12)[0]
if version == 2:
    manifest_sig_size = struct.unpack_from("<I", payload_data, 20)[0]
    manifest_offset = 24
else:
    manifest_sig_size = 0
    manifest_offset = 20

manifest_data = payload_data[manifest_offset:manifest_offset + manifest_size]
manifest = parse_protobuf(manifest_data)

# Find data section start
data_start = manifest_offset + manifest_size
if 14 in manifest:
    sig_offset = manifest[14][0][1]
    if sig_offset:
        data_start = manifest_offset + sig_offset

print(f"Data section starts at: {data_start}")

# Process partitions
partitions = manifest.get(13, [])
for p_raw in partitions:
    p_data = p_raw[1]
    p_dict = parse_protobuf(p_data)
    name = p_dict.get(1, [("bytes", b"")])[0][1].decode("utf-8", errors="replace")
    
    if name != "boot":
        continue
    
    # Find the total size of the boot partition
    new_partition_info = p_dict.get(13, [])
    total_size = 0
    if new_partition_info:
        ni_dict = parse_protobuf(new_partition_info[0][1])
        total_size = ni_dict.get(1, [("varint", 0)])[0][1]
    print(f"Boot partition total size: {total_size} bytes")
    
    # Create output buffer
    boot_img = bytearray(total_size)
    
    operations = p_dict.get(8, [])
    print(f"Processing {len(operations)} operations...")
    
    for op_idx, op_raw in enumerate(operations):
        op_data = op_raw[1]
        op_dict = parse_protobuf(op_data)
        op_type = op_dict.get(1, [("varint", 0)])[0][1]
        
        dst_extents = get_extents(op_dict, 4)
        
        if op_type == 0:  # REPLACE
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload_data[data_start + data_offset:data_start + data_offset + data_length]
            
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                boot_img[dst_offset:dst_offset + dst_len] = chunk[:dst_len]
                chunk = chunk[dst_len:]
                print(f"  Op {op_idx}: REPLACE {dst_len} bytes at offset {dst_offset}")
        
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
                print(f"  Op {op_idx}: REPLACE_XZ {dst_len} bytes at offset {dst_offset}")
        
        elif op_type == 4:  # ZERO
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                boot_img[dst_offset:dst_offset + dst_len] = b'\x00' * dst_len
                print(f"  Op {op_idx}: ZERO {dst_len} bytes at offset {dst_offset}")
        
        elif op_type in (1, 8):  # REPLACE_BZ, BROTLI_BSDIFF - need source
            for start_block, num_blocks in dst_extents:
                dst_offset = start_block * BLOCK_SIZE
                dst_len = num_blocks * BLOCK_SIZE
                print(f"  Op {op_idx}: NEED_SOURCE type={op_type} {dst_len} bytes at offset {dst_offset}")
    
    # Now check if we have an ANDROID! header
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        print(f"\nFound ANDROID! header at offset {pos}")
        header = boot_img[:4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        kernel_addr = struct.unpack_from("<I", header, 12)[0]
        ramdisk_size = struct.unpack_from("<I", header, 16)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"kernel_size={kernel_size}, page_size={page_size}, kernel_addr=0x{kernel_addr:08x}")
        print(f"ramdisk_size={ramdisk_size}")
        
        # Extract kernel from boot image
        kernel_offset = page_size
        kernel_data = bytes(boot_img[kernel_offset:kernel_offset + kernel_size])
        
        # Try to decompress kernel
        for magic_name, magic_bytes, decomp_func in [
            ("gzip", b"\x1f\x8b", lambda d: gzip.decompress(d)),
            ("XZ", b"\xfd\x37\x7a\x58", lambda d: lzma.decompress(d)),
        ]:
            if kernel_data[:len(magic_bytes)] == magic_bytes:
                try:
                    decomp = decomp_func(kernel_data)
                    print(f"Kernel compressed with {magic_name}, decompressed to {len(decomp)} bytes")
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1: end = idx + 200
                        print(f">> {decomp[idx:end].decode('utf-8', errors='replace')}")
                    
                    outpath = os.path.join(OUTPUT_DIR, "kernel_decompressed")
                    with open(outpath, "wb") as f:
                        f.write(decomp)
                    print(f"Saved decompressed kernel to {outpath}")
                    
                    # Also save kernel config if available
                    # IKCFG typically starts with a magic number
                    cfg_pos = decomp.find(b"IKCFG_ST")
                    if cfg_pos >= 0:
                        print(f"Found IKCFG at offset {cfg_pos}")
                    break
                except Exception as e:
                    print(f"{magic_name} decompress failed: {e}")
    
    # Save the boot image
    outpath = os.path.join(OUTPUT_DIR, "boot_full.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"\nSaved full boot image: {len(boot_img)} bytes to {outpath}")
    break

print("\nDone")