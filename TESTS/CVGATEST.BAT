@echo off
echo Compiling VGATEST and dependencies...
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

echo Compiling VGATEST.PAS...
cd ..\TESTS
tpc -U..\UNITS VGATEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
