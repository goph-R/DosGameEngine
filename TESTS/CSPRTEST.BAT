@echo off
echo Compiling SPRTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling SPRTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS SPRTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
