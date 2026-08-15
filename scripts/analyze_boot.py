import gzip, lzma, struct, os, zlib

data = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot.img", "rb").read()

chunk_size = 2097152
for chunk_idx in range(5):
    chunk_start = chunk_idx * chunk_size
    chunk = data[chunk_start:chunk_start + chunk_size]
    
    print(f"=== Chunk {chunk_idx} (offset {chunk_start}) ===")
    print(f"  First 32 bytes: {chunk[:32].hex()}")
    
    for magic_name, magic_bytes in [
        ("gzip", b"\x1f\x8b"),
        ("LZ4", b"\x02\x21\x4c\x18"),
        ("XZ", b"\xfd\x37\x7a\x58"),
        ("ZSTD", b"\x28\xb5\x2f\xfd"),
    ]:
        pos = chunk.find(magic_bytes)
        if pos >= 0:
            print(f"  Found {magic_name} at offset {pos}")
            
            if magic_name == "gzip":
                try:
                    decomp = gzip.decompress(chunk[pos:])
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1:
                            end = idx + 200
                        ver_str = decomp[idx:end].decode("utf-8", errors="replace")
                        print(f"  >> Kernel: {ver_str}")
                        outpath = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\kernel_decompressed"
                        with open(outpath, "wb") as f:
                            f.write(decomp)
                        print(f"  >> Saved decompressed kernel: {len(decomp)} bytes")
                except Exception as e:
                    print(f"  gzip decompress failed: {type(e).__name__}: {e}")
            
            elif magic_name == "XZ":
                try:
                    decomp = lzma.decompress(chunk[pos:])
                    if b"Linux version" in decomp:
                        idx = decomp.find(b"Linux version")
                        end = decomp.find(b"\n", idx)
                        if end == -1:
                            end = idx + 200
                        ver_str = decomp[idx:end].decode("utf-8", errors="replace")
                        print(f"  >> Kernel (XZ): {ver_str}")
                except Exception as e:
                    print(f"  XZ decompress failed: {type(e).__name__}: {e}")

    # Check for 'ANDROID!' header
    pos = chunk.find(b"ANDROID!")
    if pos >= 0:
        print(f"  Found ANDROID! header at offset {pos}")
        header = chunk[pos:pos+2048]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        kernel_addr = struct.unpack_from("<I", header, 12)[0]
        ramdisk_size = struct.unpack_from("<I", header, 16)[0]
        second_size = struct.unpack_from("<I", header, 24)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"  kernel_size={kernel_size}, page_size={page_size}, kernel_addr=0x{kernel_addr:08x}")
        print(f"  ramdisk_size={ramdisk_size}, second_size={second_size}")

print("Done")