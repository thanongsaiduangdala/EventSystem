@echo off
setlocal
cd /d "%~dp0"

where mysql >nul 2>nul && goto found
for /d %%d in ("C:\Program Files\MySQL\MySQL Server *") do if exist "%%d\bin\mysql.exe" set "PATH=%%d\bin;%PATH%"
if exist "C:\xampp\mysql\bin\mysql.exe" set "PATH=C:\xampp\mysql\bin;%PATH%"
where mysql >nul 2>nul || goto missing
:found

set "DB_HOST=localhost"
set "DB_PORT=3306"
set "DB_USER=root"
set "DB_PASSWORD="
set "DB_NAME=reservation_system"
for /f "usebackq tokens=1,* delims==" %%a in ("..\.env") do call :read "%%a" "%%b"
set "MYSQL_PWD=%DB_PASSWORD%"

mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -e "CREATE DATABASE IF NOT EXISTS %DB_NAME% CHARACTER SET utf8mb4"
if errorlevel 1 goto fail
mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% --default-character-set=utf8mb4 %DB_NAME% < data.sql
if errorlevel 1 goto fail
echo Imported Mysql\data.sql into %DB_NAME%
goto end

:read
if "%~1"=="DB_HOST" set "DB_HOST=%~2"
if "%~1"=="DB_PORT" set "DB_PORT=%~2"
if "%~1"=="DB_USER" set "DB_USER=%~2"
if "%~1"=="DB_PASSWORD" set "DB_PASSWORD=%~2"
if "%~1"=="DB_NAME" set "DB_NAME=%~2"
exit /b 0

:missing
echo mysql.exe was not found. Add the MySQL bin folder to PATH.
:fail
echo Import failed
pause
exit /b 1

:end
endlocal
