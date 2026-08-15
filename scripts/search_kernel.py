import re

EXTRACTED = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted"

# Check system.img
system = open(EXTRACTED + r"\system.img", "rb").read()
print(f"system.img: {len(system)} bytes")

for pattern in [b"vermagic=", b"Linux version", b"kernel", b"module"]:
    for m in re.finditer(pattern, system, re.IGNORECASE):
        end = min(m.start() + 200, len(system))
        ctx = system[m.start():end]
        print(f"Found '{pattern.decode()}' at offset {m.start()}: {ctx[:120]}")
        break

# Check product.img
product = open(EXTRACTED + r"\product.img", "rb").read()
print(f"\nproduct.img: {len(product)} bytes")

for pattern in [b"vermagic=", b"Linux version", b"kernel"]:
    for m in re.finditer(pattern, product, re.IGNORECASE):
        end = min(m.start() + 200, len(product))
        ctx = product[m.start():end]
        print(f"Found '{pattern.decode()}' at offset {m.start()}: {ctx[:120]}")
        break

# Check boot.img REPLACE chunks for kernel strings
boot = open(EXTRACTED + r"\boot_full.img", "rb").read()
print(f"\nboot_full.img: {len(boot)} bytes")

for pattern in [b"vermagic=", b"Linux version", b"kernel"]:
    for m in re.finditer(pattern, boot, re.IGNORECASE):
        end = min(m.start() + 200, len(boot))
        ctx = boot[m.start():end]
        print(f"Found '{pattern.decode()}' at offset {m.start()}: {ctx[:120]}")
        break

# Check vendor_boot
vb = open(EXTRACTED + r"\vendor_boot_full.img", "rb").read()
print(f"\nvendor_boot_full.img: {len(vb)} bytes")

for pattern in [b"vermagic=", b"Linux version", b"kernel"]:
    for m in re.finditer(pattern, vb, re.IGNORECASE):
        end = min(m.start() + 200, len(vb))
        ctx = vb[m.start():end]
        print(f"Found '{pattern.decode()}' at offset {m.start()}: {ctx[:120]}")
        break

print("\nDone")