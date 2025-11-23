@echo off
echo Compiling XICLONE and dependencies...
echo.

cd ..\UNITS

echo Compiling GENTYPES.PAS...
tpc GENTYPES.PAS
if errorlevel 1 goto error

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling PKMLOAD.PAS...
tpc PKMLOAD.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
if errorlevel 1 goto error

echo Compiling VGAPRINT.PAS...
tpc VGAPRINT.PAS
if errorlevel 1 goto error

echo Compiling STRUTIL.PAS...
tpc STRUTIL.PAS
if errorlevel 1 goto error

echo Compiling XICLONE.PAS...
cd ..\XICLONE
tpc -U..\UNITS XICLONE.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
echo Run XICLONE.EXE to start the game
goto end

:error
echo.
echo Build failed!
cd ..\XICLONE

:end
