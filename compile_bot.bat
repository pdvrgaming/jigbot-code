@echo off
setlocal
echo ======================================================================
echo   Compiling Jigurujingania Bot by PDVR to EX5 (MetaTrader 5)
echo   Powered by Razel Tech
echo ======================================================================

set "METAEDITOR=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "BOT_FILE=%~dp0Jigurujingania_Bot_PDVR.mq5"
set "OUTPUT_EX5=%~dp0Jigurujingania_Bot_PDVR.ex5"
set "MT5_EXPERTS=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts"

if not exist "%METAEDITOR%" (
    echo [ERROR] MetaEditor64 not found at "%METAEDITOR%"
    echo Please verify your MT5 installation directory.
    pause
    exit /b 1
)

echo Compiling %BOT_FILE%...
"%METAEDITOR%" /compile:"%BOT_FILE%"

timeout /t 2 /nobreak >nul

if exist "%OUTPUT_EX5%" (
    echo.
    echo [SUCCESS] Jigurujingania_Bot_PDVR.ex5 created successfully!
    if exist "%MT5_EXPERTS%" (
        copy /y "%OUTPUT_EX5%" "%MT5_EXPERTS%\" >nul
        echo [SYNCED] Copied to your active MT5 Experts folder.
    )
    echo [READY] You can now refresh Navigator in MT5 and run the bot!
) else (
    echo.
    echo [ERROR] Compilation did not produce an EX5 file. Please check for syntax errors.
)

echo.
pause
