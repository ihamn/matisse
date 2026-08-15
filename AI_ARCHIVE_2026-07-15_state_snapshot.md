# AI 留档快照 — 2026-07-15 (更新文档前)

## 项目状态
- v1-v30: rb_erase → fops 覆写路线 → 死路终结
- v31: 新路线 (popsicle fork, direct write) → 未完成, 源码树已丢
- 保留二进制: preload_mtk_v31_new.so (85352 bytes) 但有价无市

## 本次 AI 做了什么
1. 通读全部 CHECKPOINT 和 GUIDE 文档
2. 更新 !!!_AI_READ_THIS_FIRST.md:
   - 加入 TERMUX 环境警告章节
   - 状态更新为 v30关闭/v31未完成
   - 版本表增加到 v31
3. 更新 !!!_RESUME_GUIDE.md:
   - 加入第0步「先留档」
   - 所有步骤加入留档提醒
   - 状态更新为当前
4. 更新 !!!_LESSONS_LEARNED.md:
   - 加入 Termux 弹退风险章节
   - v31 /tmp 丢失血的教训
5. 更新 CHECKPOINT_v31_NEW_APPROACH.md:
   - 标记源码已丢失
   - 待做项加入「重新获取源码」

## 下次继续的关键点
- R1 从零开始，思路参考 CHECKPOINT_v31_NEW_APPROACH.md
- 基于旧树 CyberMeowfia 改造，源码全部放项目目录内
- 二进制命名: preload_mtk_R1.so
- 运行前必留档！禁止放 /tmp/！
