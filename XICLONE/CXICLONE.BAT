@echo off
echo Compiling XICLONE and dependencies...
echo.

cd ..\UNITS

echo Compiling GENTYPES.PAS...
tpc GENTYPES.PAS
if errorlevel 1 goto error

echo Compiling STRUTIL.PAS...
tpc STRUTIL.PAS
if errorlevel 1 goto error

echo Compiling STRMAP.PAS...
tpc STRMAP.PAS
if errorlevel 1 goto error

echo Compiling LINKLIST.PAS...
tpc LINKLIST.PAS
if errorlevel 1 goto error

echo Compiling MINIXML.PAS...
tpc MINIXML.PAS
if errorlevel 1 goto error

echo Compiling CONFIG.PAS...
tpc CONFIG.PAS
if errorlevel 1 goto error

echo Compiling SBDSP.PAS...
tpc SBDSP.PAS
if errorlevel 1 goto error

echo Compiling XMS.PAS...
tpc XMS.PAS
if errorlevel 1 goto error

echo Compiling SNDBANK.PAS...
tpc SNDBANK.PAS
if errorlevel 1 goto error

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling DRECT.PAS...
tpc DRECT.PAS
if errorlevel 1 goto error

echo Compiling PCX.PAS...
tpc PCX.PAS
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

echo Compiling VGAFONT.PAS...
tpc VGAFONT.PAS
if errorlevel 1 goto error

echo Compiling VGAUI.PAS...
tpc VGAUI.PAS
if errorlevel 1 goto error

echo Compiling XITYPES.PAS...
cd ..\XICLONE
tpc XITYPES.PAS
if errorlevel 1 goto error

echo Compiling XILOGIC.PAS...
tpc -U..\UNITS XILOGIC.PAS
if errorlevel 1 goto error

echo Compiling XIRENDER.PAS...
tpc -U..\UNITS XIRENDER.PAS
if errorlevel 1 goto error

echo Compiling XISTYLE.PAS...
tpc -U..\UNITS XISTYLE.PAS
if errorlevel 1 goto error

echo Compiling XICLONE.PAS...
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
