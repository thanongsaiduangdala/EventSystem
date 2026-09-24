@echo off
setlocal
cd /d "%~dp0"

set "PY=C:\Users\sunny\AppData\Local\Python\pythoncore-3.14-64\python.exe"
if not exist "%PY%" (
    where py >nul 2>nul && set "PY=py"
)
if not defined PY (
    echo Python not found. Edit run.bat and set PY to your python.exe path.
    pause
    exit /b 1
)

"%PY%" -m uvicorn server:app --reload
endlocal