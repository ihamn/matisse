@echo off
:loop
if "%~1"=="" goto endloop
powershell -NoProfile -Command "$h = (Get-FileHash -LiteralPath '%~1' -Algorithm SHA256).Hash.ToLower(); Write-Output ('{0}  {1}' -f $h, '%~1')"
shift
goto loop
:endloop
