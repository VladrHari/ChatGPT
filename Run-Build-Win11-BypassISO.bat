@echo off
REM ================================================
REM  .bat file to launch PowerShell and run a script
REM ================================================

REM Set the full path to your PowerShell script below
set "SCRIPT_PATH=C:\scripts\Build-Win11-BypassISO.ps1"

REM Launch PowerShell, run the script, and keep the window open
PowerShell -NoExit -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"