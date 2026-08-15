# v30 深度分析 — 2026-07-15

## 已验证事实

### 1. MTK 5.10 rb_erase (任务3)
- Case 1/2: 与主线一致，parent->rb_left == node 比较后选择写 rb_left/rb_right
- Case 3b (deeper successor): **MTK 定制！** 无条件写 parent->rb_left
  → Path C 在此核上永远是死路 (写到sprayed page自己)
- 只有 Case 1 (left=NULL, right=child) 可用于写入目标

### 2. 写入能力 (任务2)
- OFF|RED: ret=150-199 (唯一强触发) → 写 OFF+8 = name_ptr
- FOPS-8|RED: ret=1 (弱触发) → 理论写 FOPS，但 rb_erase 基本未执行
- init_task.comm-8|RED: ret=1 → 进一步确认只有 OFF 附近触发
- 自己验证了 comm 写入: /proc/1/comm 未变化 = rb_erase 未真正执行

### 3. why OFF works
- 强触发需要 parent=OFF (ashmem miscdevice base)
- rb_erase 后内核访问 OFF+8 (被改写的 name_ptr) → cascade → ret 150+
- 其他 parent 写完后没有 cascade → ret=1

## 结构体地址
```
ashmem_misc direct: 0xffffff80028e76d8
fuse_misc    direct: 0xffffff8002873ee0  (473KB away)
misc_list    direct: 0xffffff80028a78c8
```

## 当前死路
1. Path C → MTK 定制 rb_erase 永远写 sprayed page
2. Deep PI chain → 无法让 Call 2/3 操作 fake rb_nodes
3. FOPS-8 直接写 → 弱触发 (ret=1)
4. name_ptr 覆写 → 字符串指针，无直接利用价值
5. comm 覆写测试 → 确认非 OFF parent 都不行

## 仅存方向
A. 利用 name_ptr 覆写做二阶段 (但 name_ptr 只是字符串指针)
B. 找绕过 lock 回指验证的方法让 Call 3 执行
C. 完全不同的利用路径 (不依赖 FOPS 覆写)
