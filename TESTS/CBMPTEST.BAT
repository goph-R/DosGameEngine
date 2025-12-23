@echo off
echo Compiling BMP Test...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling BMPTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS BMPTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
