# matisse GhostLock project - snapshot for external review

Redmi K50 Pro (matisse, MTK 5.10.209, locked BL) CVE-2026-43499 (GhostLock) kernel privesc.
Goal: install KernelSU (root + insmod kernelsu.ko).

Read these from scratch, form your own judgment (unbiased):
1. Where is the project stuck
2. Which assumptions are unverified
3. What should be tried next

Layout:
- *.md = project archives (AI_ARCHIVE/CHECKPOINT full history)
- research/mt11_v30_src = current exploit source (main.c/slide.c/util.c/fops.c)
- research/kernel = kernel source extracts (rtmutex/futex/cred/rbtree/cred.h)
- research/kallsyms.txt = real kernel symbols (142102)
- research/duchamp-root, aristotle, popsicle, Poc-Analysis = other adaptations
- ref/ = disassembly (rb_erase.asm/rt_mutex_chain.asm)
- ghostlock_src = OnePlus 6.12 adaptation
- fusion_release = R-series source
- scripts/ logs/ = test scripts and logs
- CVE-2026-43499_ref = original PoC (submodule, need --recursive)
