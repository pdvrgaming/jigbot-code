@echo off
setlocal
set "MSG=%~1"
if "%MSG%"=="" set "MSG=Update Jig Bot and website"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" -CommitMessage "%MSG%"
pause
