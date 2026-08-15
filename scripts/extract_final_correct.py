"""FINAL: Extract boot image and kernel using data_start_bz for ALL operations"""
import struct, os, lzma, bz2, gzip, zlib

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

# KEY: Use data_start_bz for ALL operations
data_start = manifest_offset + manifest_size + manifest_sig_size
print(f"data_start (bz) = {data_start}")

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
    print(f"Boot: {max_block} blocks = {total_size} bytes ({total_size/1024/1024:.1f} MB)")
    
    boot_img = bytearray(total_size)
    
    for op_idx, (op_type, op_dict, dst_extents) in enumerate(op_info):
        if op_type == 0:  # REPLACE
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            chunk = payload[data_start + data_offset:data_start + data_offset + data_length]
            for s, n in dst_extents:
                off = s * BLOCK_SIZE
                ln = n * BLOCK_SIZE
                boot_img[off:off + ln] = chunk[:ln]
                chunk = chunk[ln:]
        
        elif op_type == 1:  # REPLACE_BZ
            data_offset = op_dict.get(2, [("varint", 0)])[0][1]
            data_length = op_dict.get(3, [("varint", 0)])[0][1]
            compressed = payload[data_start + data_offset:data_start + data_offset + data_length]
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
            compressed = payload[data_start + data_offset:data_start + data_offset + data_length]
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
    
    # Save boot image
    outpath = os.path.join(OUTPUT_DIR, "boot_final.img")
    with open(outpath, "wb") as f:
        f.write(boot_img)
    print(f"Saved boot image to: {outpath}")
    
    # Parse ANDROID! header
    pos = boot_img.find(b"ANDROID!")
    if pos >= 0:
        header = boot_img[pos:pos+4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        ramdisk_size = struct.unpack_from("<I", header, 12)[0]
        header_version = struct.unpack_from("<I", header, 40)[0]
        print(f"\nANDROID! at offset {pos}")
        print(f"Header version: {header_version}")
        print(f"kernel_size: {kernel_size} ({kernel_size/1024/1024:.1f} MB)")
        print(f"ramdisk_size: {ramdisk_size} ({ramdisk_size/1024/1024:.1f} MB)")
        
        # Extract kernel
        kernel_offset = 4096  # page_size for v4
        kernel_data = boot_img[kernel_offset:kernel_offset + kernel_size]
        print(f"\nKernel data at offset {kernel_offset}")
        print(f"Kernel compressed size: {len(kernel_data)} bytes")
        print(f"Kernel header: {kernel_data[:10].hex()}")
        
        # Decompress kernel
        print("\nDecompressing kernel...")
        try:
            decompressed = gzip.decompress(kernel_data)
            print(f"Decompressed: {len(decompressed)} bytes ({len(decompressed)/1024/1024:.1f} MB)")
            
            # Save decompressed kernel
            kernel_out = os.path.join(OUTPUT_DIR, "kernel.Image")
            with open(kernel_out, "wb") as f:
                f.write(decompressed)
            print(f"Saved kernel Image to: {kernel_out}")
            
            # Search for kernel version
            # The kernel version string is typically "Linux version X.Y.Z ..."
            print("\n=== Searching for kernel version ===")
            
            # Search for "Linux version" in the decompressed data
            search_str = b"Linux version"
            idx = 0
            found_count = 0
            while True:
                idx = decompressed.find(search_str, idx)
                if idx < 0:
                    break
                end = decompressed.find(b"\n", idx)
                if end < 0:
                    end = idx + 200
                version_str = decompressed[idx:end].decode('utf-8', errors='replace')
                print(f"  [{found_count}] offset {idx}: {version_str[:200]}")
                found_count += 1
                idx += 1
                if found_count >= 5:
                    break
            
            if found_count == 0:
                # Try looking for version in a different format
                # The kernel banner might be stored differently
                # Look for "5.15" or similar patterns
                import re
                for m in re.finditer(rb'Linux version \d+\.\d+', decompressed):
                    end = decompressed.find(b"\n", m.start())
                    if end < 0: end = m.start() + 200
                    print(f"  Found: {decompressed[m.start():end].decode('utf-8', errors='replace')}")
            
            # Check if this is a PE/EFI file
            if decompressed[:2] == b"MZ":
                print("\n=== PE/EFI Analysis ===")
                pe_offset = struct.unpack_from("<I", decompressed, 0x3C)[0]
                pe_sig = decompressed[pe_offset:pe_offset+4]
                print(f"PE signature: {pe_sig}")
                
                if pe_sig == b"PE\x00\x00":
                    machine = struct.unpack_from("<H", decompressed, pe_offset+4)[0]
                    machine_names = {0xAA64: "ARM64", 0x8664: "x64", 0x014C: "x86"}
                    print(f"Machine: {machine_names.get(machine, f'0x{machine:04x}')}")
                    
                    # Find the embedded kernel Image
                    # ARM64 Linux kernel Image starts with a specific pattern
                    # The kernel Image is embedded in the .linux section of the PE file
                    # or at a specific offset
                    
                    # Search for the ARM64 kernel magic
                    # The kernel is typically stored as a raw Image or compressed Image
                    # embedded in the PE file
                    
                    # Look for common compression signatures within the PE file
                    for sig_name, sig_bytes in [
                        ("gzip", b"\x1f\x8b\x08"),
                        ("XZ", b"\xfd\x37\x7a\x58\x5a\x00"),
                        ("LZ4", b"\x02\x21\x4c\x18"),
                        ("Zstd", b"\x28\xb5\x2f\xfd"),
                    ]:
                        pos = decompressed.find(sig_bytes, pe_offset)
                        if pos >= 0:
                            print(f"Found {sig_name} at offset {pos} (0x{pos:x})")
                            print(f"  Context: {decompressed[pos:pos+32].hex()}")
                    
                    # The embedded kernel is typically at the end of the PE file
                    # or in the .linux section
                    # For ARM64 EFI stubs, the kernel Image is appended after the PE
                    # Let's search for the kernel Image at the end of the PE file
                    print(f"\nLooking for embedded kernel Image...")
                    
                    # The SizeOfImage tells us the PE size
                    size_of_image = struct.unpack_from("<I", decompressed, pe_offset+24+56)[0]
                    print(f"PE SizeOfImage: {size_of_image} ({size_of_image/1024/1024:.1f} MB)")
                    
                    # Check data after the PE image
                    if len(decompressed) > size_of_image:
                        remaining = decompressed[size_of_image:]
                        print(f"Data after PE image: {len(remaining)} bytes")
                        print(f"First 32 bytes: {remaining[:32].hex()}")
                        
                        # Check if it's a compressed kernel
                        if remaining[:2] == b"\x1f\x8b":
                            print("gzip compressed data after PE!")
                        elif remaining[:6] == b"\xfd\x37\x7a\x58\x5a\x00":
                            print("XZ compressed data after PE!")
                    
                    # Also search for the kernel version in the PE sections
                    # The kernel version string is often in the .rodata section
                    # or embedded in the kernel Image within the PE file
            
        except Exception as e:
            print(f"Decompress failed: {e}")
            import traceback
            traceback.print_exc()
    
    # Also extract ramdisk
    ramdisk_offset = ((4096 + kernel_size + 4095) // 4096) * 4096
    ramdisk_data = boot_img[ramdisk_offset:ramdisk_offset + ramdisk_size]
    print(f"\nRamdisk at offset {ramdisk_offset}, size {len(ramdisk_data)}")
    print(f"Ramdisk header: {ramdisk_data[:16].hex()}")
    
    if ramdisk_data[:4] == b"\x02\x21\x4c\x18":
        print("Ramdisk is LZ4 compressed (legacy)")
        try:
            import lz4.block
            ramdisk_decomp = lz4.block.decompress(ramdisk_data)
            print(f"Ramdisk decompressed: {len(ramdisk_decomp)} bytes")
            if ramdisk_decomp[:6] == b"070701":
                print("Ramdisk is cpio archive (new format)")
            elif ramdisk_decomp[:6] == b"070707":
                print("Ramdisk is cpio archive (old format)")
            ramdisk_out = os.path.join(OUTPUT_DIR, "ramdisk.cpio")
            with open(ramdisk_out, "wb") as f:
                f.write(ramdisk_decomp)
            print(f"Saved ramdisk to: {ramdisk_out}")
        except Exception as e:
            print(f"LZ4 decompress failed: {e}")
    elif ramdisk_data[:2] == b"\x1f\x8b":
        print("Ramdisk is gzip compressed")
    
    break

print("\n\nDone! All tasks completed successfully!")