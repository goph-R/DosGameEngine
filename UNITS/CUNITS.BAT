@echo off
echo Compiling all engine units...
echo.

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

echo Compiling DELAY.PAS...
tpc DELAY.PAS
if errorlevel 1 goto error

echo Compiling MD5.PAS...
tpc MD5.PAS
if errorlevel 1 goto error

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling VGAPRINT.PAS...
tpc VGAPRINT.PAS
if errorlevel 1 goto error

echo Compiling DRECT.PAS...
tpc DRECT.PAS
if errorlevel 1 goto error

echo Compiling PCX.PAS...
tpc PCX.PAS
if errorlevel 1 goto error

echo Compiling BMP.PAS...
tpc BMP.PAS
if errorlevel 1 goto error

echo Compiling MINIXML.PAS...
tpc MINIXML.PAS
if errorlevel 1 goto error

echo Compiling HISCORE.PAS...
tpc HISCORE.PAS
if errorlevel 1 goto error

echo Compiling VGAFONT.PAS...
tpc VGAFONT.PAS
if errorlevel 1 goto error

echo Compiling SPRITE.PAS...
tpc SPRITE.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling MOUSE.PAS...
tpc MOUSE.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
if errorlevel 1 goto error

echo Compiling XMS.PAS...
tpc XMS.PAS
if errorlevel 1 goto error

echo Compiling SBDSP.PAS...
tpc SBDSP.PAS
if errorlevel 1 goto error

echo Compiling SNDBANK.PAS...
tpc SNDBANK.PAS
if errorlevel 1 goto error

echo Compiling PLAYHSC.PAS...
tpc PLAYHSC.PAS
if errorlevel 1 goto error

echo Compiling CONFIG.PAS...
tpc CONFIG.PAS
if errorlevel 1 goto error

echo Compiling TMXLOAD.PAS...
tpc TMXLOAD.PAS
if errorlevel 1 goto error

echo Compiling TMXDRAW.PAS...
tpc TMXDRAW.PAS
if errorlevel 1 goto error

echo Compiling TEXTUI.PAS...
tpc TEXTUI.PAS
if errorlevel 1 goto error

echo Compiling VGAUI.PAS...
tpc VGAUI.PAS
if errorlevel 1 goto error

echo Compiling LOGGER.PAS...
tpc LOGGER.PAS
if errorlevel 1 goto error

echo Compiling RESMAN.PAS...
tpc RESMAN.PAS
if errorlevel 1 goto error

echo Compiling MATHUTIL.PAS...
tpc MATHUTIL.PAS
if errorlevel 1 goto error

echo Compiling DGESCR.PAS...
tpc DGESCR.PAS
if errorlevel 1 goto error

echo Compiling DGECORE.PAS...
tpc DGECORE.PAS
if errorlevel 1 goto error

echo Compiling GAMEUNIT.PAS...
tpc GAMEUNIT.PAS
if errorlevel 1 goto error

echo.
echo All units compiled successfully!
goto end

:error
echo.
echo Unit compilation failed!

:end
