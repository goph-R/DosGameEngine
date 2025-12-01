@echo off
echo Compiling IMGTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling IMGTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS IMGTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
