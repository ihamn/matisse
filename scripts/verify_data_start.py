"""Verify the correct data_start by checking REPLACE data"""
import struct

payload = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\payload.bin", "rb").read()
boot = open(r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\extracted\boot_full.img", "rb").read()

# Two possible data_start values
data_start_standard = 24 + 226994 + 267  # 227285 (standard calculation)
data_start_working = 1748337496  # what works with signatures_offset

# Check Op 1 REPLACE data
# Op 1: data_offset=6295908, writes to blocks 512-1023 (boot offset 2097152)
op1_offset = 6295908

# Check at both data_start values
data1 = payload[data_start_standard + op1_offset:data_start_standard + op1_offset + 64]
data2 = payload[data_start_working + op1_offset:data_start_working + op1_offset + 64]
expected = boot[2097152:2097152+64]

print(f"data_start_standard = {data_start_standard}")
print(f"  Op 1 at {data_start_standard + op1_offset}: {data1[:32].hex()}")
print(f"data_start_working = {data_start_working}")
print(f"  Op 1 at {data_start_working + op1_offset}: {data2[:32].hex()}")
print(f"Expected (boot at 2097152): {expected[:32].hex()}")

print(f"\nStandard matches: {data1[:32] == expected[:32]}")
print(f"Working matches: {data2[:32] == expected[:32]}")

# Let me also check if the data_start_standard data is actually the same data
# but at a different offset. Maybe the data blobs are at 227285 but the data_offset
# is relative to something else.

# Check: does the data at 227285 look like the start of data blobs?
print(f"\nData at 227285: {payload[227285:227285+64].hex()}")

# Maybe the data_offset in the protobuf is relative to signatures_offset?
# signatures_offset = 1748337472
# data_start = 24 + signatures_offset = 24 + 1748337472 = 1748337496
# This works!

# But wait, what if signatures_offset is actually the start of data blobs?
# Let me check: is the metadata_signature_size actually huge?
# What if the 4 bytes at offset 20 are NOT uint32 but something else?

# Let me check all possible interpretations of bytes at offset 20
b20 = payload[20:24]
print(f"\nBytes at 20: {b20.hex()}")
print(f"  BE uint32: {struct.unpack_from('>I', b20)[0]}")
print(f"  LE uint32: {struct.unpack_from('<I', b20)[0]}")
print(f"  BE uint16: {struct.unpack_from('>H', b20)[0]}")
print(f"  LE uint16: {struct.unpack_from('<H', b20)[0]}")

# What if the metadata_signature_size is actually 0?
# Then data_begin = 24 + 226994 + 0 = 227018
# Op 1 at 227018 + 6295908 = 6522926
data3 = payload[227018 + op1_offset:227018 + op1_offset + 64]
print(f"\ndata_start=227018 (sig_size=0):")
print(f"  Op 1 at {227018 + op1_offset}: {data3[:32].hex()}")
print(f"  Matches: {data3[:32] == expected[:32]}")

# What if the data_offset is relative to the start of the PAYLOAD?
data4 = payload[op1_offset:op1_offset + 64]
print(f"\ndata_start=0 (absolute file offset):")
print(f"  Op 1 at {op1_offset}: {data4[:32].hex()}")
print(f"  Matches: {data4[:32] == expected[:32]}")

# What if data_offset is relative to the start of the manifest?
data5 = payload[24 + op1_offset:24 + op1_offset + 64]
print(f"\ndata_start=24 (relative to manifest start):")
print(f"  Op 1 at {24 + op1_offset}: {data5[:32].hex()}")
print(f"  Matches: {data5[:32] == expected[:32]}")