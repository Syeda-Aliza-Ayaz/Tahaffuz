@echo off
rem Tahaffuz - double-click to start the server and open the app.
rem Close the "Tahaffuz server" window to stop it.

cd /d "%~dp0"

where swipl >nul 2>nul
if %errorlevel%==0 (
    set "SWIPL=swipl"
) else (
    set "SWIPL=C:\Program Files\swipl\bin\swipl.exe"
)

start "Tahaffuz server" "%SWIPL%" server.pl

rem give the server a moment to start, then open the browser
timeout /t 2 /nobreak >nul
start "" http://localhost:8080
