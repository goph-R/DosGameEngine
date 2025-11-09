@echo off
echo Compiling TMAPTEST and dependencies...
echo.

cd ..\UNITS

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling VGAPRINT.PAS...
tpc VGAPRINT.PAS
if errorlevel 1 goto error

echo Compiling PKMLOAD.PAS...
tpc PKMLOAD.PAS
if errorlevel 1 goto error

echo Compiling STRMAP.PAS...
tpc STRMAP.PAS
if errorlevel 1 goto error

echo Compiling MINIXML.PAS...
tpc MINIXML.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
if errorlevel 1 goto error

echo Compiling TMXLOAD.PAS...
tpc TMXLOAD.PAS
if errorlevel 1 goto error

echo Compiling TMAPTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS TMAPTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
