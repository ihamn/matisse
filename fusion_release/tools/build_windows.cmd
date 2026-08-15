@echo off
REM ============================================================
REM  Windows 构建脚本 — CVE-2026-43499 GhostLock Fusion
REM  使用 NDK r29 交叉编译 preload.so
REM ============================================================

setlocal enabledelayedexpansion

set "BASE=%~dp0.."
set "NDK_ROOT=D:\android-ndk-cache\android-ndk-r29"
set "PROJECT=blazer-CP2A.260605.012"
set "API=34"
set "EXPLOIT_DIR=%BASE%\CyberMeowfia\IonStack\CVE-2026-43499\exploit"
set "SHA256SUM=%BASE%\tools\sha256sum.cmd"

REM Check NDK exists
if not exist "%NDK_ROOT%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android%API%-clang.exe" (
    echo [ERROR] NDK r29 not found at %NDK_ROOT%
    echo Please wait for download to complete or install NDK manually.
    exit /b 1
)

echo [1/4] Cleaning build directory...
cd /d "%EXPLOIT_DIR%"
if exist build rmdir /s /q build

echo [2/4] Building preload.so...
make PROJECT=%PROJECT% API=%API% SHA256SUM="%SHA256SUM%"
if errorlevel 1 (
    echo [ERROR] Build failed!
    exit /b 1
)

echo [3/4] Verifying output...
set "OUTPUT=build\%PROJECT%\bin\preload.so"
if not exist "%OUTPUT%" (
    echo [ERROR] Output file not found: %OUTPUT%
    exit /b 1
)

echo [4/4] SHA256:
call "%SHA256SUM%" "%OUTPUT%"

echo.
echo Build complete!
echo Output: %EXPLOIT_DIR%\%OUTPUT%
echo.
echo Copy to project root:
echo copy "%EXPLOIT_DIR%\%OUTPUT%" "%BASE%\binaries\r_series\preload_mtk_R9.so"
