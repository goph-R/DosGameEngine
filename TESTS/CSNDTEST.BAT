@echo off
echo Compiling SNDTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling SNDTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS SNDTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
