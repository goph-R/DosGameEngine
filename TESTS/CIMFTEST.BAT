@echo off
echo Compiling IMF Music Player Test...
cd ..\UNITS
tpc PLAYIMF.PAS
if errorlevel 1 goto error
cd ..\TESTS
tpc -U..\UNITS IMFTEST.PAS
if errorlevel 1 goto error
echo.
echo Compilation successful!
echo.
echo Usage: IMFTEST filename.imf [rate] [loop]
echo   rate: 560 (Commander Keen) or 700 (Wolfenstein 3D)
echo   loop: Add "loop" to enable music looping
echo.
echo Example: IMFTEST ..\DATA\MUSIC.IMF 700 loop
echo.
echo See DOCS\MISC\IMFSRC.md for where to download IMF files
goto end

:error
echo.
echo Compilation failed!

:end
