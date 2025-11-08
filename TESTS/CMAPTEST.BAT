@echo off
echo Compiling MAPTEST and dependencies...
echo.

cd ..\UNITS

echo Compiling STRMAP.PAS...
tpc STRMAP.PAS
if errorlevel 1 goto error

echo Compiling MAPTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS MAPTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
