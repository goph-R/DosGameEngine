@echo off
echo Compiling IMGTEST and dependencies...
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

echo Compiling STRUTIL.PAS...
tpc STRUTIL.PAS
if errorlevel 1 goto error

echo Compiling CONFIG.PAS...
tpc CONFIG.PAS
if errorlevel 1 goto error

echo Compiling RTCTIMER.PAS...
tpc RTCTIMER.PAS
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
