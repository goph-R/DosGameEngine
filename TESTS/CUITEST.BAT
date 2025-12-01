@echo off
echo Compiling UITEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling UITEST.PAS...
cd ..\TESTS
tpc -U..\UNITS UITEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful! Run UITEST.EXE to test the UI system.
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
