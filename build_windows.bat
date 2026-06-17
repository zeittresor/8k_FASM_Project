@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   8KB FASM demo experiment - build v17 stack-pointer reserved-word fix
echo ============================================================
set "FASM="
if exist "%CD%\fasm.exe" set "FASM=%CD%\fasm.exe"
if not defined FASM for %%I in (fasm.exe) do if not "%%~$PATH:I"=="" set "FASM=%%~$PATH:I"
if not defined FASM (
  echo [ERROR] fasm.exe not found. Put fasm.exe next to this batch or into PATH.
  pause
  exit /b 1
)
set "INC="
for %%D in ("%CD%\INCLUDE" "%~dp0INCLUDE" "%~dp0FASM\INCLUDE" "%~dp0..\INCLUDE" "%~dp0..\FASM\INCLUDE") do if exist "%%~D\win32ax.inc" set "INC=%%~D"
if not defined INC for %%I in ("%FASM%") do if exist "%%~dpIINCLUDE\win32ax.inc" set "INC=%%~dpIINCLUDE"
if not defined INC (
  echo [ERROR] win32ax.inc not found. Copy the complete FASM INCLUDE folder here.
  pause
  exit /b 1
)
echo [INC] %INC%\win32ax.inc
>8kb_fasm_inc.inc echo include '%INC:\=\\%\\win32ax.inc'
echo [CMD] "%FASM%" "%CD%\8kb_fasm_demo.asm" "%CD%\8kb_fasm_demo.exe"
"%FASM%" "%CD%\8kb_fasm_demo.asm" "%CD%\8kb_fasm_demo.exe"
if errorlevel 1 (
  echo [ERROR] Build failed.
  pause
  exit /b 1
)
for %%A in (8kb_fasm_demo.exe) do set SIZE=%%~zA
echo [OK] Built 8kb_fasm_demo.exe - !SIZE! bytes
if !SIZE! GTR 8192 echo [WARN] EXE is above 8192 bytes. Main EXE is above final 8192-byte target; runtime-generated data is allowed, but code still needs trimming.
pause
