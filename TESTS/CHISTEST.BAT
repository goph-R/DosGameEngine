@echo off
echo Compiling HiScore Test...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling HISTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS HISTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
