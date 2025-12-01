@echo off
echo Compiling TMXTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling TMXTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS TMXTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
