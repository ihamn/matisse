"""Verify kernel data at the failure boundary and try to fix it"""
import struct, os, lzma, zlib, gzip

# RECONSTRUCT THE KERNEL FROM SCRATCH using payload.bin operations
# This avoids any issues with the previous boot image reconstruction

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
    print(f"Boot: {max_block} blocks = {total_size} bytes")
    
    # RECONSTRUCT THE BOOT IMAGE
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
        
        elif op_type == 1:  # REPLACE_BZ
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                import bz2
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
        
        elif op_type == 8:  # BROTLI_BSDIFF - XZ decompressed
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start_bz + data_offset:data_start_bz + data_offset + data_length]
            try:
                decompressed = lzma.decompress(compressed)
            except:
                decompressed = compressed
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = decompressed[:ln]
                decompressed = decompressed[ln:]
    
    # Now extract kernel from the reconstructed boot image
    header = boot_img[:4096]
    kernel_size = struct.unpack_from("<I", header, 8)[0]
    kernel_data = boot_img[4096:4096 + kernel_size]
    
    print(f"Kernel size: {kernel_size} ({kernel_size/1024/1024:.1f} MB)")
    print(f"Kernel data length: {len(kernel_data)}")
    
    # Check the gzip header
    print(f"Gzip header: {kernel_data[:10].hex()}")
    
    # Check data at the failure point
    # Failure at compressed position 2031616, boot offset 4096 + 10 + 2031616 = 2035722
    fail_offset = 2035722
    print(f"\nData at failure offset {fail_offset}:")
    print(f"  Hex: {kernel_data[fail_offset:fail_offset+32].hex()}")
    print(f"  Block: {fail_offset // 4096}, offset in block: {fail_offset % 4096}")
    
    # Check the block containing the failure point
    block = fail_offset // 4096
    print(f"\nBlock {block} is from:")
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        for s, n in dst_extents:
            if s <= block < s + n:
                print(f"  Op {op_idx}: type={op_type}, blocks ({s}, {n})")
    
    # Try to decompress the kernel with Python's gzip module, but with error handling
    print("\n\n=== Attempting gzip decompression with error handling ===")
    
    # Try to decompress as much as possible and save partial data
    import io
    try:
        # Use gzip.GzipFile with the raw data
        buf = io.BytesIO(kernel_data)
        with gzip.GzipFile(fileobj=buf, mode='rb') as gf:
            try:
                decomp = gf.read()
                print(f"Full decompress: {len(decomp)} bytes")
            except Exception as e:
                print(f"GzipFile read failed: {e}")
                # Try to read what we have
                try:
                    partial = gf.read(10 * 1024 * 1024)  # Read up to 10MB
                    print(f"Partial read: {len(partial)} bytes")
                except:
                    pass
    except Exception as e:
        print(f"GzipFile open failed: {e}")
    
    # Try to use zlib to decompress chunk by chunk, with better error handling
    print("\n\n=== Chunk-by-chunk raw deflate decompression ===")
    dobj = zlib.decompressobj(-15)  # raw deflate
    result = bytearray()
    data = kernel_data[10:]  # skip gzip header
    pos = 0
    chunk_size = 4096  # Smaller chunks for better error localization
    
    while pos < len(data):
        chunk = data[pos:pos + chunk_size]
        if not chunk:
            break
        try:
            result.extend(dobj.decompress(chunk))
        except Exception as e:
            print(f"Error at compressed pos {pos} (boot offset {4096 + 10 + pos}): {e}")
            print(f"  Block: {(4096 + 10 + pos) // 4096}")
            print(f"  Decompressed so far: {len(result)} bytes")
            
            # Check if this is a block boundary issue
            print(f"  Chunk data at failure: {chunk[:32].hex()}")
            break
        pos += chunk_size
    
    print(f"\nPartial decompressed: {len(result)} bytes ({len(result)/1024/1024:.1f} MB)")
    
    # Save the partial decompressed data
    outpath = os.path.join(OUTPUT_DIR, "kernel_efi_partial.bin")
    with open(outpath, "wb") as f:
        f.write(result)
    print(f"Saved to: {outpath}")
    
    # Try a different approach: try to decompress as a multi-member gzip
    print("\n\n=== Trying multi-member gzip ===")
    # Some files are concatenated gzip members
    try:
        result2 = bytearray()
        pos = 0
        while pos < len(kernel_data):
            if pos + 2 > len(kernel_data):
                break
            if kernel_data[pos:pos+2] == b"\x1f\x8b":
                # Try to decompress one gzip member
                try:
                    # Find the end of this gzip member
                    # Use gzip.decompress which handles one member
                    d = gzip.decompress(kernel_data[pos:])
                    result2.extend(d)
                    print(f"  Member at {pos}: {len(d)} bytes decompressed")
                    
                    # We need to find where this member ended
                    # gzip.decompress handles this internally, but we need to know
                    # how many bytes were consumed. This is tricky.
                    # Let's just break after the first successful member for now
                    # and try to find the next member manually
                    
                    # Find the next gzip magic after the current position
                    search_start = pos + 10  # minimum gzip header size
                    next_pos = kernel_data.find(b"\x1f\x8b", search_start)
                    if next_pos > 0:
                        pos = next_pos
                    else:
                        break
                except Exception as e:
                    print(f"  Member at {pos} failed: {e}")
                    break
            else:
                pos += 1
        if result2:
            print(f"Total multi-member: {len(result2)} bytes")
            if b"Linux version" in result2:
                idx = result2.find(b"Linux version")
                print(f">> {result2[idx:idx+200].decode('utf-8', errors='replace')}")
    except Exception as e:
        print(f"Multi-member failed: {e}")

    break

print("\nDone!")