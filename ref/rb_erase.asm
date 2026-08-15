
/mnt/sdcard/Documents/matisse_backup_essentials/kernel_with_symbols.elf:	file format elf64-littleaarch64

Disassembly of section .kernel:

ffffffc008a71228 <rb_erase>:
ffffffc008a71228: d503233f     	paciasp
ffffffc008a7122c: a940a408     	ldp	x8, x9, [x0, #0x8]
ffffffc008a71230: b4000249     	cbz	x9, 0xffffffc008a71278 <rb_erase+0x50>
ffffffc008a71234: b40003e8     	cbz	x8, 0xffffffc008a712b0 <rb_erase+0x88>
ffffffc008a71238: f940090b     	ldr	x11, [x8, #0x10]
ffffffc008a7123c: b400050b     	cbz	x11, 0xffffffc008a712dc <rb_erase+0xb4>
ffffffc008a71240: aa0803e9     	mov	x9, x8
ffffffc008a71244: aa0903ea     	mov	x10, x9
ffffffc008a71248: aa0b03e9     	mov	x9, x11
ffffffc008a7124c: f940096b     	ldr	x11, [x11, #0x10]
ffffffc008a71250: b5ffffab     	cbnz	x11, 0xffffffc008a71244 <rb_erase+0x1c>
ffffffc008a71254: f940052b     	ldr	x11, [x9, #0x8]
ffffffc008a71258: f900094b     	str	x11, [x10, #0x10]
ffffffc008a7125c: f9000528     	str	x8, [x9, #0x8]
ffffffc008a71260: f940010c     	ldr	x12, [x8]
ffffffc008a71264: 9240018c     	and	x12, x12, #0x1
ffffffc008a71268: aa09018c     	orr	x12, x12, x9
ffffffc008a7126c: f900010c     	str	x12, [x8]
ffffffc008a71270: aa0a03e8     	mov	x8, x10
ffffffc008a71274: 1400001c     	b	0xffffffc008a712e4 <rb_erase+0xbc>
ffffffc008a71278: f9400009     	ldr	x9, [x0]
ffffffc008a7127c: f27ef52a     	ands	x10, x9, #0xfffffffffffffffc
ffffffc008a71280: 540006a0     	b.eq	0xffffffc008a71354 <rb_erase+0x12c>
ffffffc008a71284: aa0a03eb     	mov	x11, x10
ffffffc008a71288: f8410d6c     	ldr	x12, [x11, #0x10]!
ffffffc008a7128c: d100216d     	sub	x13, x11, #0x8
ffffffc008a71290: eb00019f     	cmp	x12, x0
ffffffc008a71294: 9a8d016b     	csel	x11, x11, x13, eq
ffffffc008a71298: f9000168     	str	x8, [x11]
ffffffc008a7129c: b4000628     	cbz	x8, 0xffffffc008a71360 <rb_erase+0x138>
ffffffc008a712a0: aa1f03ea     	mov	x10, xzr
ffffffc008a712a4: f9000109     	str	x9, [x8]
ffffffc008a712a8: b500074a     	cbnz	x10, 0xffffffc008a71390 <rb_erase+0x168>
ffffffc008a712ac: 14000034     	b	0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a712b0: f940000a     	ldr	x10, [x0]
ffffffc008a712b4: f27ef548     	ands	x8, x10, #0xfffffffffffffffc
ffffffc008a712b8: f900012a     	str	x10, [x9]
ffffffc008a712bc: 540005a0     	b.eq	0xffffffc008a71370 <rb_erase+0x148>
ffffffc008a712c0: f940090a     	ldr	x10, [x8, #0x10]
ffffffc008a712c4: eb00015f     	cmp	x10, x0
ffffffc008a712c8: 540005e0     	b.eq	0xffffffc008a71384 <rb_erase+0x15c>
ffffffc008a712cc: aa1f03ea     	mov	x10, xzr
ffffffc008a712d0: f9000509     	str	x9, [x8, #0x8]
ffffffc008a712d4: b50005ea     	cbnz	x10, 0xffffffc008a71390 <rb_erase+0x168>
ffffffc008a712d8: 14000029     	b	0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a712dc: f940050b     	ldr	x11, [x8, #0x8]
ffffffc008a712e0: aa0803e9     	mov	x9, x8
ffffffc008a712e4: f940080a     	ldr	x10, [x0, #0x10]
ffffffc008a712e8: f900092a     	str	x10, [x9, #0x10]
ffffffc008a712ec: f940014c     	ldr	x12, [x10]
ffffffc008a712f0: 9240018c     	and	x12, x12, #0x1
ffffffc008a712f4: aa09018c     	orr	x12, x12, x9
ffffffc008a712f8: f900014c     	str	x12, [x10]
ffffffc008a712fc: f940000c     	ldr	x12, [x0]
ffffffc008a71300: f27ef58a     	ands	x10, x12, #0xfffffffffffffffc
ffffffc008a71304: 54000160     	b.eq	0xffffffc008a71330 <rb_erase+0x108>
ffffffc008a71308: f8410d4d     	ldr	x13, [x10, #0x10]!
ffffffc008a7130c: d100214e     	sub	x14, x10, #0x8
ffffffc008a71310: eb0001bf     	cmp	x13, x0
ffffffc008a71314: 9a8e014a     	csel	x10, x10, x14, eq
ffffffc008a71318: f9000149     	str	x9, [x10]
ffffffc008a7131c: b400010b     	cbz	x11, 0xffffffc008a7133c <rb_erase+0x114>
ffffffc008a71320: b2400108     	orr	x8, x8, #0x1
ffffffc008a71324: aa1f03ea     	mov	x10, xzr
ffffffc008a71328: f9000168     	str	x8, [x11]
ffffffc008a7132c: 14000007     	b	0xffffffc008a71348 <rb_erase+0x120>
ffffffc008a71330: aa0103ea     	mov	x10, x1
ffffffc008a71334: f9000149     	str	x9, [x10]
ffffffc008a71338: b5ffff4b     	cbnz	x11, 0xffffffc008a71320 <rb_erase+0xf8>
ffffffc008a7133c: 3940012a     	ldrb	w10, [x9]
ffffffc008a71340: 7200015f     	tst	w10, #0x1
ffffffc008a71344: 9a8803ea     	csel	x10, xzr, x8, eq
ffffffc008a71348: f900012c     	str	x12, [x9]
ffffffc008a7134c: b500022a     	cbnz	x10, 0xffffffc008a71390 <rb_erase+0x168>
ffffffc008a71350: 1400000b     	b	0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a71354: aa0103eb     	mov	x11, x1
ffffffc008a71358: f9000168     	str	x8, [x11]
ffffffc008a7135c: b5fffa28     	cbnz	x8, 0xffffffc008a712a0 <rb_erase+0x78>
ffffffc008a71360: 93400128     	sbfx	x8, x9, #0, #1
ffffffc008a71364: 8a0a010a     	and	x10, x8, x10
ffffffc008a71368: b500014a     	cbnz	x10, 0xffffffc008a71390 <rb_erase+0x168>
ffffffc008a7136c: 14000004     	b	0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a71370: aa1f03ea     	mov	x10, xzr
ffffffc008a71374: f9000029     	str	x9, [x1]
ffffffc008a71378: b50000ca     	cbnz	x10, 0xffffffc008a71390 <rb_erase+0x168>
ffffffc008a7137c: d50323bf     	autiasp
ffffffc008a71380: d65f03c0     	ret
ffffffc008a71384: aa1f03ea     	mov	x10, xzr
ffffffc008a71388: f9000909     	str	x9, [x8, #0x10]
ffffffc008a7138c: b4ffff8a     	cbz	x10, 0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a71390: aa1f03e8     	mov	x8, xzr
ffffffc008a71394: f9400549     	ldr	x9, [x10, #0x8]
ffffffc008a71398: aa0803eb     	mov	x11, x8
ffffffc008a7139c: aa0a03e8     	mov	x8, x10
ffffffc008a713a0: eb09017f     	cmp	x11, x9
ffffffc008a713a4: 54000240     	b.eq	0xffffffc008a713ec <rb_erase+0x1c4>
ffffffc008a713a8: 3940012a     	ldrb	w10, [x9]
ffffffc008a713ac: 370004aa     	tbnz	w10, #0x0, 0xffffffc008a71440 <rb_erase+0x218>
ffffffc008a713b0: f940092a     	ldr	x10, [x9, #0x10]
ffffffc008a713b4: b240010b     	orr	x11, x8, #0x1
ffffffc008a713b8: f900050a     	str	x10, [x8, #0x8]
ffffffc008a713bc: f9000928     	str	x8, [x9, #0x10]
ffffffc008a713c0: f900014b     	str	x11, [x10]
ffffffc008a713c4: f940010c     	ldr	x12, [x8]
ffffffc008a713c8: f27ef58b     	ands	x11, x12, #0xfffffffffffffffc
ffffffc008a713cc: f900012c     	str	x12, [x9]
ffffffc008a713d0: f9000109     	str	x9, [x8]
ffffffc008a713d4: 54000300     	b.eq	0xffffffc008a71434 <rb_erase+0x20c>
ffffffc008a713d8: f8410d6c     	ldr	x12, [x11, #0x10]!
ffffffc008a713dc: d100216d     	sub	x13, x11, #0x8
ffffffc008a713e0: eb08019f     	cmp	x12, x8
ffffffc008a713e4: 9a8d016b     	csel	x11, x11, x13, eq
ffffffc008a713e8: 14000014     	b	0xffffffc008a71438 <rb_erase+0x210>
ffffffc008a713ec: f9400909     	ldr	x9, [x8, #0x10]
ffffffc008a713f0: 3940012a     	ldrb	w10, [x9]
ffffffc008a713f4: 370003ea     	tbnz	w10, #0x0, 0xffffffc008a71470 <rb_erase+0x248>
ffffffc008a713f8: f940052a     	ldr	x10, [x9, #0x8]
ffffffc008a713fc: b240010b     	orr	x11, x8, #0x1
ffffffc008a71400: f900090a     	str	x10, [x8, #0x10]
ffffffc008a71404: f9000528     	str	x8, [x9, #0x8]
ffffffc008a71408: f900014b     	str	x11, [x10]
ffffffc008a7140c: f940010c     	ldr	x12, [x8]
ffffffc008a71410: f27ef58b     	ands	x11, x12, #0xfffffffffffffffc
ffffffc008a71414: f900012c     	str	x12, [x9]
ffffffc008a71418: f9000109     	str	x9, [x8]
ffffffc008a7141c: 54000240     	b.eq	0xffffffc008a71464 <rb_erase+0x23c>
ffffffc008a71420: f8410d6c     	ldr	x12, [x11, #0x10]!
ffffffc008a71424: d100216d     	sub	x13, x11, #0x8
ffffffc008a71428: eb08019f     	cmp	x12, x8
ffffffc008a7142c: 9a8d016b     	csel	x11, x11, x13, eq
ffffffc008a71430: 1400000e     	b	0xffffffc008a71468 <rb_erase+0x240>
ffffffc008a71434: aa0103eb     	mov	x11, x1
ffffffc008a71438: f9000169     	str	x9, [x11]
ffffffc008a7143c: aa0a03e9     	mov	x9, x10
ffffffc008a71440: f940052b     	ldr	x11, [x9, #0x8]
ffffffc008a71444: b400006b     	cbz	x11, 0xffffffc008a71450 <rb_erase+0x228>
ffffffc008a71448: 3940016a     	ldrb	w10, [x11]
ffffffc008a7144c: 3600036a     	tbz	w10, #0x0, 0xffffffc008a714b8 <rb_erase+0x290>
ffffffc008a71450: f940092a     	ldr	x10, [x9, #0x10]
ffffffc008a71454: b40001ea     	cbz	x10, 0xffffffc008a71490 <rb_erase+0x268>
ffffffc008a71458: 3940014b     	ldrb	w11, [x10]
ffffffc008a7145c: 370001ab     	tbnz	w11, #0x0, 0xffffffc008a71490 <rb_erase+0x268>
ffffffc008a71460: 14000019     	b	0xffffffc008a714c4 <rb_erase+0x29c>
ffffffc008a71464: aa0103eb     	mov	x11, x1
ffffffc008a71468: f9000169     	str	x9, [x11]
ffffffc008a7146c: aa0a03e9     	mov	x9, x10
ffffffc008a71470: f940092b     	ldr	x11, [x9, #0x10]
ffffffc008a71474: b400006b     	cbz	x11, 0xffffffc008a71480 <rb_erase+0x258>
ffffffc008a71478: 3940016a     	ldrb	w10, [x11]
ffffffc008a7147c: 360005ea     	tbz	w10, #0x0, 0xffffffc008a71538 <rb_erase+0x310>
ffffffc008a71480: f940052a     	ldr	x10, [x9, #0x8]
ffffffc008a71484: b400006a     	cbz	x10, 0xffffffc008a71490 <rb_erase+0x268>
ffffffc008a71488: 3940014b     	ldrb	w11, [x10]
ffffffc008a7148c: 360005cb     	tbz	w11, #0x0, 0xffffffc008a71544 <rb_erase+0x31c>
ffffffc008a71490: f9000128     	str	x8, [x9]
ffffffc008a71494: f9400109     	ldr	x9, [x8]
ffffffc008a71498: 36000089     	tbz	w9, #0x0, 0xffffffc008a714a8 <rb_erase+0x280>
ffffffc008a7149c: f27ef52a     	ands	x10, x9, #0xfffffffffffffffc
ffffffc008a714a0: 54fff7a1     	b.ne	0xffffffc008a71394 <rb_erase+0x16c>
ffffffc008a714a4: 17ffffb6     	b	0xffffffc008a7137c <rb_erase+0x154>
ffffffc008a714a8: b2400129     	orr	x9, x9, #0x1
ffffffc008a714ac: f9000109     	str	x9, [x8]
ffffffc008a714b0: d50323bf     	autiasp
ffffffc008a714b4: d65f03c0     	ret
ffffffc008a714b8: aa0903ea     	mov	x10, x9
ffffffc008a714bc: aa0b03e9     	mov	x9, x11
ffffffc008a714c0: 14000008     	b	0xffffffc008a714e0 <rb_erase+0x2b8>
ffffffc008a714c4: f940054b     	ldr	x11, [x10, #0x8]
ffffffc008a714c8: f900092b     	str	x11, [x9, #0x10]
ffffffc008a714cc: f9000549     	str	x9, [x10, #0x8]
ffffffc008a714d0: f900050a     	str	x10, [x8, #0x8]
ffffffc008a714d4: b400006b     	cbz	x11, 0xffffffc008a714e0 <rb_erase+0x2b8>
ffffffc008a714d8: b240012c     	orr	x12, x9, #0x1
ffffffc008a714dc: f900016c     	str	x12, [x11]
ffffffc008a714e0: f940094c     	ldr	x12, [x10, #0x10]
ffffffc008a714e4: b240014b     	orr	x11, x10, #0x1
ffffffc008a714e8: f900050c     	str	x12, [x8, #0x8]
ffffffc008a714ec: f9000948     	str	x8, [x10, #0x10]
ffffffc008a714f0: f900012b     	str	x11, [x9]
ffffffc008a714f4: b40000ac     	cbz	x12, 0xffffffc008a71508 <rb_erase+0x2e0>
ffffffc008a714f8: f9400189     	ldr	x9, [x12]
ffffffc008a714fc: 92400129     	and	x9, x9, #0x1
ffffffc008a71500: aa080129     	orr	x9, x9, x8
ffffffc008a71504: f9000189     	str	x9, [x12]
ffffffc008a71508: f940010c     	ldr	x12, [x8]
ffffffc008a7150c: f27ef589     	ands	x9, x12, #0xfffffffffffffffc
ffffffc008a71510: f900014c     	str	x12, [x10]
ffffffc008a71514: f900010b     	str	x11, [x8]
ffffffc008a71518: 540000a0     	b.eq	0xffffffc008a7152c <rb_erase+0x304>
ffffffc008a7151c: f8410d2b     	ldr	x11, [x9, #0x10]!
ffffffc008a71520: d100212c     	sub	x12, x9, #0x8
ffffffc008a71524: eb08017f     	cmp	x11, x8
ffffffc008a71528: 9a8c0121     	csel	x1, x9, x12, eq
ffffffc008a7152c: f900002a     	str	x10, [x1]
ffffffc008a71530: d50323bf     	autiasp
ffffffc008a71534: d65f03c0     	ret
ffffffc008a71538: aa0903ea     	mov	x10, x9
ffffffc008a7153c: aa0b03e9     	mov	x9, x11
ffffffc008a71540: 14000008     	b	0xffffffc008a71560 <rb_erase+0x338>
ffffffc008a71544: f940094b     	ldr	x11, [x10, #0x10]
ffffffc008a71548: f900052b     	str	x11, [x9, #0x8]
ffffffc008a7154c: f9000949     	str	x9, [x10, #0x10]
ffffffc008a71550: f900090a     	str	x10, [x8, #0x10]
ffffffc008a71554: b400006b     	cbz	x11, 0xffffffc008a71560 <rb_erase+0x338>
ffffffc008a71558: b240012c     	orr	x12, x9, #0x1
ffffffc008a7155c: f900016c     	str	x12, [x11]
ffffffc008a71560: f940054c     	ldr	x12, [x10, #0x8]
ffffffc008a71564: b240014b     	orr	x11, x10, #0x1
ffffffc008a71568: f900090c     	str	x12, [x8, #0x10]
ffffffc008a7156c: f9000548     	str	x8, [x10, #0x8]
ffffffc008a71570: f900012b     	str	x11, [x9]
ffffffc008a71574: b5fffc2c     	cbnz	x12, 0xffffffc008a714f8 <rb_erase+0x2d0>
ffffffc008a71578: 17ffffe4     	b	0xffffffc008a71508 <rb_erase+0x2e0>

ffffffc008a7157c <dummy_copy>:
ffffffc008a7157c: d503233f     	paciasp
ffffffc008a71580: d50323bf     	autiasp
ffffffc008a71584: d65f03c0     	ret

ffffffc008a71588 <dummy_propagate>:
ffffffc008a71588: d503233f     	paciasp
ffffffc008a7158c: d50323bf     	autiasp
ffffffc008a71590: d65f03c0     	ret

ffffffc008a71594 <__rb_insert_augmented>:
ffffffc008a71594: d503233f     	paciasp
ffffffc008a71598: f800865e     	str	x30, [x18], #0x8
ffffffc008a7159c: a9bc7bfd     	stp	x29, x30, [sp, #-0x40]!
ffffffc008a715a0: f9000bf7     	str	x23, [sp, #0x10]
ffffffc008a715a4: a90257f6     	stp	x22, x21, [sp, #0x20]
ffffffc008a715a8: a9034ff4     	stp	x20, x19, [sp, #0x30]
ffffffc008a715ac: 910003fd     	mov	x29, sp
ffffffc008a715b0: aa0003f5     	mov	x21, x0
ffffffc008a715b4: f9400000     	ldr	x0, [x0]
ffffffc008a715b8: b4000e40     	cbz	x0, 0xffffffc008a71780 <__rb_insert_augmented+0x1ec>
ffffffc008a715bc: aa0203f3     	mov	x19, x2
ffffffc008a715c0: aa0103f6     	mov	x22, x1
ffffffc008a715c4: 14000009     	b	0xffffffc008a715e8 <__rb_insert_augmented+0x54>
ffffffc008a715c8: b2400289     	orr	x9, x20, #0x1
ffffffc008a715cc: f9000109     	str	x9, [x8]
ffffffc008a715d0: f9000009     	str	x9, [x0]
ffffffc008a715d4: f9400288     	ldr	x8, [x20]
ffffffc008a715d8: aa1403f5     	mov	x21, x20
ffffffc008a715dc: 927ef500     	and	x0, x8, #0xfffffffffffffffc
ffffffc008a715e0: f9000280     	str	x0, [x20]
ffffffc008a715e4: b4000d00     	cbz	x0, 0xffffffc008a71784 <__rb_insert_augmented+0x1f0>
ffffffc008a715e8: f9400014     	ldr	x20, [x0]
ffffffc008a715ec: 37000bd4     	tbnz	w20, #0x0, 0xffffffc008a71764 <__rb_insert_augmented+0x1d0>
ffffffc008a715f0: f9400688     	ldr	x8, [x20, #0x8]
ffffffc008a715f4: eb00011f     	cmp	x8, x0
ffffffc008a715f8: 540000a0     	b.eq	0xffffffc008a7160c <__rb_insert_augmented+0x78>
ffffffc008a715fc: b40001a8     	cbz	x8, 0xffffffc008a71630 <__rb_insert_augmented+0x9c>
ffffffc008a71600: 39400109     	ldrb	w9, [x8]
ffffffc008a71604: 3607fe29     	tbz	w9, #0x0, 0xffffffc008a715c8 <__rb_insert_augmented+0x34>
ffffffc008a71608: 1400000a     	b	0xffffffc008a71630 <__rb_insert_augmented+0x9c>
ffffffc008a7160c: f9400a88     	ldr	x8, [x20, #0x10]
ffffffc008a71610: b4000068     	cbz	x8, 0xffffffc008a7161c <__rb_insert_augmented+0x88>
ffffffc008a71614: 39400109     	ldrb	w9, [x8]
ffffffc008a71618: 3607fd89     	tbz	w9, #0x0, 0xffffffc008a715c8 <__rb_insert_augmented+0x34>
ffffffc008a7161c: f9400808     	ldr	x8, [x0, #0x10]
ffffffc008a71620: eb0802bf     	cmp	x21, x8
ffffffc008a71624: 54000500     	b.eq	0xffffffc008a716c4 <__rb_insert_augmented+0x130>
ffffffc008a71628: aa0003f5     	mov	x21, x0
ffffffc008a7162c: 14000036     	b	0xffffffc008a71704 <__rb_insert_augmented+0x170>
ffffffc008a71630: f9400408     	ldr	x8, [x0, #0x8]
ffffffc008a71634: b0006df7     	adrp	x23, 0xffffffc00982e000 <rproc_carveouts_show.cfi_jt>
ffffffc008a71638: 910dc2f7     	add	x23, x23, #0x370
ffffffc008a7163c: eb0802bf     	cmp	x21, x8
ffffffc008a71640: 54000060     	b.eq	0xffffffc008a7164c <__rb_insert_augmented+0xb8>
ffffffc008a71644: aa0003f5     	mov	x21, x0
ffffffc008a71648: 1400000f     	b	0xffffffc008a71684 <__rb_insert_augmented+0xf0>
ffffffc008a7164c: f9400aa8     	ldr	x8, [x21, #0x10]
ffffffc008a71650: f9000408     	str	x8, [x0, #0x8]
ffffffc008a71654: f9000aa0     	str	x0, [x21, #0x10]
ffffffc008a71658: b4000068     	cbz	x8, 0xffffffc008a71664 <__rb_insert_augmented+0xd0>
ffffffc008a7165c: b2400009     	orr	x9, x0, #0x1
ffffffc008a71660: f9000109     	str	x9, [x8]
ffffffc008a71664: cb170268     	sub	x8, x19, x23
ffffffc008a71668: 93c80d08     	ror	x8, x8, #0x3
ffffffc008a7166c: f100791f     	cmp	x8, #0x1e
ffffffc008a71670: f9000015     	str	x21, [x0]
ffffffc008a71674: 540009e2     	b.hs	0xffffffc008a717b0 <__rb_insert_augmented+0x21c>
ffffffc008a71678: aa1503e1     	mov	x1, x21
ffffffc008a7167c: d63f0260     	blr	x19
ffffffc008a71680: f94006a8     	ldr	x8, [x21, #0x8]
ffffffc008a71684: f9000a88     	str	x8, [x20, #0x10]
ffffffc008a71688: f90006b4     	str	x20, [x21, #0x8]
ffffffc008a7168c: b4000068     	cbz	x8, 0xffffffc008a71698 <__rb_insert_augmented+0x104>
ffffffc008a71690: b2400289     	orr	x9, x20, #0x1
ffffffc008a71694: f9000109     	str	x9, [x8]
ffffffc008a71698: f9400289     	ldr	x9, [x20]
ffffffc008a7169c: f27ef528     	ands	x8, x9, #0xfffffffffffffffc
ffffffc008a716a0: f90002a9     	str	x9, [x21]
ffffffc008a716a4: f9000295     	str	x21, [x20]
ffffffc008a716a8: 540000a0     	b.eq	0xffffffc008a716bc <__rb_insert_augmented+0x128>
ffffffc008a716ac: f8410d09     	ldr	x9, [x8, #0x10]!
ffffffc008a716b0: d100210a     	sub	x10, x8, #0x8
ffffffc008a716b4: eb14013f     	cmp	x9, x20
ffffffc008a716b8: 9a8a0116     	csel	x22, x8, x10, eq
ffffffc008a716bc: cb170268     	sub	x8, x19, x23
ffffffc008a716c0: 14000022     	b	0xffffffc008a71748 <__rb_insert_augmented+0x1b4>
ffffffc008a716c4: f94006a8     	ldr	x8, [x21, #0x8]
ffffffc008a716c8: f9000808     	str	x8, [x0, #0x10]
ffffffc008a716cc: f90006a0     	str	x0, [x21, #0x8]
ffffffc008a716d0: b4000068     	cbz	x8, 0xffffffc008a716dc <__rb_insert_augmented+0x148>
ffffffc008a716d4: b2400009     	orr	x9, x0, #0x1
ffffffc008a716d8: f9000109     	str	x9, [x8]
ffffffc008a716dc: b0006de8     	adrp	x8, 0xffffffc00982e000 <rproc_carveouts_show.cfi_jt>
ffffffc008a716e0: 910dc108     	add	x8, x8, #0x370
ffffffc008a716e4: cb080268     	sub	x8, x19, x8
ffffffc008a716e8: 93c80d08     	ror	x8, x8, #0x3
ffffffc008a716ec: f100791f     	cmp	x8, #0x1e
ffffffc008a716f0: f9000015     	str	x21, [x0]
ffffffc008a716f4: 54000722     	b.hs	0xffffffc008a717d8 <__rb_insert_augmented+0x244>
ffffffc008a716f8: aa1503e1     	mov	x1, x21
ffffffc008a716fc: d63f0260     	blr	x19
ffffffc008a71700: f9400aa8     	ldr	x8, [x21, #0x10]
ffffffc008a71704: f9000688     	str	x8, [x20, #0x8]
ffffffc008a71708: f9000ab4     	str	x20, [x21, #0x10]
ffffffc008a7170c: b4000068     	cbz	x8, 0xffffffc008a71718 <__rb_insert_augmented+0x184>
ffffffc008a71710: b2400289     	orr	x9, x20, #0x1
ffffffc008a71714: f9000109     	str	x9, [x8]
ffffffc008a71718: f9400289     	ldr	x9, [x20]
ffffffc008a7171c: f27ef528     	ands	x8, x9, #0xfffffffffffffffc
ffffffc008a71720: f90002a9     	str	x9, [x21]
ffffffc008a71724: f9000295     	str	x21, [x20]
ffffffc008a71728: 540000a0     	b.eq	0xffffffc008a7173c <__rb_insert_augmented+0x1a8>
ffffffc008a7172c: f8410d09     	ldr	x9, [x8, #0x10]!
ffffffc008a71730: d100210a     	sub	x10, x8, #0x8
ffffffc008a71734: eb14013f     	cmp	x9, x20
ffffffc008a71738: 9a8a0116     	csel	x22, x8, x10, eq
ffffffc008a7173c: b0006de8     	adrp	x8, 0xffffffc00982e000 <rproc_carveouts_show.cfi_jt>
ffffffc008a71740: 910dc108     	add	x8, x8, #0x370
ffffffc008a71744: cb080268     	sub	x8, x19, x8
ffffffc008a71748: 93c80d08     	ror	x8, x8, #0x3
ffffffc008a7174c: f100791f     	cmp	x8, #0x1e
ffffffc008a71750: f90002d5     	str	x21, [x22]
ffffffc008a71754: 540001e2     	b.hs	0xffffffc008a71790 <__rb_insert_augmented+0x1fc>
ffffffc008a71758: aa1403e0     	mov	x0, x20
ffffffc008a7175c: aa1503e1     	mov	x1, x21
ffffffc008a71760: d63f0260     	blr	x19
ffffffc008a71764: a9434ff4     	ldp	x20, x19, [sp, #0x30]
ffffffc008a71768: a94257f6     	ldp	x22, x21, [sp, #0x20]
ffffffc008a7176c: f9400bf7     	ldr	x23, [sp, #0x10]
ffffffc008a71770: a8c47bfd     	ldp	x29, x30, [sp], #0x40
ffffffc008a71774: f85f8e5e     	ldr	x30, [x18, #-0x8]!
ffffffc008a71778: d50323bf     	autiasp
ffffffc008a7177c: d65f03c0     	ret
ffffffc008a71780: aa1503f4     	mov	x20, x21
ffffffc008a71784: 52800028     	mov	w8, #0x1        // =1
ffffffc008a71788: f9000288     	str	x8, [x20]
ffffffc008a7178c: 17fffff6     	b	0xffffffc008a71764 <__rb_insert_augmented+0x1d0>
ffffffc008a71790: d2863480     	mov	x0, #0x31a4     // =12708
ffffffc008a71794: f2b95c00     	movk	x0, #0xcae0, lsl #16
ffffffc008a71798: f2daaa40     	movk	x0, #0xd552, lsl #32
ffffffc008a7179c: f2f6c4c0     	movk	x0, #0xb626, lsl #48
ffffffc008a717a0: aa1303e1     	mov	x1, x19
ffffffc008a717a4: aa1f03e2     	mov	x2, xzr
ffffffc008a717a8: 97e57455     	bl	0xffffffc0083ce8fc <__cfi_slowpath>
ffffffc008a717ac: 17ffffeb     	b	0xffffffc008a71758 <__rb_insert_augmented+0x1c4>
ffffffc008a717b0: f9000fa0     	str	x0, [x29, #0x18]
ffffffc008a717b4: d2863480     	mov	x0, #0x31a4     // =12708
ffffffc008a717b8: f2b95c00     	movk	x0, #0xcae0, lsl #16
ffffffc008a717bc: f2daaa40     	movk	x0, #0xd552, lsl #32
ffffffc008a717c0: f2f6c4c0     	movk	x0, #0xb626, lsl #48
ffffffc008a717c4: aa1303e1     	mov	x1, x19
ffffffc008a717c8: aa1f03e2     	mov	x2, xzr
ffffffc008a717cc: 97e5744c     	bl	0xffffffc0083ce8fc <__cfi_slowpath>
ffffffc008a717d0: f9400fa0     	ldr	x0, [x29, #0x18]
ffffffc008a717d4: 17ffffa9     	b	0xffffffc008a71678 <__rb_insert_augmented+0xe4>
ffffffc008a717d8: aa0003f7     	mov	x23, x0
ffffffc008a717dc: d2863480     	mov	x0, #0x31a4     // =12708
ffffffc008a717e0: f2b95c00     	movk	x0, #0xcae0, lsl #16
ffffffc008a717e4: f2daaa40     	movk	x0, #0xd552, lsl #32
ffffffc008a717e8: f2f6c4c0     	movk	x0, #0xb626, lsl #48
ffffffc008a717ec: aa1303e1     	mov	x1, x19
ffffffc008a717f0: aa1f03e2     	mov	x2, xzr
ffffffc008a717f4: 97e57442     	bl	0xffffffc0083ce8fc <__cfi_slowpath>
ffffffc008a717f8: aa1703e0     	mov	x0, x23
ffffffc008a717fc: 17ffffbf     	b	0xffffffc008a716f8 <__rb_insert_augmented+0x164>
