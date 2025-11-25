@echo off
echo Compiling PCX Test...
cd ..\UNITS
tpc PCXLOAD.PAS
if errorlevel 1 goto error
cd ..\TESTS
tpc -U..\UNITS PCXTEST.PAS
if errorlevel 1 goto error
echo.
echo Compilation successful!
echo Run PCXTEST.EXE to test PCX loading
goto end

:error
echo.
echo Compilation failed!

:end
