@echo off
echo Compiling SPRTEST and dependencies...
echo.

cd ..\UNITS

echo Compiling GENTYPES.PAS...
tpc GENTYPES.PAS
if errorlevel 1 goto error

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling VGAPRINT.PAS...
tpc VGAPRINT.PAS
if errorlevel 1 goto error

echo Compiling SPRITE.PAS...
tpc SPRITE.PAS
if errorlevel 1 goto error

echo Compiling PCXLOAD.PAS...
tpc PCXLOAD.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
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

echo Compiling VGAFONT.PAS...
tpc VGAFONT.PAS
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

echo Compiling RESMAN.PAS...
tpc RESMAN.PAS
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
