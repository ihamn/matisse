"""Find the actual ARM64 Linux kernel Image within the PE wrapper"""
import struct, os

KERNEL_PATH = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\kernel.Image"
OUTPUT_DIR = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

with open(KERNEL_PATH, "rb") as f:
    data = f.read()

print(f"Total: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")

# Search for ARM64 kernel Image magic "ARM\x64" at offset 0x38
magic = b"ARM\x64"
print(f"\n=== Searching for ARM64 kernel magic '{magic.decode()}' ===")

idx = 0
found = []
while True:
    idx = data.find(magic, idx)
    if idx < 0:
        break
    # Check if it's at offset 0x38 from the start of a kernel Image
    # The kernel Image header is 64 bytes (0x40), with magic at offset 0x38
    if idx >= 0x38:
        potential_start = idx - 0x38
        if potential_start >= 0 and potential_start + 0x40 <= len(data):
            # Verify the header structure
            header = data[potential_start:potential_start + 0x40]
            # First 4 bytes should be a branch instruction
            b_instr = struct.unpack_from("<I", header, 0)[0]
            # Check if it's an unconditional branch (0x14xxxxxx)
            is_branch = (b_instr & 0xFC000000) == 0x14000000
            
            if is_branch:
                print(f"\n  *** ARM64 kernel Image at offset {potential_start} (0x{potential_start:x}) ***")
                print(f"  Header hex: {header.hex()}")
                print(f"  b instruction: 0x{b_instr:08x}")
                
                # Parse header
                text_offset = struct.unpack_from("<Q", header, 8)[0]
                image_size = struct.unpack_from("<Q", header, 16)[0]
                flags = struct.unpack_from("<Q", header, 24)[0]
                print(f"  text_offset: 0x{text_offset:x}")
                print(f"  image_size: {image_size} ({image_size/1024/1024:.1f} MB)")
                print(f"  flags: 0x{flags:x} (LE={flags & 0x1}, BE={flags & 0x2}, PageSize={flags & 0x18})")
                
                found.append((potential_start, image_size))
            else:
                print(f"\n  Magic at offset {idx} but not a valid kernel header (b_instr=0x{b_instr:08x})")
    idx += 1

if found:
    print(f"\n\n=== Found {len(found)} ARM64 kernel Image(s) ===")
    for i, (start, image_size) in enumerate(found):
        kernel_data = data[start:start + image_size]
        print(f"\n[{i}] Offset {start} (0x{start:x}), size {image_size}")
        
        # Save the kernel Image
        outpath = os.path.join(OUTPUT_DIR, f"kernel_arm64_image_{i}.bin")
        with open(outpath, "wb") as f:
            f.write(kernel_data)
        print(f"  Saved to: {outpath}")
        
        # Search for Linux version
        ver_idx = kernel_data.find(b"Linux version")
        if ver_idx >= 0:
            end = kernel_data.find(b"\n", ver_idx)
            if end < 0: end = ver_idx + 300
            print(f"  Version: {kernel_data[ver_idx:end].decode('utf-8', errors='replace')[:200]}")
else:
    print("\nNo ARM64 kernel Image magic found!")
    print("Trying to find kernel by other means...")
    
    # Search for the kernel version string and work backwards
    ver_idx = data.find(b"Linux version 5.10")
    if ver_idx >= 0:
        print(f"\nKernel version string at offset {ver_idx}")
        print(f"Context: {data[max(0,ver_idx-64):ver_idx+100].decode('utf-8', errors='replace')}")
        
        # The kernel version is typically in .rodata, which is after the code
        # Let's search backwards for the kernel Image header
        # ARM64 kernel Image header is at a page-aligned offset
        
        # Search for the header pattern within a reasonable range before the version string
        search_start = max(0, ver_idx - 50*1024*1024)  # 50MB before
        search_data = data[search_start:ver_idx]
        
        for i in range(0, len(search_data), 4096):
            potential_start = search_start + i
            if potential_start + 0x40 > len(data):
                break
            header = data[potential_start:potential_start + 0x40]
            b_instr = struct.unpack_from("<I", header, 0)[0]
            is_branch = (b_instr & 0xFC000000) == 0x14000000
            
            if is_branch:
                magic_check = header[0x38:0x3C]
                if magic_check == b"ARM\x64":
                    image_size = struct.unpack_from("<Q", header, 16)[0]
                    print(f"\nFound kernel Image at offset {potential_start} (0x{potential_start:x})")
                    print(f"  image_size: {image_size} ({image_size/1024/1024:.1f} MB)")
                    
                    kernel_data = data[potential_start:potential_start + image_size]
                    outpath = os.path.join(OUTPUT_DIR, "kernel_arm64_image.bin")
                    with open(outpath, "wb") as f:
                        f.write(kernel_data)
                    print(f"  Saved to: {outpath}")
                    break

# Also, let's search for the vmlinux or Image within the .text section
# The PE .text section is at raw offset 0x10000
print(f"\n=== Analyzing PE .text section ===")
text_data = data[0x10000:0x10000 + 41091072]
print(f".text section size: {len(text_data)} bytes")

# Search for ARM\x64 within .text
text_idx = text_data.find(b"ARM\x64")
if text_idx >= 0:
    print(f"ARM\\x64 found at offset 0x10000 + {text_idx} = 0x{0x10000+text_idx:x}")
    if text_idx >= 0x38:
        potential_start = 0x10000 + text_idx - 0x38
        header = data[potential_start:potential_start + 0x40]
        print(f"Potential kernel Image at 0x{potential_start:x}")
        print(f"Header: {header.hex()}")
        b_instr = struct.unpack_from("<I", header, 0)[0]
        print(f"b instruction: 0x{b_instr:08x}")
        image_size = struct.unpack_from("<Q", header, 16)[0]
        print(f"image_size: {image_size} ({image_size/1024/1024:.1f} MB)")
        
        if (b_instr & 0xFC000000) == 0x14000000:
            kernel_data = data[potential_start:potential_start + image_size]
            outpath = os.path.join(OUTPUT_DIR, "kernel_arm64_image.bin")
            with open(outpath, "wb") as f:
                f.write(kernel_data)
            print(f"Saved to: {outpath}")

print("\nDone!")