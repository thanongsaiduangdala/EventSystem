@echo off
setlocal
cd /d "%~dp0"

where mysqldump >nul 2>nul && goto found
for /d %%d in ("C:\Program Files\MySQL\MySQL Server *") do if exist "%%d\bin\mysqldump.exe" set "PATH=%%d\bin;%PATH%"
if exist "C:\xampp\mysql\bin\mysqldump.exe" set "PATH=C:\xampp\mysql\bin;%PATH%"
where mysqldump >nul 2>nul || goto missing
:found

set "DB_HOST=localhost"
set "DB_PORT=3306"
set "DB_USER=root"
set "DB_PASSWORD="
set "DB_NAME=reservation_system"
for /f "usebackq tokens=1,* delims==" %%a in ("..\.env") do call :read "%%a" "%%b"
set "MYSQL_PWD=%DB_PASSWORD%"

mysqldump -h %DB_HOST% -P %DB_PORT% -u %DB_USER% --default-character-set=utf8mb4 --no-tablespaces --routines=false --triggers=false --result-file=data.sql %DB_NAME%
if errorlevel 1 goto fail
echo Exported to Mysql\data.sql
goto end

:read
if "%~1"=="DB_HOST" set "DB_HOST=%~2"
if "%~1"=="DB_PORT" set "DB_PORT=%~2"
if "%~1"=="DB_USER" set "DB_USER=%~2"
if "%~1"=="DB_PASSWORD" set "DB_PASSWORD=%~2"
if "%~1"=="DB_NAME" set "DB_NAME=%~2"
exit /b 0

:missing
echo mysqldump.exe was not found. Add the MySQL bin folder to PATH.
:fail
echo Export failed
pause
exit /b 1

:end
endlocal
