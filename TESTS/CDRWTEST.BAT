@echo off
echo Compiling DRWTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling DRWTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS DRWTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
