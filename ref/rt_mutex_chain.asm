
/mnt/sdcard/Documents/matisse_backup_essentials/kernel_with_symbols.elf:	file format elf64-littleaarch64

Disassembly of section .kernel:

ffffffc0081eae38 <rt_mutex_adjust_prio_chain>:
ffffffc0081eae38: d503233f     	paciasp
ffffffc0081eae3c: d10243ff     	sub	sp, sp, #0x90
ffffffc0081eae40: f800865e     	str	x30, [x18], #0x8
ffffffc0081eae44: a9037bfd     	stp	x29, x30, [sp, #0x30]
ffffffc0081eae48: a9046ffc     	stp	x28, x27, [sp, #0x40]
ffffffc0081eae4c: a90567fa     	stp	x26, x25, [sp, #0x50]
ffffffc0081eae50: a9065ff8     	stp	x24, x23, [sp, #0x60]
ffffffc0081eae54: a90757f6     	stp	x22, x21, [sp, #0x70]
ffffffc0081eae58: a9084ff4     	stp	x20, x19, [sp, #0x80]
ffffffc0081eae5c: 9100c3fd     	add	x29, sp, #0x30
ffffffc0081eae60: f0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eae64: 2a0103f7     	mov	w23, w1
ffffffc0081eae68: b941ba01     	ldr	w1, [x16, #0x1b8]
ffffffc0081eae6c: aa0003f3     	mov	x19, x0
ffffffc0081eae70: 7100043f     	cmp	w1, #0x1
ffffffc0081eae74: 54009e2b     	b.lt	0xffffffc0081ec238 <rt_mutex_adjust_prio_chain+0x1400>
ffffffc0081eae78: aa0403f5     	mov	x21, x4
ffffffc0081eae7c: aa0303f8     	mov	x24, x3
ffffffc0081eae80: 9000f2a3     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eae84: f000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eae88: aa0203ea     	mov	x10, x2
ffffffc0081eae8c: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eae90: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eae94: b0012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eae98: 91095063     	add	x3, x3, #0x254
ffffffc0081eae9c: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eaea0: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eaea4: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eaea8: b0012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eaeac: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eaeb0: b0012daf     	adrp	x15, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eaeb4: 52800028     	mov	w8, #0x1        // =1
ffffffc0081eaeb8: 5280003a     	mov	w26, #0x1       // =1
ffffffc0081eaebc: aa1503f6     	mov	x22, x21
ffffffc0081eaec0: d538410c     	mrs	x12, SP_EL0
ffffffc0081eaec4: b81fc3a8     	stur	w8, [x29, #-0x4]
ffffffc0081eaec8: d503201f     	nop
ffffffc0081eaecc: 52800c08     	mov	w8, #0x60       // =96
ffffffc0081eaed0: d50342df     	msr	DAIFSet, #0x2
ffffffc0081eaed4: 91006194     	add	x20, x12, #0x18
ffffffc0081eaed8: 88dffe88     	ldar	w8, [x20]
ffffffc0081eaedc: 11000508     	add	w8, w8, #0x1
ffffffc0081eaee0: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eaee4: 9121b279     	add	x25, x19, #0x86c
ffffffc0081eaee8: 140001a6     	b	0xffffffc0081eb580 <rt_mutex_adjust_prio_chain+0x748>
ffffffc0081eaeec: 140001a5     	b	0xffffffc0081eb580 <rt_mutex_adjust_prio_chain+0x748>
ffffffc0081eaef0: aa1f03e1     	mov	x1, xzr
ffffffc0081eaef4: aa1903e0     	mov	x0, x25
ffffffc0081eaef8: 52800022     	mov	w2, #0x1        // =1
ffffffc0081eaefc: 2a0103e8     	mov	w8, w1
ffffffc0081eaf00: 88e87f22     	casa	w8, w2, [x25]
ffffffc0081eaf04: 2a0803e0     	mov	w0, w8
ffffffc0081eaf08: aa0003e1     	mov	x1, x0
ffffffc0081eaf0c: 350034c1     	cbnz	w1, 0xffffffc0081eb5a4 <rt_mutex_adjust_prio_chain+0x76c>
ffffffc0081eaf10: f9444e7c     	ldr	x28, [x19, #0x898]
ffffffc0081eaf14: b400965c     	cbz	x28, 0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eaf18: b40000b5     	cbz	x21, 0xffffffc0081eaf2c <rt_mutex_adjust_prio_chain+0xf4>
ffffffc0081eaf1c: 91006148     	add	x8, x10, #0x18
ffffffc0081eaf20: c8dffd08     	ldar	x8, [x8]
ffffffc0081eaf24: f100091f     	cmp	x8, #0x2
ffffffc0081eaf28: 540095a3     	b.lo	0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eaf2c: f9401f88     	ldr	x8, [x28, #0x38]
ffffffc0081eaf30: eb08031f     	cmp	x24, x8
ffffffc0081eaf34: 54009541     	b.ne	0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eaf38: b40001b6     	cbz	x22, 0xffffffc0081eaf6c <rt_mutex_adjust_prio_chain+0x134>
ffffffc0081eaf3c: 91220268     	add	x8, x19, #0x880
ffffffc0081eaf40: c8dffd08     	ldar	x8, [x8]
ffffffc0081eaf44: b40094c8     	cbz	x8, 0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eaf48: f9444668     	ldr	x8, [x19, #0x888]
ffffffc0081eaf4c: d1006108     	sub	x8, x8, #0x18
ffffffc0081eaf50: eb0802df     	cmp	x22, x8
ffffffc0081eaf54: 1a9f17e9     	cset	w9, eq
ffffffc0081eaf58: 710006ff     	cmp	w23, #0x1
ffffffc0081eaf5c: 0a09035a     	and	w26, w26, w9
ffffffc0081eaf60: 54000060     	b.eq	0xffffffc0081eaf6c <rt_mutex_adjust_prio_chain+0x134>
ffffffc0081eaf64: eb0802df     	cmp	x22, x8
ffffffc0081eaf68: 540093a1     	b.ne	0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eaf6c: b9408668     	ldr	w8, [x19, #0x84]
ffffffc0081eaf70: b9404389     	ldr	w9, [x28, #0x40]
ffffffc0081eaf74: 6b08013f     	cmp	w9, w8
ffffffc0081eaf78: 540001c1     	b.ne	0xffffffc0081eafb0 <rt_mutex_adjust_prio_chain+0x178>
ffffffc0081eaf7c: 37f80068     	tbnz	w8, #0x1f, 0xffffffc0081eaf88 <rt_mutex_adjust_prio_chain+0x150>
ffffffc0081eaf80: 52800028     	mov	w8, #0x1        // =1
ffffffc0081eaf84: 14000005     	b	0xffffffc0081eaf98 <rt_mutex_adjust_prio_chain+0x160>
ffffffc0081eaf88: f941b268     	ldr	x8, [x19, #0x360]
ffffffc0081eaf8c: f9402789     	ldr	x9, [x28, #0x48]
ffffffc0081eaf90: eb08013f     	cmp	x9, x8
ffffffc0081eaf94: 1a9f17e8     	cset	w8, eq
ffffffc0081eaf98: 7100011f     	cmp	w8, #0x0
ffffffc0081eaf9c: 1a9f17e9     	cset	w9, eq
ffffffc0081eafa0: 710006ff     	cmp	w23, #0x1
ffffffc0081eafa4: 0a09035a     	and	w26, w26, w9
ffffffc0081eafa8: 54000040     	b.eq	0xffffffc0081eafb0 <rt_mutex_adjust_prio_chain+0x178>
ffffffc0081eafac: 35009188     	cbnz	w8, 0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eafb0: f9401f9b     	ldr	x27, [x28, #0x38]
ffffffc0081eafb4: 88dffe88     	ldar	w8, [x20]
ffffffc0081eafb8: 11000508     	add	w8, w8, #0x1
ffffffc0081eafbc: b9000288     	str	w8, [x20]
ffffffc0081eafc0: 88dfff68     	ldar	w8, [x27]
ffffffc0081eafc4: 35000148     	cbnz	w8, 0xffffffc0081eafec <rt_mutex_adjust_prio_chain+0x1b4>
ffffffc0081eafc8: 14000074     	b	0xffffffc0081eb198 <rt_mutex_adjust_prio_chain+0x360>
ffffffc0081eafcc: 14000073     	b	0xffffffc0081eb198 <rt_mutex_adjust_prio_chain+0x360>
ffffffc0081eafd0: aa1b03e0     	mov	x0, x27
ffffffc0081eafd4: aa1f03e1     	mov	x1, xzr
ffffffc0081eafd8: 52800022     	mov	w2, #0x1        // =1
ffffffc0081eafdc: 2a0103e8     	mov	w8, w1
ffffffc0081eafe0: 88e87f62     	casa	w8, w2, [x27]
ffffffc0081eafe4: 2a0803e0     	mov	w0, w8
ffffffc0081eafe8: 34001060     	cbz	w0, 0xffffffc0081eb1f4 <rt_mutex_adjust_prio_chain+0x3bc>
ffffffc0081eafec: c8dffe88     	ldar	x8, [x20]
ffffffc0081eaff0: f1000508     	subs	x8, x8, #0x1
ffffffc0081eaff4: b9000288     	str	w8, [x20]
ffffffc0081eaff8: 540003c0     	b.eq	0xffffffc0081eb070 <rt_mutex_adjust_prio_chain+0x238>
ffffffc0081eaffc: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb000: b4000388     	cbz	x8, 0xffffffc0081eb070 <rt_mutex_adjust_prio_chain+0x238>
ffffffc0081eb004: 2a1f03e8     	mov	w8, wzr
ffffffc0081eb008: 089fff28     	stlrb	w8, [x25]
ffffffc0081eb00c: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081eb010: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb014: f1000508     	subs	x8, x8, #0x1
ffffffc0081eb018: b9000288     	str	w8, [x20]
ffffffc0081eb01c: 54000740     	b.eq	0xffffffc0081eb104 <rt_mutex_adjust_prio_chain+0x2cc>
ffffffc0081eb020: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb024: b4000708     	cbz	x8, 0xffffffc0081eb104 <rt_mutex_adjust_prio_chain+0x2cc>
ffffffc0081eb028: d503203f     	yield
ffffffc0081eb02c: d503201f     	nop
ffffffc0081eb030: 52800c08     	mov	w8, #0x60       // =96
ffffffc0081eb034: d50342df     	msr	DAIFSet, #0x2
ffffffc0081eb038: 88dffe88     	ldar	w8, [x20]
ffffffc0081eb03c: 11000508     	add	w8, w8, #0x1
ffffffc0081eb040: b9000288     	str	w8, [x20]
ffffffc0081eb044: 1400005f     	b	0xffffffc0081eb1c0 <rt_mutex_adjust_prio_chain+0x388>
ffffffc0081eb048: 1400005e     	b	0xffffffc0081eb1c0 <rt_mutex_adjust_prio_chain+0x388>
ffffffc0081eb04c: aa1f03e1     	mov	x1, xzr
ffffffc0081eb050: aa1903e0     	mov	x0, x25
ffffffc0081eb054: 52800022     	mov	w2, #0x1        // =1
ffffffc0081eb058: 2a0103e8     	mov	w8, w1
ffffffc0081eb05c: 88e87f22     	casa	w8, w2, [x25]
ffffffc0081eb060: 2a0803e0     	mov	w0, w8
ffffffc0081eb064: aa0003e1     	mov	x1, x0
ffffffc0081eb068: 34fff541     	cbz	w1, 0xffffffc0081eaf10 <rt_mutex_adjust_prio_chain+0xd8>
ffffffc0081eb06c: 1400014e     	b	0xffffffc0081eb5a4 <rt_mutex_adjust_prio_chain+0x76c>
ffffffc0081eb070: 91006188     	add	x8, x12, #0x18
ffffffc0081eb074: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb078: 35fffc68     	cbnz	w8, 0xffffffc0081eb004 <rt_mutex_adjust_prio_chain+0x1cc>
ffffffc0081eb07c: d53b4228     	mrs	x8, DAIF
ffffffc0081eb080: 12190109     	and	w9, w8, #0x80
ffffffc0081eb084: 35fffc09     	cbnz	w9, 0xffffffc0081eb004 <rt_mutex_adjust_prio_chain+0x1cc>
ffffffc0081eb088: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081eb08c: f81f03a5     	stur	x5, [x29, #-0x10]
ffffffc0081eb090: f9000fea     	str	x10, [sp, #0x18]
ffffffc0081eb094: 9100619b     	add	x27, x12, #0x18
ffffffc0081eb098: 88dfff68     	ldar	w8, [x27]
ffffffc0081eb09c: 11000508     	add	w8, w8, #0x1
ffffffc0081eb0a0: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb0a4: 52800020     	mov	w0, #0x1        // =1
ffffffc0081eb0a8: aa0f03fc     	mov	x28, x15
ffffffc0081eb0ac: 94605b7c     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081eb0b0: a9412bec     	ldp	x12, x10, [sp, #0x10]
ffffffc0081eb0b4: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081eb0b8: 88dfff68     	ldar	w8, [x27]
ffffffc0081eb0bc: 51000508     	sub	w8, w8, #0x1
ffffffc0081eb0c0: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb0c4: f9400188     	ldr	x8, [x12]
ffffffc0081eb0c8: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb0cc: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb0d0: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb0d4: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb0d8: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb0dc: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb0e0: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb0e4: 91095063     	add	x3, x3, #0x254
ffffffc0081eb0e8: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb0ec: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb0f0: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb0f4: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb0f8: aa1c03ef     	mov	x15, x28
ffffffc0081eb0fc: 370ffcc8     	tbnz	w8, #0x1, 0xffffffc0081eb094 <rt_mutex_adjust_prio_chain+0x25c>
ffffffc0081eb100: 17ffffc1     	b	0xffffffc0081eb004 <rt_mutex_adjust_prio_chain+0x1cc>
ffffffc0081eb104: 91006188     	add	x8, x12, #0x18
ffffffc0081eb108: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb10c: 35fff8e8     	cbnz	w8, 0xffffffc0081eb028 <rt_mutex_adjust_prio_chain+0x1f0>
ffffffc0081eb110: d53b4228     	mrs	x8, DAIF
ffffffc0081eb114: 12190109     	and	w9, w8, #0x80
ffffffc0081eb118: 35fff889     	cbnz	w9, 0xffffffc0081eb028 <rt_mutex_adjust_prio_chain+0x1f0>
ffffffc0081eb11c: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081eb120: f81f03a5     	stur	x5, [x29, #-0x10]
ffffffc0081eb124: f9000fea     	str	x10, [sp, #0x18]
ffffffc0081eb128: 9100619b     	add	x27, x12, #0x18
ffffffc0081eb12c: 88dfff68     	ldar	w8, [x27]
ffffffc0081eb130: 11000508     	add	w8, w8, #0x1
ffffffc0081eb134: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb138: 52800020     	mov	w0, #0x1        // =1
ffffffc0081eb13c: aa0f03fc     	mov	x28, x15
ffffffc0081eb140: 94605b57     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081eb144: a9412bec     	ldp	x12, x10, [sp, #0x10]
ffffffc0081eb148: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081eb14c: 88dfff68     	ldar	w8, [x27]
ffffffc0081eb150: 51000508     	sub	w8, w8, #0x1
ffffffc0081eb154: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb158: f9400188     	ldr	x8, [x12]
ffffffc0081eb15c: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb160: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb164: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb168: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb16c: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb170: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb174: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb178: 91095063     	add	x3, x3, #0x254
ffffffc0081eb17c: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb180: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb184: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb188: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb18c: aa1c03ef     	mov	x15, x28
ffffffc0081eb190: 370ffcc8     	tbnz	w8, #0x1, 0xffffffc0081eb128 <rt_mutex_adjust_prio_chain+0x2f0>
ffffffc0081eb194: 17ffffa5     	b	0xffffffc0081eb028 <rt_mutex_adjust_prio_chain+0x1f0>
ffffffc0081eb198: d503249f     	bti	j
ffffffc0081eb19c: aa1f03e8     	mov	x8, xzr
ffffffc0081eb1a0: f9800371     	prfm	pstl1strm, [x27]
ffffffc0081eb1a4: 885fff60     	ldaxr	w0, [x27]
ffffffc0081eb1a8: 4a080009     	eor	w9, w0, w8
ffffffc0081eb1ac: 35000069     	cbnz	w9, 0xffffffc0081eb1b8 <rt_mutex_adjust_prio_chain+0x380>
ffffffc0081eb1b0: 88097f6d     	stxr	w9, w13, [x27]
ffffffc0081eb1b4: 35ffff89     	cbnz	w9, 0xffffffc0081eb1a4 <rt_mutex_adjust_prio_chain+0x36c>
ffffffc0081eb1b8: 35fff1a0     	cbnz	w0, 0xffffffc0081eafec <rt_mutex_adjust_prio_chain+0x1b4>
ffffffc0081eb1bc: 1400000e     	b	0xffffffc0081eb1f4 <rt_mutex_adjust_prio_chain+0x3bc>
ffffffc0081eb1c0: d503249f     	bti	j
ffffffc0081eb1c4: aa1f03e8     	mov	x8, xzr
ffffffc0081eb1c8: f9800331     	prfm	pstl1strm, [x25]
ffffffc0081eb1cc: 885fff21     	ldaxr	w1, [x25]
ffffffc0081eb1d0: 4a080029     	eor	w9, w1, w8
ffffffc0081eb1d4: 35000069     	cbnz	w9, 0xffffffc0081eb1e0 <rt_mutex_adjust_prio_chain+0x3a8>
ffffffc0081eb1d8: 88097f2d     	stxr	w9, w13, [x25]
ffffffc0081eb1dc: 35ffff89     	cbnz	w9, 0xffffffc0081eb1cc <rt_mutex_adjust_prio_chain+0x394>
ffffffc0081eb1e0: 34ffe981     	cbz	w1, 0xffffffc0081eaf10 <rt_mutex_adjust_prio_chain+0xd8>
ffffffc0081eb1e4: 140000f0     	b	0xffffffc0081eb5a4 <rt_mutex_adjust_prio_chain+0x76c>
ffffffc0081eb1e8: d503249f     	bti	j
ffffffc0081eb1ec: 52801408     	mov	w8, #0xa0       // =160
ffffffc0081eb1f0: 17ffff91     	b	0xffffffc0081eb034 <rt_mutex_adjust_prio_chain+0x1fc>
ffffffc0081eb1f4: eb0a037f     	cmp	x27, x10
ffffffc0081eb1f8: 54008500     	b.eq	0xffffffc0081ec298 <rt_mutex_adjust_prio_chain+0x1460>
ffffffc0081eb1fc: 91006368     	add	x8, x27, #0x18
ffffffc0081eb200: c8dffd08     	ldar	x8, [x8]
ffffffc0081eb204: 927ff908     	and	x8, x8, #0xfffffffffffffffe
ffffffc0081eb208: eb05011f     	cmp	x8, x5
ffffffc0081eb20c: 54008440     	b.eq	0xffffffc0081ec294 <rt_mutex_adjust_prio_chain+0x145c>
ffffffc0081eb210: f81f03a5     	stur	x5, [x29, #-0x10]
ffffffc0081eb214: f9000fea     	str	x10, [sp, #0x18]
ffffffc0081eb218: 3600013a     	tbz	w26, #0x0, 0xffffffc0081eb23c <rt_mutex_adjust_prio_chain+0x404>
ffffffc0081eb21c: f9400b68     	ldr	x8, [x27, #0x10]
ffffffc0081eb220: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081eb224: b4000588     	cbz	x8, 0xffffffc0081eb2d4 <rt_mutex_adjust_prio_chain+0x49c>
ffffffc0081eb228: f9401d09     	ldr	x9, [x8, #0x38]
ffffffc0081eb22c: f90007e8     	str	x8, [sp, #0x8]
ffffffc0081eb230: eb1b013f     	cmp	x9, x27
ffffffc0081eb234: 54000520     	b.eq	0xffffffc0081eb2d8 <rt_mutex_adjust_prio_chain+0x4a0>
ffffffc0081eb238: 140004e2     	b	0xffffffc0081ec5c0 <rt_mutex_adjust_prio_chain+0x1788>
ffffffc0081eb23c: 2a1f03e8     	mov	w8, wzr
ffffffc0081eb240: 089fff28     	stlrb	w8, [x25]
ffffffc0081eb244: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb248: f1000508     	subs	x8, x8, #0x1
ffffffc0081eb24c: b9000288     	str	w8, [x20]
ffffffc0081eb250: 54001200     	b.eq	0xffffffc0081eb490 <rt_mutex_adjust_prio_chain+0x658>
ffffffc0081eb254: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb258: b40011c8     	cbz	x8, 0xffffffc0081eb490 <rt_mutex_adjust_prio_chain+0x658>
ffffffc0081eb25c: 91010268     	add	x8, x19, #0x40
ffffffc0081eb260: 140000ed     	b	0xffffffc0081eb614 <rt_mutex_adjust_prio_chain+0x7dc>
ffffffc0081eb264: 140000ec     	b	0xffffffc0081eb614 <rt_mutex_adjust_prio_chain+0x7dc>
ffffffc0081eb268: 52800029     	mov	w9, #0x1        // =1
ffffffc0081eb26c: 4b0903e9     	neg	w9, w9
ffffffc0081eb270: b8690109     	ldaddl	w9, w9, [x8]
ffffffc0081eb274: 7100052a     	subs	w10, w9, #0x1
ffffffc0081eb278: 54001e21     	b.ne	0xffffffc0081eb63c <rt_mutex_adjust_prio_chain+0x804>
ffffffc0081eb27c: d50339bf     	dmb	ishld
ffffffc0081eb280: aa1303e0     	mov	x0, x19
ffffffc0081eb284: aa0c03f3     	mov	x19, x12
ffffffc0081eb288: aa0f03f6     	mov	x22, x15
ffffffc0081eb28c: aa1003f9     	mov	x25, x16
ffffffc0081eb290: aa1103f8     	mov	x24, x17
ffffffc0081eb294: aa0303fc     	mov	x28, x3
ffffffc0081eb298: 97fcea45     	bl	0xffffffc008125bac <__put_task_struct>
ffffffc0081eb29c: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb2a0: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb2a4: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb2a8: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb2ac: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb2b0: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb2b4: aa1c03e3     	mov	x3, x28
ffffffc0081eb2b8: aa1803f1     	mov	x17, x24
ffffffc0081eb2bc: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb2c0: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb2c4: aa1903f0     	mov	x16, x25
ffffffc0081eb2c8: aa1603ef     	mov	x15, x22
ffffffc0081eb2cc: aa1303ec     	mov	x12, x19
ffffffc0081eb2d0: 140000dd     	b	0xffffffc0081eb644 <rt_mutex_adjust_prio_chain+0x80c>
ffffffc0081eb2d4: f90007ff     	str	xzr, [sp, #0x8]
ffffffc0081eb2d8: f9400389     	ldr	x9, [x28]
ffffffc0081eb2dc: eb1c013f     	cmp	x9, x28
ffffffc0081eb2e0: 54000300     	b.eq	0xffffffc0081eb340 <rt_mutex_adjust_prio_chain+0x508>
ffffffc0081eb2e4: aa1103f8     	mov	x24, x17
ffffffc0081eb2e8: aa0f03f6     	mov	x22, x15
ffffffc0081eb2ec: eb1c011f     	cmp	x8, x28
ffffffc0081eb2f0: 54000181     	b.ne	0xffffffc0081eb320 <rt_mutex_adjust_prio_chain+0x4e8>
ffffffc0081eb2f4: f9400109     	ldr	x9, [x8]
ffffffc0081eb2f8: eb08013f     	cmp	x9, x8
ffffffc0081eb2fc: 54000061     	b.ne	0xffffffc0081eb308 <rt_mutex_adjust_prio_chain+0x4d0>
ffffffc0081eb300: aa1f03e9     	mov	x9, xzr
ffffffc0081eb304: 14000006     	b	0xffffffc0081eb31c <rt_mutex_adjust_prio_chain+0x4e4>
ffffffc0081eb308: f940050a     	ldr	x10, [x8, #0x8]
ffffffc0081eb30c: b4000aea     	cbz	x10, 0xffffffc0081eb468 <rt_mutex_adjust_prio_chain+0x630>
ffffffc0081eb310: aa0a03e9     	mov	x9, x10
ffffffc0081eb314: f940094a     	ldr	x10, [x10, #0x10]
ffffffc0081eb318: b5ffffca     	cbnz	x10, 0xffffffc0081eb310 <rt_mutex_adjust_prio_chain+0x4d8>
ffffffc0081eb31c: f9000b69     	str	x9, [x27, #0x10]
ffffffc0081eb320: 91002361     	add	x1, x27, #0x8
ffffffc0081eb324: aa1c03e0     	mov	x0, x28
ffffffc0081eb328: 942217c0     	bl	0xffffffc008a71228 <rb_erase>
ffffffc0081eb32c: aa1603ef     	mov	x15, x22
ffffffc0081eb330: aa1803f1     	mov	x17, x24
ffffffc0081eb334: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb338: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb33c: f900039c     	str	x28, [x28]
ffffffc0081eb340: b9408668     	ldr	w8, [x19, #0x84]
ffffffc0081eb344: aa1b03e1     	mov	x1, x27
ffffffc0081eb348: b9004388     	str	w8, [x28, #0x40]
ffffffc0081eb34c: f941b26a     	ldr	x10, [x19, #0x360]
ffffffc0081eb350: f900278a     	str	x10, [x28, #0x48]
ffffffc0081eb354: f8408c2c     	ldr	x12, [x1, #0x8]!
ffffffc0081eb358: b400034c     	cbz	x12, 0xffffffc0081eb3c0 <rt_mutex_adjust_prio_chain+0x588>
ffffffc0081eb35c: 52800029     	mov	w9, #0x1        // =1
ffffffc0081eb360: 14000007     	b	0xffffffc0081eb37c <rt_mutex_adjust_prio_chain+0x544>
ffffffc0081eb364: 7100019f     	cmp	w12, #0x0
ffffffc0081eb368: 9a8400cd     	csel	x13, x6, x4, eq
ffffffc0081eb36c: f86d696c     	ldr	x12, [x11, x13]
ffffffc0081eb370: 1a9f07ee     	cset	w14, ne
ffffffc0081eb374: 0a0e0129     	and	w9, w9, w14
ffffffc0081eb378: b400016c     	cbz	x12, 0xffffffc0081eb3a4 <rt_mutex_adjust_prio_chain+0x56c>
ffffffc0081eb37c: aa0c03eb     	mov	x11, x12
ffffffc0081eb380: b940418c     	ldr	w12, [x12, #0x40]
ffffffc0081eb384: 6b0c011f     	cmp	w8, w12
ffffffc0081eb388: 1a9fa7ec     	cset	w12, lt
ffffffc0081eb38c: 36fffec8     	tbz	w8, #0x1f, 0xffffffc0081eb364 <rt_mutex_adjust_prio_chain+0x52c>
ffffffc0081eb390: 54fffeab     	b.lt	0xffffffc0081eb364 <rt_mutex_adjust_prio_chain+0x52c>
ffffffc0081eb394: f940256c     	ldr	x12, [x11, #0x48]
ffffffc0081eb398: cb0c014c     	sub	x12, x10, x12
ffffffc0081eb39c: d37ffd8c     	lsr	x12, x12, #63
ffffffc0081eb3a0: 17fffff1     	b	0xffffffc0081eb364 <rt_mutex_adjust_prio_chain+0x52c>
ffffffc0081eb3a4: aa1103f8     	mov	x24, x17
ffffffc0081eb3a8: aa0f03f6     	mov	x22, x15
ffffffc0081eb3ac: a9007f8b     	stp	x11, xzr, [x28]
ffffffc0081eb3b0: f9000b9f     	str	xzr, [x28, #0x10]
ffffffc0081eb3b4: f82d697c     	str	x28, [x11, x13]
ffffffc0081eb3b8: 350000e9     	cbnz	w9, 0xffffffc0081eb3d4 <rt_mutex_adjust_prio_chain+0x59c>
ffffffc0081eb3bc: 14000007     	b	0xffffffc0081eb3d8 <rt_mutex_adjust_prio_chain+0x5a0>
ffffffc0081eb3c0: aa1103f8     	mov	x24, x17
ffffffc0081eb3c4: aa0f03f6     	mov	x22, x15
ffffffc0081eb3c8: a900ff9f     	stp	xzr, xzr, [x28, #0x8]
ffffffc0081eb3cc: f900039f     	str	xzr, [x28]
ffffffc0081eb3d0: f900003c     	str	x28, [x1]
ffffffc0081eb3d4: f9000b7c     	str	x28, [x27, #0x10]
ffffffc0081eb3d8: aa1c03e0     	mov	x0, x28
ffffffc0081eb3dc: 9422171f     	bl	0xffffffc008a71058 <rb_insert_color>
ffffffc0081eb3e0: 2a1f03e8     	mov	w8, wzr
ffffffc0081eb3e4: 089fff28     	stlrb	w8, [x25]
ffffffc0081eb3e8: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb3ec: f1000508     	subs	x8, x8, #0x1
ffffffc0081eb3f0: b9000288     	str	w8, [x20]
ffffffc0081eb3f4: 540009a0     	b.eq	0xffffffc0081eb528 <rt_mutex_adjust_prio_chain+0x6f0>
ffffffc0081eb3f8: c8dffe88     	ldar	x8, [x20]
ffffffc0081eb3fc: b4000968     	cbz	x8, 0xffffffc0081eb528 <rt_mutex_adjust_prio_chain+0x6f0>
ffffffc0081eb400: 91010268     	add	x8, x19, #0x40
ffffffc0081eb404: 140000e9     	b	0xffffffc0081eb7a8 <rt_mutex_adjust_prio_chain+0x970>
ffffffc0081eb408: 140000e8     	b	0xffffffc0081eb7a8 <rt_mutex_adjust_prio_chain+0x970>
ffffffc0081eb40c: 52800029     	mov	w9, #0x1        // =1
ffffffc0081eb410: 4b0903e9     	neg	w9, w9
ffffffc0081eb414: b8690109     	ldaddl	w9, w9, [x8]
ffffffc0081eb418: 7100052a     	subs	w10, w9, #0x1
ffffffc0081eb41c: 54001d81     	b.ne	0xffffffc0081eb7cc <rt_mutex_adjust_prio_chain+0x994>
ffffffc0081eb420: d50339bf     	dmb	ishld
ffffffc0081eb424: aa1303e0     	mov	x0, x19
ffffffc0081eb428: 97fce9e1     	bl	0xffffffc008125bac <__put_task_struct>
ffffffc0081eb42c: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081eb430: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb434: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb438: aa1603ef     	mov	x15, x22
ffffffc0081eb43c: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb440: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb444: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb448: aa1803f1     	mov	x17, x24
ffffffc0081eb44c: 91095063     	add	x3, x3, #0x254
ffffffc0081eb450: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb454: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb458: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb45c: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb460: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb464: 140000ea     	b	0xffffffc0081eb80c <rt_mutex_adjust_prio_chain+0x9d4>
ffffffc0081eb468: f27ef529     	ands	x9, x9, #0xfffffffffffffffc
ffffffc0081eb46c: 54fff580     	b.eq	0xffffffc0081eb31c <rt_mutex_adjust_prio_chain+0x4e4>
ffffffc0081eb470: f940052a     	ldr	x10, [x9, #0x8]
ffffffc0081eb474: eb0a011f     	cmp	x8, x10
ffffffc0081eb478: 54fff521     	b.ne	0xffffffc0081eb31c <rt_mutex_adjust_prio_chain+0x4e4>
ffffffc0081eb47c: f940012a     	ldr	x10, [x9]
ffffffc0081eb480: aa0903e8     	mov	x8, x9
ffffffc0081eb484: f27ef549     	ands	x9, x10, #0xfffffffffffffffc
ffffffc0081eb488: 54ffff41     	b.ne	0xffffffc0081eb470 <rt_mutex_adjust_prio_chain+0x638>
ffffffc0081eb48c: 17ffffa4     	b	0xffffffc0081eb31c <rt_mutex_adjust_prio_chain+0x4e4>
ffffffc0081eb490: 91006188     	add	x8, x12, #0x18
ffffffc0081eb494: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb498: 35ffee28     	cbnz	w8, 0xffffffc0081eb25c <rt_mutex_adjust_prio_chain+0x424>
ffffffc0081eb49c: d53b4228     	mrs	x8, DAIF
ffffffc0081eb4a0: 12190109     	and	w9, w8, #0x80
ffffffc0081eb4a4: 35ffedc9     	cbnz	w9, 0xffffffc0081eb25c <rt_mutex_adjust_prio_chain+0x424>
ffffffc0081eb4a8: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081eb4ac: 91006196     	add	x22, x12, #0x18
ffffffc0081eb4b0: 88dffec8     	ldar	w8, [x22]
ffffffc0081eb4b4: 11000508     	add	w8, w8, #0x1
ffffffc0081eb4b8: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb4bc: 52800020     	mov	w0, #0x1        // =1
ffffffc0081eb4c0: aa0f03f9     	mov	x25, x15
ffffffc0081eb4c4: aa0503fc     	mov	x28, x5
ffffffc0081eb4c8: aa0a03f8     	mov	x24, x10
ffffffc0081eb4cc: 94605a74     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081eb4d0: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081eb4d4: 88dffec8     	ldar	w8, [x22]
ffffffc0081eb4d8: 51000508     	sub	w8, w8, #0x1
ffffffc0081eb4dc: b9001988     	str	w8, [x12, #0x18]
ffffffc0081eb4e0: f9400188     	ldr	x8, [x12]
ffffffc0081eb4e4: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb4e8: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb4ec: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb4f0: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb4f4: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb4f8: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb4fc: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb500: 91095063     	add	x3, x3, #0x254
ffffffc0081eb504: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb508: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb50c: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb510: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb514: aa1803ea     	mov	x10, x24
ffffffc0081eb518: aa1c03e5     	mov	x5, x28
ffffffc0081eb51c: aa1903ef     	mov	x15, x25
ffffffc0081eb520: 370ffc68     	tbnz	w8, #0x1, 0xffffffc0081eb4ac <rt_mutex_adjust_prio_chain+0x674>
ffffffc0081eb524: 17ffff4e     	b	0xffffffc0081eb25c <rt_mutex_adjust_prio_chain+0x424>
ffffffc0081eb528: f9400be8     	ldr	x8, [sp, #0x10]
ffffffc0081eb52c: 91006108     	add	x8, x8, #0x18
ffffffc0081eb530: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb534: 35fff668     	cbnz	w8, 0xffffffc0081eb400 <rt_mutex_adjust_prio_chain+0x5c8>
ffffffc0081eb538: d53b4228     	mrs	x8, DAIF
ffffffc0081eb53c: 12190109     	and	w9, w8, #0x80
ffffffc0081eb540: 35fff609     	cbnz	w9, 0xffffffc0081eb400 <rt_mutex_adjust_prio_chain+0x5c8>
ffffffc0081eb544: f9400bf9     	ldr	x25, [sp, #0x10]
ffffffc0081eb548: 52800020     	mov	w0, #0x1        // =1
ffffffc0081eb54c: 91006328     	add	x8, x25, #0x18
ffffffc0081eb550: f90003e8     	str	x8, [sp]
ffffffc0081eb554: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb558: 11000508     	add	w8, w8, #0x1
ffffffc0081eb55c: b9001b28     	str	w8, [x25, #0x18]
ffffffc0081eb560: 94605a4f     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081eb564: f94003e8     	ldr	x8, [sp]
ffffffc0081eb568: 88dffd08     	ldar	w8, [x8]
ffffffc0081eb56c: 51000508     	sub	w8, w8, #0x1
ffffffc0081eb570: b9001b28     	str	w8, [x25, #0x18]
ffffffc0081eb574: f9400328     	ldr	x8, [x25]
ffffffc0081eb578: 370ffe68     	tbnz	w8, #0x1, 0xffffffc0081eb544 <rt_mutex_adjust_prio_chain+0x70c>
ffffffc0081eb57c: 17ffffa1     	b	0xffffffc0081eb400 <rt_mutex_adjust_prio_chain+0x5c8>
ffffffc0081eb580: d503249f     	bti	j
ffffffc0081eb584: aa1f03e8     	mov	x8, xzr
ffffffc0081eb588: f9800331     	prfm	pstl1strm, [x25]
ffffffc0081eb58c: 885fff21     	ldaxr	w1, [x25]
ffffffc0081eb590: 4a080029     	eor	w9, w1, w8
ffffffc0081eb594: 35000069     	cbnz	w9, 0xffffffc0081eb5a0 <rt_mutex_adjust_prio_chain+0x768>
ffffffc0081eb598: 88097f2d     	stxr	w9, w13, [x25]
ffffffc0081eb59c: 35ffff89     	cbnz	w9, 0xffffffc0081eb58c <rt_mutex_adjust_prio_chain+0x754>
ffffffc0081eb5a0: 34ffcb81     	cbz	w1, 0xffffffc0081eaf10 <rt_mutex_adjust_prio_chain+0xd8>
ffffffc0081eb5a4: aa1903e0     	mov	x0, x25
ffffffc0081eb5a8: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081eb5ac: aa0f03fc     	mov	x28, x15
ffffffc0081eb5b0: f81f03a5     	stur	x5, [x29, #-0x10]
ffffffc0081eb5b4: aa0a03fb     	mov	x27, x10
ffffffc0081eb5b8: 97fff774     	bl	0xffffffc0081e9388 <queued_spin_lock_slowpath>
ffffffc0081eb5bc: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081eb5c0: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081eb5c4: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb5c8: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb5cc: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb5d0: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb5d4: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb5d8: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb5dc: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb5e0: 91095063     	add	x3, x3, #0x254
ffffffc0081eb5e4: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb5e8: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb5ec: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb5f0: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb5f4: aa1b03ea     	mov	x10, x27
ffffffc0081eb5f8: aa1c03ef     	mov	x15, x28
ffffffc0081eb5fc: f9444e7c     	ldr	x28, [x19, #0x898]
ffffffc0081eb600: b5ffc8dc     	cbnz	x28, 0xffffffc0081eaf18 <rt_mutex_adjust_prio_chain+0xe0>
ffffffc0081eb604: 140002f6     	b	0xffffffc0081ec1dc <rt_mutex_adjust_prio_chain+0x13a4>
ffffffc0081eb608: d503249f     	bti	j
ffffffc0081eb60c: 52801408     	mov	w8, #0xa0       // =160
ffffffc0081eb610: 17fffe30     	b	0xffffffc0081eaed0 <rt_mutex_adjust_prio_chain+0x98>
ffffffc0081eb614: d503249f     	bti	j
ffffffc0081eb618: aa0b03e0     	mov	x0, x11
ffffffc0081eb61c: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081eb620: 885f7d09     	ldxr	w9, [x8]
ffffffc0081eb624: 4b0d012a     	sub	w10, w9, w13
ffffffc0081eb628: 880bfd0a     	stlxr	w11, w10, [x8]
ffffffc0081eb62c: 35ffffab     	cbnz	w11, 0xffffffc0081eb620 <rt_mutex_adjust_prio_chain+0x7e8>
ffffffc0081eb630: aa0003eb     	mov	x11, x0
ffffffc0081eb634: 7100052a     	subs	w10, w9, #0x1
ffffffc0081eb638: 54ffe220     	b.eq	0xffffffc0081eb27c <rt_mutex_adjust_prio_chain+0x444>
ffffffc0081eb63c: 2a090149     	orr	w9, w10, w9
ffffffc0081eb640: 37f807e9     	tbnz	w9, #0x1f, 0xffffffc0081eb73c <rt_mutex_adjust_prio_chain+0x904>
ffffffc0081eb644: 91006368     	add	x8, x27, #0x18
ffffffc0081eb648: c8dffd09     	ldar	x9, [x8]
ffffffc0081eb64c: f100053f     	cmp	x9, #0x1
ffffffc0081eb650: 540064a9     	b.ls	0xffffffc0081ec2e4 <rt_mutex_adjust_prio_chain+0x14ac>
ffffffc0081eb654: c8dffd08     	ldar	x8, [x8]
ffffffc0081eb658: 927ff913     	and	x19, x8, #0xfffffffffffffffe
ffffffc0081eb65c: 91010268     	add	x8, x19, #0x40
ffffffc0081eb660: 14000120     	b	0xffffffc0081ebae0 <rt_mutex_adjust_prio_chain+0xca8>
ffffffc0081eb664: 1400011f     	b	0xffffffc0081ebae0 <rt_mutex_adjust_prio_chain+0xca8>
ffffffc0081eb668: 52800029     	mov	w9, #0x1        // =1
ffffffc0081eb66c: b8290109     	ldadd	w9, w9, [x8]
ffffffc0081eb670: 340024a9     	cbz	w9, 0xffffffc0081ebb04 <rt_mutex_adjust_prio_chain+0xccc>
ffffffc0081eb674: 1100052a     	add	w10, w9, #0x1
ffffffc0081eb678: 2a090149     	orr	w9, w10, w9
ffffffc0081eb67c: 37f802e9     	tbnz	w9, #0x1f, 0xffffffc0081eb6d8 <rt_mutex_adjust_prio_chain+0x8a0>
ffffffc0081eb680: 88dffe88     	ldar	w8, [x20]
ffffffc0081eb684: 11000508     	add	w8, w8, #0x1
ffffffc0081eb688: b9000288     	str	w8, [x20]
ffffffc0081eb68c: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081eb690: f9400fea     	ldr	x10, [sp, #0x18]
ffffffc0081eb694: 9121b279     	add	x25, x19, #0x86c
ffffffc0081eb698: 14000134     	b	0xffffffc0081ebb68 <rt_mutex_adjust_prio_chain+0xd30>
ffffffc0081eb69c: 14000133     	b	0xffffffc0081ebb68 <rt_mutex_adjust_prio_chain+0xd30>
ffffffc0081eb6a0: aa1f03e1     	mov	x1, xzr
ffffffc0081eb6a4: aa1903e0     	mov	x0, x25
ffffffc0081eb6a8: 52800022     	mov	w2, #0x1        // =1
ffffffc0081eb6ac: 2a0103e8     	mov	w8, w1
ffffffc0081eb6b0: 88e87f22     	casa	w8, w2, [x25]
ffffffc0081eb6b4: 2a0803e0     	mov	w0, w8
ffffffc0081eb6b8: aa0003e1     	mov	x1, x0
ffffffc0081eb6bc: 35002681     	cbnz	w1, 0xffffffc0081ebb8c <rt_mutex_adjust_prio_chain+0xd54>
ffffffc0081eb6c0: f9444e68     	ldr	x8, [x19, #0x898]
ffffffc0081eb6c4: b4002948     	cbz	x8, 0xffffffc0081ebbec <rt_mutex_adjust_prio_chain+0xdb4>
ffffffc0081eb6c8: f9401d18     	ldr	x24, [x8, #0x38]
ffffffc0081eb6cc: f9400b76     	ldr	x22, [x27, #0x10]
ffffffc0081eb6d0: b5002956     	cbnz	x22, 0xffffffc0081ebbf8 <rt_mutex_adjust_prio_chain+0xdc0>
ffffffc0081eb6d4: 1400014c     	b	0xffffffc0081ebc04 <rt_mutex_adjust_prio_chain+0xdcc>
ffffffc0081eb6d8: b900010e     	str	w14, [x8]
ffffffc0081eb6dc: 397a7168     	ldrb	w8, [x11, #0xe9c]
ffffffc0081eb6e0: 3707fd08     	tbnz	w8, #0x0, 0xffffffc0081eb680 <rt_mutex_adjust_prio_chain+0x848>
ffffffc0081eb6e4: aa1e03e0     	mov	x0, x30
ffffffc0081eb6e8: 393a716d     	strb	w13, [x11, #0xe9c]
ffffffc0081eb6ec: aa0c03f6     	mov	x22, x12
ffffffc0081eb6f0: aa0f03f9     	mov	x25, x15
ffffffc0081eb6f4: aa1103f8     	mov	x24, x17
ffffffc0081eb6f8: aa1e03fc     	mov	x28, x30
ffffffc0081eb6fc: 97fcfdfe     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081eb700: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb704: aa1c03fe     	mov	x30, x28
ffffffc0081eb708: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb70c: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb710: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb714: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb718: 91095063     	add	x3, x3, #0x254
ffffffc0081eb71c: aa1803f1     	mov	x17, x24
ffffffc0081eb720: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb724: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb728: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb72c: aa1903ef     	mov	x15, x25
ffffffc0081eb730: aa1603ec     	mov	x12, x22
ffffffc0081eb734: d4210000     	brk	#0x800
ffffffc0081eb738: 17ffffd2     	b	0xffffffc0081eb680 <rt_mutex_adjust_prio_chain+0x848>
ffffffc0081eb73c: b900010e     	str	w14, [x8]
ffffffc0081eb740: 397a79e8     	ldrb	w8, [x15, #0xe9e]
ffffffc0081eb744: 3707f808     	tbnz	w8, #0x0, 0xffffffc0081eb644 <rt_mutex_adjust_prio_chain+0x80c>
ffffffc0081eb748: f000f360     	adrp	x0, 0xffffffc00a05a000 <hci_reset_dev.hw_err+0x2616f>
ffffffc0081eb74c: 911d6000     	add	x0, x0, #0x758
ffffffc0081eb750: 393a79ed     	strb	w13, [x15, #0xe9e]
ffffffc0081eb754: aa0c03f3     	mov	x19, x12
ffffffc0081eb758: aa0f03f6     	mov	x22, x15
ffffffc0081eb75c: aa1003f9     	mov	x25, x16
ffffffc0081eb760: aa1103f8     	mov	x24, x17
ffffffc0081eb764: aa1e03fc     	mov	x28, x30
ffffffc0081eb768: 97fcfde3     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081eb76c: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb770: aa1c03fe     	mov	x30, x28
ffffffc0081eb774: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb778: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb77c: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb780: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb784: 91095063     	add	x3, x3, #0x254
ffffffc0081eb788: aa1803f1     	mov	x17, x24
ffffffc0081eb78c: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb790: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb794: aa1903f0     	mov	x16, x25
ffffffc0081eb798: aa1603ef     	mov	x15, x22
ffffffc0081eb79c: aa1303ec     	mov	x12, x19
ffffffc0081eb7a0: d4210000     	brk	#0x800
ffffffc0081eb7a4: 17ffffa8     	b	0xffffffc0081eb644 <rt_mutex_adjust_prio_chain+0x80c>
ffffffc0081eb7a8: d503249f     	bti	j
ffffffc0081eb7ac: 5280002c     	mov	w12, #0x1       // =1
ffffffc0081eb7b0: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081eb7b4: 885f7d09     	ldxr	w9, [x8]
ffffffc0081eb7b8: 4b0c012a     	sub	w10, w9, w12
ffffffc0081eb7bc: 880bfd0a     	stlxr	w11, w10, [x8]
ffffffc0081eb7c0: 35ffffab     	cbnz	w11, 0xffffffc0081eb7b4 <rt_mutex_adjust_prio_chain+0x97c>
ffffffc0081eb7c4: 7100052a     	subs	w10, w9, #0x1
ffffffc0081eb7c8: 54ffe2c0     	b.eq	0xffffffc0081eb420 <rt_mutex_adjust_prio_chain+0x5e8>
ffffffc0081eb7cc: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081eb7d0: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eb7d4: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eb7d8: 2a090149     	orr	w9, w10, w9
ffffffc0081eb7dc: aa1603ef     	mov	x15, x22
ffffffc0081eb7e0: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb7e4: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eb7e8: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eb7ec: aa1803f1     	mov	x17, x24
ffffffc0081eb7f0: 91095063     	add	x3, x3, #0x254
ffffffc0081eb7f4: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb7f8: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb7fc: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eb800: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb804: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eb808: 37f81369     	tbnz	w9, #0x1f, 0xffffffc0081eba74 <rt_mutex_adjust_prio_chain+0xc3c>
ffffffc0081eb80c: 91006368     	add	x8, x27, #0x18
ffffffc0081eb810: c8dffd09     	ldar	x9, [x8]
ffffffc0081eb814: f100053f     	cmp	x9, #0x1
ffffffc0081eb818: 54005549     	b.ls	0xffffffc0081ec2c0 <rt_mutex_adjust_prio_chain+0x1488>
ffffffc0081eb81c: c8dffd08     	ldar	x8, [x8]
ffffffc0081eb820: 927ff913     	and	x19, x8, #0xfffffffffffffffe
ffffffc0081eb824: 91010268     	add	x8, x19, #0x40
ffffffc0081eb828: 14000153     	b	0xffffffc0081ebd74 <rt_mutex_adjust_prio_chain+0xf3c>
ffffffc0081eb82c: 14000152     	b	0xffffffc0081ebd74 <rt_mutex_adjust_prio_chain+0xf3c>
ffffffc0081eb830: 52800029     	mov	w9, #0x1        // =1
ffffffc0081eb834: b8290109     	ldadd	w9, w9, [x8]
ffffffc0081eb838: 34002b09     	cbz	w9, 0xffffffc0081ebd98 <rt_mutex_adjust_prio_chain+0xf60>
ffffffc0081eb83c: 1100052a     	add	w10, w9, #0x1
ffffffc0081eb840: 2a090149     	orr	w9, w10, w9
ffffffc0081eb844: 37f80e69     	tbnz	w9, #0x1f, 0xffffffc0081eba10 <rt_mutex_adjust_prio_chain+0xbd8>
ffffffc0081eb848: 88dffe88     	ldar	w8, [x20]
ffffffc0081eb84c: 11000508     	add	w8, w8, #0x1
ffffffc0081eb850: b9000288     	str	w8, [x20]
ffffffc0081eb854: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081eb858: f9400fea     	ldr	x10, [sp, #0x18]
ffffffc0081eb85c: 9121b279     	add	x25, x19, #0x86c
ffffffc0081eb860: 14000167     	b	0xffffffc0081ebdfc <rt_mutex_adjust_prio_chain+0xfc4>
ffffffc0081eb864: 14000166     	b	0xffffffc0081ebdfc <rt_mutex_adjust_prio_chain+0xfc4>
ffffffc0081eb868: aa1f03e1     	mov	x1, xzr
ffffffc0081eb86c: aa1903e0     	mov	x0, x25
ffffffc0081eb870: 52800022     	mov	w2, #0x1        // =1
ffffffc0081eb874: 2a0103e8     	mov	w8, w1
ffffffc0081eb878: 88e87f22     	casa	w8, w2, [x25]
ffffffc0081eb87c: 2a0803e0     	mov	w0, w8
ffffffc0081eb880: aa0003e1     	mov	x1, x0
ffffffc0081eb884: 35002ce1     	cbnz	w1, 0xffffffc0081ebe20 <rt_mutex_adjust_prio_chain+0xfe8>
ffffffc0081eb888: f9400b68     	ldr	x8, [x27, #0x10]
ffffffc0081eb88c: b4002fc8     	cbz	x8, 0xffffffc0081ebe84 <rt_mutex_adjust_prio_chain+0x104c>
ffffffc0081eb890: f9401d09     	ldr	x9, [x8, #0x38]
ffffffc0081eb894: eb1b013f     	cmp	x9, x27
ffffffc0081eb898: aa0803e9     	mov	x9, x8
ffffffc0081eb89c: 54006941     	b.ne	0xffffffc0081ec5c4 <rt_mutex_adjust_prio_chain+0x178c>
ffffffc0081eb8a0: eb09039f     	cmp	x28, x9
ffffffc0081eb8a4: 54002f60     	b.eq	0xffffffc0081ebe90 <rt_mutex_adjust_prio_chain+0x1058>
ffffffc0081eb8a8: f94007e9     	ldr	x9, [sp, #0x8]
ffffffc0081eb8ac: eb1c013f     	cmp	x9, x28
ffffffc0081eb8b0: 54003a01     	b.ne	0xffffffc0081ebff0 <rt_mutex_adjust_prio_chain+0x11b8>
ffffffc0081eb8b4: aa1c03f8     	mov	x24, x28
ffffffc0081eb8b8: f8418f09     	ldr	x9, [x24, #0x18]!
ffffffc0081eb8bc: f90003f9     	str	x25, [sp]
ffffffc0081eb8c0: eb18013f     	cmp	x9, x24
ffffffc0081eb8c4: 540002a0     	b.eq	0xffffffc0081eb918 <rt_mutex_adjust_prio_chain+0xae0>
ffffffc0081eb8c8: f9444668     	ldr	x8, [x19, #0x888]
ffffffc0081eb8cc: aa1103f9     	mov	x25, x17
ffffffc0081eb8d0: eb18011f     	cmp	x8, x24
ffffffc0081eb8d4: 540000e1     	b.ne	0xffffffc0081eb8f0 <rt_mutex_adjust_prio_chain+0xab8>
ffffffc0081eb8d8: f940138a     	ldr	x10, [x28, #0x20]
ffffffc0081eb8dc: b400084a     	cbz	x10, 0xffffffc0081eb9e4 <rt_mutex_adjust_prio_chain+0xbac>
ffffffc0081eb8e0: aa0a03e8     	mov	x8, x10
ffffffc0081eb8e4: f940094a     	ldr	x10, [x10, #0x10]
ffffffc0081eb8e8: b5ffffca     	cbnz	x10, 0xffffffc0081eb8e0 <rt_mutex_adjust_prio_chain+0xaa8>
ffffffc0081eb8ec: f9044668     	str	x8, [x19, #0x888]
ffffffc0081eb8f0: 91220261     	add	x1, x19, #0x880
ffffffc0081eb8f4: aa1803e0     	mov	x0, x24
ffffffc0081eb8f8: 9422164c     	bl	0xffffffc008a71228 <rb_erase>
ffffffc0081eb8fc: f9000318     	str	x24, [x24]
ffffffc0081eb900: f9400b68     	ldr	x8, [x27, #0x10]
ffffffc0081eb904: 90012daf     	adrp	x15, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eb908: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081eb90c: aa1903f1     	mov	x17, x25
ffffffc0081eb910: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eb914: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eb918: b40000c8     	cbz	x8, 0xffffffc0081eb930 <rt_mutex_adjust_prio_chain+0xaf8>
ffffffc0081eb91c: f9401d09     	ldr	x9, [x8, #0x38]
ffffffc0081eb920: aa0803fc     	mov	x28, x8
ffffffc0081eb924: eb1b013f     	cmp	x9, x27
ffffffc0081eb928: 54000060     	b.eq	0xffffffc0081eb934 <rt_mutex_adjust_prio_chain+0xafc>
ffffffc0081eb92c: 14000327     	b	0xffffffc0081ec5c8 <rt_mutex_adjust_prio_chain+0x1790>
ffffffc0081eb930: aa1f03fc     	mov	x28, xzr
ffffffc0081eb934: f944426c     	ldr	x12, [x19, #0x880]
ffffffc0081eb938: 91220261     	add	x1, x19, #0x880
ffffffc0081eb93c: b400030c     	cbz	x12, 0xffffffc0081eb99c <rt_mutex_adjust_prio_chain+0xb64>
ffffffc0081eb940: b940438a     	ldr	w10, [x28, #0x40]
ffffffc0081eb944: 52800028     	mov	w8, #0x1        // =1
ffffffc0081eb948: 1400000a     	b	0xffffffc0081eb970 <rt_mutex_adjust_prio_chain+0xb38>
ffffffc0081eb94c: 7100017f     	cmp	w11, #0x0
ffffffc0081eb950: 9a8400cc     	csel	x12, x6, x4, eq
ffffffc0081eb954: f86c692c     	ldr	x12, [x9, x12]
ffffffc0081eb958: 1a9f07eb     	cset	w11, ne
ffffffc0081eb95c: 9100412d     	add	x13, x9, #0x10
ffffffc0081eb960: 9100212e     	add	x14, x9, #0x8
ffffffc0081eb964: 0a0b0108     	and	w8, w8, w11
ffffffc0081eb968: 9a8d01cb     	csel	x11, x14, x13, eq
ffffffc0081eb96c: b40001ec     	cbz	x12, 0xffffffc0081eb9a8 <rt_mutex_adjust_prio_chain+0xb70>
ffffffc0081eb970: b940298b     	ldr	w11, [x12, #0x28]
ffffffc0081eb974: aa0c03e9     	mov	x9, x12
ffffffc0081eb978: 6b0b015f     	cmp	w10, w11
ffffffc0081eb97c: 1a9fa7eb     	cset	w11, lt
ffffffc0081eb980: 36fffe6a     	tbz	w10, #0x1f, 0xffffffc0081eb94c <rt_mutex_adjust_prio_chain+0xb14>
ffffffc0081eb984: 54fffe4b     	b.lt	0xffffffc0081eb94c <rt_mutex_adjust_prio_chain+0xb14>
ffffffc0081eb988: f940278b     	ldr	x11, [x28, #0x48]
ffffffc0081eb98c: f940192c     	ldr	x12, [x9, #0x30]
ffffffc0081eb990: cb0c016b     	sub	x11, x11, x12
ffffffc0081eb994: d37ffd6b     	lsr	x11, x11, #63
ffffffc0081eb998: 17ffffed     	b	0xffffffc0081eb94c <rt_mutex_adjust_prio_chain+0xb14>
ffffffc0081eb99c: aa1f03e9     	mov	x9, xzr
ffffffc0081eb9a0: 52800028     	mov	w8, #0x1        // =1
ffffffc0081eb9a4: aa0103eb     	mov	x11, x1
ffffffc0081eb9a8: aa1c03e0     	mov	x0, x28
ffffffc0081eb9ac: aa1103f9     	mov	x25, x17
ffffffc0081eb9b0: aa1003f8     	mov	x24, x16
ffffffc0081eb9b4: aa0f03f6     	mov	x22, x15
ffffffc0081eb9b8: f8018c09     	str	x9, [x0, #0x18]!
ffffffc0081eb9bc: a900fc1f     	stp	xzr, xzr, [x0, #0x8]
ffffffc0081eb9c0: f9000160     	str	x0, [x11]
ffffffc0081eb9c4: 34000048     	cbz	w8, 0xffffffc0081eb9cc <rt_mutex_adjust_prio_chain+0xb94>
ffffffc0081eb9c8: f9044660     	str	x0, [x19, #0x888]
ffffffc0081eb9cc: 942215a3     	bl	0xffffffc008a71058 <rb_insert_color>
ffffffc0081eb9d0: 91220268     	add	x8, x19, #0x880
ffffffc0081eb9d4: c8dffd08     	ldar	x8, [x8]
ffffffc0081eb9d8: b5002e48     	cbnz	x8, 0xffffffc0081ebfa0 <rt_mutex_adjust_prio_chain+0x1168>
ffffffc0081eb9dc: aa1f03e1     	mov	x1, xzr
ffffffc0081eb9e0: 14000172     	b	0xffffffc0081ebfa8 <rt_mutex_adjust_prio_chain+0x1170>
ffffffc0081eb9e4: f27ef528     	ands	x8, x9, #0xfffffffffffffffc
ffffffc0081eb9e8: 54fff820     	b.eq	0xffffffc0081eb8ec <rt_mutex_adjust_prio_chain+0xab4>
ffffffc0081eb9ec: aa1803e9     	mov	x9, x24
ffffffc0081eb9f0: f940050a     	ldr	x10, [x8, #0x8]
ffffffc0081eb9f4: eb0a013f     	cmp	x9, x10
ffffffc0081eb9f8: 54fff7a1     	b.ne	0xffffffc0081eb8ec <rt_mutex_adjust_prio_chain+0xab4>
ffffffc0081eb9fc: f940010a     	ldr	x10, [x8]
ffffffc0081eba00: aa0803e9     	mov	x9, x8
ffffffc0081eba04: f27ef548     	ands	x8, x10, #0xfffffffffffffffc
ffffffc0081eba08: 54ffff41     	b.ne	0xffffffc0081eb9f0 <rt_mutex_adjust_prio_chain+0xbb8>
ffffffc0081eba0c: 17ffffb8     	b	0xffffffc0081eb8ec <rt_mutex_adjust_prio_chain+0xab4>
ffffffc0081eba10: b900010e     	str	w14, [x8]
ffffffc0081eba14: 397a7168     	ldrb	w8, [x11, #0xe9c]
ffffffc0081eba18: 3707f188     	tbnz	w8, #0x0, 0xffffffc0081eb848 <rt_mutex_adjust_prio_chain+0xa10>
ffffffc0081eba1c: aa1e03e0     	mov	x0, x30
ffffffc0081eba20: 393a716d     	strb	w13, [x11, #0xe9c]
ffffffc0081eba24: aa0c03f8     	mov	x24, x12
ffffffc0081eba28: aa0f03f6     	mov	x22, x15
ffffffc0081eba2c: aa1003f9     	mov	x25, x16
ffffffc0081eba30: 97fcfd31     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081eba34: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081eba38: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081eba3c: 91012bde     	add	x30, x30, #0x4a
ffffffc0081eba40: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eba44: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081eba48: 52800106     	mov	w6, #0x8        // =8
ffffffc0081eba4c: 52800204     	mov	w4, #0x10       // =16
ffffffc0081eba50: 91095063     	add	x3, x3, #0x254
ffffffc0081eba54: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081eba58: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081eba5c: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081eba60: aa1903f0     	mov	x16, x25
ffffffc0081eba64: aa1603ef     	mov	x15, x22
ffffffc0081eba68: aa1803ec     	mov	x12, x24
ffffffc0081eba6c: d4210000     	brk	#0x800
ffffffc0081eba70: 17ffff76     	b	0xffffffc0081eb848 <rt_mutex_adjust_prio_chain+0xa10>
ffffffc0081eba74: b900010e     	str	w14, [x8]
ffffffc0081eba78: 397a79e8     	ldrb	w8, [x15, #0xe9e]
ffffffc0081eba7c: 3707ec88     	tbnz	w8, #0x0, 0xffffffc0081eb80c <rt_mutex_adjust_prio_chain+0x9d4>
ffffffc0081eba80: f000f360     	adrp	x0, 0xffffffc00a05a000 <hci_reset_dev.hw_err+0x2616f>
ffffffc0081eba84: 911d6000     	add	x0, x0, #0x758
ffffffc0081eba88: 393a79ed     	strb	w13, [x15, #0xe9e]
ffffffc0081eba8c: aa0c03f3     	mov	x19, x12
ffffffc0081eba90: aa0f03f6     	mov	x22, x15
ffffffc0081eba94: aa1003f8     	mov	x24, x16
ffffffc0081eba98: aa1103f9     	mov	x25, x17
ffffffc0081eba9c: 97fcfd16     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081ebaa0: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebaa4: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebaa8: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebaac: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebab0: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebab4: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebab8: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebabc: 91095063     	add	x3, x3, #0x254
ffffffc0081ebac0: aa1903f1     	mov	x17, x25
ffffffc0081ebac4: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebac8: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebacc: aa1803f0     	mov	x16, x24
ffffffc0081ebad0: aa1603ef     	mov	x15, x22
ffffffc0081ebad4: aa1303ec     	mov	x12, x19
ffffffc0081ebad8: d4210000     	brk	#0x800
ffffffc0081ebadc: 17ffff4c     	b	0xffffffc0081eb80c <rt_mutex_adjust_prio_chain+0x9d4>
ffffffc0081ebae0: d503249f     	bti	j
ffffffc0081ebae4: aa0b03e0     	mov	x0, x11
ffffffc0081ebae8: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081ebaec: 885f7d09     	ldxr	w9, [x8]
ffffffc0081ebaf0: 1100052a     	add	w10, w9, #0x1
ffffffc0081ebaf4: 880b7d0a     	stxr	w11, w10, [x8]
ffffffc0081ebaf8: 35ffffab     	cbnz	w11, 0xffffffc0081ebaec <rt_mutex_adjust_prio_chain+0xcb4>
ffffffc0081ebafc: aa0003eb     	mov	x11, x0
ffffffc0081ebb00: 35ffdba9     	cbnz	w9, 0xffffffc0081eb674 <rt_mutex_adjust_prio_chain+0x83c>
ffffffc0081ebb04: b900010e     	str	w14, [x8]
ffffffc0081ebb08: 397a7628     	ldrb	w8, [x17, #0xe9d]
ffffffc0081ebb0c: 3707dba8     	tbnz	w8, #0x0, 0xffffffc0081eb680 <rt_mutex_adjust_prio_chain+0x848>
ffffffc0081ebb10: aa0303e0     	mov	x0, x3
ffffffc0081ebb14: 393a762d     	strb	w13, [x17, #0xe9d]
ffffffc0081ebb18: aa0c03f6     	mov	x22, x12
ffffffc0081ebb1c: aa0f03f9     	mov	x25, x15
ffffffc0081ebb20: aa1103f8     	mov	x24, x17
ffffffc0081ebb24: aa1e03fc     	mov	x28, x30
ffffffc0081ebb28: 97fcfcf3     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081ebb2c: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebb30: aa1c03fe     	mov	x30, x28
ffffffc0081ebb34: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebb38: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebb3c: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebb40: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebb44: 91095063     	add	x3, x3, #0x254
ffffffc0081ebb48: aa1803f1     	mov	x17, x24
ffffffc0081ebb4c: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebb50: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebb54: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebb58: aa1903ef     	mov	x15, x25
ffffffc0081ebb5c: aa1603ec     	mov	x12, x22
ffffffc0081ebb60: d4210000     	brk	#0x800
ffffffc0081ebb64: 17fffec7     	b	0xffffffc0081eb680 <rt_mutex_adjust_prio_chain+0x848>
ffffffc0081ebb68: d503249f     	bti	j
ffffffc0081ebb6c: aa1f03e8     	mov	x8, xzr
ffffffc0081ebb70: f9800331     	prfm	pstl1strm, [x25]
ffffffc0081ebb74: 885fff21     	ldaxr	w1, [x25]
ffffffc0081ebb78: 4a080029     	eor	w9, w1, w8
ffffffc0081ebb7c: 35000069     	cbnz	w9, 0xffffffc0081ebb88 <rt_mutex_adjust_prio_chain+0xd50>
ffffffc0081ebb80: 88097f2d     	stxr	w9, w13, [x25]
ffffffc0081ebb84: 35ffff89     	cbnz	w9, 0xffffffc0081ebb74 <rt_mutex_adjust_prio_chain+0xd3c>
ffffffc0081ebb88: 34ffd9c1     	cbz	w1, 0xffffffc0081eb6c0 <rt_mutex_adjust_prio_chain+0x888>
ffffffc0081ebb8c: aa1903e0     	mov	x0, x25
ffffffc0081ebb90: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081ebb94: aa0f03f8     	mov	x24, x15
ffffffc0081ebb98: aa0503fc     	mov	x28, x5
ffffffc0081ebb9c: aa0a03f6     	mov	x22, x10
ffffffc0081ebba0: 97fff5fa     	bl	0xffffffc0081e9388 <queued_spin_lock_slowpath>
ffffffc0081ebba4: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081ebba8: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebbac: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebbb0: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebbb4: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebbb8: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebbbc: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebbc0: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebbc4: 91095063     	add	x3, x3, #0x254
ffffffc0081ebbc8: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebbcc: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebbd0: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebbd4: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebbd8: aa1603ea     	mov	x10, x22
ffffffc0081ebbdc: aa1c03e5     	mov	x5, x28
ffffffc0081ebbe0: aa1803ef     	mov	x15, x24
ffffffc0081ebbe4: f9444e68     	ldr	x8, [x19, #0x898]
ffffffc0081ebbe8: b5ffd708     	cbnz	x8, 0xffffffc0081eb6c8 <rt_mutex_adjust_prio_chain+0x890>
ffffffc0081ebbec: aa1f03f8     	mov	x24, xzr
ffffffc0081ebbf0: f9400b76     	ldr	x22, [x27, #0x10]
ffffffc0081ebbf4: b4000096     	cbz	x22, 0xffffffc0081ebc04 <rt_mutex_adjust_prio_chain+0xdcc>
ffffffc0081ebbf8: f9401ec8     	ldr	x8, [x22, #0x38]
ffffffc0081ebbfc: eb1b011f     	cmp	x8, x27
ffffffc0081ebc00: 54004de1     	b.ne	0xffffffc0081ec5bc <rt_mutex_adjust_prio_chain+0x1784>
ffffffc0081ebc04: 2a1f03e8     	mov	w8, wzr
ffffffc0081ebc08: 089fff28     	stlrb	w8, [x25]
ffffffc0081ebc0c: c8dffe88     	ldar	x8, [x20]
ffffffc0081ebc10: f1000508     	subs	x8, x8, #0x1
ffffffc0081ebc14: b9000288     	str	w8, [x20]
ffffffc0081ebc18: 540001c0     	b.eq	0xffffffc0081ebc50 <rt_mutex_adjust_prio_chain+0xe18>
ffffffc0081ebc1c: c8dffe88     	ldar	x8, [x20]
ffffffc0081ebc20: b4000188     	cbz	x8, 0xffffffc0081ebc50 <rt_mutex_adjust_prio_chain+0xe18>
ffffffc0081ebc24: 2a1f03e8     	mov	w8, wzr
ffffffc0081ebc28: 089fff68     	stlrb	w8, [x27]
ffffffc0081ebc2c: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081ebc30: c8dffe88     	ldar	x8, [x20]
ffffffc0081ebc34: f1000508     	subs	x8, x8, #0x1
ffffffc0081ebc38: b9000288     	str	w8, [x20]
ffffffc0081ebc3c: 54000500     	b.eq	0xffffffc0081ebcdc <rt_mutex_adjust_prio_chain+0xea4>
ffffffc0081ebc40: c8dffe88     	ldar	x8, [x20]
ffffffc0081ebc44: b40004c8     	cbz	x8, 0xffffffc0081ebcdc <rt_mutex_adjust_prio_chain+0xea4>
ffffffc0081ebc48: b50021f8     	cbnz	x24, 0xffffffc0081ec084 <rt_mutex_adjust_prio_chain+0x124c>
ffffffc0081ebc4c: 140001c5     	b	0xffffffc0081ec360 <rt_mutex_adjust_prio_chain+0x1528>
ffffffc0081ebc50: 91006188     	add	x8, x12, #0x18
ffffffc0081ebc54: 88dffd08     	ldar	w8, [x8]
ffffffc0081ebc58: 35fffe68     	cbnz	w8, 0xffffffc0081ebc24 <rt_mutex_adjust_prio_chain+0xdec>
ffffffc0081ebc5c: d53b4228     	mrs	x8, DAIF
ffffffc0081ebc60: 12190109     	and	w9, w8, #0x80
ffffffc0081ebc64: 35fffe09     	cbnz	w9, 0xffffffc0081ebc24 <rt_mutex_adjust_prio_chain+0xdec>
ffffffc0081ebc68: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081ebc6c: 91006199     	add	x25, x12, #0x18
ffffffc0081ebc70: 88dfff28     	ldar	w8, [x25]
ffffffc0081ebc74: 11000508     	add	w8, w8, #0x1
ffffffc0081ebc78: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ebc7c: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ebc80: aa0f03fc     	mov	x28, x15
ffffffc0081ebc84: 94605886     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ebc88: a9412bec     	ldp	x12, x10, [sp, #0x10]
ffffffc0081ebc8c: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081ebc90: 88dfff28     	ldar	w8, [x25]
ffffffc0081ebc94: 51000508     	sub	w8, w8, #0x1
ffffffc0081ebc98: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ebc9c: f9400188     	ldr	x8, [x12]
ffffffc0081ebca0: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebca4: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebca8: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebcac: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebcb0: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebcb4: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebcb8: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebcbc: 91095063     	add	x3, x3, #0x254
ffffffc0081ebcc0: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebcc4: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebcc8: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebccc: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebcd0: aa1c03ef     	mov	x15, x28
ffffffc0081ebcd4: 370ffcc8     	tbnz	w8, #0x1, 0xffffffc0081ebc6c <rt_mutex_adjust_prio_chain+0xe34>
ffffffc0081ebcd8: 17ffffd3     	b	0xffffffc0081ebc24 <rt_mutex_adjust_prio_chain+0xdec>
ffffffc0081ebcdc: 91006188     	add	x8, x12, #0x18
ffffffc0081ebce0: 88dffd08     	ldar	w8, [x8]
ffffffc0081ebce4: 35fffb28     	cbnz	w8, 0xffffffc0081ebc48 <rt_mutex_adjust_prio_chain+0xe10>
ffffffc0081ebce8: d53b4228     	mrs	x8, DAIF
ffffffc0081ebcec: 12190109     	and	w9, w8, #0x80
ffffffc0081ebcf0: 35fffac9     	cbnz	w9, 0xffffffc0081ebc48 <rt_mutex_adjust_prio_chain+0xe10>
ffffffc0081ebcf4: f9000bec     	str	x12, [sp, #0x10]
ffffffc0081ebcf8: 91006194     	add	x20, x12, #0x18
ffffffc0081ebcfc: 88dffe88     	ldar	w8, [x20]
ffffffc0081ebd00: 11000508     	add	w8, w8, #0x1
ffffffc0081ebd04: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ebd08: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ebd0c: aa0f03fb     	mov	x27, x15
ffffffc0081ebd10: aa0503fc     	mov	x28, x5
ffffffc0081ebd14: aa0a03f9     	mov	x25, x10
ffffffc0081ebd18: 94605861     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ebd1c: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081ebd20: 88dffe88     	ldar	w8, [x20]
ffffffc0081ebd24: 51000508     	sub	w8, w8, #0x1
ffffffc0081ebd28: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ebd2c: f9400188     	ldr	x8, [x12]
ffffffc0081ebd30: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebd34: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebd38: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebd3c: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebd40: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebd44: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebd48: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebd4c: 91095063     	add	x3, x3, #0x254
ffffffc0081ebd50: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebd54: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebd58: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebd5c: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebd60: aa1903ea     	mov	x10, x25
ffffffc0081ebd64: aa1c03e5     	mov	x5, x28
ffffffc0081ebd68: aa1b03ef     	mov	x15, x27
ffffffc0081ebd6c: 370ffc68     	tbnz	w8, #0x1, 0xffffffc0081ebcf8 <rt_mutex_adjust_prio_chain+0xec0>
ffffffc0081ebd70: 17ffffb6     	b	0xffffffc0081ebc48 <rt_mutex_adjust_prio_chain+0xe10>
ffffffc0081ebd74: d503249f     	bti	j
ffffffc0081ebd78: aa0b03e0     	mov	x0, x11
ffffffc0081ebd7c: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081ebd80: 885f7d09     	ldxr	w9, [x8]
ffffffc0081ebd84: 1100052a     	add	w10, w9, #0x1
ffffffc0081ebd88: 880b7d0a     	stxr	w11, w10, [x8]
ffffffc0081ebd8c: 35ffffab     	cbnz	w11, 0xffffffc0081ebd80 <rt_mutex_adjust_prio_chain+0xf48>
ffffffc0081ebd90: aa0003eb     	mov	x11, x0
ffffffc0081ebd94: 35ffd549     	cbnz	w9, 0xffffffc0081eb83c <rt_mutex_adjust_prio_chain+0xa04>
ffffffc0081ebd98: b900010e     	str	w14, [x8]
ffffffc0081ebd9c: 397a7628     	ldrb	w8, [x17, #0xe9d]
ffffffc0081ebda0: 3707d548     	tbnz	w8, #0x0, 0xffffffc0081eb848 <rt_mutex_adjust_prio_chain+0xa10>
ffffffc0081ebda4: aa0303e0     	mov	x0, x3
ffffffc0081ebda8: 393a762d     	strb	w13, [x17, #0xe9d]
ffffffc0081ebdac: aa0c03f8     	mov	x24, x12
ffffffc0081ebdb0: aa0f03f6     	mov	x22, x15
ffffffc0081ebdb4: aa1003f9     	mov	x25, x16
ffffffc0081ebdb8: 97fcfc4f     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081ebdbc: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebdc0: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebdc4: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebdc8: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebdcc: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebdd0: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebdd4: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebdd8: 91095063     	add	x3, x3, #0x254
ffffffc0081ebddc: 90012db1     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebde0: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebde4: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebde8: aa1903f0     	mov	x16, x25
ffffffc0081ebdec: aa1603ef     	mov	x15, x22
ffffffc0081ebdf0: aa1803ec     	mov	x12, x24
ffffffc0081ebdf4: d4210000     	brk	#0x800
ffffffc0081ebdf8: 17fffe94     	b	0xffffffc0081eb848 <rt_mutex_adjust_prio_chain+0xa10>
ffffffc0081ebdfc: d503249f     	bti	j
ffffffc0081ebe00: aa1f03e8     	mov	x8, xzr
ffffffc0081ebe04: f9800331     	prfm	pstl1strm, [x25]
ffffffc0081ebe08: 885fff21     	ldaxr	w1, [x25]
ffffffc0081ebe0c: 4a080029     	eor	w9, w1, w8
ffffffc0081ebe10: 35000069     	cbnz	w9, 0xffffffc0081ebe1c <rt_mutex_adjust_prio_chain+0xfe4>
ffffffc0081ebe14: 88097f2d     	stxr	w9, w13, [x25]
ffffffc0081ebe18: 35ffff89     	cbnz	w9, 0xffffffc0081ebe08 <rt_mutex_adjust_prio_chain+0xfd0>
ffffffc0081ebe1c: 34ffd361     	cbz	w1, 0xffffffc0081eb888 <rt_mutex_adjust_prio_chain+0xa50>
ffffffc0081ebe20: aa1903e0     	mov	x0, x25
ffffffc0081ebe24: aa0f03f6     	mov	x22, x15
ffffffc0081ebe28: aa0a03f8     	mov	x24, x10
ffffffc0081ebe2c: f90003f9     	str	x25, [sp]
ffffffc0081ebe30: aa1103f9     	mov	x25, x17
ffffffc0081ebe34: 97fff555     	bl	0xffffffc0081e9388 <queued_spin_lock_slowpath>
ffffffc0081ebe38: aa1903f1     	mov	x17, x25
ffffffc0081ebe3c: f94003f9     	ldr	x25, [sp]
ffffffc0081ebe40: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081ebe44: f9400bec     	ldr	x12, [sp, #0x10]
ffffffc0081ebe48: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebe4c: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebe50: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebe54: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebe58: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebe5c: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebe60: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebe64: 91095063     	add	x3, x3, #0x254
ffffffc0081ebe68: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebe6c: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebe70: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebe74: aa1803ea     	mov	x10, x24
ffffffc0081ebe78: aa1603ef     	mov	x15, x22
ffffffc0081ebe7c: f9400b68     	ldr	x8, [x27, #0x10]
ffffffc0081ebe80: b5ffd088     	cbnz	x8, 0xffffffc0081eb890 <rt_mutex_adjust_prio_chain+0xa58>
ffffffc0081ebe84: aa1f03e9     	mov	x9, xzr
ffffffc0081ebe88: eb09039f     	cmp	x28, x9
ffffffc0081ebe8c: 54ffd0e1     	b.ne	0xffffffc0081eb8a8 <rt_mutex_adjust_prio_chain+0xa70>
ffffffc0081ebe90: f94007eb     	ldr	x11, [sp, #0x8]
ffffffc0081ebe94: aa0b03f8     	mov	x24, x11
ffffffc0081ebe98: f8418f08     	ldr	x8, [x24, #0x18]!
ffffffc0081ebe9c: f90003f9     	str	x25, [sp]
ffffffc0081ebea0: eb18011f     	cmp	x8, x24
ffffffc0081ebea4: 540002a0     	b.eq	0xffffffc0081ebef8 <rt_mutex_adjust_prio_chain+0x10c0>
ffffffc0081ebea8: f9444669     	ldr	x9, [x19, #0x888]
ffffffc0081ebeac: aa1103f9     	mov	x25, x17
ffffffc0081ebeb0: aa0f03f6     	mov	x22, x15
ffffffc0081ebeb4: eb18013f     	cmp	x9, x24
ffffffc0081ebeb8: 540000e1     	b.ne	0xffffffc0081ebed4 <rt_mutex_adjust_prio_chain+0x109c>
ffffffc0081ebebc: f9401169     	ldr	x9, [x11, #0x20]
ffffffc0081ebec0: b4000ee9     	cbz	x9, 0xffffffc0081ec09c <rt_mutex_adjust_prio_chain+0x1264>
ffffffc0081ebec4: aa0903e8     	mov	x8, x9
ffffffc0081ebec8: f9400929     	ldr	x9, [x9, #0x10]
ffffffc0081ebecc: b5ffffc9     	cbnz	x9, 0xffffffc0081ebec4 <rt_mutex_adjust_prio_chain+0x108c>
ffffffc0081ebed0: f9044668     	str	x8, [x19, #0x888]
ffffffc0081ebed4: 91220261     	add	x1, x19, #0x880
ffffffc0081ebed8: aa1803e0     	mov	x0, x24
ffffffc0081ebedc: 942214d3     	bl	0xffffffc008a71228 <rb_erase>
ffffffc0081ebee0: aa1603ef     	mov	x15, x22
ffffffc0081ebee4: d0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ebee8: aa1903f1     	mov	x17, x25
ffffffc0081ebeec: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebef0: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebef4: f9000318     	str	x24, [x24]
ffffffc0081ebef8: f944426c     	ldr	x12, [x19, #0x880]
ffffffc0081ebefc: 91220261     	add	x1, x19, #0x880
ffffffc0081ebf00: b400030c     	cbz	x12, 0xffffffc0081ebf60 <rt_mutex_adjust_prio_chain+0x1128>
ffffffc0081ebf04: b940438a     	ldr	w10, [x28, #0x40]
ffffffc0081ebf08: 52800028     	mov	w8, #0x1        // =1
ffffffc0081ebf0c: 1400000a     	b	0xffffffc0081ebf34 <rt_mutex_adjust_prio_chain+0x10fc>
ffffffc0081ebf10: 7100017f     	cmp	w11, #0x0
ffffffc0081ebf14: 9a8400cc     	csel	x12, x6, x4, eq
ffffffc0081ebf18: f86c692c     	ldr	x12, [x9, x12]
ffffffc0081ebf1c: 1a9f07eb     	cset	w11, ne
ffffffc0081ebf20: 9100412d     	add	x13, x9, #0x10
ffffffc0081ebf24: 9100212e     	add	x14, x9, #0x8
ffffffc0081ebf28: 0a0b0108     	and	w8, w8, w11
ffffffc0081ebf2c: 9a8d01cb     	csel	x11, x14, x13, eq
ffffffc0081ebf30: b40001ec     	cbz	x12, 0xffffffc0081ebf6c <rt_mutex_adjust_prio_chain+0x1134>
ffffffc0081ebf34: b940298b     	ldr	w11, [x12, #0x28]
ffffffc0081ebf38: aa0c03e9     	mov	x9, x12
ffffffc0081ebf3c: 6b0b015f     	cmp	w10, w11
ffffffc0081ebf40: 1a9fa7eb     	cset	w11, lt
ffffffc0081ebf44: 36fffe6a     	tbz	w10, #0x1f, 0xffffffc0081ebf10 <rt_mutex_adjust_prio_chain+0x10d8>
ffffffc0081ebf48: 54fffe4b     	b.lt	0xffffffc0081ebf10 <rt_mutex_adjust_prio_chain+0x10d8>
ffffffc0081ebf4c: f940278b     	ldr	x11, [x28, #0x48]
ffffffc0081ebf50: f940192c     	ldr	x12, [x9, #0x30]
ffffffc0081ebf54: cb0c016b     	sub	x11, x11, x12
ffffffc0081ebf58: d37ffd6b     	lsr	x11, x11, #63
ffffffc0081ebf5c: 17ffffed     	b	0xffffffc0081ebf10 <rt_mutex_adjust_prio_chain+0x10d8>
ffffffc0081ebf60: aa1f03e9     	mov	x9, xzr
ffffffc0081ebf64: 52800028     	mov	w8, #0x1        // =1
ffffffc0081ebf68: aa0103eb     	mov	x11, x1
ffffffc0081ebf6c: aa1c03e0     	mov	x0, x28
ffffffc0081ebf70: aa1103f9     	mov	x25, x17
ffffffc0081ebf74: aa1003f8     	mov	x24, x16
ffffffc0081ebf78: aa0f03f6     	mov	x22, x15
ffffffc0081ebf7c: f8018c09     	str	x9, [x0, #0x18]!
ffffffc0081ebf80: a900fc1f     	stp	xzr, xzr, [x0, #0x8]
ffffffc0081ebf84: f9000160     	str	x0, [x11]
ffffffc0081ebf88: 34000048     	cbz	w8, 0xffffffc0081ebf90 <rt_mutex_adjust_prio_chain+0x1158>
ffffffc0081ebf8c: f9044660     	str	x0, [x19, #0x888]
ffffffc0081ebf90: 94221432     	bl	0xffffffc008a71058 <rb_insert_color>
ffffffc0081ebf94: 91220268     	add	x8, x19, #0x880
ffffffc0081ebf98: c8dffd08     	ldar	x8, [x8]
ffffffc0081ebf9c: b4ffd208     	cbz	x8, 0xffffffc0081eb9dc <rt_mutex_adjust_prio_chain+0xba4>
ffffffc0081ebfa0: f9444668     	ldr	x8, [x19, #0x888]
ffffffc0081ebfa4: f9400d01     	ldr	x1, [x8, #0x18]
ffffffc0081ebfa8: aa1303e0     	mov	x0, x19
ffffffc0081ebfac: 97feddcd     	bl	0xffffffc0081a36e0 <rt_mutex_setprio>
ffffffc0081ebfb0: a9412bec     	ldp	x12, x10, [sp, #0x10]
ffffffc0081ebfb4: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081ebfb8: aa1903f1     	mov	x17, x25
ffffffc0081ebfbc: f94003f9     	ldr	x25, [sp]
ffffffc0081ebfc0: f000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ebfc4: d000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ebfc8: aa1603ef     	mov	x15, x22
ffffffc0081ebfcc: aa1803f0     	mov	x16, x24
ffffffc0081ebfd0: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ebfd4: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ebfd8: 91095063     	add	x3, x3, #0x254
ffffffc0081ebfdc: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ebfe0: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ebfe4: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ebfe8: 90012dab     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ebfec: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ebff0: f9444e68     	ldr	x8, [x19, #0x898]
ffffffc0081ebff4: b40000a8     	cbz	x8, 0xffffffc0081ec008 <rt_mutex_adjust_prio_chain+0x11d0>
ffffffc0081ebff8: f9401d18     	ldr	x24, [x8, #0x38]
ffffffc0081ebffc: f9400b76     	ldr	x22, [x27, #0x10]
ffffffc0081ec000: b50000b6     	cbnz	x22, 0xffffffc0081ec014 <rt_mutex_adjust_prio_chain+0x11dc>
ffffffc0081ec004: 14000007     	b	0xffffffc0081ec020 <rt_mutex_adjust_prio_chain+0x11e8>
ffffffc0081ec008: aa1f03f8     	mov	x24, xzr
ffffffc0081ec00c: f9400b76     	ldr	x22, [x27, #0x10]
ffffffc0081ec010: b4000096     	cbz	x22, 0xffffffc0081ec020 <rt_mutex_adjust_prio_chain+0x11e8>
ffffffc0081ec014: f9401ec8     	ldr	x8, [x22, #0x38]
ffffffc0081ec018: eb1b011f     	cmp	x8, x27
ffffffc0081ec01c: 54002d81     	b.ne	0xffffffc0081ec5cc <rt_mutex_adjust_prio_chain+0x1794>
ffffffc0081ec020: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec024: 089fff28     	stlrb	w8, [x25]
ffffffc0081ec028: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec02c: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec030: b9000288     	str	w8, [x20]
ffffffc0081ec034: 540004a0     	b.eq	0xffffffc0081ec0c8 <rt_mutex_adjust_prio_chain+0x1290>
ffffffc0081ec038: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec03c: b4000468     	cbz	x8, 0xffffffc0081ec0c8 <rt_mutex_adjust_prio_chain+0x1290>
ffffffc0081ec040: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec044: 089fff68     	stlrb	w8, [x27]
ffffffc0081ec048: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081ec04c: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec050: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec054: b9000288     	str	w8, [x20]
ffffffc0081ec058: 540007a0     	b.eq	0xffffffc0081ec14c <rt_mutex_adjust_prio_chain+0x1314>
ffffffc0081ec05c: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec060: b4000768     	cbz	x8, 0xffffffc0081ec14c <rt_mutex_adjust_prio_chain+0x1314>
ffffffc0081ec064: 710006ff     	cmp	w23, #0x1
ffffffc0081ec068: 1a9f17e8     	cset	w8, eq
ffffffc0081ec06c: eb16039f     	cmp	x28, x22
ffffffc0081ec070: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec074: 1a9f17e9     	cset	w9, eq
ffffffc0081ec078: b4000c98     	cbz	x24, 0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec07c: 2a090108     	orr	w8, w8, w9
ffffffc0081ec080: 36000c48     	tbz	w8, #0x0, 0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec084: b85fc3a8     	ldur	w8, [x29, #-0x4]
ffffffc0081ec088: b941ba01     	ldr	w1, [x16, #0x1b8]
ffffffc0081ec08c: 11000508     	add	w8, w8, #0x1
ffffffc0081ec090: 6b01011f     	cmp	w8, w1
ffffffc0081ec094: 54ff718d     	b.le	0xffffffc0081eaec4 <rt_mutex_adjust_prio_chain+0x8c>
ffffffc0081ec098: 14000068     	b	0xffffffc0081ec238 <rt_mutex_adjust_prio_chain+0x1400>
ffffffc0081ec09c: f27ef508     	ands	x8, x8, #0xfffffffffffffffc
ffffffc0081ec0a0: 54fff180     	b.eq	0xffffffc0081ebed0 <rt_mutex_adjust_prio_chain+0x1098>
ffffffc0081ec0a4: aa1803e9     	mov	x9, x24
ffffffc0081ec0a8: f940050a     	ldr	x10, [x8, #0x8]
ffffffc0081ec0ac: eb0a013f     	cmp	x9, x10
ffffffc0081ec0b0: 54fff101     	b.ne	0xffffffc0081ebed0 <rt_mutex_adjust_prio_chain+0x1098>
ffffffc0081ec0b4: f940010a     	ldr	x10, [x8]
ffffffc0081ec0b8: aa0803e9     	mov	x9, x8
ffffffc0081ec0bc: f27ef548     	ands	x8, x10, #0xfffffffffffffffc
ffffffc0081ec0c0: 54ffff41     	b.ne	0xffffffc0081ec0a8 <rt_mutex_adjust_prio_chain+0x1270>
ffffffc0081ec0c4: 17ffff83     	b	0xffffffc0081ebed0 <rt_mutex_adjust_prio_chain+0x1098>
ffffffc0081ec0c8: 91006188     	add	x8, x12, #0x18
ffffffc0081ec0cc: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec0d0: 35fffb88     	cbnz	w8, 0xffffffc0081ec040 <rt_mutex_adjust_prio_chain+0x1208>
ffffffc0081ec0d4: d53b4228     	mrs	x8, DAIF
ffffffc0081ec0d8: 12190109     	and	w9, w8, #0x80
ffffffc0081ec0dc: 35fffb29     	cbnz	w9, 0xffffffc0081ec040 <rt_mutex_adjust_prio_chain+0x1208>
ffffffc0081ec0e0: 91006199     	add	x25, x12, #0x18
ffffffc0081ec0e4: 88dfff28     	ldar	w8, [x25]
ffffffc0081ec0e8: 11000508     	add	w8, w8, #0x1
ffffffc0081ec0ec: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ec0f0: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec0f4: 9460576a     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec0f8: a9412bec     	ldp	x12, x10, [sp, #0x10]
ffffffc0081ec0fc: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081ec100: 88dfff28     	ldar	w8, [x25]
ffffffc0081ec104: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec108: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ec10c: f9400188     	ldr	x8, [x12]
ffffffc0081ec110: b000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ec114: d000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ec118: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ec11c: f0012d8b     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec120: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ec124: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ec128: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ec12c: 91095063     	add	x3, x3, #0x254
ffffffc0081ec130: f0012d91     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec134: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ec138: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ec13c: b0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ec140: f0012d8f     	adrp	x15, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec144: 370ffce8     	tbnz	w8, #0x1, 0xffffffc0081ec0e0 <rt_mutex_adjust_prio_chain+0x12a8>
ffffffc0081ec148: 17ffffbe     	b	0xffffffc0081ec040 <rt_mutex_adjust_prio_chain+0x1208>
ffffffc0081ec14c: 91006188     	add	x8, x12, #0x18
ffffffc0081ec150: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec154: 35fff888     	cbnz	w8, 0xffffffc0081ec064 <rt_mutex_adjust_prio_chain+0x122c>
ffffffc0081ec158: d53b4228     	mrs	x8, DAIF
ffffffc0081ec15c: 12190109     	and	w9, w8, #0x80
ffffffc0081ec160: 35fff829     	cbnz	w9, 0xffffffc0081ec064 <rt_mutex_adjust_prio_chain+0x122c>
ffffffc0081ec164: 91006194     	add	x20, x12, #0x18
ffffffc0081ec168: 88dffe88     	ldar	w8, [x20]
ffffffc0081ec16c: 11000508     	add	w8, w8, #0x1
ffffffc0081ec170: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ec174: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec178: aa0c03f9     	mov	x25, x12
ffffffc0081ec17c: aa0f03fb     	mov	x27, x15
ffffffc0081ec180: 94605747     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec184: f9400fea     	ldr	x10, [sp, #0x18]
ffffffc0081ec188: f85f03a5     	ldur	x5, [x29, #-0x10]
ffffffc0081ec18c: 88dffe88     	ldar	w8, [x20]
ffffffc0081ec190: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec194: b9001b28     	str	w8, [x25, #0x18]
ffffffc0081ec198: f9400328     	ldr	x8, [x25]
ffffffc0081ec19c: b000f3fe     	adrp	x30, 0xffffffc00a069000 <max_tt_usecs+0x56b8>
ffffffc0081ec1a0: d000f283     	adrp	x3, 0xffffffc00a03e000 <hci_reset_dev.hw_err+0xa16f>
ffffffc0081ec1a4: 91012bde     	add	x30, x30, #0x4a
ffffffc0081ec1a8: f0012d8b     	adrp	x11, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec1ac: 52801c07     	mov	w7, #0xe0       // =224
ffffffc0081ec1b0: 52800106     	mov	w6, #0x8        // =8
ffffffc0081ec1b4: 52800204     	mov	w4, #0x10       // =16
ffffffc0081ec1b8: 91095063     	add	x3, x3, #0x254
ffffffc0081ec1bc: f0012d91     	adrp	x17, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec1c0: 52b8000e     	mov	w14, #-0x40000000 // =-1073741824
ffffffc0081ec1c4: 5280002d     	mov	w13, #0x1       // =1
ffffffc0081ec1c8: b0012e50     	adrp	x16, 0xffffffc00a7b5000 <psi_system+0x150>
ffffffc0081ec1cc: aa1b03ef     	mov	x15, x27
ffffffc0081ec1d0: aa1903ec     	mov	x12, x25
ffffffc0081ec1d4: 370ffc88     	tbnz	w8, #0x1, 0xffffffc0081ec164 <rt_mutex_adjust_prio_chain+0x132c>
ffffffc0081ec1d8: 17ffffa3     	b	0xffffffc0081ec064 <rt_mutex_adjust_prio_chain+0x122c>
ffffffc0081ec1dc: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec1e0: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec1e4: 089fff28     	stlrb	w8, [x25]
ffffffc0081ec1e8: 52801c08     	mov	w8, #0xe0       // =224
ffffffc0081ec1ec: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081ec1f0: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec1f4: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec1f8: b9000288     	str	w8, [x20]
ffffffc0081ec1fc: 54000e00     	b.eq	0xffffffc0081ec3bc <rt_mutex_adjust_prio_chain+0x1584>
ffffffc0081ec200: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec204: b4000dc8     	cbz	x8, 0xffffffc0081ec3bc <rt_mutex_adjust_prio_chain+0x1584>
ffffffc0081ec208: 91010268     	add	x8, x19, #0x40
ffffffc0081ec20c: 140000b3     	b	0xffffffc0081ec4d8 <rt_mutex_adjust_prio_chain+0x16a0>
ffffffc0081ec210: 140000b2     	b	0xffffffc0081ec4d8 <rt_mutex_adjust_prio_chain+0x16a0>
ffffffc0081ec214: 52800029     	mov	w9, #0x1        // =1
ffffffc0081ec218: 4b0903e9     	neg	w9, w9
ffffffc0081ec21c: b8690109     	ldaddl	w9, w9, [x8]
ffffffc0081ec220: 7100052a     	subs	w10, w9, #0x1
ffffffc0081ec224: 540016c1     	b.ne	0xffffffc0081ec4fc <rt_mutex_adjust_prio_chain+0x16c4>
ffffffc0081ec228: d50339bf     	dmb	ishld
ffffffc0081ec22c: aa1303e0     	mov	x0, x19
ffffffc0081ec230: 97fce65f     	bl	0xffffffc008125bac <__put_task_struct>
ffffffc0081ec234: 140000cb     	b	0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec238: f0013d28     	adrp	x8, 0xffffffc00a993000 <group_path+0x514>
ffffffc0081ec23c: b94b5509     	ldr	w9, [x8, #0xb54]
ffffffc0081ec240: 6b01013f     	cmp	w9, w1
ffffffc0081ec244: 540001a1     	b.ne	0xffffffc0081ec278 <rt_mutex_adjust_prio_chain+0x1440>
ffffffc0081ec248: 91010268     	add	x8, x19, #0x40
ffffffc0081ec24c: 140000b9     	b	0xffffffc0081ec530 <rt_mutex_adjust_prio_chain+0x16f8>
ffffffc0081ec250: 140000b8     	b	0xffffffc0081ec530 <rt_mutex_adjust_prio_chain+0x16f8>
ffffffc0081ec254: 52800029     	mov	w9, #0x1        // =1
ffffffc0081ec258: 4b0903e9     	neg	w9, w9
ffffffc0081ec25c: b8690109     	ldaddl	w9, w9, [x8]
ffffffc0081ec260: 7100052a     	subs	w10, w9, #0x1
ffffffc0081ec264: 54001781     	b.ne	0xffffffc0081ec554 <rt_mutex_adjust_prio_chain+0x171c>
ffffffc0081ec268: d50339bf     	dmb	ishld
ffffffc0081ec26c: aa1303e0     	mov	x0, x19
ffffffc0081ec270: 97fce64f     	bl	0xffffffc008125bac <__put_task_struct>
ffffffc0081ec274: 140000ba     	b	0xffffffc0081ec55c <rt_mutex_adjust_prio_chain+0x1724>
ffffffc0081ec278: b90b5501     	str	w1, [x8, #0xb54]
ffffffc0081ec27c: b945c8a3     	ldr	w3, [x5, #0x5c8]
ffffffc0081ec280: 9000f720     	adrp	x0, 0xffffffc00a0d0000 <f_midi_shortname+0x17747>
ffffffc0081ec284: 911e40a2     	add	x2, x5, #0x790
ffffffc0081ec288: 912fe800     	add	x0, x0, #0xbfa
ffffffc0081ec28c: 94002ba7     	bl	0xffffffc0081f7128 <printk>
ffffffc0081ec290: 17ffffee     	b	0xffffffc0081ec248 <rt_mutex_adjust_prio_chain+0x1410>
ffffffc0081ec294: aa1b03ea     	mov	x10, x27
ffffffc0081ec298: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec29c: 089ffd48     	stlrb	w8, [x10]
ffffffc0081ec2a0: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec2a4: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec2a8: b9000288     	str	w8, [x20]
ffffffc0081ec2ac: 54000b40     	b.eq	0xffffffc0081ec414 <rt_mutex_adjust_prio_chain+0x15dc>
ffffffc0081ec2b0: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec2b4: b4000b08     	cbz	x8, 0xffffffc0081ec414 <rt_mutex_adjust_prio_chain+0x15dc>
ffffffc0081ec2b8: 1280045b     	mov	w27, #-0x23     // =-35
ffffffc0081ec2bc: 17ffffc9     	b	0xffffffc0081ec1e0 <rt_mutex_adjust_prio_chain+0x13a8>
ffffffc0081ec2c0: f9400b68     	ldr	x8, [x27, #0x10]
ffffffc0081ec2c4: b4000528     	cbz	x8, 0xffffffc0081ec368 <rt_mutex_adjust_prio_chain+0x1530>
ffffffc0081ec2c8: f9401d09     	ldr	x9, [x8, #0x38]
ffffffc0081ec2cc: eb1b013f     	cmp	x9, x27
ffffffc0081ec2d0: 54001801     	b.ne	0xffffffc0081ec5d0 <rt_mutex_adjust_prio_chain+0x1798>
ffffffc0081ec2d4: f94007e9     	ldr	x9, [sp, #0x8]
ffffffc0081ec2d8: eb08013f     	cmp	x9, x8
ffffffc0081ec2dc: 540004c1     	b.ne	0xffffffc0081ec374 <rt_mutex_adjust_prio_chain+0x153c>
ffffffc0081ec2e0: 1400002b     	b	0xffffffc0081ec38c <rt_mutex_adjust_prio_chain+0x1554>
ffffffc0081ec2e4: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec2e8: 089fff68     	stlrb	w8, [x27]
ffffffc0081ec2ec: 52801c08     	mov	w8, #0xe0       // =224
ffffffc0081ec2f0: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081ec2f4: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec2f8: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec2fc: b9000288     	str	w8, [x20]
ffffffc0081ec300: 54000060     	b.eq	0xffffffc0081ec30c <rt_mutex_adjust_prio_chain+0x14d4>
ffffffc0081ec304: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec308: b5000568     	cbnz	x8, 0xffffffc0081ec3b4 <rt_mutex_adjust_prio_chain+0x157c>
ffffffc0081ec30c: 91006188     	add	x8, x12, #0x18
ffffffc0081ec310: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec314: 35000508     	cbnz	w8, 0xffffffc0081ec3b4 <rt_mutex_adjust_prio_chain+0x157c>
ffffffc0081ec318: d53b4228     	mrs	x8, DAIF
ffffffc0081ec31c: 12190109     	and	w9, w8, #0x80
ffffffc0081ec320: 350004a9     	cbnz	w9, 0xffffffc0081ec3b4 <rt_mutex_adjust_prio_chain+0x157c>
ffffffc0081ec324: aa0c03f4     	mov	x20, x12
ffffffc0081ec328: 91006293     	add	x19, x20, #0x18
ffffffc0081ec32c: 88dffe68     	ldar	w8, [x19]
ffffffc0081ec330: 11000508     	add	w8, w8, #0x1
ffffffc0081ec334: b9001a88     	str	w8, [x20, #0x18]
ffffffc0081ec338: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec33c: aa1403f5     	mov	x21, x20
ffffffc0081ec340: 946056d7     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec344: 88dffe68     	ldar	w8, [x19]
ffffffc0081ec348: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec34c: b9001a88     	str	w8, [x20, #0x18]
ffffffc0081ec350: f9400288     	ldr	x8, [x20]
ffffffc0081ec354: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec358: 370ffe88     	tbnz	w8, #0x1, 0xffffffc0081ec328 <rt_mutex_adjust_prio_chain+0x14f0>
ffffffc0081ec35c: 14000081     	b	0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec360: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec364: 17ffffa9     	b	0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec368: f94007e8     	ldr	x8, [sp, #0x8]
ffffffc0081ec36c: b4000108     	cbz	x8, 0xffffffc0081ec38c <rt_mutex_adjust_prio_chain+0x1554>
ffffffc0081ec370: aa1f03e8     	mov	x8, xzr
ffffffc0081ec374: f9401900     	ldr	x0, [x8, #0x30]
ffffffc0081ec378: 52800061     	mov	w1, #0x3        // =3
ffffffc0081ec37c: 2a1f03e2     	mov	w2, wzr
ffffffc0081ec380: aa0c03f3     	mov	x19, x12
ffffffc0081ec384: 97feb7e3     	bl	0xffffffc00819a310 <try_to_wake_up>
ffffffc0081ec388: aa1303ec     	mov	x12, x19
ffffffc0081ec38c: 2a1f03e8     	mov	w8, wzr
ffffffc0081ec390: 089fff68     	stlrb	w8, [x27]
ffffffc0081ec394: 52801c08     	mov	w8, #0xe0       // =224
ffffffc0081ec398: d50342ff     	msr	DAIFClr, #0x2
ffffffc0081ec39c: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec3a0: f1000508     	subs	x8, x8, #0x1
ffffffc0081ec3a4: b9000288     	str	w8, [x20]
ffffffc0081ec3a8: 540004e0     	b.eq	0xffffffc0081ec444 <rt_mutex_adjust_prio_chain+0x160c>
ffffffc0081ec3ac: c8dffe88     	ldar	x8, [x20]
ffffffc0081ec3b0: b40004a8     	cbz	x8, 0xffffffc0081ec444 <rt_mutex_adjust_prio_chain+0x160c>
ffffffc0081ec3b4: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec3b8: 1400006a     	b	0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec3bc: 91006188     	add	x8, x12, #0x18
ffffffc0081ec3c0: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec3c4: 35fff228     	cbnz	w8, 0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec3c8: d53b4228     	mrs	x8, DAIF
ffffffc0081ec3cc: 12190109     	and	w9, w8, #0x80
ffffffc0081ec3d0: 35fff1c9     	cbnz	w9, 0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec3d4: aa0f03f7     	mov	x23, x15
ffffffc0081ec3d8: aa0c03f5     	mov	x21, x12
ffffffc0081ec3dc: 910062b4     	add	x20, x21, #0x18
ffffffc0081ec3e0: 88dffe88     	ldar	w8, [x20]
ffffffc0081ec3e4: 11000508     	add	w8, w8, #0x1
ffffffc0081ec3e8: b9001aa8     	str	w8, [x21, #0x18]
ffffffc0081ec3ec: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec3f0: aa1503f6     	mov	x22, x21
ffffffc0081ec3f4: 946056aa     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec3f8: 88dffe88     	ldar	w8, [x20]
ffffffc0081ec3fc: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec400: b9001aa8     	str	w8, [x21, #0x18]
ffffffc0081ec404: f94002a8     	ldr	x8, [x21]
ffffffc0081ec408: 370ffea8     	tbnz	w8, #0x1, 0xffffffc0081ec3dc <rt_mutex_adjust_prio_chain+0x15a4>
ffffffc0081ec40c: aa1703ef     	mov	x15, x23
ffffffc0081ec410: 17ffff7e     	b	0xffffffc0081ec208 <rt_mutex_adjust_prio_chain+0x13d0>
ffffffc0081ec414: 91006188     	add	x8, x12, #0x18
ffffffc0081ec418: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec41c: aa0f03f7     	mov	x23, x15
ffffffc0081ec420: aa0c03f6     	mov	x22, x12
ffffffc0081ec424: 35000088     	cbnz	w8, 0xffffffc0081ec434 <rt_mutex_adjust_prio_chain+0x15fc>
ffffffc0081ec428: d53b4228     	mrs	x8, DAIF
ffffffc0081ec42c: 12190109     	and	w9, w8, #0x80
ffffffc0081ec430: 34000349     	cbz	w9, 0xffffffc0081ec498 <rt_mutex_adjust_prio_chain+0x1660>
ffffffc0081ec434: 1280045b     	mov	w27, #-0x23     // =-35
ffffffc0081ec438: aa1603ec     	mov	x12, x22
ffffffc0081ec43c: aa1703ef     	mov	x15, x23
ffffffc0081ec440: 17ffff68     	b	0xffffffc0081ec1e0 <rt_mutex_adjust_prio_chain+0x13a8>
ffffffc0081ec444: 91006188     	add	x8, x12, #0x18
ffffffc0081ec448: 88dffd08     	ldar	w8, [x8]
ffffffc0081ec44c: 35fffb48     	cbnz	w8, 0xffffffc0081ec3b4 <rt_mutex_adjust_prio_chain+0x157c>
ffffffc0081ec450: d53b4228     	mrs	x8, DAIF
ffffffc0081ec454: 12190109     	and	w9, w8, #0x80
ffffffc0081ec458: 35fffae9     	cbnz	w9, 0xffffffc0081ec3b4 <rt_mutex_adjust_prio_chain+0x157c>
ffffffc0081ec45c: aa0c03f4     	mov	x20, x12
ffffffc0081ec460: 91006293     	add	x19, x20, #0x18
ffffffc0081ec464: 88dffe68     	ldar	w8, [x19]
ffffffc0081ec468: 11000508     	add	w8, w8, #0x1
ffffffc0081ec46c: b9001a88     	str	w8, [x20, #0x18]
ffffffc0081ec470: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec474: aa1403f5     	mov	x21, x20
ffffffc0081ec478: 94605689     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec47c: 88dffe68     	ldar	w8, [x19]
ffffffc0081ec480: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec484: b9001a88     	str	w8, [x20, #0x18]
ffffffc0081ec488: f9400288     	ldr	x8, [x20]
ffffffc0081ec48c: 2a1f03fb     	mov	w27, wzr
ffffffc0081ec490: 370ffe88     	tbnz	w8, #0x1, 0xffffffc0081ec460 <rt_mutex_adjust_prio_chain+0x1628>
ffffffc0081ec494: 14000033     	b	0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec498: aa1603ec     	mov	x12, x22
ffffffc0081ec49c: 1280045b     	mov	w27, #-0x23     // =-35
ffffffc0081ec4a0: 91006195     	add	x21, x12, #0x18
ffffffc0081ec4a4: 88dffea8     	ldar	w8, [x21]
ffffffc0081ec4a8: 11000508     	add	w8, w8, #0x1
ffffffc0081ec4ac: b9001988     	str	w8, [x12, #0x18]
ffffffc0081ec4b0: 52800020     	mov	w0, #0x1        // =1
ffffffc0081ec4b4: 9460567a     	bl	0xffffffc009a01e9c <__schedule>
ffffffc0081ec4b8: 88dffea8     	ldar	w8, [x21]
ffffffc0081ec4bc: 51000508     	sub	w8, w8, #0x1
ffffffc0081ec4c0: b9001ac8     	str	w8, [x22, #0x18]
ffffffc0081ec4c4: f94002c8     	ldr	x8, [x22]
ffffffc0081ec4c8: aa1703ef     	mov	x15, x23
ffffffc0081ec4cc: aa1603ec     	mov	x12, x22
ffffffc0081ec4d0: 370ffe88     	tbnz	w8, #0x1, 0xffffffc0081ec4a0 <rt_mutex_adjust_prio_chain+0x1668>
ffffffc0081ec4d4: 17ffff43     	b	0xffffffc0081ec1e0 <rt_mutex_adjust_prio_chain+0x13a8>
ffffffc0081ec4d8: d503249f     	bti	j
ffffffc0081ec4dc: 5280002a     	mov	w10, #0x1       // =1
ffffffc0081ec4e0: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081ec4e4: 885f7d09     	ldxr	w9, [x8]
ffffffc0081ec4e8: 4b0a012b     	sub	w11, w9, w10
ffffffc0081ec4ec: 880cfd0b     	stlxr	w12, w11, [x8]
ffffffc0081ec4f0: 35ffffac     	cbnz	w12, 0xffffffc0081ec4e4 <rt_mutex_adjust_prio_chain+0x16ac>
ffffffc0081ec4f4: 7100052a     	subs	w10, w9, #0x1
ffffffc0081ec4f8: 54ffe980     	b.eq	0xffffffc0081ec228 <rt_mutex_adjust_prio_chain+0x13f0>
ffffffc0081ec4fc: 2a090149     	orr	w9, w10, w9
ffffffc0081ec500: 36f80309     	tbz	w9, #0x1f, 0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec504: 52b80009     	mov	w9, #-0x40000000 // =-1073741824
ffffffc0081ec508: b9000109     	str	w9, [x8]
ffffffc0081ec50c: 397a79e8     	ldrb	w8, [x15, #0xe9e]
ffffffc0081ec510: 37000288     	tbnz	w8, #0x0, 0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec514: d000f360     	adrp	x0, 0xffffffc00a05a000 <hci_reset_dev.hw_err+0x2616f>
ffffffc0081ec518: 52800028     	mov	w8, #0x1        // =1
ffffffc0081ec51c: 911d6000     	add	x0, x0, #0x758
ffffffc0081ec520: 393a79e8     	strb	w8, [x15, #0xe9e]
ffffffc0081ec524: 97fcfa74     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081ec528: d4210000     	brk	#0x800
ffffffc0081ec52c: 1400000d     	b	0xffffffc0081ec560 <rt_mutex_adjust_prio_chain+0x1728>
ffffffc0081ec530: d503249f     	bti	j
ffffffc0081ec534: 5280002a     	mov	w10, #0x1       // =1
ffffffc0081ec538: f9800111     	prfm	pstl1strm, [x8]
ffffffc0081ec53c: 885f7d09     	ldxr	w9, [x8]
ffffffc0081ec540: 4b0a012b     	sub	w11, w9, w10
ffffffc0081ec544: 880cfd0b     	stlxr	w12, w11, [x8]
ffffffc0081ec548: 35ffffac     	cbnz	w12, 0xffffffc0081ec53c <rt_mutex_adjust_prio_chain+0x1704>
ffffffc0081ec54c: 7100052a     	subs	w10, w9, #0x1
ffffffc0081ec550: 54ffe8c0     	b.eq	0xffffffc0081ec268 <rt_mutex_adjust_prio_chain+0x1430>
ffffffc0081ec554: 2a090149     	orr	w9, w10, w9
ffffffc0081ec558: 37f801a9     	tbnz	w9, #0x1f, 0xffffffc0081ec58c <rt_mutex_adjust_prio_chain+0x1754>
ffffffc0081ec55c: 1280045b     	mov	w27, #-0x23     // =-35
ffffffc0081ec560: a9437bfd     	ldp	x29, x30, [sp, #0x30]
ffffffc0081ec564: 2a1b03e0     	mov	w0, w27
ffffffc0081ec568: a9484ff4     	ldp	x20, x19, [sp, #0x80]
ffffffc0081ec56c: a94757f6     	ldp	x22, x21, [sp, #0x70]
ffffffc0081ec570: a9465ff8     	ldp	x24, x23, [sp, #0x60]
ffffffc0081ec574: a94567fa     	ldp	x26, x25, [sp, #0x50]
ffffffc0081ec578: a9446ffc     	ldp	x28, x27, [sp, #0x40]
ffffffc0081ec57c: f85f8e5e     	ldr	x30, [x18, #-0x8]!
ffffffc0081ec580: 910243ff     	add	sp, sp, #0x90
ffffffc0081ec584: d50323bf     	autiasp
ffffffc0081ec588: d65f03c0     	ret
ffffffc0081ec58c: 52b80009     	mov	w9, #-0x40000000 // =-1073741824
ffffffc0081ec590: b9000109     	str	w9, [x8]
ffffffc0081ec594: f0012d88     	adrp	x8, 0xffffffc00a79f000 <event_sys_exit+0x48>
ffffffc0081ec598: 397a7909     	ldrb	w9, [x8, #0xe9e]
ffffffc0081ec59c: 3707fe09     	tbnz	w9, #0x0, 0xffffffc0081ec55c <rt_mutex_adjust_prio_chain+0x1724>
ffffffc0081ec5a0: d000f360     	adrp	x0, 0xffffffc00a05a000 <hci_reset_dev.hw_err+0x2616f>
ffffffc0081ec5a4: 52800029     	mov	w9, #0x1        // =1
ffffffc0081ec5a8: 911d6000     	add	x0, x0, #0x758
ffffffc0081ec5ac: 393a7909     	strb	w9, [x8, #0xe9e]
ffffffc0081ec5b0: 97fcfa51     	bl	0xffffffc00812aef4 <__warn_printk>
ffffffc0081ec5b4: d4210000     	brk	#0x800
ffffffc0081ec5b8: 17ffffe9     	b	0xffffffc0081ec55c <rt_mutex_adjust_prio_chain+0x1724>
ffffffc0081ec5bc: d4210000     	brk	#0x800
ffffffc0081ec5c0: d4210000     	brk	#0x800
ffffffc0081ec5c4: d4210000     	brk	#0x800
ffffffc0081ec5c8: d4210000     	brk	#0x800
ffffffc0081ec5cc: d4210000     	brk	#0x800
ffffffc0081ec5d0: d4210000     	brk	#0x800
ffffffc0081ec5d4: d5184608     	msr	ICC_PMR_EL1, x8
ffffffc0081ec5d8: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec5dc: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec5e0: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec5e4: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec5e8: b8bfc368     	ldapr	w8, [x27]
ffffffc0081ec5ec: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec5f0: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec5f4: d5184607     	msr	ICC_PMR_EL1, x7
ffffffc0081ec5f8: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec5fc: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec600: d5184608     	msr	ICC_PMR_EL1, x8
ffffffc0081ec604: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec608: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec60c: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec610: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec614: b8bfc368     	ldapr	w8, [x27]
ffffffc0081ec618: b8bfc368     	ldapr	w8, [x27]
ffffffc0081ec61c: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec620: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec624: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec628: b8bfc368     	ldapr	w8, [x27]
ffffffc0081ec62c: b8bfc368     	ldapr	w8, [x27]
ffffffc0081ec630: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec634: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec638: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec63c: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec640: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec644: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec648: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec64c: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec650: b8bfc2c8     	ldapr	w8, [x22]
ffffffc0081ec654: b8bfc2c8     	ldapr	w8, [x22]
ffffffc0081ec658: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec65c: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec660: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec664: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec668: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec66c: f8bfc109     	ldapr	x9, [x8]
ffffffc0081ec670: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec674: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec678: f8bfc109     	ldapr	x9, [x8]
ffffffc0081ec67c: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec680: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec684: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec688: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec68c: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec690: d5184607     	msr	ICC_PMR_EL1, x7
ffffffc0081ec694: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec698: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec69c: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec6a0: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec6a4: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec6a8: b8bfc328     	ldapr	w8, [x25]
ffffffc0081ec6ac: b8bfc328     	ldapr	w8, [x25]
ffffffc0081ec6b0: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec6b4: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec6b8: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec6bc: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec6c0: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec6c4: f8bfc108     	ldapr	x8, [x8]
ffffffc0081ec6c8: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec6cc: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec6d0: d5184607     	msr	ICC_PMR_EL1, x7
ffffffc0081ec6d4: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec6d8: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec6dc: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec6e0: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec6e4: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec6e8: b8bfc328     	ldapr	w8, [x25]
ffffffc0081ec6ec: b8bfc328     	ldapr	w8, [x25]
ffffffc0081ec6f0: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec6f4: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec6f8: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec6fc: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec700: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec704: d5184608     	msr	ICC_PMR_EL1, x8
ffffffc0081ec708: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec70c: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec710: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec714: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec718: d5184608     	msr	ICC_PMR_EL1, x8
ffffffc0081ec71c: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec720: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec724: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec728: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec72c: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec730: b8bfc268     	ldapr	w8, [x19]
ffffffc0081ec734: b8bfc268     	ldapr	w8, [x19]
ffffffc0081ec738: d5184608     	msr	ICC_PMR_EL1, x8
ffffffc0081ec73c: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec740: f8bfc288     	ldapr	x8, [x20]
ffffffc0081ec744: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec748: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec74c: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec750: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec754: b8bfc288     	ldapr	w8, [x20]
ffffffc0081ec758: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec75c: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec760: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec764: b8bfc108     	ldapr	w8, [x8]
ffffffc0081ec768: d5384608     	mrs	x8, ICC_PMR_EL1
ffffffc0081ec76c: 521b0909     	eor	w9, w8, #0xe0
ffffffc0081ec770: b8bfc268     	ldapr	w8, [x19]
ffffffc0081ec774: b8bfc268     	ldapr	w8, [x19]
ffffffc0081ec778: b8bfc2a8     	ldapr	w8, [x21]
ffffffc0081ec77c: b8bfc2a8     	ldapr	w8, [x21]

ffffffc0081ec780 <__rt_mutex_init>:
ffffffc0081ec780: d503233f     	paciasp
ffffffc0081ec784: b900001f     	str	wzr, [x0]
ffffffc0081ec788: a900fc1f     	stp	xzr, xzr, [x0, #0x8]
ffffffc0081ec78c: f9000c1f     	str	xzr, [x0, #0x18]
ffffffc0081ec790: d50323bf     	autiasp
ffffffc0081ec794: d65f03c0     	ret
