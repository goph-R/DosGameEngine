@echo off
echo Compiling UITEST and dependencies...
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

echo Compiling MINIXML.PAS...
tpc MINIXML.PAS
if errorlevel 1 goto error

echo Compiling LINKLIST.PAS...
tpc LINKLIST.PAS
if errorlevel 1 goto error

echo Compiling DRECT.PAS...
tpc DRECT.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling PCXLOAD.PAS...
tpc PCXLOAD.PAS
if errorlevel 1 goto error

echo Compiling VGAFONT.PAS...
tpc VGAFONT.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
if errorlevel 1 goto error

echo Compiling LOGGER.PAS...
tpc LOGGER.PAS
if errorlevel 1 goto error

echo Compiling VGAUI.PAS...
tpc VGAUI.PAS
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
