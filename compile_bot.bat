@echo off
setlocal
echo ======================================================================
echo   Compiling Jig Bot to EX5 (MetaTrader 5)
echo   Powered by Razel Tech
echo ======================================================================

set "METAEDITOR=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "BOT_FILE=%~dp0jig_bot.mq5"
set "OUTPUT_EX5=%~dp0jig_bot.ex5"
set "MT5_EXPERTS=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts"

if not exist "%METAEDITOR%" (
    echo [ERROR] MetaEditor64 not found at "%METAEDITOR%"
    echo Please verify your MT5 installation directory.
    if not "%~1"=="--nopause" pause
    exit /b 1
)

echo Compiling %BOT_FILE%...
"%METAEDITOR%" /compile:"%BOT_FILE%"

timeout /t 2 /nobreak >nul 2>&1

if exist "%OUTPUT_EX5%" (
    echo.
    echo [SUCCESS] jig_bot.ex5 created successfully!
    if exist "%MT5_EXPERTS%" (
        copy /y "%OUTPUT_EX5%" "%MT5_EXPERTS%\" >nul
        echo [SYNCED] Copied to your active MT5 Experts folder.
    )
    set "MT5_SOUNDS=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Sounds"
    if exist "%~dp0jig bot" (
        if not exist "%MT5_SOUNDS%" mkdir "%MT5_SOUNDS%" >nul 2>&1
        copy /y "%~dp0jig bot\*.wav" "%MT5_SOUNDS%\" >nul 2>&1
        echo [AUDIO] Synced jig bot audio files to MT5 Sounds folder.
    )
    echo [READY] You can now refresh Navigator in MT5 and run Jig Bot!
) else (
    echo.
    echo [ERROR] Compilation did not produce an EX5 file. Please check for syntax errors.
)

echo.
if not "%~1"=="--nopause" pause
