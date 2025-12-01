@echo off
echo Compiling PCX Test...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling PCXTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS PCXTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
