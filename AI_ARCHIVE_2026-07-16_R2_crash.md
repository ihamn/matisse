# AI 留档快照 — 2026-07-16 (R2 崩溃分析)

## 本次 AI 做了什么
1. 通读全部项目文档 (AI_READ_THIS_FIRST, LESSONS_LEARNED, RESUME_GUIDE, CHECKPOINT_v30/v31, 全部 R 系列日志)
2. 阅读全部源码 (main.c, slide.c, preload.c, util.c, fops.c, pipe.c, common.h, target.h, Makefile)
3. 发现 R2 = R1 (SHA256 完全相同): 没有真正 make clean && make
4. 分析 R2_test1 崩溃原因:
   - 卡在 prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE) 阶段
   - slide 阶段 clone 500+ 子进程 + heap spray + SKB reclaim
   - R1_test1→2→3→4 连续跑耗尽 slab → 后续测试重启
5. 验证二进制代码路径: strings 确认 R2.so 含 direct mode 字符串，不含 FOPS stage 字符串
   → R1_test2/3 输出 FOPS stage 是因为跑了 rish 命名空间里的旧 v 系列 .so

## 更新的文档
- !!!_LESSONS_LEARNED.md: 新增 R2 崩溃教训 (3 条)
- !!!_AI_READ_THIS_FIRST.md: 状态更新为 R2 崩溃分析结果，更新版本速查表
- !!!_RESUME_GUIDE.md: 状态更新为 R3 待编译
- CHECKPOINT_R2_crash_analysis.md: 新建，R2 详细分析 + R3 行动计划
- AI_ARCHIVE_2026-07-16_R2_crash.md: 本文件

## 下次继续的关键点
- R3 必须真·make clean && make（build/ 目录还在，说明没 clean 过）
- 编译后先 sha256sum 验证 ≠ 017fb8a6
- strings 验证含 direct mode 字符串
- 手机已重启，建议先开原神压 slab 再跑
- 只跑一次，跑完立刻 tee 日志
- 成功标志: direct mode=init_cred / direct-root-summary root=1
