#!/bin/bash
# 扫描全部历史卡: consumer mt19b 首发时刻 vs 轮类型 (R=child mode, C=external mode)
cd /data/user/work/matisse || exit 1
commits="6f3609f cda33de a19c14f 5615898 483d901 0db3240 ab426a6 0fa5139 b2173ab 65118fe 6167859 16747b8 ab005c6 297ebbf"
for c in $commits; do
  for r in R11 R12 R13 R14 C1; do
    f=$(git show "$c:logs_raw/$r/${r}_raw.out" 2>/dev/null)
    if [ -z "$f" ]; then continue; fi
    t19=$(printf '%s' "$f" | grep -o 'mt19b: sched attempt=0.*t=[0-9]*ms' | grep -o 't=[0-9]*' | head -1)
    m48=$(printf '%s' "$f" | grep -o 'mt48: PTR stage=[RC]' | head -1)
    n25=$(printf '%s' "$f" | grep -c 'mt25: futex trigger')
    mode=$(printf '%s' "$f" | grep -o 'mt33: child pid=[0-9]*' | head -1)
    ext=$(printf '%s' "$f" | grep -o 'mt49: external' | head -1)
    if [ -n "$t19" ]; then
      echo "$c/$r: first-mt19b=${t19#t=}ms shots=$n25 $m48 ${mode:+CHILD} ${ext:+EXTERNAL}"
    else
      echo "$c/$r: NO-STORM $m48 ${mode:+CHILD} ${ext:+EXTERNAL}"
    fi
  done
done
