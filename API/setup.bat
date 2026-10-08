@echo off
setlocal
cd /d "%~dp0"

set "PY="
where py >nul 2>nul && set "PY=py"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY goto no_python

where mysql >nul 2>nul && goto mysql_ready
for /d %%d in ("C:\Program Files\MySQL\MySQL Server *") do if exist "%%d\bin\mysql.exe" set "PATH=%%d\bin;%PATH%"
if exist "C:\xampp\mysql\bin\mysql.exe" set "PATH=C:\xampp\mysql\bin;%PATH%"
where mysql >nul 2>nul || goto no_mysql
:mysql_ready

if exist "venv\Scripts\python.exe" goto venv_ready
echo Creating virtual environment...
%PY% -m venv venv || goto fail
:venv_ready

echo Installing requirements...
"venv\Scripts\python.exe" -m pip install -q -r requirements.txt || goto fail

set "DB_HOST=localhost"
set "DB_PORT=3306"
set "DB_USER=root"
set "DB_NAME=reservation_system"
set "DBPW="
set /p DBPW=Enter the MySQL password for user root (press Enter if it has none): 
"venv\Scripts\python.exe" setup_env.py || goto fail

set "MYSQL_PWD=%DBPW%"
mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -e "SELECT 1" >nul 2>nul || goto no_connect
mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -e "CREATE DATABASE IF NOT EXISTS %DB_NAME% CHARACTER SET utf8mb4" || goto fail

if exist "Mysql\data.sql" (set "SQL=Mysql\data.sql") else (set "SQL=Mysql\001_fresh_schema.sql")

choice /c YN /m "Import %SQL% into %DB_NAME% now? Data from data.sql replaces existing tables"
if errorlevel 2 goto start_api
mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% --default-character-set=utf8mb4 %DB_NAME% < "%SQL%" || goto fail

:start_api
echo.
echo Starting the API on http://127.0.0.1:8000  (press Ctrl+C to stop)
"venv\Scripts\python.exe" -m uvicorn server:app --reload
goto end

:no_python
echo Python was not found. Install Python 3 from python.org and tick "Add to PATH", then run this again.
goto fail

:no_mysql
echo mysql.exe was not found. Install MySQL Server, or start XAMPP, then run this again.
echo If it is installed somewhere else, add its bin folder to PATH.
goto fail

:no_connect
echo Could not connect to MySQL as root on port 3306. Check that the MySQL service is running and the password is right.
goto fail

:fail
echo.
echo Setup stopped because of an error.
pause
exit /b 1

:end
endlocal
