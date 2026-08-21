@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SRC=8kb_fasm_demo.asm"
set "OUT=8kb_fasm_demo.exe"
set "FASM="

if defined FASM_EXE if exist "%FASM_EXE%" set "FASM=%FASM_EXE%"
if not defined FASM if exist "%~dp0fasm.exe" set "FASM=%~dp0fasm.exe"
if not defined FASM if exist "C:\fasm\fasm.exe" set "FASM=C:\fasm\fasm.exe"
if not defined FASM for %%F in (fasm.exe) do if not "%%~$PATH:F"=="" set "FASM=%%~$PATH:F"

if not defined FASM (
  echo [ERROR] fasm.exe not found.
  echo Set FASM_EXE to your fasm.exe path, put FASM beside this script,
  echo or install FASM in C:\fasm / PATH.
  exit /b 1
)

for %%I in ("%FASM%") do set "FASMDIR=%%~dpI"
set "INCLUDE=%FASMDIR%INCLUDE;%INCLUDE%"

echo [BUILD] %FASM%
"%FASM%" "%SRC%" "%OUT%"
if errorlevel 1 exit /b 1

for %%I in ("%OUT%") do set "SIZE=%%~zI"
echo [SIZE]  !SIZE! bytes
if !SIZE! LEQ 8192 (
  set /a FREE=8192-SIZE
  echo [8K]    PASS - !FREE! bytes free.
) else (
  set /a OVER=SIZE-8192
  echo [8K]    OVER by !OVER! bytes.
)

echo [PE]     validating entry point / import directory...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_pe.ps1" "%OUT%"
if errorlevel 1 (
  echo [ERROR] PE validation failed - executable will NOT be started.
  exit /b 2
)

echo [OK]     build and PE validation passed.
exit /b 0
