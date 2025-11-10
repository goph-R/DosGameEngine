@echo off
echo Compiling SETUP and dependencies...
echo.

cd ..\UNITS

echo Compiling GENTYPES.PAS...
tpc GENTYPES.PAS
if errorlevel 1 goto error

echo Compiling STRUTIL.PAS...
tpc STRUTIL.PAS
if errorlevel 1 goto error

echo Compiling CONFIG.PAS...
tpc CONFIG.PAS
if errorlevel 1 goto error

echo Compiling KEYBOARD.PAS...
tpc KEYBOARD.PAS
if errorlevel 1 goto error

echo Compiling TEXTUI.PAS...
tpc TEXTUI.PAS
if errorlevel 1 goto error

echo Compiling PLAYHSC.PAS...
tpc PLAYHSC.PAS
if errorlevel 1 goto error

echo Compiling SBDSP.PAS...
tpc SBDSP.PAS
if errorlevel 1 goto error

echo Compiling VOCLOAD.PAS...
cd ..\SETUP
tpc -U..\UNITS VOCLOAD.PAS
if errorlevel 1 goto error

echo Compiling SETUP.PAS...
tpc -U..\UNITS SETUP.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\SETUP

:end
