@echo off
echo Compiling BMPTEST.PAS...
tpc -U..\UNITS BMPTEST.PAS
if errorlevel 1 goto error
echo.
echo Compilation successful!
echo Run BMPTEST.EXE to test BMP image loading
goto end

:error
echo.
echo Compilation failed!

:end
