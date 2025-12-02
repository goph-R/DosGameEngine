@echo off
echo Compiling XICLONE and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling XICLONE.PAS...
cd ..\XICLONE
tpc -U..\UNITS XICLONE.PAS
if errorlevel 1 goto error

echo.
echo Build successful! Run XICLONE.EXE to play the example game.
goto end

:error
echo.
echo Build failed!
cd ..\XICLONE

:end
