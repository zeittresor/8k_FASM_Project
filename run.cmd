@echo off
setlocal
cd /d "%~dp0"
call build.cmd
if errorlevel 1 exit /b %errorlevel%
echo [RUN]    8kb_fasm_demo.exe
start "" /wait "8kb_fasm_demo.exe"
