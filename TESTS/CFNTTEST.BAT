@echo off
echo Compiling FNTTEST and dependencies...
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

echo Compiling VGA.PAS...
tpc VGA.PAS
if errorlevel 1 goto error

echo Compiling PCXLOAD.PAS...
tpc PCXLOAD.PAS
if errorlevel 1 goto error

echo Compiling VGAFONT.PAS...
tpc VGAFONT.PAS
if errorlevel 1 goto error

echo Compiling FNTTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS FNTTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
