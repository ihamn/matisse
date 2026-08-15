"""Decompress XZ data section at data_start_bz"""
import struct, lzma, os

PAYLOAD_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(PAYLOAD_PATH, "rb") as f:
    payload = f.read()

manifest_size = struct.unpack_from(">Q", payload, 12)[0]
manifest_sig_size = struct.unpack_from(">I", payload, 20)[0]
data_start_bz = 24 + manifest_size + manifest_sig_size  # 227285

print(f"data_start_bz = {data_start_bz}")

# The data at data_start_bz starts with XZ magic
data_section = payload[data_start_bz:]
print(f"Data section size: {len(data_section)} bytes ({len(data_section)/1024/1024:.1f} MB)")

# Try to decompress the first chunk
# LZMA might need to find the stream end
try:
    decompressed = lzma.decompress(data_section[:500000000])
    print(f"Decompressed: {len(decompressed)} bytes ({len(decompressed)/1024/1024:.1f} MB)")
    print(f"First 64 bytes: {decompressed[:64].hex()}")
    
    if b"ANDROID!" in decompressed[:4096]:
        pos = decompressed.find(b"ANDROID!")
        print(f"ANDROID! at offset {pos}")
        header = decompressed[:4096]
        kernel_size = struct.unpack_from("<I", header, 8)[0]
        page_size = struct.unpack_from("<I", header, 36)[0]
        print(f"kernel_size={kernel_size}, page_size={page_size}")
        
        # Save as boot.img
        outpath = os.path.join(OUTPUT_DIR, "boot_from_xz.img")
        with open(outpath, "wb") as f:
            f.write(decompressed)
        print(f"Saved to {outpath}")
    else:
        print("No ANDROID! header found in decompressed data")
        
except Exception as e:
    print(f"Decompress failed: {e}")