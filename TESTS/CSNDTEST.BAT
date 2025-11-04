@echo off
echo Compiling SNDTEST and dependencies...
echo.

cd ..\UNITS

echo Compiling XMS.PAS...
tpc XMS.PAS
if errorlevel 1 goto error

echo Compiling SBDSP.PAS...
tpc SBDSP.PAS
if errorlevel 1 goto error

echo Compiling SNDBANK.PAS...
tpc SNDBANK.PAS
if errorlevel 1 goto error

echo Compiling SNDTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS SNDTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
