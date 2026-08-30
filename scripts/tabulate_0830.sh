#!/bin/bash
# mt66 前置调查: 今天 4 张卡所有轮次的关键行对照表
cd /data/user/work/matisse || exit 1
for c in ab005c6 16747b8 297ebbf 65118fe; do
  echo "########## CARD $c ##########"
  for r in R11 R12 R13 R14 C1; do
    f=$(git show "$c:logs_raw/$r/${r}_raw.out" 2>/dev/null)
    if [ -z "$f" ]; then echo "  $r: (no file)"; continue; fi
    n19=$(printf '%s\n' "$f" | grep -c "mt19b:")
    n25=$(printf '%s\n' "$f" | grep -c "mt25: futex trigger")
    psr=$(printf '%s\n' "$f" | grep -c "pselect returned")
    mt51=$(printf '%s\n' "$f" | grep -c "mt51:")
    cc=$(printf '%s\n' "$f" | grep -o "consume_calls=[0-9]*" | tail -1)
    rd=$(printf '%s\n' "$f" | grep -o "route_done=[0-9]*" | tail -1)
    m48=$(printf '%s\n' "$f" | grep -o "mt48: PTR stage=[RC]" | head -1)
    cap=$(printf '%s\n' "$f" | grep -o "CapEff=[0-9a-f]\{8,16\}" | sort | uniq -c | tr '\n' ' ')
    lines=$(printf '%s\n' "$f" | wc -l)
    echo "  $r: mt19b=$n19 mt25=$n25 pselret=$psr mt51=$mt51 $cc $rd $m48 lines=$lines"
    echo "       cap: $cap"
  done
done
