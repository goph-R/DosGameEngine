@echo off
echo Compiling FNTTEST and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling FNTTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS FNTTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
