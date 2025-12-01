@echo off
echo Compiling MOUTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling MOUTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS MOUTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
