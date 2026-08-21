@echo off
echo Source: https://github.com/zeittresor/8k_FASM_Project
setlocal
cd /d "%~dp0"
call build.cmd
if errorlevel 1 exit /b %errorlevel%
echo [RUN]    8kb_fasm_demo.exe
start "" /wait "8kb_fasm_demo.exe"

