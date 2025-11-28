@echo off
REM Compile UITEST.PAS - VGAUI Test Program

echo Compiling VGAUI unit...
cd ..\UNITS
tpc VGAUI.PAS
if errorlevel 1 goto error

echo.
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
goto end

:end
